// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Theme-aware "System Window" palette for the Hunter Report.
///
/// The report follows the app's light/dark theme (driven by [HunterTheme.isDark],
/// which the app sets before every build). In both themes it keeps the same
/// premium "Hunter System Report" identity — a blue-accented System window —
/// but adapts surfaces, text and depth to feel native:
///
/// • Dark  → dark surfaces, bright blue glow, white text, glassmorphism.
/// • Light → light surfaces, soft blue accents, dark text, elegant shadows.
///
/// The DARK constants are also exposed publicly so the shareable report image
/// can stay a fixed premium-dark design regardless of the in-app theme.
class ReportPalette {
  ReportPalette._();

  static bool get _dark => HunterTheme.isDark;

  /// Whether the report is currently rendering in the dark theme.
  static bool get isDark => _dark;

  // ══ DARK constants (also used verbatim by the fixed-dark share card) ══
  static const darkBgTop = Color(0xFF05070E);
  static const darkBgBottom = Color(0xFF0A1120);
  static const darkAccent = Color(0xFF4EA8FF);
  static const darkAccentBright = Color(0xFF8CD0FF);
  static const darkMint = Color(0xFF6EE7B7);
  static const darkGold = Color(0xFFFFD35C);
  static const darkPurple = Color(0xFFB98CFF);
  static const darkWarn = Color(0xFFFF8A80);
  static const darkFat = Color(0xFFFFB27A);
  static const darkTextPrimary = Color(0xFFEAF2FF);
  static const darkTextSecondary = Color(0xFF9DB2D0);
  static const darkTextTertiary = Color(0xFF5E7196);
  static const darkGlassHi = Color(0x14FFFFFF);
  static const darkGlassLo = Color(0x08FFFFFF);

  // ══ LIGHT constants ══
  static const lightBgTop = Color(0xFFEDF3FF);
  static const lightBgBottom = Color(0xFFFFFFFF);
  static const lightAccent = Color(0xFF2F80ED);
  static const lightAccentBright = Color(0xFF1B5FCC);
  static const lightMint = Color(0xFF0E9F6E);
  static const lightGold = Color(0xFFC98A00);
  static const lightPurple = Color(0xFF7C3AED);
  static const lightWarn = Color(0xFFE5484D);
  static const lightFat = Color(0xFFE07B39);
  static const lightTextPrimary = Color(0xFF0F1B2D);
  static const lightTextSecondary = Color(0xFF4A5B74);
  static const lightTextTertiary = Color(0xFF8A99B2);
  static const lightGlassHi = Color(0xF2FFFFFF); // ~0.95 white — frosted
  static const lightGlassLo = Color(0xCCEFF4FF); // ~0.8 light blue

  // ══ Dynamic tokens (adapt to the active theme) ══
  static Color get bgTop => _dark ? darkBgTop : lightBgTop;
  static Color get bgBottom => _dark ? darkBgBottom : lightBgBottom;
  static Color get accent => _dark ? darkAccent : lightAccent;
  static Color get accentBright => _dark ? darkAccentBright : lightAccentBright;
  static Color get mint => _dark ? darkMint : lightMint;
  static Color get gold => _dark ? darkGold : lightGold;
  static Color get purple => _dark ? darkPurple : lightPurple;
  static Color get warn => _dark ? darkWarn : lightWarn;
  static Color get fatAccent => _dark ? darkFat : lightFat;
  static Color get textPrimary => _dark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      _dark ? darkTextSecondary : lightTextSecondary;
  static Color get textTertiary =>
      _dark ? darkTextTertiary : lightTextTertiary;
  static Color get glassHi => _dark ? darkGlassHi : lightGlassHi;
  static Color get glassLo => _dark ? darkGlassLo : lightGlassLo;

  /// Subtle inner fill (stat cells, toggle track).
  static Color get fillSubtle =>
      _dark ? Colors.white.withOpacity(0.04) : lightAccent.withOpacity(0.05);

  /// Progress-bar / control track background.
  static Color get track =>
      _dark ? Colors.white.withOpacity(0.06) : lightAccent.withOpacity(0.10);

  /// Glass card border colour.
  static Color get cardBorder => accent.withOpacity(_dark ? 0.22 : 0.30);

  /// Card depth: a blue glow in dark, an elegant soft shadow in light.
  static List<BoxShadow> get cardShadow => _dark
      ? [
          BoxShadow(
            color: darkAccent.withOpacity(0.10),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF0F1B2D).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: lightAccent.withOpacity(0.06),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ];

  /// Restrained 5-step rating colour scale (adapts to theme).
  static Color ratingColor(int level) => _ratingFrom(
        level,
        top: mint,
        high: accentBright,
        mid: accent,
        low: textSecondary,
        base: textTertiary,
      );

  /// Fixed-DARK rating colours for the share image (theme-independent).
  static Color darkRatingColor(int level) => _ratingFrom(
        level,
        top: darkMint,
        high: darkAccentBright,
        mid: darkAccent,
        low: darkTextSecondary,
        base: darkTextTertiary,
      );

  static Color _ratingFrom(
    int level, {
    required Color top,
    required Color high,
    required Color mid,
    required Color low,
    required Color base,
  }) {
    switch (level) {
      case 4:
        return top;
      case 3:
        return high;
      case 2:
        return mid;
      case 1:
        return low;
      default:
        return base;
    }
  }
}
