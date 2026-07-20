// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Theme-aware "System Window" palette for the Hunter Report, using the Hunter
/// Ascend orange/gold design language (NOT blue).
///
/// Surfaces and text are pulled straight from [HunterTheme] so the report feels
/// native to the app in both light and dark themes. Accents are the Hunter
/// orange + gold used across the rest of the app:
///
/// • Dark  → dark surfaces, warm orange glow, gold highlights, light text.
/// • Light → light/warm surfaces, orange accents, gold highlights, dark text,
///           elegant soft shadows.
///
/// The DARK constants are also exposed so the shareable report image can stay a
/// fixed premium-dark (orange/gold) design regardless of the in-app theme.
class ReportPalette {
  ReportPalette._();

  static bool get _dark => HunterTheme.isDark;

  /// Whether the report is currently rendering in the dark theme.
  static bool get isDark => _dark;

  // ══ Fixed-DARK constants (used verbatim by the fixed-dark share card) ══
  static const darkBgTop = Color(0xFF0C1017);
  static const darkBgBottom = Color(0xFF070A10);
  static const darkAccent = Color(0xFFFF7A3D); // Hunter orange (dark)
  static const darkAccentBright = Color(0xFFFF9E5C); // brighter orange
  static const darkGold = Color(0xFFFFD54A);
  static const darkMint = Color(0xFF4ADE80); // green (weight-positive)
  static const darkWarn = Color(0xFFFF8A80); // red (weight-gain)
  static const darkFat = Color(0xFFFFB27A);
  static const darkTextPrimary = Color(0xFFF5F6F8);
  static const darkTextSecondary = Color(0xFFC2C8D2);
  static const darkTextTertiary = Color(0xFF808895);
  static const darkGlassHi = Color(0x14FFFFFF);
  static const darkGlassLo = Color(0x08FFFFFF);

  // ══ Orange / gold accent constants (theme variants) ══
  static const _lAccent = Color(0xFFFF6B2B); // Hunter brand orange
  static const _lAccentBright = Color(0xFFF0611F); // deeper orange (contrast)
  static const _lGold = Color(0xFFC7960E); // deep gold (legible on white)
  static const _lMint = Color(0xFF2E9E6B); // green (weight-positive)
  static const _lWarn = Color(0xFFE5484D); // red (weight-gain)
  static const _lFat = Color(0xFFC77F1A); // amber

  static const _dAccent = darkAccent;
  static const _dAccentBright = darkAccentBright;
  static const _dGold = darkGold;
  static const _dMint = darkMint;
  static const _dWarn = darkWarn;
  static const _dFat = darkFat;

  // ══ Dynamic accent tokens ══
  static Color get accent => _dark ? _dAccent : _lAccent;
  static Color get accentBright => _dark ? _dAccentBright : _lAccentBright;
  static Color get gold => _dark ? _dGold : _lGold;
  static Color get mint => _dark ? _dMint : _lMint;
  static Color get warn => _dark ? _dWarn : _lWarn;
  static Color get fatAccent => _dark ? _dFat : _lFat;

  /// Max-tier accent — matches the app's purple Max branding in both themes.
  static Color get purple =>
      _dark ? const Color(0xFFB98CFF) : const Color(0xFF7C3AED);

  // ══ Surfaces & text — reused straight from the app theme ══
  static Color get bgTop => HunterTheme.surface;
  static Color get bgBottom => HunterTheme.background;
  static Color get textPrimary => HunterTheme.textPrimary;
  static Color get textSecondary => HunterTheme.textSecondary;
  static Color get textTertiary => HunterTheme.textTertiary;

  // ══ Glass fills (warm/neutral, never blue) ══
  //
  // Card fills. The in-app cards no longer use a real-time BackdropFilter
  // (removed for scroll performance), so these fills are more opaque and
  // card-based — cards stay perfectly legible over the ambient glow while
  // keeping a soft, premium frosted gradient. Fully theme-aware.
  static Color get glassHi => _dark
      ? HunterTheme.cardColor.withOpacity(0.90)
      : Colors.white.withOpacity(0.96);
  static Color get glassLo => _dark
      ? HunterTheme.cardColor.withOpacity(0.78)
      : const Color(0xFFFFF3EC).withOpacity(0.92);

  /// Subtle inner fill (stat cells, toggle track).
  static Color get fillSubtle =>
      _dark ? Colors.white.withOpacity(0.04) : accent.withOpacity(0.05);

  /// Progress-bar / control track background.
  static Color get track =>
      _dark ? Colors.white.withOpacity(0.06) : accent.withOpacity(0.10);

  /// Glass card border colour.
  static Color get cardBorder => accent.withOpacity(_dark ? 0.22 : 0.30);

  /// Card depth: a warm orange glow in dark, an elegant soft shadow in light.
  static List<BoxShadow> get cardShadow => _dark
      ? [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ];

  /// Restrained 5-step rating colour scale (orange/gold, adapts to theme).
  /// Top rating = gold, descending through bright orange → orange → muted text.
  static Color ratingColor(int level) => _ratingFrom(
        level,
        top: gold,
        high: accentBright,
        mid: accent,
        low: textSecondary,
        base: textTertiary,
      );

  /// Fixed-DARK rating colours for the share image (theme-independent).
  static Color darkRatingColor(int level) => _ratingFrom(
        level,
        top: darkGold,
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
