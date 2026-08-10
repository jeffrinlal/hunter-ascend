import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/models/shop_item.dart';
import 'package:hunter_ascend/services/coin_service.dart';

/// Shop purchase and ownership service.
///
/// Handles:
/// - Checking item ownership
/// - Purchasing items (deduct coins + mark as owned)
/// - Equipping items (future phase)
///
/// Ownership is stored in `hunters/{uid}` as simple arrays:
/// - `ownedAvatarFrames: List<String>`
/// - `ownedHunterTitles: List<String>`
/// - `ownedProfileEffects: List<String>`
///
/// NO inventory system, NO item stats, NO equipment bonuses — purely cosmetic.
class ShopService {
  ShopService._();
  static final ShopService instance = ShopService._();

  final _firestore = FirebaseFirestore.instance;

  /// Checks if the user owns a specific item.
  Future<bool> ownsItem(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final item = ShopCatalog.getItemById(itemId);
    if (item == null) return false;

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return false;

      final fieldName = _getOwnershipFieldName(item.category);
      final ownedList = List<String>.from(data[fieldName] ?? []);

      return ownedList.contains(itemId);
    } catch (e) {
      debugPrint('ShopService.ownsItem: $e');
      return false;
    }
  }

  /// Returns all owned item IDs for the current user across all categories.
  Future<Set<String>> getOwnedItems() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return {};

      final owned = <String>{};
      owned.addAll(List<String>.from(data['ownedAvatarFrames'] ?? []));
      owned.addAll(List<String>.from(data['ownedHunterTitles'] ?? []));
      owned.addAll(List<String>.from(data['ownedProfileEffects'] ?? []));

      return owned;
    } catch (e) {
      debugPrint('ShopService.getOwnedItems: $e');
      return {};
    }
  }

  /// Purchases an item.
  ///
  /// Returns true if successful, false if:
  /// - User not signed in
  /// - Item not found
  /// - Already owned
  /// - Insufficient coins
  /// - Transaction fails
  ///
  /// The purchase is atomic: coins are deducted AND item is marked as owned
  /// in a single transaction. If either fails, neither happens.
  Future<bool> purchaseItem(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final item = ShopCatalog.getItemById(itemId);
    if (item == null) return false;

    // Check if already owned (prevents duplicate purchases).
    if (await ownsItem(itemId)) return false;

    try {
      // Atomic transaction: deduct coins AND mark as owned.
      final success = await _firestore.runTransaction<bool>((txn) async {
        final ref = _firestore.collection('hunters').doc(uid);
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};

        // Check coin balance.
        int currentCoins = (data['coins'] ?? 0) as int;
        if (currentCoins < item.price) return false;

        // Deduct coins.
        currentCoins -= item.price;

        // Add to owned list.
        final fieldName = _getOwnershipFieldName(item.category);
        final ownedList = List<String>.from(data[fieldName] ?? []);
        if (ownedList.contains(itemId)) return false; // Double-check

        ownedList.add(itemId);

        txn.update(ref, {
          'coins': currentCoins,
          fieldName: ownedList,
        });

        return true;
      });

      return success;
    } catch (e) {
      debugPrint('ShopService.purchaseItem: $e');
      return false;
    }
  }

  /// Equips an item (sets it as the active cosmetic).
  ///
  /// Phase 1: Only the storage is implemented here. The actual visual
  /// rendering (avatar frames, titles, effects) will be added in future
  /// phases.
  ///
  /// Returns true if successful, false if:
  /// - User not signed in
  /// - Item not owned
  /// - Transaction fails
  Future<bool> equipItem(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final item = ShopCatalog.getItemById(itemId);
    if (item == null) return false;

    // Can only equip owned items.
    if (!await ownsItem(itemId)) return false;

    try {
      final fieldName = _getEquippedFieldName(item.category);
      await _firestore.collection('hunters').doc(uid).update({
        fieldName: itemId,
      });

      return true;
    } catch (e) {
      debugPrint('ShopService.equipItem: $e');
      return false;
    }
  }

  /// Gets the currently equipped item for a category.
  Future<String?> getEquippedItem(ShopItemCategory category) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('hunters').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;

      final fieldName = _getEquippedFieldName(category);
      return data[fieldName] as String?;
    } catch (e) {
      debugPrint('ShopService.getEquippedItem: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _getOwnershipFieldName(ShopItemCategory category) {
    switch (category) {
      case ShopItemCategory.avatarFrame:
        return 'ownedAvatarFrames';
      case ShopItemCategory.hunterTitle:
        return 'ownedHunterTitles';
      case ShopItemCategory.profileEffect:
        return 'ownedProfileEffects';
    }
  }

  String _getEquippedFieldName(ShopItemCategory category) {
    switch (category) {
      case ShopItemCategory.avatarFrame:
        return 'equippedAvatarFrame';
      case ShopItemCategory.hunterTitle:
        return 'equippedHunterTitle';
      case ShopItemCategory.profileEffect:
        return 'equippedProfileEffect';
    }
  }
}
