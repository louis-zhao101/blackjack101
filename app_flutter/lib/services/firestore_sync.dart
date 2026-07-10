import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../engine/stats.dart';

/// Result of attempting to redeem an invite code.
enum ReferralRedeemOutcome { success, invalid, ownCode, already, error }

/// Cloud persistence on Firestore, replacing the Supabase `sync.ts` layer.
///
/// Data model:
///   users/{uid}                       -> { bankroll, ownedProducts, achievements,
///                                           strategyCells, drill, learnProgress,
///                                           appearance, cardBack, chipStyle, updatedAt }
///   users/{uid}/sessions/{sessionId}  -> Session.toJson()
class FirestoreSync {
  final FirebaseFirestore _db;
  FirestoreSync([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) =>
      _userDoc(uid).collection('sessions');

  Future<void> upsertSession(String uid, Session session) {
    return _sessionsCol(uid).doc(session.id).set(session.toJson());
  }

  Future<void> upsertProfile(String uid, int bankroll) {
    return _userDoc(uid).set(
      {'bankroll': bankroll, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Mirrors the user's owned à la carte cosmetics into their profile so they
  /// sync across devices. RevenueCat remains the payment source of truth; this
  /// is a convenience cache. The Pro/lifetime entitlement is intentionally NOT
  /// stored here — Pro is always resolved live from RevenueCat.
  Future<void> upsertOwnedProducts(String uid, Set<String> ownedProducts) {
    return _userDoc(uid).set(
      {
        'ownedProducts': ownedProducts.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Mirrors the user's unlocked achievement ids into their profile so they
  /// follow the account across devices. Local storage stays the source of truth;
  /// this is a union-merged convenience cache.
  Future<void> upsertAchievements(String uid, Set<String> achievementIds) {
    return _userDoc(uid).set(
      {
        'achievements': achievementIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Per-cell strategy accuracy (chart cell key -> [correct, total]). Local is
  /// the source of truth; this is a cross-device convenience cache, stored as a
  /// JSON string since cell keys contain characters awkward as map field names.
  Future<void> upsertStrategyCells(String uid, Map<String, (int, int)> cells) {
    final encoded = jsonEncode(cells.map((k, v) => MapEntry(k, [v.$1, v.$2])));
    return _userDoc(uid).set(
      {'strategyCells': encoded, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Lifetime Test Yourself drill stats, mirrored so practice progress and its
  /// achievements follow the account across devices.
  Future<void> upsertDrillStats(
    String uid, {
    required int total,
    required int correct,
    required int bestStreak,
    required Set<String> attempted,
    required List<bool> recent,
  }) {
    return _userDoc(uid).set(
      {
        'drill': {
          'total': total,
          'correct': correct,
          'bestStreak': bestStreak,
          'attempted': attempted.toList(),
          'recent': recent.map((b) => b ? '1' : '0').join(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Completed Learn lesson ids, mirrored so progress follows the account.
  Future<void> upsertLearnProgress(String uid, Set<String> lessonIds) {
    return _userDoc(uid).set(
      {'learnProgress': lessonIds.toList(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// The user's selected cosmetics (table felt, card back, chip palette) so a
  /// signed-in look follows them across devices. Only non-null fields are written.
  Future<void> upsertCosmeticSelection(
    String uid, {
    String? appearance,
    String? cardBack,
    String? chipStyle,
  }) {
    return _userDoc(uid).set(
      {
        'appearance': ?appearance,
        'cardBack': ?cardBack,
        'chipStyle': ?chipStyle,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Live stream of the user's cosmetic selection from their profile doc, so a
  /// theme picked on one device follows them to the others without a restart.
  /// De-duped so unrelated profile writes (bankroll, stats) don't re-emit.
  Stream<({String? appearance, String? cardBack, String? chipStyle})> watchCosmeticSelection(
      String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final d = snap.data() ?? const <String, dynamic>{};
      return (
        appearance: d['appearance'] as String?,
        cardBack: d['cardBack'] as String?,
        chipStyle: d['chipStyle'] as String?,
      );
    }).distinct();
  }

  /// Clears the user's stats history from the cloud: deletes every session and
  /// wipes the strategy-cell heatmap, while leaving the profile (bankroll,
  /// cosmetics, achievements) intact. Backs the "Clear stats history" action.
  Future<void> clearStatsHistory(String uid) async {
    final sessions = await _sessionsCol(uid).get();
    final batch = _db.batch();
    for (final doc in sessions.docs) {
      batch.delete(doc.reference);
    }
    batch.set(
      _userDoc(uid),
      {'strategyCells': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // --- Referrals ----------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _codesCol =>
      _db.collection('referral_codes');
  CollectionReference<Map<String, dynamic>> get _referralsCol =>
      _db.collection('referrals');

  // Unambiguous alphabet (no 0/O/1/I/L) for codes people read aloud/retype.
  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _genCode([Random? rng]) {
    final r = rng ?? Random();
    return List.generate(6, (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)]).join();
  }

  /// Returns the user's referral code, generating and registering a unique one
  /// on first call. Idempotent — later calls return the stored code.
  Future<String> ensureReferralCode(String uid) async {
    final existing = (await _userDoc(uid).get()).data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    for (var attempt = 0; attempt < 6; attempt++) {
      final code = _genCode();
      final codeRef = _codesCol.doc(code);
      if ((await codeRef.get()).exists) continue;
      final batch = _db.batch();
      batch.set(codeRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
      batch.set(
        _userDoc(uid),
        {'referralCode': code, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();
      return code;
    }
    throw StateError('Could not allocate a referral code');
  }

  /// Records that [refereeUid] was referred via [rawCode], setting their
  /// `referredBy` and writing a referral record the referrer can count. Enforces
  /// the code exists, isn't the user's own, and hasn't already been redeemed.
  Future<ReferralRedeemOutcome> redeemReferral(String refereeUid, String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return ReferralRedeemOutcome.invalid;
    try {
      final referrer = (await _codesCol.doc(code).get()).data()?['uid'] as String?;
      if (referrer == null) return ReferralRedeemOutcome.invalid;
      if (referrer == refereeUid) return ReferralRedeemOutcome.ownCode;

      final already = (await _userDoc(refereeUid).get()).data()?['referredBy'] as String?;
      if (already != null) return ReferralRedeemOutcome.already;

      final batch = _db.batch();
      batch.set(
        _userDoc(refereeUid),
        {'referredBy': referrer, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      batch.set(_referralsCol.doc(refereeUid), {
        'referrer': referrer,
        'code': code,
        'at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return ReferralRedeemOutcome.success;
    } catch (_) {
      return ReferralRedeemOutcome.error;
    }
  }

  /// How many people have redeemed [uid]'s code.
  Future<int> countReferrals(String uid) async {
    final agg = await _referralsCol.where('referrer', isEqualTo: uid).count().get();
    return agg.count ?? 0;
  }

  /// One-shot fetch of everything the Invite Friends UI needs: the user's own
  /// code, who (if anyone) referred them, how many they've referred, and whether
  /// their referrer reward has already been claimed (so it's granted only once).
  Future<({String code, String? referredBy, int referralCount, bool referrerRewarded})>
      loadReferralInfo(String uid) async {
    final code = await ensureReferralCode(uid);
    final data = (await _userDoc(uid).get()).data() ?? const <String, dynamic>{};
    final count = await countReferrals(uid);
    return (
      code: code,
      referredBy: data['referredBy'] as String?,
      referralCount: count,
      referrerRewarded: (data['referrerRewarded'] as bool?) ?? false,
    );
  }

  /// Marks the referrer reward as claimed so it is never granted twice, even
  /// across devices (the reward is "the next card back you don't own", so
  /// re-granting would hand out a new back on every launch).
  Future<void> markReferrerRewarded(String uid) {
    return _userDoc(uid).set(
      {'referrerRewarded': true, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Permanently removes the user's profile and all their sessions.
  Future<void> deleteUserData(String uid) async {
    final sessions = await _sessionsCol(uid).get();
    final batch = _db.batch();
    for (final doc in sessions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_userDoc(uid));
    await batch.commit();
  }

  Future<
      ({
        int? bankroll,
        List<Session> sessions,
        Set<String> ownedProducts,
        Set<String> achievements,
        Map<String, (int, int)> strategyCells,
        ({int total, int correct, int bestStreak, Set<String> attempted, List<bool> recent})?
            drill,
        Set<String> learnProgress,
        String? appearance,
        String? cardBack,
        String? chipStyle,
      })> loadUserData(String uid) async {
    final profileFut = _userDoc(uid).get();
    final sessionsFut =
        _sessionsCol(uid).orderBy('startTime', descending: true).limit(50).get();
    final results = await Future.wait([profileFut, sessionsFut]);

    final profile = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final sessionsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final data = profile.data() ?? const {};

    final bankroll = data['bankroll'];
    final owned =
        (data['ownedProducts'] as List?)?.map((e) => e as String).toSet() ?? <String>{};
    final achievements =
        (data['achievements'] as List?)?.map((e) => e as String).toSet() ?? <String>{};
    final learnProgress =
        (data['learnProgress'] as List?)?.map((e) => e as String).toSet() ?? <String>{};
    final sessions = sessionsSnap.docs.map((d) => Session.fromJson(d.data())).toList();

    var strategyCells = <String, (int, int)>{};
    final rawCells = data['strategyCells'];
    if (rawCells is String && rawCells.isNotEmpty) {
      final decoded = jsonDecode(rawCells) as Map<String, dynamic>;
      strategyCells = decoded.map((k, v) {
        final list = (v as List).cast<num>();
        return MapEntry(k, (list[0].toInt(), list[1].toInt()));
      });
    }

    ({int total, int correct, int bestStreak, Set<String> attempted, List<bool> recent})? drill;
    final rawDrill = data['drill'];
    if (rawDrill is Map) {
      final recentStr = (rawDrill['recent'] as String?) ?? '';
      drill = (
        total: (rawDrill['total'] as num?)?.toInt() ?? 0,
        correct: (rawDrill['correct'] as num?)?.toInt() ?? 0,
        bestStreak: (rawDrill['bestStreak'] as num?)?.toInt() ?? 0,
        attempted: ((rawDrill['attempted'] as List?) ?? const []).map((e) => e as String).toSet(),
        recent: recentStr.split('').map((c) => c == '1').toList(),
      );
    }

    return (
      bankroll: bankroll == null ? null : (bankroll as num).toInt(),
      sessions: sessions,
      ownedProducts: owned,
      achievements: achievements,
      strategyCells: strategyCells,
      drill: drill,
      learnProgress: learnProgress,
      appearance: data['appearance'] as String?,
      cardBack: data['cardBack'] as String?,
      chipStyle: data['chipStyle'] as String?,
    );
  }
}
