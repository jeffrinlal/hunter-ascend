/// Identifies each available UI skin.
///
/// Unlike [AppTheme] (color-only), each [SkinId] can have a fully custom
/// layout per screen — see [SkinnableScreen].
///
/// The metadata for each id (name, description, pricing, durations, rarity)
/// lives in `SkinCatalog` (see `skin_catalog.dart`), NOT here — this enum is
/// purely an identifier. Adding a new skin means: add a value here, then add
/// a matching `SkinData` entry to `SkinCatalog.all`.
enum SkinId {
  classic, // the default UI — always free, permanent, never expires
  shadowMonarch,
  cyberHunter,
  frostborn,
  inferno;

  static SkinId fromId(String? id) {
    if (id == null || id.isEmpty) return SkinId.classic;
    for (final s in SkinId.values) {
      if (s.name == id) return s;
    }
    return SkinId.classic;
  }
}

/// Screens that support skin-specific layouts.
enum SkinnableScreen { dashboard, duel, leaderboard, profile, missions }