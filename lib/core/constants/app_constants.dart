/// App-wide constants that centralize literal values repeated across more
/// than one file. Every value here is byte-identical to the literal it
/// replaces — this changes only where the value is declared, never the value.
library;

class AppConstants {
  AppConstants._();

  // ── AdMob banner ad unit IDs ───────────────────────────────────────────
  /// Banner used on the Calorie Tracker and Duel Request screens.
  static const String challengeBannerAdUnitId =
      'ca-app-pub-5435480116436845/4699186117';

  /// Banner used on the Dashboard (home + weekly) and the Duel screen.
  static const String dashboardBannerAdUnitId =
      'ca-app-pub-5435480116436845/4995463929';

  /// Banner used on the Map History screen.
  static const String mapHistoryBannerAdUnitId =
      'ca-app-pub-5435480116436845/6580125873';

  // ── AdMob rewarded ad unit IDs ─────────────────────────────────────────
  /// Rewarded ad for streak recovery and membership claims.
  static const String streakRecoveryRewardedAdUnitId =
      'ca-app-pub-5435480116436845/4406856317';

  /// Rewarded ad for discipline punishment.
  static const String punishmentRewardedAdUnitId =
      'ca-app-pub-5435480116436845/7002658082';

  // ── AdMob test ad unit IDs (debug builds only) ─────────────────────────
  /// Google's official test rewarded ad unit ID.
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Google's official test banner ad unit ID.
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
}
