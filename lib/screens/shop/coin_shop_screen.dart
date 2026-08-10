import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/models/fitness_plan.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/models/shop_item.dart';
import 'package:hunter_ascend/services/coin_service.dart';
import 'package:hunter_ascend/services/shop_service.dart';
import 'package:hunter_ascend/services/plan_shop_service.dart';
import 'package:hunter_ascend/services/rewarded_ad_manager.dart';
import 'package:hunter_ascend/screens/profile/plan_viewer_screen.dart';

/// Coin Shop — Phase 1 Foundation + Fitness Plans Integration.
///
/// Unified shop containing:
/// - Cosmetics (avatar frames, titles, effects) purchased with coins
/// - Fitness Plans (PDF plans) unlocked with rewarded ads
///
/// The shop displays both types of content in a tabbed interface.
/// Minimum cosmetic price: 400 coins.
/// Basic/Pro/Max all use the SAME shop prices and coin economy.
class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key});

  @override
  State<CoinShopScreen> createState() => _CoinShopScreenState();
}

/// State of the rewarded ad button (for fitness plans).
enum _AdButtonState { loading, ready, unavailable }

class _CoinShopScreenState extends State<CoinShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _coins = 0;
  Set<String> _ownedItems = {};
  String? _equippedAvatarFrame;
  String? _equippedHunterTitle;
  String? _equippedProfileEffect;
  int _hunterLevel = 1;
  bool _loading = true;
  ShopItemCategory _selectedCategory = ShopItemCategory.avatarFrame;

  // Fitness Plans ad manager
  late final RewardedAdManager _adManager;
  String? _unlockingPlanId;

  // Coin earning ad manager
  late final RewardedAdManager _coinAdManager;
  bool _isEarningCoins = false;
  int _adsWatchedInSequence = 0; // 0, 1, or 2 for the 2-ad flow
  bool _isLoadingSecondAd = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 3 cosmetics + 1 fitness
    _loadShopData();

    _adManager = RewardedAdManager(
      onAdStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    _adManager.loadAd();

    _coinAdManager = RewardedAdManager(
      onAdStatusChanged: () {
        if (mounted) {
          setState(() {
            // Update loading state when ad status changes
            if (_adsWatchedInSequence == 1) {
              _isLoadingSecondAd = _coinAdManager.isLoading;
            }
          });
        }
      },
    );
    _coinAdManager.loadAd();
  }

  @override
  void dispose() {
    _adManager.dispose();
    _coinAdManager.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    setState(() => _loading = true);

    final coins = await CoinService.instance.getCurrentBalance();
    final owned = await ShopService.instance.getOwnedItems();
    final equippedFrame =
        await ShopService.instance.getEquippedItem(ShopItemCategory.avatarFrame);
    final equippedTitle =
        await ShopService.instance.getEquippedItem(ShopItemCategory.hunterTitle);
    final equippedEffect = await ShopService.instance
        .getEquippedItem(ShopItemCategory.profileEffect);

    final hunter = HunterRepository.instance.getCached();
    final level = hunter?.level ?? 1;

    if (mounted) {
      setState(() {
        _coins = coins;
        _ownedItems = owned;
        _equippedAvatarFrame = equippedFrame;
        _equippedHunterTitle = equippedTitle;
        _equippedProfileEffect = equippedEffect;
        _hunterLevel = level;
        _loading = false;
      });
    }
  }

  // ── Fitness Plan Rewarded Ad ──────────────────────────────────────────

  _AdButtonState _adStateFromManager() {
    if (_adManager.isReady) return _AdButtonState.ready;
    if (_adManager.isLoading) return _AdButtonState.loading;
    return _AdButtonState.unavailable;
  }

  void _showAdForPlan(FitnessPlan plan) {
    if (_unlockingPlanId != null) return;

    _adManager.showAd(
      onRewardEarned: () => _claimPlanUnlock(plan),
      onAdDismissed: () {
        if (mounted) setState(() {});
      },
      onAdFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Could not show rewarded ad. Please try again.'),
              backgroundColor: HunterTheme.danger,
            ),
          );
        }
      },
    );
    setState(() {});
  }

  Future<void> _claimPlanUnlock(FitnessPlan plan) async {
    if (!mounted) return;
    setState(() => _unlockingPlanId = plan.id);

    final result = await PlanShopService.instance.claimPlanUnlock(plan);

    if (!mounted) return;

    setState(() => _unlockingPlanId = null);

    if (result.wasUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${plan.title} unlocked for ${plan.durationDays} days!'),
          backgroundColor: HunterTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result.message ?? 'Failed to unlock plan.'}'),
          backgroundColor: HunterTheme.danger,
        ),
      );
    }
  }

  void _openPlanViewer(FitnessPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanViewerScreen(plan: plan),
      ),
    );
  }

  // ── Coin Earning via Rewarded Ads ─────────────────────────────────────

  /// Watch 1 ad → +20 coins
  void _earnCoinsWithOneAd() {
    if (_isEarningCoins) return;
    if (!_coinAdManager.isReady) return;

    setState(() => _isEarningCoins = true);

    _coinAdManager.showAd(
      onRewardEarned: () => _awardCoinsAfterAd(20),
      onAdDismissed: () {
        if (mounted) {
          setState(() => _isEarningCoins = false);
        }
      },
      onAdFailed: () {
        if (mounted) {
          setState(() => _isEarningCoins = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Could not show ad. Please try again.'),
              backgroundColor: HunterTheme.danger,
            ),
          );
        }
      },
    );
  }

  /// Watch 2 ads → +50 coins total
  /// Must watch BOTH ads successfully to get the reward.
  /// User must explicitly tap to watch the second ad.
  void _earnCoinsWithTwoAds() {
    if (_isEarningCoins) return;
    if (!_coinAdManager.isReady) return;

    setState(() {
      _isEarningCoins = true;
      _adsWatchedInSequence = 0;
      _isLoadingSecondAd = false;
    });

    _showFirstOfTwoAds();
  }

  void _showFirstOfTwoAds() {
    if (!_coinAdManager.isReady) {
      // Ad not ready, abort sequence
      if (mounted) {
        setState(() {
          _isEarningCoins = false;
          _adsWatchedInSequence = 0;
          _isLoadingSecondAd = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Ad not ready. Please try again.'),
            backgroundColor: HunterTheme.danger,
          ),
        );
      }
      return;
    }

    _coinAdManager.showAd(
      onRewardEarned: () {
        // First ad completed successfully
        if (mounted) {
          setState(() {
            _adsWatchedInSequence = 1;
            _isLoadingSecondAd = true;
          });
          // RewardedAdManager automatically loads the next ad in onAdDismissedFullScreenContent
          // Do NOT call loadAd() here - it's already handled
        }
      },
      onAdDismissed: () {
        // User closed the ad
        if (_adsWatchedInSequence == 0) {
          // First ad was closed/failed, abort sequence
          if (mounted) {
            setState(() {
              _isEarningCoins = false;
              _adsWatchedInSequence = 0;
              _isLoadingSecondAd = false;
            });
          }
        } else {
          // First ad completed, ad manager will automatically load next ad
          if (mounted) {
            setState(() {
              _isLoadingSecondAd = _coinAdManager.isLoading;
            });
          }
        }
      },
      onAdFailed: () {
        // First ad failed, abort sequence
        if (mounted) {
          setState(() {
            _isEarningCoins = false;
            _adsWatchedInSequence = 0;
            _isLoadingSecondAd = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Could not show ad. Please try again.'),
              backgroundColor: HunterTheme.danger,
            ),
          );
        }
      },
    );
  }

  void _showSecondOfTwoAds() {
    if (_adsWatchedInSequence != 1) return; // Prevent duplicate taps
    if (!_coinAdManager.isReady) {
      // Second ad not ready yet
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⏳ Second ad is still loading. Please wait.'),
            backgroundColor: HunterTheme.info,
          ),
        );
      }
      return;
    }

    setState(() => _isLoadingSecondAd = false);

    _coinAdManager.showAd(
      onRewardEarned: () {
        // Second ad completed successfully, award 50 coins total
        if (mounted) {
          setState(() => _adsWatchedInSequence = 2);
          _awardCoinsAfterAd(50);
        }
      },
      onAdDismissed: () {
        // User closed the second ad
        if (_adsWatchedInSequence < 2) {
          // Second ad was closed/failed, don't award coins
          if (mounted) {
            setState(() {
              _isEarningCoins = false;
              _adsWatchedInSequence = 0;
              _isLoadingSecondAd = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('❌ Second ad not completed. No coins awarded.'),
                backgroundColor: HunterTheme.danger,
              ),
            );
          }
        }
      },
      onAdFailed: () {
        // Second ad failed, don't award coins
        if (mounted) {
          setState(() {
            _isEarningCoins = false;
            _adsWatchedInSequence = 0;
            _isLoadingSecondAd = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Second ad failed. No coins awarded.'),
              backgroundColor: HunterTheme.danger,
            ),
          );
        }
      },
    );
  }

  Future<void> _awardCoinsAfterAd(int amount) async {
    final newBalance = await CoinService.instance.awardCoins(amount: amount);

    if (!mounted) return;

    if (newBalance != null) {
      setState(() {
        _coins = newBalance;
        _isEarningCoins = false;
        _adsWatchedInSequence = 0;
        _isLoadingSecondAd = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Earned $amount coins! New balance: $newBalance 🪙'),
          backgroundColor: HunterTheme.success,
        ),
      );
    } else {
      setState(() {
        _isEarningCoins = false;
        _adsWatchedInSequence = 0;
        _isLoadingSecondAd = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Failed to award coins. Please try again.'),
          backgroundColor: HunterTheme.danger,
        ),
      );
    }
  }

  // ── Cosmetic Shop Methods (existing) ──────────────────────────────────

  Future<void> _purchaseItem(ShopItem item) async {
    if (_ownedItems.contains(item.id)) return;
    if (_coins < item.price) {
      _showInsufficientCoinsDialog(item.price);
      return;
    }

    final success = await ShopService.instance.purchaseItem(item.id);

    if (success) {
      await _loadShopData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Purchased ${item.name}!'),
            backgroundColor: HunterTheme.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Purchase failed. Please try again.'),
            backgroundColor: HunterTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _equipItem(ShopItem item) async {
    final success = await ShopService.instance.equipItem(item.id);

    if (success) {
      await _loadShopData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Equipped ${item.name}!'),
            backgroundColor: HunterTheme.success,
          ),
        );
      }
    }
  }

  void _showInsufficientCoinsDialog(int requiredPrice) {
    final theme = MembershipTheme.current;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HunterTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: HunterTheme.gold,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'INSUFFICIENT COINS',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You need $requiredPrice coins.\nYou have $_coins coins.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete dungeons to earn more coins!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'UNDERSTOOD',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MembershipTheme.current; // Get current membership theme
    
    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        backgroundColor: HunterTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: HunterTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'COIN SHOP',
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HunterTheme.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🪙',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_coins',
                    style: TextStyle(
                      color: HunterTheme.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.accent,
              ),
            )
          : Column(
              children: [
                _buildEarnCoinsSection(),
                _buildCategoryTabs(),
                Expanded(child: _buildItemGrid()),
              ],
            ),
    );
  }

  Widget _buildEarnCoinsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HunterTheme.gold.withOpacity(0.12),
            HunterTheme.gold.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🪙',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'EARN COINS',
                style: TextStyle(
                  color: HunterTheme.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Watch ads to earn more coins.',
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          // Show different UI based on state
          if (_adsWatchedInSequence == 0)
            // Initial state: Show both options
            Row(
              children: [
                Expanded(
                  child: _buildEarnCoinsButton(
                    label: 'Watch 1 Ad',
                    reward: '+20 🪙',
                    onTap: _earnCoinsWithOneAd,
                    isLoading: _isEarningCoins && _adsWatchedInSequence == 0,
                    isDisabled: _isEarningCoins || !_coinAdManager.isReady,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEarnCoinsButton(
                    label: 'Watch 2 Ads',
                    reward: '+50 🪙',
                    onTap: _earnCoinsWithTwoAds,
                    isLoading: false,
                    isDisabled: _isEarningCoins || !_coinAdManager.isReady,
                  ),
                ),
              ],
            )
          else if (_adsWatchedInSequence == 1)
            // After first ad: Show progress and second ad button
            Column(
              children: [
                // Progress indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: HunterTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HunterTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: HunterTheme.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '✓ Ad 1/2 completed',
                        style: TextStyle(
                          color: HunterTheme.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Second ad button, loading state, or error state
                if (_isLoadingSecondAd)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: HunterTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HunterTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HunterTheme.gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '⏳ Loading Ad 2/2...',
                          style: TextStyle(
                            color: HunterTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_coinAdManager.isUnavailable)
                  // Show retry option if ad failed to load
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: HunterTheme.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HunterTheme.danger.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: HunterTheme.danger,
                              size: 20,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ad 2/2 failed to load',
                              style: TextStyle(
                                color: HunterTheme.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() => _isLoadingSecondAd = true);
                          _coinAdManager.retry();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: HunterTheme.info.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: HunterTheme.info),
                          ),
                          child: Text(
                            'Retry Loading Ad',
                            style: TextStyle(
                              color: HunterTheme.info,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: _coinAdManager.isReady ? _showSecondOfTwoAds : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _coinAdManager.isReady
                            ? HunterTheme.gold.withOpacity(0.15)
                            : HunterTheme.cardColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _coinAdManager.isReady
                              ? HunterTheme.gold
                              : HunterTheme.border,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Watch Ad 2/2 → +50 🪙',
                          style: TextStyle(
                            color: _coinAdManager.isReady
                                ? HunterTheme.gold
                                : HunterTheme.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Cancel button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEarningCoins = false;
                      _adsWatchedInSequence = 0;
                      _isLoadingSecondAd = false;
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEarnCoinsButton({
    required String label,
    required String reward,
    required VoidCallback onTap,
    required bool isLoading,
    required bool isDisabled,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? HunterTheme.cardColor.withOpacity(0.5)
              : HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? HunterTheme.border.withOpacity(0.3)
                : HunterTheme.gold.withOpacity(0.5),
          ),
        ),
        child: Column(
          children: [
            if (isLoading)
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HunterTheme.gold,
                ),
              )
            else
              Text(
                label,
                style: TextStyle(
                  color: isDisabled
                      ? HunterTheme.textTertiary
                      : HunterTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              reward,
              style: TextStyle(
                color: isDisabled
                    ? HunterTheme.textTertiary
                    : HunterTheme.gold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HunterTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCategoryTab(
              'Avatar Frames',
              '🖼️',
              0,
            ),
          ),
          Container(width: 1, height: 40, color: HunterTheme.border),
          Expanded(
            child: _buildCategoryTab(
              'Titles',
              '🏷️',
              1,
            ),
          ),
          Container(width: 1, height: 40, color: HunterTheme.border),
          Expanded(
            child: _buildCategoryTab(
              'Effects',
              '✨',
              2,
            ),
          ),
          Container(width: 1, height: 40, color: HunterTheme.border),
          Expanded(
            child: _buildCategoryTab(
              'Plans',
              '📋',
              3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String label, String emoji, int index) {
    final theme = MembershipTheme.current;
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accent.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected
                        ? theme.accent
                        : HunterTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Avatar Frames
        _buildCosmeticGrid(ShopCatalog.getItemsByCategory(
            ShopItemCategory.avatarFrame, _hunterLevel)),
        // Titles
        _buildCosmeticGrid(ShopCatalog.getItemsByCategory(
            ShopItemCategory.hunterTitle, _hunterLevel)),
        // Effects
        _buildCosmeticGrid(ShopCatalog.getItemsByCategory(
            ShopItemCategory.profileEffect, _hunterLevel)),
        // Fitness Plans
        _buildFitnessPlansTab(),
      ],
    );
  }

  Widget _buildCosmeticGrid(List<ShopItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items available yet.\nKeep leveling up!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index]),
    );
  }

  Widget _buildFitnessPlansTab() {
    final theme = MembershipTheme.current;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: HunterTheme.textFaint),
              const SizedBox(height: 16),
              Text(
                'Sign in to unlock fitness plans',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection('planUnlocks')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: theme.accent),
          );
        }

        final Map<String, PlanUnlockState> unlockMap = {};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final state = PlanShopService.stateFromSnapshot(doc);
            if (state != null) {
              unlockMap[doc.id] = state;
            }
          }
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: PlanCatalog.all.length,
          itemBuilder: (context, index) {
            final plan = PlanCatalog.all[index];
            final unlock = unlockMap[plan.id];
            return _buildPlanCard(plan, unlock);
          },
        );
      },
    );
  }

  Widget _buildPlanCard(FitnessPlan plan, PlanUnlockState? unlock) {
    final accent = plan.goal.accentColor;
    final isActive = unlock?.isActive ?? false;
    final isExpired = unlock?.isExpired ?? false;

    return GestureDetector(
      onTap: isActive ? () => _openPlanViewer(plan) : () => _showAdForPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? accent.withOpacity(0.5) : HunterTheme.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Icon(plan.goal.icon, size: 40, color: accent.withOpacity(0.8)),
                const SizedBox(height: 8),
                Text(
                  plan.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.durationDays} days',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '✓ VIEW PLAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              )
            else if (isExpired)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: HunterTheme.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    '🎥 UNLOCK AGAIN',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _unlockingPlanId == plan.id ? 'UNLOCKING...' : '🎥 WATCH AD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final theme = MembershipTheme.current;
    final isOwned = _ownedItems.contains(item.id);
    final isEquipped = _isEquipped(item);
    final canAfford = _coins >= item.price;

    return GestureDetector(
      onTap:
          isOwned
              ? (isEquipped ? null : () => _equipItem(item))
              : () => _purchaseItem(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isEquipped
                    ? HunterTheme.gold
                    : isOwned
                        ? HunterTheme.success.withOpacity(0.4)
                        : HunterTheme.border,
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            Column(
              children: [
                if (!isOwned) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: HunterTheme.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: HunterTheme.gold.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '${item.price}',
                          style: TextStyle(
                            color: HunterTheme.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        isEquipped
                            ? HunterTheme.gold.withOpacity(0.15)
                            : isOwned
                                ? HunterTheme.success.withOpacity(0.12)
                                : canAfford
                                    ? theme.accent.withOpacity(0.15)
                                    : HunterTheme.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isEquipped
                              ? HunterTheme.gold
                              : isOwned
                                  ? HunterTheme.success
                                  : canAfford
                                      ? theme.accent
                                      : HunterTheme.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isEquipped
                          ? '✓ EQUIPPED'
                          : isOwned
                              ? 'EQUIP'
                              : canAfford
                                  ? 'BUY'
                                  : 'LOCKED',
                      style: TextStyle(
                        color:
                            isEquipped
                                ? HunterTheme.gold
                                : isOwned
                                    ? HunterTheme.success
                                    : canAfford
                                        ? theme.accent
                                        : HunterTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isEquipped(ShopItem item) {
    switch (item.category) {
      case ShopItemCategory.avatarFrame:
        return _equippedAvatarFrame == item.id;
      case ShopItemCategory.hunterTitle:
        return _equippedHunterTitle == item.id;
      case ShopItemCategory.profileEffect:
        return _equippedProfileEffect == item.id;
    }
  }
}
