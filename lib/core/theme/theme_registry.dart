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

  static const _shadowBlue = AppThemeData(
    theme: AppTheme.shadowBlue,
    name: 'Shadow Blue',
    description: 'A deep ocean darkness with steel-blue precision.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF0A1628),
    surface: Color(0xFF0E1E34),
    card: Color(0xFF122440),
    primary: Color(0xFF4A90D9),
    textPrimary: Color(0xFFE8F0FA),
    textSecondary: Color(0xFFA8C4E0),
    textTertiary: Color(0xFF7A9CBF),
    textFaint: Color(0xFF4E7099),
    border: Color(0xFF1E3A5C),
  );

  static const _crimsonRed = AppThemeData(
    theme: AppTheme.crimsonRed,
    name: 'Crimson Red',
    description: 'Blood-red intensity for the fearless hunter.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF1A0A0A),
    surface: Color(0xFF221010),
    card: Color(0xFF2A1414),
    primary: Color(0xFFFF4757),
    textPrimary: Color(0xFFFAF0F0),
    textSecondary: Color(0xFFD9A8A8),
    textTertiary: Color(0xFFBF7A7A),
    textFaint: Color(0xFF8A5050),
    border: Color(0xFF4A1E1E),
  );

  static const _emeraldGreen = AppThemeData(
    theme: AppTheme.emeraldGreen,
    name: 'Emerald Green',
    description: 'Nature\'s power channeled through emerald light.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF0A1A10),
    surface: Color(0xFF0E2218),
    card: Color(0xFF122A1E),
    primary: Color(0xFF2ED573),
    textPrimary: Color(0xFFE8FAF0),
    textSecondary: Color(0xFFA8D9BE),
    textTertiary: Color(0xFF7ABF99),
    textFaint: Color(0xFF4E9970),
    border: Color(0xFF1E4A32),
  );

  static const _sunsetOrange = AppThemeData(
    theme: AppTheme.sunsetOrange,
    name: 'Sunset Orange',
    description: 'Warm amber glow of a hunter\'s twilight.',
    requiredTier: MembershipTier.pro,
    background: Color(0xFF1A1208),
    surface: Color(0xFF221A0E),
    card: Color(0xFF2A2012),
    primary: Color(0xFFFF9F43),
    textPrimary: Color(0xFFFAF4E8),
    textSecondary: Color(0xFFD9C4A0),
    textTertiary: Color(0xFFBFA070),
    textFaint: Color(0xFF8A7040),
    border: Color(0xFF4A3A1E),
  );

  static const _shadowMonarch = AppThemeData(
    theme: AppTheme.shadowMonarch,
    name: 'Shadow Monarch',
    description: 'Inspired by the ruler of shadows. Purple dominion.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF0D0A14),
    surface: Color(0xFF140E1E),
    card: Color(0xFF1A1228),
    primary: Color(0xFF9B59B6),
    textPrimary: Color(0xFFF0E8FA),
    textSecondary: Color(0xFFC4A8D9),
    textTertiary: Color(0xFF9A7ABF),
    textFaint: Color(0xFF6E4E8A),
    border: Color(0xFF3A1E5C),
  );

  static const _royalGold = AppThemeData(
    theme: AppTheme.royalGold,
    name: 'Royal Gold',
    description: 'The mark of a supreme hunter. Gold sovereignty.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF141008),
    surface: Color(0xFF1E180E),
    card: Color(0xFF262012),
    primary: Color(0xFFFFD700),
    textPrimary: Color(0xFFFAF6E8),
    textSecondary: Color(0xFFD9CCA0),
    textTertiary: Color(0xFFBFAA70),
    textFaint: Color(0xFF8A7840),
    border: Color(0xFF4A3E1E),
  );

  static const _obsidianBlack = AppThemeData(
    theme: AppTheme.obsidianBlack,
    name: 'Obsidian Black',
    description: 'Pure darkness. Nothing hidden, nothing spared.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    card: Color(0xFF141414),
    primary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xFFB0B0B0),
    textTertiary: Color(0xFF808080),
    textFaint: Color(0xFF505050),
    border: Color(0xFF2A2A2A),
  );

  static const _neonCyber = AppThemeData(
    theme: AppTheme.neonCyber,
    name: 'Neon Cyber',
    description: 'Digital warfare. Neon circuits on void.',
    requiredTier: MembershipTier.max,
    background: Color(0xFF050510),
    surface: Color(0xFF0A0A1A),
    card: Color(0xFF101024),
    primary: Color(0xFF00FF88),
    textPrimary: Color(0xFFE8FAF0),
    textSecondary: Color(0xFFA0D9C0),
    textTertiary: Color(0xFF70BF99),
    textFaint: Color(0xFF409966),
    border: Color(0xFF1A4A30),
  );
}
