import 'package:cloud_firestore/cloud_firestore.dart';

import '../engine/stats.dart';

/// Cloud persistence on Firestore, replacing the Supabase `sync.ts` layer.
///
/// Data model:
///   users/{uid}                       -> { bankroll, updatedAt }
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

  Future<({int? bankroll, List<Session> sessions})> loadUserData(String uid) async {
    final profileFut = _userDoc(uid).get();
    final sessionsFut =
        _sessionsCol(uid).orderBy('startTime', descending: true).limit(50).get();
    final results = await Future.wait([profileFut, sessionsFut]);

    final profile = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final sessionsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

    final bankroll = profile.data()?['bankroll'];
    final sessions = sessionsSnap.docs.map((d) => Session.fromJson(d.data())).toList();

    return (
      bankroll: bankroll == null ? null : (bankroll as num).toInt(),
      sessions: sessions,
    );
  }
}
