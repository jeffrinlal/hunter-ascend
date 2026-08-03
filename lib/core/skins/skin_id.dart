/// Identifies each available UI skin.
///
/// Unlike [AppTheme] (color-only), each [SkinId] can have a fully custom
/// layout per screen — see [SkinRegistry].
enum SkinId {
  classic; // the current default UI — always free, never expires

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