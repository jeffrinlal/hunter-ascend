import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reusable AdMob helpers.
///
/// Centralizes ONLY the duplicated [BannerAd] construction boilerplate
/// (standard size + ad request + listener wiring) that was repeated across
/// screens. Ad unit IDs, callbacks, `.load()` timing, banner placement,
/// disposal, and rewarded/punishment logic remain in each screen, unchanged.
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
