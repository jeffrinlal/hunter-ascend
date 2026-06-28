import 'package:flutter/material.dart';

/// Central palette for the white + orange premium light theme.
/// Every screen references these tokens, so the whole app can be re-themed
/// by editing this one file.
class HunterTheme {
  HunterTheme._();

  // ── Core palette ──────────────────────────────────────────────────────
  static const background    = Color(0xFFFAFAFA); // scaffolds / app background
  static const surface       = Color(0xFFFFF0E8); // soft card / input surface
  static const cardColor     = Color(0xFFFFFFFF); // primary card surface
  static const primary       = Color(0xFFFF6B2B); // orange accent
  static const textPrimary   = Color(0xFF1A1A1A); // primary text
  static const textSecondary = Color(0xFF666666); // secondary text
  static const textTertiary  = Color(0xFF999999); // hint text
  static const textFaint     = Color(0xFFBBBBBB); // faint / disabled text
  static const border        = Color(0xFFFFE0D0); // subtle orange-tinted border

  // ── Semantic accents ──────────────────────────────────────────────────
  static const success     = Color(0xFF44DD88); // positive / completed
  static const successAlt   = Color(0xFF2ECC71); // XP / secondary green
  static const successDeep  = Color(0xFF2EAE76); // deeper green
  static const danger       = Color(0xFFFF4444); // error / decline / over-goal
  static const dangerAlt     = Color(0xFFE74C3C); // secondary red
  static const dangerDeep   = Color(0xFFE5484D); // deep red
  static const gold         = Color(0xFFFFD700); // 1st place / highlight
  static const goldBright    = Color(0xFFFFB300); // bright gold
  static const goldDeep     = Color(0xFFB8900A); // deep gold (gradient stop)
  static const goldDark     = Color(0xFF8A6800); // dark gold (gradient stop)
  static const purple       = Color(0xFF9B59B6); // rank tier
  static const purpleLight   = Color(0xFFAA88FF); // light purple
  static const info         = Color(0xFF3498DB); // rank tier blue
  static const bronze       = Color(0xFFCD7F32); // 3rd place
  static const silver       = Color(0xFF9AA7B8); // 2nd place

  // ── Pastel surfaces (status backgrounds / gradient tints) ─────────────
  static const greenSurface = Color(0xFFE8F8F0);
  static const redSurface   = Color(0xFFFFD9D9);
  static const amberSurface = Color(0xFFFFF1D6);
  static const roseSurface  = Color(0xFFFFE5EC);
  static const pinkSurface  = Color(0xFFFCE4EC);

  // ── Backwards-compatible aliases ──────────────────────────────────────
  static const backgroundTop = background;
  static const backgroundMid = surface;
  static const card          = cardColor;
  static const neonBlue      = primary;
}
