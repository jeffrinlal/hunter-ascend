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
}
