import 'package:flutter/material.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Identifies each available dark theme in the app.
///
/// Used as a type-safe key for theme lookup, persistence, and comparison
/// instead of raw strings. Adding a new theme = adding one enum value here
/// and one [AppThemeData] entry in [ThemeRegistry].
enum AppTheme {
  dark,
  shadowBlue,
  crimsonRed,
  emeraldGreen,
  sunsetOrange,
  shadowMonarch,
  royalGold,
  obsidianBlack,
  neonCyber;

  /// Parses a persisted string ID back into the enum.
  /// Falls back to [AppTheme.dark] for unrecognized values.
  static AppTheme fromId(String? id) {
    if (id == null || id.isEmpty) return AppTheme.dark;
    for (final theme in AppTheme.values) {
      if (theme.name == id) return theme;
    }
    return AppTheme.dark;
  }
}

/// Immutable definition of a single dark-mode theme palette.
///
/// Each theme provides the 9 core color tokens that [HunterTheme] exposes
/// via its static getters when in dark mode. Semantic accents (success,
/// danger, gold, etc.) remain constant across all themes.
@immutable
class AppThemeData {
  const AppThemeData({
    required this.theme,
    required this.name,
    required this.description,
    required this.requiredTier,
    required this.background,
    required this.surface,
    required this.card,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textFaint,
    required this.border,
  });

  /// The enum identifier for this theme.
  final AppTheme theme;

  /// Human-readable display name shown in the gallery.
  final String name;

  /// Short description shown in the preview bottom sheet.
  final String description;

  /// The minimum membership tier required to use this theme.
  final MembershipTier requiredTier;

  // ── Core palette tokens ────────────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color card;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textFaint;
  final Color border;
}
