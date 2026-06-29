import 'package:flutter/material.dart';

/// Global theme-mode notifier (light by default). Persisted via
/// shared_preferences in main.dart / settings_screen.dart.
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);

/// Central palette for the app.
///
/// Light = white + orange premium theme. Dark = original dark palette
/// (#080C14 background, #00E5FF cyan accent). Screens read the dynamic getters
/// below, so flipping [isDark] (driven by [themeNotifier]) re-colors the app.
/// Central design system: color tokens and light/dark [ThemeData].
///
/// Tokens are dynamic getters keyed off [isDark] (set once per build by the
/// app-level theme listener) so a single source drives every screen's palette.
class HunterTheme {
  HunterTheme._();

  /// Set from the ValueListenableBuilder wrapping MaterialApp before each build.
  static bool isDark = false;

  // ── LIGHT palette ─────────────────────────────────────────────────────
  static const _lBackground    = Color(0xFFFAFAFA);
  static const _lSurface       = Color(0xFFFFF0E8);
  static const _lCard          = Color(0xFFFFFFFF);
  static const _lPrimary       = Color(0xFFFF6B2B);
  static const _lTextPrimary   = Color(0xFF1A1A1A);
  static const _lTextSecondary = Color(0xFF666666);
  static const _lTextTertiary  = Color(0xFF999999);
  static const _lTextFaint     = Color(0xFFBBBBBB);
  static const _lBorder        = Color(0xFFFFE0D0);

  // ── DARK palette (original) ───────────────────────────────────────────
  static const _dBackground    = Color(0xFF080C14);
  static const _dSurface       = Color(0xFF0D1620);
  static const _dCard          = Color(0xFF111523);
  static const _dPrimary       = Color(0xFF00E5FF);
  static const _dTextPrimary   = Color(0xFFF5F7FA);
  static const _dTextSecondary = Color(0xFFB8C2D9);
  static const _dTextTertiary  = Color(0xFF8898BB);
  static const _dTextFaint     = Color(0xFF5A6478);
  static const _dBorder        = Color(0xFF1E2D4A);

  // ── Dynamic core tokens (used across all screens) ─────────────────────
  static Color get background    => isDark ? _dBackground    : _lBackground;
  static Color get surface       => isDark ? _dSurface       : _lSurface;
  static Color get cardColor     => isDark ? _dCard          : _lCard;
  static Color get primary       => isDark ? _dPrimary       : _lPrimary;
  static Color get textPrimary   => isDark ? _dTextPrimary   : _lTextPrimary;
  static Color get textSecondary => isDark ? _dTextSecondary : _lTextSecondary;
  static Color get textTertiary  => isDark ? _dTextTertiary  : _lTextTertiary;
  static Color get textFaint     => isDark ? _dTextFaint     : _lTextFaint;
  static Color get border        => isDark ? _dBorder        : _lBorder;

  // ── Semantic accents (mode-independent) ───────────────────────────────
  static const success     = Color(0xFF44DD88);
  static const successAlt   = Color(0xFF2ECC71);
  static const successDeep  = Color(0xFF2EAE76);
  static const danger       = Color(0xFFFF4444);
  static const dangerAlt     = Color(0xFFE74C3C);
  static const dangerDeep   = Color(0xFFE5484D);
  static const gold         = Color(0xFFFFD700);
  static const goldBright    = Color(0xFFFFB300);
  static const goldDeep     = Color(0xFFB8900A);
  static const goldDark     = Color(0xFF8A6800);
  static const purple       = Color(0xFF9B59B6);
  static const purpleLight   = Color(0xFFAA88FF);
  static const info         = Color(0xFF3498DB);
  static const bronze       = Color(0xFFCD7F32);
  static const silver       = Color(0xFF9AA7B8);

  // ── Pastel status surfaces (lighten in light mode, darken in dark) ────
  static Color get greenSurface => isDark ? const Color(0xFF0D2018) : const Color(0xFFE8F8F0);
  static Color get redSurface   => isDark ? const Color(0xFF1A0808) : const Color(0xFFFFD9D9);
  static Color get amberSurface => isDark ? const Color(0xFF1A1500) : const Color(0xFFFFF1D6);
  static Color get roseSurface  => isDark ? const Color(0xFF2A0A1A) : const Color(0xFFFFE5EC);
  static Color get pinkSurface  => isDark ? const Color(0xFF1A0510) : const Color(0xFFFCE4EC);

  // ── Backwards-compatible aliases ──────────────────────────────────────
  static Color get backgroundTop => background;
  static Color get backgroundMid => surface;
  static Color get card          => cardColor;
  static Color get neonBlue      => primary;

  // ── ThemeData for MaterialApp (light/dark) ────────────────────────────
  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        bg: _lBackground, card: _lCard, accent: _lPrimary,
        textP: _lTextPrimary, textS: _lTextSecondary,
        onAccent: Colors.white,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        bg: _dBackground, card: _dCard, accent: _dPrimary,
        textP: _dTextPrimary, textS: _dTextSecondary,
        onAccent: const Color(0xFF080C14),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color card,
    required Color accent,
    required Color textP,
    required Color textS,
    required Color onAccent,
  }) {
    final base =
        brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      canvasColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: card,
        background: bg,
        brightness: brightness,
        onPrimary: onAccent,
        onSurface: textP,
        onBackground: textP,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textP,
        elevation: 0,
        iconTheme: IconThemeData(color: textS),
        titleTextStyle: TextStyle(
          color: textP,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(color: accent),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      cardColor: card,
      dividerColor: textS.withOpacity(0.2),
      textTheme: base.textTheme.apply(bodyColor: textP, displayColor: textP),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent.withOpacity(0.4)
              : textS.withOpacity(0.3),
        ),
      ),
    );
  }
}
