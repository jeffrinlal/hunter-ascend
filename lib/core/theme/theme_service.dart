import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/theme_registry.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Manages premium dark-theme selection and persistence.
///
/// ## Unlock model
/// Applying a theme is gated in the UI (see [ThemeGalleryScreen]) by watching
/// a single rewarded ad — but only when the selected theme is **not already
/// active**. Once applied, the selection is persisted via the existing
/// SharedPreferences mechanism and restored for free on the next launch, so
/// the active theme never re-prompts for an ad. The default [AppTheme.dark]
/// can always be re-applied for free.
///
/// There is no membership gating and no timed expiry on themes — access is
/// driven purely by the rewarded-ad flow integrated in the gallery.
///
/// ## Startup
/// Call [initialize] once in `main.dart`.
///
/// ## Applying a theme
/// ```dart
/// await ThemeService.instance.applyTheme(AppTheme.shadowBlue);
/// ```
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _prefsKey = 'selectedDarkThemeId';

  /// Fires whenever the active dark theme changes.
  /// The gallery and any other listeners can rebuild on this.
  final ValueNotifier<AppTheme> activeThemeNotifier =
      ValueNotifier<AppTheme>(AppTheme.dark);

  /// The currently applied dark theme data.
  AppThemeData get activeThemeData =>
      ThemeRegistry.getByTheme(activeThemeNotifier.value);

  /// Global key used to show snackbars from the service layer.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;

  /// Cached SharedPreferences instance (set during [initialize]).
  SharedPreferences? _cachedPrefs;

  /// Restores the persisted theme selection and applies it.
  ///
  /// Must be called once on startup (from `main.dart`). Themes are no longer
  /// gated by membership, so the persisted selection is simply re-applied —
  /// nothing is reverted.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final savedId = prefs.getString(_prefsKey);
    _applyWithoutPersist(AppTheme.fromId(savedId));
  }

  /// Applies [theme], persists the selection, and notifies listeners.
  ///
  /// Called by the gallery after the user watches a rewarded ad (for a
  /// non-active theme), or immediately for the default theme / the already
  /// active theme. Always succeeds — the ad gate lives in the UI.
  Future<void> applyTheme(AppTheme theme) async {
    _applyWithoutPersist(theme);
    await _persist(theme);

    // Premium themes are dark palettes. If the user is currently in light
    // mode, switch to dark so the applied theme is visible immediately.
    if (theme != AppTheme.dark && !HunterTheme.isDark) {
      HunterTheme.isDark = true;
      themeNotifier.value = ThemeMode.dark;
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setBool('darkMode', true);
    }
  }

  /// Whether [theme] is the one currently applied.
  bool isActive(AppTheme theme) => activeThemeNotifier.value == theme;

  // ── Private ──────────────────────────────────────────────────────────────

  void _applyWithoutPersist(AppTheme theme) {
    activeThemeNotifier.value = theme;
    HunterTheme.activeDarkTheme = ThemeRegistry.getByTheme(theme);
    // Note: We intentionally do NOT force-notify themeNotifier here.
    //
    // Force-notifying themeNotifier rebuilds the root MaterialApp's
    // ValueListenableBuilder, which recreates the entire Navigator tree —
    // destroying HomeDashboardScreen's State and its cached Firestore
    // StreamBuilder snapshot (causing a skeleton flash). Instead,
    // HunterTheme.activeDarkTheme is updated and screens listening to
    // activeThemeNotifier repaint from the HunterTheme.* getters. The
    // MaterialApp's ThemeData also updates on the next natural rebuild.
  }

  Future<void> _persist(AppTheme theme) async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setString(_prefsKey, theme.name);
  }
}
