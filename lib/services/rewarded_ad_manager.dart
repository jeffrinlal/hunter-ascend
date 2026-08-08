import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';


/// Manages rewarded ad loading, caching, and lifecycle for rewarded-ad
/// unlock flows (membership claims, plan shop unlocks, streak recovery).
/// Automatically preloads the next ad after one is consumed.
///
/// Pass [adUnitId] to use a specific ad unit; otherwise defaults to the
/// same streak-recovery rewarded ad unit used by the membership screen
/// (debug/release switching handled by [AppConstants]).
///
/// Usage:
/// ```dart
/// final manager = RewardedAdManager(
///   onAdStatusChanged: () => setState(() {}),
/// );
/// manager.loadAd();
/// // ...
/// manager.showAd(onRewardEarned: () { /* claim reward */ });
/// // ...
/// manager.dispose();
/// ```
class RewardedAdManager {
  RewardedAdManager({
    required this.onAdStatusChanged,
    String? adUnitId,
  }) : _adUnitId = adUnitId ?? AppConstants.streakRecoveryRewardedAdUnitId;

  /// Called whenever the ad status changes (loaded, failed, shown, etc.)
  /// so the UI can rebuild.
  final VoidCallback onAdStatusChanged;

  /// Rewarded ad unit ID. Defaults to the streak-recovery/membership unit
  /// (with automatic debug/release switching via [AppConstants]).
  final String _adUnitId;

  /// The currently cached rewarded ad (null if not loaded).
  RewardedAd? _rewardedAd;

  /// Whether an ad is currently loading.
  bool _isLoading = false;

  /// Number of consecutive load failures (for retry backoff).
  int _loadFailures = 0;

  /// Maximum retry attempts before giving up.
  static const int _maxRetries = 3;

  // ── Public State ─────────────────────────────────────────────────────────

  /// Whether a rewarded ad is ready to be shown.
  bool get isReady => _rewardedAd != null;

  /// Whether an ad is currently loading.
  bool get isLoading => _isLoading;

  /// Whether the ad is unavailable (failed to load after retries).
  bool get isUnavailable => !isReady && !_isLoading && _loadFailures >= _maxRetries;

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Loads a rewarded ad. Safe to call multiple times — will not duplicate
  /// load requests if one is already in progress or an ad is cached.
  void loadAd() {
    if (_rewardedAd != null || _isLoading) return;

    _isLoading = true;
    onAdStatusChanged();

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _loadFailures = 0;
          onAdStatusChanged();
          debugPrint('RewardedAdManager: Ad loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          _loadFailures++;
          onAdStatusChanged();
          debugPrint('RewardedAdManager: Ad failed to load — '
              '${error.message} (attempt $_loadFailures/$_maxRetries)');

          // Retry with exponential backoff if under max retries.
          if (_loadFailures < _maxRetries) {
            final delay = Duration(seconds: 2 * _loadFailures);
            Future.delayed(delay, loadAd);
          }
        },
      ),
    );
  }

  // ── Show ─────────────────────────────────────────────────────────────────

  /// Shows the cached rewarded ad. Calls [onRewardEarned] when the user
  /// earns the reward. Calls [onAdDismissed] when the ad is closed
  /// (regardless of reward status). Calls [onAdFailed] if the ad cannot
  /// be shown.
  ///
  /// Automatically loads the next ad after the current one is consumed.
  void showAd({
    required VoidCallback onRewardEarned,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('RewardedAdManager: No ad available to show.');
      onAdFailed?.call();
      return;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdDismissed?.call();
        // Preload next ad immediately.
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('RewardedAdManager: Ad failed to show — ${error.message}');
        ad.dispose();
        onAdFailed?.call();
        // Try loading another ad.
        loadAd();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      debugPrint('RewardedAdManager: Reward earned — '
          '${reward.amount} ${reward.type}');
      onRewardEarned();
    });

    onAdStatusChanged();
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  /// Resets the failure counter and attempts to load again.
  /// Use when the user manually retries.
  void retry() {
    _loadFailures = 0;
    loadAd();
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  /// Disposes the cached ad and cleans up resources.
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
