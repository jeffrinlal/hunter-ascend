import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/models/shop_item.dart';

/// Shop purchase, ownership and equip service for Leaderboard Effects.
///
/// Effects are TEMPORARY: purchased with coins for [ShopItem.coinDuration] or
/// unlocked via a rewarded ad for [ShopItem.adDuration]. Ownership is tracked
/// in `hunters/{uid}` as:
///
/// - `ownedProfileEffects: List<String>` — all effect IDs ever unlocked
/// - `equippedProfileEffect: String` — the currently equipped effect ID
/// - `effectExpiry: String` — ISO 8601 expiry of the currently active unlock
///
/// When an effect expires, it must stop rendering on the leaderboard. The
/// leaderboard checks expiry from the already-loaded data (no new read).
/// The shop UI shows remaining days and allows re-unlock.
///
/// Purchase transactions remain atomic (coins deducted + expiry set in one
/// transaction). Rewarded ad unlocks write only after the ad reward callback.
///
/// NO inventory system, NO item stats, NO equipment bonuses — purely cosmetic.
class ShopService {
  ShopService._();
  static final ShopService instance = ShopService._();

  final _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // OWNERSHIP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns all owned item IDs for the current user.
  Future<Set<String>> getOwnedItems() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return {};

      final owned = <String>{};
      owned.addAll(List<String>.from(data['ownedProfileEffects'] ?? []));

      return owned;
    } catch (e) {
      debugPrint('ShopService.getOwnedItems: $e');
      return {};
    }
  }

  /// Gets the currently equipped effect ID.
  Future<String?> getEquippedItem(ShopItemCategory category) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;

      return data[_getEquippedFieldName(category)] as String?;
    } catch (e) {
      debugPrint('ShopService.getEquippedItem: $e');
      return null;
    }
  }

  /// Gets the effect expiry as a DateTime, or null if not set / expired.
  Future<DateTime?> getEffectExpiry() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;

      final expiryStr = data['effectExpiry']?.toString();
      if (expiryStr == null) return null;
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null || DateTime.now().isAfter(expiry)) return null;
      return expiry;
    } catch (e) {
      debugPrint('ShopService.getEffectExpiry: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COIN PURCHASE (atomic transaction)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Purchases an effect with coins for [ShopItem.coinDuration].
  ///
  /// Atomic: coins are deducted, effect is equipped, and expiry is set in a
  /// single transaction. If insufficient coins or the transaction fails,
  /// nothing happens.
  ///
  /// Returns true if successful.
  Future<bool> purchaseItem(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final item = ShopCatalog.getItemById(itemId);
    if (item == null) return false;

    try {
      final success = await _firestore.runTransaction<bool>((txn) async {
        final ref = _firestore.collection('hunters').doc(uid);
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};

        // Check coin balance.
        int currentCoins = (data['coins'] ?? 0) as int;
        if (currentCoins < item.price) return false;

        // Deduct coins.
        currentCoins -= item.price;

        // Add to owned list (idempotent — keeps history of all unlocked effects).
        final ownedList =
            List<String>.from(data['ownedProfileEffects'] ?? []);
        if (!ownedList.contains(itemId)) {
          ownedList.add(itemId);
        }

        // Compute expiry from NOW + coinDuration.
        final expiry =
            DateTime.now().add(item.coinDuration).toIso8601String();

        txn.update(ref, {
          'coins': currentCoins,
          'ownedProfileEffects': ownedList,
          'equippedProfileEffect': itemId,
          'effectExpiry': expiry,
        });

        return true;
      });

      return success;
    } catch (e) {
      debugPrint('ShopService.purchaseItem: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AD UNLOCK (rewarded ad callback)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Unlocks an effect via rewarded ad for [ShopItem.adDuration].
  ///
  /// MUST only be called after the rewarded ad's onUserEarnedReward callback.
  /// This is NOT triggered merely by opening/showing the ad.
  ///
  /// Returns true if successful.
  Future<bool> unlockWithAd(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final item = ShopCatalog.getItemById(itemId);
    if (item == null) return false;

    try {
      final ref = _firestore.collection('hunters').doc(uid);
      final doc = await ref.get();
      final data = doc.data() ?? {};

      // Add to owned list (idempotent).
      final ownedList =
          List<String>.from(data['ownedProfileEffects'] ?? []);
      if (!ownedList.contains(itemId)) {
        ownedList.add(itemId);
      }

      // Compute expiry from NOW + adDuration.
      final expiry = DateTime.now().add(item.adDuration).toIso8601String();

      await ref.update({
        'ownedProfileEffects': ownedList,
        'equippedProfileEffect': itemId,
        'effectExpiry': expiry,
      });

      return true;
    } catch (e) {
      debugPrint('ShopService.unlockWithAd: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EQUIP (switch between already-owned effects)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Equips an already-owned effect. The expiry is NOT changed — the hunter
  /// keeps whatever remaining time they had. If the effect is expired, this
  /// will NOT re-activate it; the caller must purchase/ad-unlock again.
  ///
  /// Returns true if successful.
  Future<bool> equipItem(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final item = ShopCatalog.getItemById(itemId);
    if (item == null) return false;

    try {
      await _firestore.collection('hunters').doc(uid).update({
        'equippedProfileEffect': itemId,
      });

      return true;
    } catch (e) {
      debugPrint('ShopService.equipItem: $e');
      return false;
    }
  }

  // NOTE: no explicit "unequip" is needed. An expired effect stops rendering
  // automatically because the leaderboard resolves it through
  // `LeaderboardEntry.activeEffect`, which returns null once `effectExpiry`
  // has passed. That check is a pure local DateTime comparison on data the
  // leaderboard already loaded, so expiry costs no read and no write.

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _getEquippedFieldName(ShopItemCategory category) {
    switch (category) {
      case ShopItemCategory.profileEffect:
        return 'equippedProfileEffect';
    }
  }
}
