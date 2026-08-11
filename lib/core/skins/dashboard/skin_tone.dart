import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Semantic color roles shared by every skin's structural components.
///
/// ## Why this exists
/// It enforces the Skin/Theme architecture rule at a single auditable point:
/// - **SKIN** owns structure, layout, component design, animation, identity.
/// - **PREMIUM THEME** owns colors.
///
/// This class contains **zero literal color values**. Every getter forwards
/// to an existing [HunterTheme] token, which itself resolves through the
/// active Premium Theme (`HunterTheme.activeDarkTheme`). It is therefore NOT
/// a second theme system — it introduces no colors and holds no state; it
/// only gives the skins' structural roles readable names.
///
/// Net effect: any skin + any Premium Theme → that skin's structure, that
/// theme's colors, automatically.
class SkinTone {
  SkinTone._();

  // ── Surfaces ──
  static Color get backdropTop => HunterTheme.surface;
  static Color get backdropBottom => HunterTheme.background;
  static Color get panel => HunterTheme.cardColor;
  static Color get panelAlt => HunterTheme.surface;

  // ── Structure: borders, dividers, meter tracks ──
  static Color get line => HunterTheme.border;

  // ── Accents (Premium Theme driven) ──
  static Color get accent => HunterTheme.primary;
  static Color get accentBright => HunterTheme.secondary;
  static List<Color> get accentRamp => HunterTheme.primaryGradient;

  // ── Text tiers ──
  static Color get textStrong => HunterTheme.textPrimary;
  static Color get textSoft => HunterTheme.textSecondary;
  static Color get textFaint => HunterTheme.textTertiary;

  // ── Semantic state ──
  static Color get complete => HunterTheme.success;

  /// Premium-theme-driven glow multiplier (1.0 default; OLED themes calmer,
  /// neon/glass themes stronger). Multiply glow opacities by this.
  static double get glow => HunterTheme.glowStrength;
}
