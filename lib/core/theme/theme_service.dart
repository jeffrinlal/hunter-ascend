import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/theme_registry.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Manages premium dark-theme selection, persistence, membership validation,
/// ad-reward unlock expiry, and automatic fallback.
///
/// ## Startup
/// Call [initialize] once in `main.dart` after [MembershipService] has loaded.
///
/// ## Applying a theme
/// ```dart
/// ThemeService.instance.applyTheme(AppTheme.shadowBlue);
/// ```
///
/// ## Special (ad-reward) themes
/// ```dart
/// ThemeService.instance.unlockSpecialTheme(AppTheme.crystalGlass);
/// ```
/// Unlocks the theme for 24 hours. On startup or when checked, expired
/// unlocks automatically revert to Dark with a snackbar.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _prefsKey = 'selectedDarkThemeId';

  /// SharedPreferences key prefix for ad-reward theme expiry timestamps.
  /// Full key: `specialThemeExpiry_<themeName>` e.g. `specialThemeExpiry_crystalGlass`
  static const String _specialExpiryPrefix = 'specialThemeExpiry_';

  /// Default duration a special theme remains unlocked if [AppThemeData.unlockDuration]
  /// is not specified. Individual themes override this via their own field.
  static const Duration _defaultUnlockDuration = Duration(hours: 24);

  /// Fires whenever the active dark theme changes.
  /// The gallery and any other listeners can rebuild on this.
  final ValueNotifier<AppTheme> activeThemeNotifier =
      ValueNotifier<AppTheme>(AppTheme.dark);

  /// The currently applied dark theme data.
  AppThemeData get activeThemeData =>
      ThemeRegistry.getByTheme(activeThemeNotifier.value);

  /// Global key used to show snackbars from the service layer (e.g. on
  /// membership downgrade or special theme expiry).
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;

  /// Initializes the theme service: loads persisted selection, validates
  /// access (membership + ad-reward expiry), applies the theme, and starts
  /// listening for membership tier changes.
  ///
  /// Must be called once after [MembershipService.instance.loadMembership()]
  /// completes.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final savedId = prefs.getString(_prefsKey);
    final theme = AppTheme.fromId(savedId);
    final themeData = ThemeRegistry.getByTheme(theme);

    if (_canAccess(themeData)) {
      _applyWithoutPersist(theme);
    } else {
      // User no longer has access (membership expired or special theme expired).
      _applyWithoutPersist(AppTheme.dark);
      await _persist(AppTheme.dark);
      // Schedule snackbar after first frame so the scaffold is available.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (themeData.isAdRewardTheme) {
          _showSpecialExpiredSnackbar(themeData);
        } else {
          _showFallbackSnackbar(themeData);
        }
      });
    }

    // Listen for membership tier changes (upgrade/downgrade).
    MembershipService.instance.tierNotifier.addListener(_onTierChanged);
  }

  /// Applies a theme, persists the selection, and notifies listeners.
  ///
  /// Returns `true` if the theme was successfully applied, `false` if the
  /// user does not have access (caller should show upgrade/ad dialog).
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

  /// Whether the current user can access [themeData] right now.
  bool canAccess(AppThemeData themeData) => _canAccess(themeData);

  // ─────────────────────────────────────────────────────────────────────────
  // Special (Ad-Reward) Theme Unlock
  // ─────────────────────────────────────────────────────────────────────────

  /// Unlocks a special theme for [specialUnlockDuration] (24h).
  /// Called after the rewarded ad callback fires successfully.
  /// Persists the expiry timestamp and applies the theme immediately.
  Future<void> unlockSpecialTheme(AppTheme theme) async {
    final themeData = ThemeRegistry.getByTheme(theme);
    if (!themeData.isAdRewardTheme) return;

    final duration = themeData.unlockDuration ?? _defaultUnlockDuration;
    final expiry = DateTime.now().add(duration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_specialExpiryPrefix${theme.name}',
      expiry.millisecondsSinceEpoch,
    );

    // Apply the theme.
    _applyWithoutPersist(theme);
    await _persist(theme);

    // Switch to dark mode if needed.
    if (!HunterTheme.isDark) {
      HunterTheme.isDark = true;
      themeNotifier.value = ThemeMode.dark;
      final p = await SharedPreferences.getInstance();
      await p.setBool('darkMode', true);
    }
  }

  /// Returns the expiry [DateTime] for a special theme, or `null` if it has
  /// never been unlocked or the key doesn't exist.
  Future<DateTime?> getSpecialThemeExpiry(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('$_specialExpiryPrefix${theme.name}');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Whether a special theme is currently unlocked (expiry in the future).
  Future<bool> isSpecialThemeUnlocked(AppTheme theme) async {
    final expiry = await getSpecialThemeExpiry(theme);
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  // ── Private ──────────────────────────────────────────────────────────────

  bool _canAccess(AppThemeData themeData) {
    // Ad-reward themes: check expiry synchronously from cached prefs.
    if (themeData.isAdRewardTheme) {
      return _isSpecialUnlockedSync(themeData.theme);
    }

    // Membership-gated themes.
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

  /// Synchronous check for special theme unlock using the SharedPreferences
  /// instance cached during [initialize]. Falls back to false if prefs
  /// haven't been loaded yet.
  bool _isSpecialUnlockedSync(AppTheme theme) {
    // SharedPreferences is synchronous after the first getInstance() await.
    // We use a sync read here since initialize() has already awaited it.
    final prefs = _cachedPrefs;
    if (prefs == null) return false;
    final millis = prefs.getInt('$_specialExpiryPrefix${theme.name}');
    if (millis == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(millis).isAfter(DateTime.now());
  }

  /// Cached SharedPreferences instance (set during initialize).
  SharedPreferences? _cachedPrefs;

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
    _cachedPrefs = prefs;
    await prefs.setString(_prefsKey, theme.name);
  }

  void _onTierChanged() {
    final current = activeThemeNotifier.value;
    final currentData = ThemeRegistry.getByTheme(current);
    if (!_canAccess(currentData)) {
      _applyWithoutPersist(AppTheme.dark);
      _persist(AppTheme.dark);
      if (currentData.isAdRewardTheme) {
        _showSpecialExpiredSnackbar(currentData);
      } else {
        _showFallbackSnackbar(currentData);
      }
    }
  }

  void _showFallbackSnackbar(AppThemeData lostTheme) {
    final tierName =
        lostTheme.requiredTier == MembershipTier.max ? 'MAX' : 'PRO';
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Your selected theme requires $tierName Membership. Dark Theme has been applied.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSpecialExpiredSnackbar(AppThemeData lostTheme) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('${lostTheme.name} theme expired.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
