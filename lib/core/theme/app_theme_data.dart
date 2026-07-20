import 'package:flutter/material.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Defines how a theme is unlocked.
///
/// [membership] — gated by Free/Pro/Max tier (existing behavior).
/// [adReward] — unlocked temporarily by watching a rewarded ad.
enum ThemeUnlockType {
  membership,
  adReward,
}

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
  neonCyber,
  crystalGlass;

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
    this.secondary,
    this.glowStrength = 1.0,
    this.heroGradient,
    this.unlockType = ThemeUnlockType.membership,
    this.unlockDuration,
  });

  /// The enum identifier for this theme.
  final AppTheme theme;

  /// Human-readable display name shown in the gallery.
  final String name;

  /// Short description shown in the preview bottom sheet.
  final String description;

  /// The minimum membership tier required to use this theme.
  /// Only relevant when [unlockType] is [ThemeUnlockType.membership].
  final MembershipTier requiredTier;

  /// How this theme is unlocked. Defaults to [ThemeUnlockType.membership].
  final ThemeUnlockType unlockType;

  /// How long this theme remains unlocked after an ad-reward.
  /// Only relevant when [unlockType] is [ThemeUnlockType.adReward].
  /// Defaults to `null` (not applicable for membership themes).
  final Duration? unlockDuration;

  /// Whether this theme uses the ad-reward unlock mechanism.
  bool get isAdRewardTheme => unlockType == ThemeUnlockType.adReward;

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

  // ── Premium identity tokens ─────────────────────────────────────────────
  //
  // These give each theme its own "feel" beyond flat accent swaps. They are
  // consumed centrally via HunterTheme (primaryGradient / secondary /
  // glowStrength / heroGradient) so screens opt in without hardcoding colors.

  /// Secondary accent used to build premium gradients (primary → secondary).
  /// When null, [primary] is reused so gradients degrade gracefully.
  final Color? secondary;

  /// Relative glow / shadow intensity for this theme (1.0 = default). Lower
  /// for OLED / minimal themes, higher for neon / glass themes.
  final double glowStrength;

  /// Optional multi-stop gradient for immersive hero / premium surfaces.
  /// When null, callers fall back to `[primary, secondary ?? primary]`.
  final List<Color>? heroGradient;

  /// The effective secondary accent (falls back to [primary]).
  Color get effectiveSecondary => secondary ?? primary;

  /// The effective hero gradient stops (falls back to primary→secondary).
  List<Color> get effectiveHeroGradient =>
      heroGradient ?? [primary, effectiveSecondary];
}
