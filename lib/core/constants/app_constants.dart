/// App-wide constants that centralize literal values repeated across more
/// than one file. Every value here is byte-identical to the literal it
/// replaces — this changes only where the value is declared, never the value.
library;

class AppConstants {
  AppConstants._();

  // ── AdMob banner ad unit IDs (each used in multiple screens) ───────────
  /// Banner used on the Calorie Tracker and Duel Request screens.
  static const String challengeBannerAdUnitId =
      'ca-app-pub-5435480116436845/4699186117';

  /// Banner used on the Dashboard (home + weekly) and the Duel screen.
  static const String dashboardBannerAdUnitId =
      'ca-app-pub-5435480116436845/4995463929';

  // ── AdMob rewarded ad unit IDs ─────────────────────────────────────────
  /// Rewarded ad used on the Membership screen (Pro/Max membership claims).
  static const String membershipRewardedAdUnitId =
      'ca-app-pub-5435480116436845/4406856317';

  /// Google's official test rewarded ad unit ID (used in debug builds).
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
}
