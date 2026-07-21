import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Raised when account cleanup cannot safely continue on the client.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Summary of the explicitly known Firestore data removed during account
/// deletion.
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.retainedAwardedAchievements,
  });

  /// Achievement claims with awarded XP deliberately retained as inaccessible
  /// orphan documents. Deleting them would let a future client retry a
  /// permanent XP grant, so Firestore rules only allow deletion before XP is
  /// awarded.
  final int retainedAwardedAchievements;
}

/// Removes the current user's explicitly known, private Firestore footprint.
///
/// Firestore client SDKs cannot enumerate or recursively delete arbitrary
/// subcollections. Keep every collection/subcollection that this method owns
/// explicit, and update this service when new user-owned paths are added.
/// Shared duel history is intentionally not changed here: it belongs to both
/// participants. Deletion is blocked while the caller has an active duel.
class AccountDeletionService {
  AccountDeletionService._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final AccountDeletionService instance = AccountDeletionService._();

  static const int _batchSize = 400;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Deletes only documents owned by [uid]. The caller must still be the
  /// currently authenticated user; Firestore rules enforce the same boundary.
  Future<AccountDeletionResult> deleteCurrentUserData(String uid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      throw const AccountDeletionException(
        'You must be signed in to delete this account.',
      );
    }

    await _ensureNoActiveDuels(uid);

    final hunter = _firestore.collection('hunters').doc(uid);
    final retainedAwardedAchievements = await hunter
        .collection('unlockedAchievements')
        .where('xpAwarded', isEqualTo: true)
        .get()
        .then((snapshot) => snapshot.size);

    // Delete root collections first. Each query repeats after a successful
    // commit, so this works for more than one Firestore write batch.
    await _deleteQuery(
      _firestore.collection('hunterNames').where('uid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('custom_quests').where('uid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('weight_history').where('uid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('runs').where('uid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('calorie_logs').where('uid', isEqualTo: uid),
    );

    // A pending invitation can be removed by either participant. Shared duel
    // documents are not deleted or anonymized on the client.
    await _deleteQuery(
      _firestore.collection('duel_requests').where('fromUid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('duel_requests').where('toUid', isEqualTo: uid),
    );

    // Firestore parent deletion does not cascade. These known child
    // collections must be cleared before deleting hunters/{uid}.
    await _deleteQuery(hunter.collection('rankRewards'));
    await _deleteQuery(hunter.collection('equippedRewards'));
    await _deleteQuery(
      hunter
          .collection('unlockedAchievements')
          .where('xpAwarded', isEqualTo: false),
    );

    await hunter.delete();

    debugPrint(
      'Account deletion Firestore cleanup completed for $uid; '
      'retained awarded achievements: $retainedAwardedAchievements.',
    );
    return AccountDeletionResult(
      retainedAwardedAchievements: retainedAwardedAchievements,
    );
  }

  Future<void> _ensureNoActiveDuels(String uid) async {
    // Query each known participant field separately rather than requiring a
    // composite index with status. The status filter is applied locally.
    final results = await Future.wait([
      _firestore.collection('duels').where('player1', isEqualTo: uid).get(),
      _firestore.collection('duels').where('player2', isEqualTo: uid).get(),
      // Include the participant list for legacy documents that might not have
      // both dedicated player fields.
      _firestore
          .collection('duels')
          .where('participants', arrayContains: uid)
          .get(),
    ]);

    final hasActiveDuel = results.any(
      (snapshot) => snapshot.docs.any(
        (document) => document.data()['status'] == 'active',
      ),
    );
    if (hasActiveDuel) {
      throw const AccountDeletionException(
        'Finish or cancel your active duel before deleting your account. '
        'Shared duel records are retained to preserve the other participant\'s '
        'history.',
      );
    }
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(_batchSize).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < _batchSize) return;
    }
  }
}
