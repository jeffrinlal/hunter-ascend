import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Manages 30-day feature unlocks for Nutrition and Map via rewarded ads
/// for Basic users. Pro and Max users always have access.
///
/// Each feature unlock is independent and stored as an ISO date string
/// in the hunter document (nutritionUnlockExpiry, mapUnlockExpiry).
class FeatureUnlockService {
  FeatureUnlockService._();
  static final instance = FeatureUnlockService._();

  // ── Ad state ──
  RewardedAd? _nutritionAd;
  RewardedAd? _mapAd;
  bool _nutritionAdReady = false;
  bool _mapAdReady = false;
  bool _isShowingNutritionAd = false;
  bool _isShowingMapAd = false;

  /// Check if Nutrition is unlocked for the current user.
  /// Returns true if:
  /// - User is Pro or Max
  /// - User is Basic with a valid nutritionUnlockExpiry (not expired)
  Future<bool> isNutritionUnlocked() async {
    if (MembershipService.instance.hasPremium) {
      return true; // Pro and Max always unlocked
    }

    // Basic user: check expiry
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final expiryStr = data['nutritionUnlockExpiry'] as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    return DateTime.now().isBefore(expiry);
  }

  /// Check if Map is unlocked for the current user.
  /// Returns true if:
  /// - User is Pro or Max
  /// - User is Basic with a valid mapUnlockExpiry (not expired)
  Future<bool> isMapUnlocked() async {
    if (MembershipService.instance.hasPremium) {
      return true; // Pro and Max always unlocked
    }

    // Basic user: check expiry
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final expiryStr = data['mapUnlockExpiry'] as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    return DateTime.now().isBefore(expiry);
  }

  /// Get remaining days for Nutrition unlock (null if not unlocked or expired)
  Future<int?> getNutritionRemainingDays() async {
    final unlocked = await isNutritionUnlocked();
    if (!unlocked) return null;

    if (MembershipService.instance.hasPremium) {
      return null; // Permanent for premium
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    final expiryStr = data['nutritionUnlockExpiry'] as String?;
    if (expiryStr == null) return null;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return null;

    final remaining = expiry.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : null;
  }

  /// Get remaining days for Map unlock (null if not unlocked or expired)
  Future<int?> getMapRemainingDays() async {
    final unlocked = await isMapUnlocked();
    if (!unlocked) return null;

    if (MembershipService.instance.hasPremium) {
      return null; // Permanent for premium
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    final expiryStr = data['mapUnlockExpiry'] as String?;
    if (expiryStr == null) return null;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return null;

    final remaining = expiry.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : null;
  }

  /// Load Nutrition unlock rewarded ad
  void loadNutritionAd() {
    if (_nutritionAd != null) return;

    RewardedAd.load(
      adUnitId: AppConstants.streakRecoveryRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _nutritionAd = ad;
          _nutritionAdReady = true;
          debugPrint('[FeatureUnlock] Nutrition ad loaded');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[FeatureUnlock] Nutrition ad failed: $error');
          _nutritionAdReady = false;
        },
      ),
    );
  }

  /// Load Map unlock rewarded ad
  void loadMapAd() {
    if (_mapAd != null) return;

    RewardedAd.load(
      adUnitId: AppConstants.streakRecoveryRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _mapAd = ad;
          _mapAdReady = true;
          debugPrint('[FeatureUnlock] Map ad loaded');
        },
        onAdFailedToLoad: (error) {
          debugPrint('[FeatureUnlock] Map ad failed: $error');
          _mapAdReady = false;
        },
      ),
    );
  }

  /// Show Nutrition unlock flow
  Future<void> showNutritionUnlockFlow(BuildContext context) async {
    if (_isShowingNutritionAd) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Please sign in to unlock Nutrition')),
        );
      }
      return;
    }

    // Check if Pro/Max can skip ad
    final skipAd = await MembershipService.instance.shouldSkipRewardedAd();
    if (skipAd) {
      await _grantNutritionUnlock(user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Nutrition unlocked for 30 days!')),
        );
      }
      return;
    }

    // Check if ad is ready
    if (!_nutritionAdReady || _nutritionAd == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Ad not ready. Please try again.')),
        );
      }
      loadNutritionAd(); // Retry loading
      return;
    }

    _isShowingNutritionAd = true;
    bool rewardEarned = false;

    _nutritionAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _nutritionAd = null;
        _nutritionAdReady = false;
        _isShowingNutritionAd = false;
        loadNutritionAd(); // Preload next ad

        if (!rewardEarned && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Ad closed early. No unlock granted.')),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _nutritionAd = null;
        _nutritionAdReady = false;
        _isShowingNutritionAd = false;
        loadNutritionAd();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Ad failed to show: ${error.message}')),
          );
        }
      },
    );

    _nutritionAd!.show(onUserEarnedReward: (ad, reward) async {
      rewardEarned = true;
      await _grantNutritionUnlock(user.uid);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Nutrition unlocked for 30 days!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  /// Show Map unlock flow
  Future<void> showMapUnlockFlow(BuildContext context) async {
    if (_isShowingMapAd) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Please sign in to unlock Map')),
        );
      }
      return;
    }

    // Check if Pro/Max can skip ad
    final skipAd = await MembershipService.instance.shouldSkipRewardedAd();
    if (skipAd) {
      await _grantMapUnlock(user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Map unlocked for 30 days!')),
        );
      }
      return;
    }

    // Check if ad is ready
    if (!_mapAdReady || _mapAd == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Ad not ready. Please try again.')),
        );
      }
      loadMapAd(); // Retry loading
      return;
    }

    _isShowingMapAd = true;
    bool rewardEarned = false;

    _mapAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _mapAd = null;
        _mapAdReady = false;
        _isShowingMapAd = false;
        loadMapAd(); // Preload next ad

        if (!rewardEarned && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Ad closed early. No unlock granted.')),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _mapAd = null;
        _mapAdReady = false;
        _isShowingMapAd = false;
        loadMapAd();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Ad failed to show: ${error.message}')),
          );
        }
      },
    );

    _mapAd!.show(onUserEarnedReward: (ad, reward) async {
      rewardEarned = true;
      await _grantMapUnlock(user.uid);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Map unlocked for 30 days!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  /// Grant Nutrition unlock (30 days from now)
  Future<void> _grantNutritionUnlock(String uid) async {
    final expiry = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .update({'nutritionUnlockExpiry': expiry.toIso8601String()});
    debugPrint('[FeatureUnlock] Nutrition unlocked until $expiry');
  }

  /// Grant Map unlock (30 days from now)
  Future<void> _grantMapUnlock(String uid) async {
    final expiry = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .update({'mapUnlockExpiry': expiry.toIso8601String()});
    debugPrint('[FeatureUnlock] Map unlocked until $expiry');
  }

  /// Dispose all ads (call on app close/logout)
  void dispose() {
    _nutritionAd?.dispose();
    _mapAd?.dispose();
    _nutritionAd = null;
    _mapAd = null;
    _nutritionAdReady = false;
    _mapAdReady = false;
  }
}
