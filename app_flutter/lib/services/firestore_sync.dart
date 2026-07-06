import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../engine/stats.dart';

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
