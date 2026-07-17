/// App-wide constants that centralize literal values repeated across more
/// than one file. Every value here is byte-identical to the literal it
/// replaces — this changes only where the value is declared, never the value.
library;

import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  // ── Production AdMob banner ad unit IDs ────────────────────────────────
  static const String _prodChallengeBannerAdUnitId =
      'ca-app-pub-5435480116436845/4699186117';

  static const String _prodDashboardBannerAdUnitId =
      'ca-app-pub-5435480116436845/4995463929';

  static const String _prodMapHistoryBannerAdUnitId =
      'ca-app-pub-5435480116436845/6580125873';

  // ── Production AdMob rewarded ad unit IDs ──────────────────────────────
  static const String _prodStreakRecoveryRewardedAdUnitId =
      'ca-app-pub-5435480116436845/4406856317';

  static const String _prodPunishmentRewardedAdUnitId =
      'ca-app-pub-5435480116436845/7002658082';

  // ── Google official test ad unit IDs ───────────────────────────────────
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── Public getters: automatically return test IDs in debug, ────────────
  // ── production IDs in release builds. ──────────────────────────────────

  /// Banner used on the Calorie Tracker and Duel Request screens.
  static String get challengeBannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodChallengeBannerAdUnitId;

  /// Banner used on the Dashboard (home + weekly) and the Duel screen.
  static String get dashboardBannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodDashboardBannerAdUnitId;

  /// Banner used on the Map History screen.
  static String get mapHistoryBannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodMapHistoryBannerAdUnitId;

  /// Rewarded ad for streak recovery and membership claims.
  static String get streakRecoveryRewardedAdUnitId =>
      kDebugMode ? _testRewardedAdUnitId : _prodStreakRecoveryRewardedAdUnitId;

  /// Rewarded ad for discipline punishment.
  static String get punishmentRewardedAdUnitId =>
      kDebugMode ? _testRewardedAdUnitId : _prodPunishmentRewardedAdUnitId;
}
