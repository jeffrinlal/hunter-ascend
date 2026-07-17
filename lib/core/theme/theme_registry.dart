import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Central registry of all available dark-mode themes.
///
/// Adding a new theme requires only adding one [AppThemeData] entry to
/// [allThemes]. The gallery, persistence, and membership validation all
/// derive their data from this single list — no business logic changes needed.
class ThemeRegistry {
  ThemeRegistry._();

  /// The default dark theme applied when no premium theme is selected or
  /// when the user's membership no longer covers their selected theme.
  static const AppThemeData defaultDarkTheme = _dark;

  /// All available dark-mode themes in display order.
  static const List<AppThemeData> allThemes = [
    _dark,
    _shadowBlue,
    _crimsonRed,
    _emeraldGreen,
    _sunsetOrange,
    _shadowMonarch,
    _royalGold,
    _obsidianBlack,
    _neonCyber,
  ];

  /// Returns the [AppThemeData] for the given [AppTheme] enum value.
  /// Falls back to [defaultDarkTheme] if not found (should never happen
  /// unless a theme was removed without updating the enum).
  static AppThemeData getByTheme(AppTheme theme) {
    for (final t in allThemes) {
      if (t.theme == theme) return t;
    }
    return defaultDarkTheme;
  }

  /// Returns all themes that require the given [tier].
  static List<AppThemeData> themesForTier(MembershipTier tier) {
    return allThemes.where((t) => t.requiredTier == tier).toList();
  }

  // ── Theme Definitions ──────────────────────────────────────────────────

  /// Original dark theme — unchanged.
  static const _dark = AppThemeData(
    theme: AppTheme.dark,
    name: 'Dark',
    description: 'The original hunter\'s interface. Cyan precision on deep black.',
    requiredTier: MembershipTier.basic,
    background: Color(0xFF080C14),
    surface: Color(0xFF0D1620),
    card: Color(0xFF111523),
    primary: Color(0xFF00E5FF),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFB8C2D9),
    textTertiary: Color(0xFF8898BB),
    textFaint: Color(0xFF5A6478),
    border: Color(0xFF1E2D4A),
  );

  /// Shadow Blue — Inspired by Linear and GitHub Dark.
  /// Neutral slate-grey base with a desaturated steel-blue accent.
  /// Designed for long coding/reading sessions.
  static const _shadowBlue = AppThemeData(
    theme: AppTheme.shadowBlue,
    name: 'Shadow Blue',
    description: 'Quiet precision. A slate canvas with steel-blue focus.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF0F1114),
    surface: Color(0xFF16181D),
    card: Color(0xFF1C1F25),
    primary: Color(0xFF6B9FCC),
    textPrimary: Color(0xFFE2E6EB),
    textSecondary: Color(0xFF9BA4B2),
    textTertiary: Color(0xFF6B7280),
    textFaint: Color(0xFF4B5058),
    border: Color(0xFF282C34),
  );

  /// Crimson Red — Inspired by dark IDEs with warm red accents.
  /// Neutral charcoal base with a muted rose accent. Not aggressive.
  static const _crimsonRed = AppThemeData(
    theme: AppTheme.crimsonRed,
    name: 'Crimson Red',
    description: 'Controlled intensity. Charcoal depth with muted rose.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF111113),
    surface: Color(0xFF1A1A1D),
    card: Color(0xFF212124),
    primary: Color(0xFFE06C75),
    textPrimary: Color(0xFFE8E4E4),
    textSecondary: Color(0xFFA8A0A0),
    textTertiary: Color(0xFF787070),
    textFaint: Color(0xFF524C4C),
    border: Color(0xFF2E2A2A),
  );

  /// Emerald Green — Inspired by terminal aesthetics and Spotify's dark UI.
  /// Near-black neutral base with a soft sage-green accent.
  static const _emeraldGreen = AppThemeData(
    theme: AppTheme.emeraldGreen,
    name: 'Emerald Green',
    description: 'Calm focus. Deep black with soft sage accents.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF0E1110),
    surface: Color(0xFF151917),
    card: Color(0xFF1C201E),
    primary: Color(0xFF6BCB8B),
    textPrimary: Color(0xFFE4EBE7),
    textSecondary: Color(0xFF9EAAA2),
    textTertiary: Color(0xFF6E7A74),
    textFaint: Color(0xFF4A5450),
    border: Color(0xFF272E2A),
  );

  /// Sunset Orange — Inspired by Arc Browser's warm dark mode.
  /// Warm-neutral base with a muted amber accent. Cozy evening feel.
  static const _sunsetOrange = AppThemeData(
    theme: AppTheme.sunsetOrange,
    name: 'Sunset Orange',
    description: 'Warm evenings. A cozy warmth with amber glow.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF131210),
    surface: Color(0xFF1B1917),
    card: Color(0xFF22201D),
    primary: Color(0xFFD4915C),
    textPrimary: Color(0xFFEBE6E1),
    textSecondary: Color(0xFFADA49A),
    textTertiary: Color(0xFF7D756C),
    textFaint: Color(0xFF565048),
    border: Color(0xFF302B26),
  );

  /// Shadow Monarch — Inspired by Discord's dark theme with purple accents.
  /// Cool neutral-grey base with a refined lavender accent. Regal without
  /// being overwhelming.
  static const _shadowMonarch = AppThemeData(
    theme: AppTheme.shadowMonarch,
    name: 'Shadow Monarch',
    description: 'Quiet dominion. Cool grey with refined lavender.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF101014),
    surface: Color(0xFF17171D),
    card: Color(0xFF1E1E26),
    primary: Color(0xFF9D8EC7),
    textPrimary: Color(0xFFE6E3ED),
    textSecondary: Color(0xFFA29DB3),
    textTertiary: Color(0xFF736E82),
    textFaint: Color(0xFF4F4B5A),
    border: Color(0xFF2A2832),
  );

  /// Royal Gold — Inspired by luxury apps and premium fintech dark modes.
  /// Deep warm-grey base with a refined champagne-gold accent. Understated
  /// wealth, not flashy.
  static const _royalGold = AppThemeData(
    theme: AppTheme.royalGold,
    name: 'Royal Gold',
    description: 'Understated wealth. Deep grey with champagne accents.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF121110),
    surface: Color(0xFF1A1918),
    card: Color(0xFF222120),
    primary: Color(0xFFD4A953),
    textPrimary: Color(0xFFEDE9E3),
    textSecondary: Color(0xFFB0A898),
    textTertiary: Color(0xFF7E776A),
    textFaint: Color(0xFF565148),
    border: Color(0xFF302D28),
  );

  /// Obsidian Black — Inspired by OLED-optimized apps (Apple, Nothing).
  /// True black background with carefully lifted surfaces and a clean
  /// neutral-white accent. Maximum contrast, zero color noise.
  static const _obsidianBlack = AppThemeData(
    theme: AppTheme.obsidianBlack,
    name: 'Obsidian Black',
    description: 'Pure void. OLED black with crystalline contrast.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF000000),
    surface: Color(0xFF0C0C0C),
    card: Color(0xFF161616),
    primary: Color(0xFFE0E0E0),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xFF9E9E9E),
    textTertiary: Color(0xFF6E6E6E),
    textFaint: Color(0xFF454545),
    border: Color(0xFF262626),
  );

  /// Neon Cyber — Inspired by cyberpunk aesthetics but restrained.
  /// Deep blue-black base with a soft mint-green accent. Futuristic
  /// without eye strain.
  static const _neonCyber = AppThemeData(
    theme: AppTheme.neonCyber,
    name: 'Neon Cyber',
    description: 'Restrained future. Deep void with soft mint circuits.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF0A0C10),
    surface: Color(0xFF11141A),
    card: Color(0xFF181C22),
    primary: Color(0xFF5CEAA0),
    textPrimary: Color(0xFFE4EDE8),
    textSecondary: Color(0xFF94A8A0),
    textTertiary: Color(0xFF657872),
    textFaint: Color(0xFF434E4A),
    border: Color(0xFF232A28),
  );
}
