/// Category of cosmetic shop items.
enum ShopItemCategory {
  avatarFrame,
  hunterTitle,
  profileEffect,
}

/// One cosmetic item in the Coin Shop.
///
/// This is a lightweight display-only model — there's NO inventory,
/// equipment, or item database. Ownership is tracked in Firestore as a
/// simple list of owned item IDs.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.price,
    this.description,
    this.minLevel,
  });

  /// Unique identifier (used for ownership tracking).
  final String id;

  /// Display name shown in the shop.
  final String name;

  /// Visual emoji/icon shown on the item card.
  final String emoji;

  /// Category this item belongs to.
  final ShopItemCategory category;

  /// Cost in coins (minimum 400 coins per design requirement).
  final int price;

  /// Optional description text.
  final String? description;

  /// Optional minimum hunter level required to see/purchase this item.
  final int? minLevel;
}

/// Static catalog of available shop items.
///
/// This is Phase 1 foundation — only a small sample catalog to validate
/// the architecture. Future phases will expand the catalog.
class ShopCatalog {
  ShopCatalog._();

  static const List<ShopItem> allItems = [
    // ── Avatar Frames ──────────────────────────────────────────────────
    ShopItem(
      id: 'frame_bronze_shield',
      name: 'Bronze Shield',
      emoji: '🛡️',
      category: ShopItemCategory.avatarFrame,
      price: 400,
      description: 'A sturdy bronze frame for dedicated hunters.',
    ),
    ShopItem(
      id: 'frame_silver_star',
      name: 'Silver Star',
      emoji: '⭐',
      category: ShopItemCategory.avatarFrame,
      price: 750,
      description: 'A shining silver star frame.',
      minLevel: 10,
    ),
    ShopItem(
      id: 'frame_gold_crown',
      name: 'Golden Crown',
      emoji: '👑',
      category: ShopItemCategory.avatarFrame,
      price: 1200,
      description: 'The mark of true royalty.',
      minLevel: 20,
    ),

    // ── Hunter Titles ──────────────────────────────────────────────────
    ShopItem(
      id: 'title_iron_fist',
      name: 'Iron Fist',
      emoji: '✊',
      category: ShopItemCategory.hunterTitle,
      price: 500,
      description: 'Earned through unwavering determination.',
    ),
    ShopItem(
      id: 'title_storm_bringer',
      name: 'Storm Bringer',
      emoji: '⚡',
      category: ShopItemCategory.hunterTitle,
      price: 900,
      description: 'Those who master the elements.',
      minLevel: 15,
    ),
    ShopItem(
      id: 'title_shadow_walker',
      name: 'Shadow Walker',
      emoji: '🌑',
      category: ShopItemCategory.hunterTitle,
      price: 2000,
      description: 'Move unseen, strike unheard.',
      minLevel: 35,
    ),

    // ── Profile Effects ────────────────────────────────────────────────
    ShopItem(
      id: 'effect_fire_aura',
      name: 'Fire Aura',
      emoji: '🔥',
      category: ShopItemCategory.profileEffect,
      price: 800,
      description: 'Burn bright with fiery determination.',
    ),
    ShopItem(
      id: 'effect_ice_shield',
      name: 'Ice Shield',
      emoji: '❄️',
      category: ShopItemCategory.profileEffect,
      price: 1500,
      description: 'Cool, calm, unbreakable.',
      minLevel: 25,
    ),
    ShopItem(
      id: 'effect_lightning_strike',
      name: 'Lightning Strike',
      emoji: '⚡',
      category: ShopItemCategory.profileEffect,
      price: 3000,
      description: 'The power of the storm itself.',
      minLevel: 50,
    ),
  ];

  /// Returns all items the hunter is eligible to see based on their level.
  static List<ShopItem> getAvailableItems(int hunterLevel) {
    return allItems
        .where((item) => item.minLevel == null || hunterLevel >= item.minLevel!)
        .toList();
  }

  /// Returns items filtered by category.
  static List<ShopItem> getItemsByCategory(
    ShopItemCategory category,
    int hunterLevel,
  ) {
    return getAvailableItems(hunterLevel)
        .where((item) => item.category == category)
        .toList();
  }

  /// Finds an item by its ID.
  static ShopItem? getItemById(String id) {
    try {
      return allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
