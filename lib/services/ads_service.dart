import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Reusable AdMob helpers.
///
/// Centralizes the duplicated [BannerAd] construction boilerplate
/// (standard size + ad request + listener wiring) and the shared
/// mission-banner lifecycle ([MissionBannerAd]) used by every surface that
/// runs a mission. Ad unit IDs, rewarded/punishment logic and banner
/// placement remain where they always were.
class AdsService {
  AdsService._();

  /// Builds a standard `AdSize.banner` [BannerAd] for [adUnitId] with the
  /// given listener callbacks. The caller still calls `.load()` (preserving
  /// the original per-screen load timing) and is responsible for disposal.
  static BannerAd createBannerAd({
    required String adUnitId,
    required void Function(Ad ad) onAdLoaded,
    void Function(Ad ad, LoadAdError error)? onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }
}

/// Banner ad shown on the active mission card.
///
/// The shared banner lifecycle the Missions screen has always used, now
/// reusable by any surface that runs a mission (Missions, Dungeons):
/// the standard banner unit ([AppConstants.dashboardBannerAdUnitId]), ONE
/// retry three seconds after a failed load, and automatic dispose/reload
/// when the membership tier gains or loses banner ads.
class MissionBannerAd {
  MissionBannerAd({this.onChanged}) {
    MembershipService.instance.tierNotifier.addListener(_onTierChanged);
  }

  /// Called whenever [ad] / [ready] change (load succeeded, tier flipped) —
  /// screens typically `setState` here.
  final VoidCallback? onChanged;

  BannerAd? _ad;
  bool _ready = false;
  bool _retried = false;

  BannerAd? get ad => _ad;
  bool get ready => _ready;

  void load() {
    if (!MembershipService.instance.showBannerAds) return;
    if (_ad != null) return;
    _ad = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) {
        _ready = true;
        onChanged?.call();
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('MISSION BANNER FAILED: $error');
        ad.dispose();
        _ad = null;
        // Retry once after a short delay.
        if (_retried) return;
        _retried = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (_ad == null) {
            _ad = AdsService.createBannerAd(
              adUnitId: AppConstants.dashboardBannerAdUnitId,
              onAdLoaded: (ad) {
                _ready = true;
                onChanged?.call();
              },
              onAdFailedToLoad: (ad, error) {
                debugPrint('MISSION BANNER RETRY FAILED: $error');
                ad.dispose();
                _ad = null;
              },
            );
            _ad!.load();
          }
        });
      },
    );
    _ad!.load();
  }

  void _onTierChanged() {
    if (!MembershipService.instance.showBannerAds) {
      _disposeAd();
    } else if (_ad == null) {
      _retried = false;
      load();
    }
    onChanged?.call();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _ready = false;
  }

  void dispose() {
    MembershipService.instance.tierNotifier.removeListener(_onTierChanged);
    _disposeAd();
  }
}
