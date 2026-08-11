/// Category of cosmetic shop items.
///
/// The `avatarFrame` and `hunterTitle` categories were removed from the shop
/// along with all of their items, leaving Profile Effects as the only
/// coin-purchased cosmetic category. (Fitness Plans and Skins are separate
/// systems with their own models and are unaffected.)
enum ShopItemCategory {
  profileEffect,
}

/// One cosmetic item in the Coin Shop.
///
/// This is a lightweight display-only model — there's NO inventory,
/// equipment, or item database. Ownership is tracked in Firestore as a
/// simple list of owned item IDs with an expiry timestamp.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.price,
    this.description,
    this.minLevel,
    this.coinDuration = const Duration(days: 7),
    this.adDuration = const Duration(days: 3),
  });

  /// Unique identifier (used for ownership tracking).
  final String id;

  /// Display name shown in the shop.
  final String name;

  /// Visual emoji/icon shown on the item card.
  final String emoji;

  /// Category this item belongs to.
  final ShopItemCategory category;

  /// Cost in coins.
  final int price;

  /// Optional description text.
  final String? description;

  /// Optional minimum hunter level required to see/purchase this item.
  final int? minLevel;

  /// Duration granted when purchased with coins.
  final Duration coinDuration;

  /// Duration granted when unlocked via rewarded ad.
  final Duration adDuration;
}

/// Static catalog of available shop items.
///
/// All 10 Leaderboard Effects cost 2,000 coins for 7 days, or 1 rewarded ad
/// for 3 days. They are temporary cosmetic unlocks that render ONLY on the
/// Global Leaderboard as a glowing name treatment and ambient energy.
class ShopCatalog {
  ShopCatalog._();

  static const List<ShopItem> allItems = [
    // ══════════════ LEADERBOARD EFFECTS ══════════════
    //
    // Each effect has a genuinely different visual identity on the leaderboard:
    // unique glow character, particle/energy style, motion style and name glow.
    // They share pricing (2,000 coins / 7 days, or 1 ad / 3 days) but NOT
    // visual treatment.
    ShopItem(
      id: 'effect_fire_aura',
      name: 'Fire Aura',
      emoji: '🔥',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Blazing flames engulf your name.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_frost_aura',
      name: 'Frost Aura',
      emoji: '❄️',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Crystalline ice radiates from your presence.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_lightning_aura',
      name: 'Lightning Aura',
      emoji: '⚡',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Electric energy crackles around your name.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_shadow_aura',
      name: 'Shadow Aura',
      emoji: '🌑',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Dark energy swirls in your wake.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_cosmic_aura',
      name: 'Cosmic Aura',
      emoji: '🌌',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Starlight and nebula surround you.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_aqua_aura',
      name: 'Aqua Aura',
      emoji: '🌊',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Flowing currents cascade from your name.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_nature_aura',
      name: 'Nature Aura',
      emoji: '🌿',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Living organic energy pulses around you.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_void_aura',
      name: 'Void Aura',
      emoji: '🕳️',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'The void consumes the space around your name.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_divine_aura',
      name: 'Divine Aura',
      emoji: '✨',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Radiant celestial light blesses your presence.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
    ShopItem(
      id: 'effect_soul_reaper_aura',
      name: 'Soul Reaper Aura',
      emoji: '👻',
      category: ShopItemCategory.profileEffect,
      price: 2000,
      description: 'Spectral spirits drift around your name.',
      coinDuration: Duration(days: 7),
      adDuration: Duration(days: 3),
    ),
  ];

  /// Returns all items the hunter is eligible to see based on their level.
  /// All effects are currently level-free (no minLevel gate).
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
