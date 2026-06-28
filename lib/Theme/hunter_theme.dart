import 'package:flutter/material.dart';

/// Central palette for the white + orange premium light theme.
/// All screens reference these tokens so the palette can be tuned in one place.
class HunterTheme {
  HunterTheme._();

  // ── Core palette ──────────────────────────────────────────────────────
  static const background    = Color(0xFFFAFAFA); // scaffolds / app background
  static const surface       = Color(0xFFFFF0E8); // soft card / input surface
  static const cardColor     = Color(0xFFFFFFFF); // primary card surface
  static const primary       = Color(0xFFFF6B2B); // orange accent
  static const textPrimary   = Color(0xFF1A1A1A); // primary text
  static const textSecondary = Color(0xFF666666); // secondary text
  static const textTertiary  = Color(0xFF999999); // hint / disabled text
  static const border        = Color(0xFFFFE0D0); // subtle orange-tinted border

  // ── Backwards-compatible aliases (kept so existing names keep working) ──
  static const backgroundTop = background;
  static const backgroundMid = surface;
  static const card          = cardColor;
  static const neonBlue      = primary;
}
