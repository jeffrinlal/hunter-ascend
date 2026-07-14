// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// Fixed dark / blue "System Window" palette for the Hunter Report.
///
/// The report intentionally renders in this fixed dark theme regardless of the
/// app's light/dark setting, so it always feels like an official System window.
/// Centralising the colours here keeps every report widget visually consistent
/// and makes future tuning a single-file change.
class ReportPalette {
  ReportPalette._();

  // Background gradient (top → bottom).
  static const bgTop = Color(0xFF05070E);
  static const bgBottom = Color(0xFF0A1120);

  // Accents (blue is primary; mint/gold are used sparingly).
  static const accent = Color(0xFF4EA8FF); // primary blue glow
  static const accentBright = Color(0xFF8CD0FF); // lighter blue
  static const mint = Color(0xFF6EE7B7); // top-rating / positive accent
  static const gold = Color(0xFFFFD35C); // premium accent (Pro)
  static const purple = Color(0xFFB98CFF); // premium accent (Max)
  static const warn = Color(0xFFFF8A80); // weight-gain / caution accent

  // Text.
  static const textPrimary = Color(0xFFEAF2FF);
  static const textSecondary = Color(0xFF9DB2D0);
  static const textTertiary = Color(0xFF5E7196);

  // Glass fills.
  static const glassHi = Color(0x14FFFFFF); // ~0.08 white
  static const glassLo = Color(0x08FFFFFF); // ~0.03 white

  /// Restrained 5-step colour scale for analysis ratings (0 = lowest).
  static Color ratingColor(int level) {
    switch (level) {
      case 4:
        return mint;
      case 3:
        return accentBright;
      case 2:
        return accent;
      case 1:
        return textSecondary;
      default:
        return textTertiary;
    }
  }
}
