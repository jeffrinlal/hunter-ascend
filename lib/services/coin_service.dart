import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Centralized coin balance service.
///
/// Coins are a persistent cosmetic currency earned from Dungeon clears.
/// The balance NEVER resets — it's permanent across daily Dungeon resets.
///
/// Architecture:
/// - Stored in `hunters/{uid}` as `coins: int`
/// - Updated via Firestore transaction on Dungeon claim
/// - Deducted via transaction on shop purchases
/// - Basic/Pro/Max all use the SAME economy (no membership bonuses)
class CoinService {
  CoinService._();
  static final CoinService instance = CoinService._();

  final _firestore = FirebaseFirestore.instance;

  /// Awards coins to the current user atomically via a Firestore transaction.
  ///
  /// Used by Dungeon clear claim to add the reward coins to the persistent
  /// balance. Returns the new balance, or null if no user is signed in or
  /// the transaction fails.
  Future<int?> awardCoins({required int amount}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final ref = _firestore.collection('hunters').doc(uid);

    try {
      final result = await _firestore.runTransaction<int>((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};

        int currentCoins = (data['coins'] ?? 0) as int;
        currentCoins += amount;

        txn.update(ref, {'coins': currentCoins});

        return currentCoins;
      });

      return result;
    } catch (e) {
      debugPrint('CoinService.awardCoins: $e');
      return null;
    }
  }

  /// Spends coins for a shop purchase atomically.
  ///
  /// Returns the new balance if successful, or null if:
  /// - No user is signed in
  /// - Insufficient coins
  /// - Transaction fails
  ///
  /// The caller is responsible for marking the item as owned after a
  /// successful purchase (this method only handles the coin deduction).
  Future<int?> spendCoins({required int amount}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final ref = _firestore.collection('hunters').doc(uid);

    try {
      final result = await _firestore.runTransaction<int?>((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};

        int currentCoins = (data['coins'] ?? 0) as int;
        if (currentCoins < amount) return null; // Insufficient coins

        currentCoins -= amount;

        txn.update(ref, {'coins': currentCoins});

        return currentCoins;
      });

      return result;
    } catch (e) {
      debugPrint('CoinService.spendCoins: $e');
      return null;
    }
  }

  /// Gets the current coin balance for the signed-in user.
  ///
  /// Returns 0 if no user is signed in or the document doesn't exist.
  Future<int> getCurrentBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return 0;

      return (data['coins'] ?? 0) as int;
    } catch (e) {
      debugPrint('CoinService.getCurrentBalance: $e');
      return 0;
    }
  }
}
