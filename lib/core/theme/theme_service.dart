import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/theme_registry.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Manages premium dark-theme selection, persistence, membership validation,
/// and automatic fallback when a user's tier no longer covers their theme.
///
/// ## Startup
/// Call [initialize] once in `main.dart` after [MembershipService] has loaded.
///
/// ## Applying a theme
/// ```dart
/// ThemeService.instance.applyTheme(AppTheme.shadowBlue);
/// ```
///
/// ## Membership downgrade
/// The service listens to [MembershipService.instance.tierNotifier] and
/// automatically reverts to the default dark theme (with a snackbar message)
/// if the user's tier no longer covers the selected theme.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _prefsKey = 'selectedDarkThemeId';

  /// Fires whenever the active dark theme changes.
  /// The gallery and any other listeners can rebuild on this.
  final ValueNotifier<AppTheme> activeThemeNotifier =
      ValueNotifier<AppTheme>(AppTheme.dark);

  /// The currently applied dark theme data.
  AppThemeData get activeThemeData => ThemeRegistry.getByTheme(activeThemeNotifier.value);

  /// Global key used to show snackbars from the service layer (e.g. on
  /// membership downgrade). Set by the root MaterialApp's scaffoldMessengerKey.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;

  /// Initializes the theme service: loads persisted selection, validates
  /// membership access, applies the theme, and starts listening for
  /// membership tier changes.
  ///
  /// Must be called once after [MembershipService.instance.loadMembership()]
  /// completes.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKey);
    final theme = AppTheme.fromId(savedId);
    final themeData = ThemeRegistry.getByTheme(theme);

    if (_canAccess(themeData)) {
      _applyWithoutPersist(theme);
    } else {
      // User no longer has access (membership expired between sessions).
      _applyWithoutPersist(AppTheme.dark);
      await _persist(AppTheme.dark);
      // Schedule snackbar after first frame so the scaffold is available.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFallbackSnackbar(themeData);
      });
    }

    // Listen for membership tier changes (upgrade/downgrade).
    MembershipService.instance.tierNotifier.addListener(_onTierChanged);
  }

  /// Applies a theme, persists the selection, and notifies listeners.
  ///
  /// Returns `true` if the theme was successfully applied, `false` if the
  /// user does not have membership access (caller should show upgrade dialog).
  Future<bool> applyTheme(AppTheme theme) async {
    final themeData = ThemeRegistry.getByTheme(theme);
    if (!_canAccess(themeData)) return false;

    _applyWithoutPersist(theme);
    await _persist(theme);

    // If the user selects a premium dark theme while in light mode,
    // switch to dark mode so they see the theme immediately.
    if (theme != AppTheme.dark && !HunterTheme.isDark) {
      HunterTheme.isDark = true;
      themeNotifier.value = ThemeMode.dark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', true);
    }

    return true;
  }

  /// Whether the current user's membership tier can access [themeData].
  bool canAccess(AppThemeData themeData) => _canAccess(themeData);

  // ── Private ──────────────────────────────────────────────────────────────

  bool _canAccess(AppThemeData themeData) {
    final effectiveTier = MembershipService.instance.isMax
        ? MembershipTier.max
        : MembershipService.instance.isPro
            ? MembershipTier.pro
            : MembershipTier.basic;

    switch (themeData.requiredTier) {
      case MembershipTier.basic:
        return true;
      case MembershipTier.pro:
        return effectiveTier == MembershipTier.pro ||
            effectiveTier == MembershipTier.max;
      case MembershipTier.max:
        return effectiveTier == MembershipTier.max;
    }
  }

  void _applyWithoutPersist(AppTheme theme) {
    activeThemeNotifier.value = theme;
    final data = ThemeRegistry.getByTheme(theme);
    HunterTheme.activeDarkTheme = data;
    // Trigger a rebuild of the app's theme by nudging the themeNotifier.
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    themeNotifier.notifyListeners();
  }

  Future<void> _persist(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, theme.name);
  }

  void _onTierChanged() {
    final current = activeThemeNotifier.value;
    final currentData = ThemeRegistry.getByTheme(current);
    if (!_canAccess(currentData)) {
      _applyWithoutPersist(AppTheme.dark);
      _persist(AppTheme.dark);
      _showFallbackSnackbar(currentData);
    }
  }

  void _showFallbackSnackbar(AppThemeData lostTheme) {
    final tierName = lostTheme.requiredTier == MembershipTier.max ? 'MAX' : 'PRO';
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Your selected theme requires $tierName Membership. Dark Theme has been applied.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
