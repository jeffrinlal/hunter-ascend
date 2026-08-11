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
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_data.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/shop/widgets/shop_ui.dart';

/// Coin Shop — Phase 1 Foundation + Fitness Plans + Skins Integration.
///
/// Unified shop containing:
/// - Cosmetics (avatar frames, titles, effects) purchased with coins
/// - Fitness Plans (PDF plans) unlocked with rewarded ads
/// - Skins (temporary UI unlocks) purchased with coins OR a rewarded ad
///
/// The shop displays all content types in a tabbed interface.
/// Minimum cosmetic price: 400 coins.
/// Basic/Pro/Max all use the SAME shop prices and coin economy — including
/// skins, which are not membership-gated (Phase 2 scope).
///
/// Phase 2 note: this screen only wires Shop -> Preview -> Unlock -> Equip
/// for skins. No actual skin visual transformation is rendered anywhere —
/// that remains a later phase (`SkinDashboardLayout` etc. are still TODO).
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
  String? _equippedProfileEffect;
  int _hunterLevel = 1;
  bool _loading = true;

  // Fitness Plans ad manager
  late final RewardedAdManager _adManager;
  String? _unlockingPlanId;

  // Coin earning ad manager
  late final RewardedAdManager _coinAdManager;
  bool _isEarningCoins = false;
  int _adsWatchedInSequence = 0; // 0, 1, or 2 for the 2-ad flow
  bool _isLoadingSecondAd = false;

  // Skins ad manager (independent instance — mirrors _adManager/_coinAdManager,
  // does NOT reuse either so a skin ad in progress never interferes with a
  // plan ad or a coin-earning ad in progress).
  late final RewardedAdManager _skinAdManager;
  SkinId? _unlockingSkinId;

  // Skin unlock expiries, batch-loaded once per shop-data load (see
  // SkinService.getAllUnlockExpiries) so the Skins grid never issues one
  // Firestore read per card.
  Map<SkinId, DateTime> _skinExpiries = {};

  // Stable identity for the pre-existing planUnlocks listener.
  //
  // The stream used to be constructed inline inside build(), so every rebuild
  // handed StreamBuilder a NEW Stream object, which made it cancel and
  // re-subscribe (re-priming the whole query). This tab sits under an
  // AnimatedBuilder on _tabController and the screen also calls setState from
  // three ad-status callbacks, so that churned on every tab-swipe frame.
  //
  // Memoised per uid — same collection, same query, still exactly ONE
  // listener; only the object identity is now stable across rebuilds.
  // Mirrors MainShell's cached-stream approach.
  String? _planUnlocksUid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _planUnlocksStream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _planUnlocksStreamFor(String uid) {
    if (_planUnlocksStream == null || _planUnlocksUid != uid) {
      _planUnlocksUid = uid;
      _planUnlocksStream = FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection('planUnlocks')
          .snapshots();
    }
    return _planUnlocksStream!;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // effects + fitness plans + skins
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

    _skinAdManager = RewardedAdManager(
      onAdStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    _skinAdManager.loadAd();
  }

  @override
  void dispose() {
    _adManager.dispose();
    _coinAdManager.dispose();
    _skinAdManager.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    setState(() => _loading = true);

    final coins = await CoinService.instance.getCurrentBalance();
    final owned = await ShopService.instance.getOwnedItems();
    final equippedEffect = await ShopService.instance
        .getEquippedItem(ShopItemCategory.profileEffect);

    final hunter = HunterRepository.instance.getCached();
    final level = hunter?.level ?? 1;

    // One batched read for every skin's expiry, instead of one read per
    // skin card (see SkinService.getAllUnlockExpiries doc comment).
    final skinExpiries = await SkinService.instance.getAllUnlockExpiries();

    if (mounted) {
      setState(() {
        _coins = coins;
        _ownedItems = owned;
        _equippedProfileEffect = equippedEffect;
        _hunterLevel = level;
        _skinExpiries = skinExpiries;
        _loading = false;
      });
    }
  }

  // ── Skins ──────────────────────────────────────────────────────────────

  /// Whether [skin] currently has unexpired access, based on the batched
  /// [_skinExpiries] map loaded in [_loadShopData] — no per-card Firestore
  /// read. [SkinId.classic] is always considered accessible.
  bool _skinHasAccess(SkinId skin) {
    if (skin == SkinId.classic) return true;
    final expiry = _skinExpiries[skin];
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  /// Whether [skin] was unlocked before but has since expired (distinct
  /// from "never unlocked") — drives the "Expired / Unlock Again" card
  /// state.
  bool _skinIsExpired(SkinId skin) {
    if (skin == SkinId.classic) return false;
    final expiry = _skinExpiries[skin];
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  Future<void> _showSkinPurchaseConfirm(SkinData skin) async {
    final theme = MembershipTheme.current;
    final confirmed = await showDialog<bool>(
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
              Icon(Icons.auto_awesome_rounded, color: theme.accent, size: 40),
              const SizedBox(height: 16),
              Text(
                'UNLOCK ${skin.name.toUpperCase()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unlock ${skin.name} for ${skin.coinUnlockDuration.inDays} days using ${skin.coinPrice} coins?',
                textAlign: TextAlign.center,
                style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HunterTheme.textPrimary,
                        side: BorderSide(color: HunterTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('CONFIRM',
                          style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _purchaseSkin(skin);
  }

  Future<void> _purchaseSkin(SkinData skin) async {
    if (_coins < skin.coinPrice) {
      _showInsufficientCoinsDialog(skin.coinPrice);
      return;
    }

    final result = await SkinService.instance.purchaseSkinWithCoins(skin.id);

    if (!mounted) return;

    if (result.success) {
      await _loadShopData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${skin.name} unlocked for ${skin.coinUnlockDuration.inDays} days!'),
          backgroundColor: HunterTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result.message ?? 'Purchase failed. Please try again.'}'),
          backgroundColor: HunterTheme.danger,
        ),
      );
    }
  }

  void _showAdForSkin(SkinData skin) {
    if (_unlockingSkinId != null) return;

    _skinAdManager.showAd(
      onRewardEarned: () => _claimSkinAdUnlock(skin),
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

  Future<void> _claimSkinAdUnlock(SkinData skin) async {
    if (!mounted) return;
    setState(() => _unlockingSkinId = skin.id);

    // Only reached from a genuine onRewardEarned callback above — no grant
    // path exists for a failed/dismissed/incomplete ad.
    final result = await SkinService.instance.grantAdUnlock(skin.id);

    if (!mounted) return;
    setState(() => _unlockingSkinId = null);

    if (result.success) {
      await _loadShopData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${skin.name} unlocked for ${skin.adUnlockDuration.inDays} days!'),
          backgroundColor: HunterTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result.message ?? 'Failed to unlock skin.'}'),
          backgroundColor: HunterTheme.danger,
        ),
      );
    }
  }

  /// Equips a non-classic skin.
  ///
  /// Skin and Premium Theme are mutually exclusive as the *active
  /// appearance*, so if a Premium Theme is currently applied the user is
  /// asked to confirm first. Choosing "Keep Premium Theme" aborts without
  /// touching anything; choosing "Use Skin" activates the skin, which
  /// suppresses the theme's appearance while leaving the theme *selection*
  /// saved in [ThemeService] (nothing is deleted, no ownership is lost).
  /// The skin's unlock and remaining duration are never modified here.
  Future<void> _equipSkin(SkinData skin) async {
    if (ThemeService.instance.isPremiumThemeActive) {
      final useSkin = await _showAppearanceSwitchDialog();
      if (useSkin != true || !mounted) return; // "Keep Premium Theme" → no-op
    }

    final success = await SkinService.instance.activateSkin(skin.id);
    if (!mounted) return;

    if (success) {
      setState(() {}); // activeSkinNotifier already drives the equipped chip
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${skin.name} equipped!'),
          backgroundColor: HunterTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ This skin is no longer unlocked. Unlock it again first.'),
          backgroundColor: HunterTheme.danger,
        ),
      );
      await _loadShopData(); // refresh — it likely just expired
    }
  }

  /// Confirmation shown when equipping a skin would replace an active
  /// Premium Theme as the visual appearance.
  ///
  /// Returns `true` for "Use Skin", `false`/`null` for "Keep Premium Theme"
  /// (including a barrier dismiss), so the caller can safely abort.
  Future<bool?> _showAppearanceSwitchDialog() {
    final theme = MembershipTheme.current;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
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
              Icon(Icons.auto_awesome_rounded, color: theme.accent, size: 36),
              const SizedBox(height: 16),
              Text(
                'Switch to Skin appearance?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Skins and Premium Themes cannot be used together. '
                'Your Premium Theme stays saved and you can switch back at any time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(
                    'Use Skin',
                    style: TextStyle(
                      color: MembershipTheme.isMax ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HunterTheme.textPrimary,
                    side: BorderSide(color: HunterTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text(
                    'Keep Premium Theme',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Switches the active skin back to Classic. Per spec: does NOT touch any
  /// other skin's ownership/expiry — [SkinService.activateSkin] for
  /// [SkinId.classic] only changes which skin is selected/active.
  ///
  /// No conflict dialog here: Classic is always available and is explicitly
  /// allowed to coexist with a Premium Theme, so selecting Classic simply
  /// hands the appearance back to the theme system.
  Future<void> _useClassicSkin() async {
    await SkinService.instance.activateSkin(SkinId.classic);
    if (mounted) setState(() {});
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
        // onAdDismissed fires AFTER onRewardEarned
        // Check if reward was earned (state is 2) or ad was closed early (state < 2)
        // Note: _awardCoinsAfterAd may have already reset state to 0, so we need
        // to check if we're still in earning mode to determine if this was a success
        if (_adsWatchedInSequence < 2 && _isEarningCoins) {
          // Second ad was closed/failed without earning reward
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
        // If _isEarningCoins is false, the reward was already processed
        // Do nothing to avoid showing error after success
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

  // ═══════════════════════════════════════════════════════════════════
  // PRESENTATION
  //
  // Premium marketplace UI. Every component lives in
  // lib/screens/shop/widgets/shop_ui.dart and is purely presentational —
  // all coin/purchase/skin-unlock/ad logic above is untouched, and no
  // Firestore listener or read is added here (the Fitness Plans tab keeps
  // using the single pre-existing planUnlocks snapshot stream, and skin
  // expiries come from the already-batched `_skinExpiries` map).
  //
  // Colors come only from HunterTheme / MembershipTheme tokens, so changing
  // the Premium Theme or membership tier recolors the whole shop.
  // ═══════════════════════════════════════════════════════════════════

  // Frames and Titles were removed from the shop entirely, so the shop now
  // has exactly three categories. Order must stay in sync with the
  // TabBarView children in [_buildItemGrid].
  static const List<ShopCategory> _categories = [
    ShopCategory(label: 'Effects', icon: Icons.auto_awesome_rounded),
    ShopCategory(label: 'Plans', icon: Icons.fitness_center_rounded),
    ShopCategory(label: 'Skins', icon: Icons.palette_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // Rebuilds (and therefore re-reads every theme token) whenever the
    // light/dark mode, Premium Theme, membership tier or active skin
    // changes. No Firestore involvement.
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
        SkinService.instance.activeSkinNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: MembershipTheme.current.accent))
            : Column(
                children: [
                  ShopHeader(coins: _coins, onBack: () => Navigator.of(context).pop()),
                  ShopEarnCoinsPanel(
                    adsWatchedInSequence: _adsWatchedInSequence,
                    isEarning: _isEarningCoins,
                    isLoadingSecondAd: _isLoadingSecondAd,
                    adReady: _coinAdManager.isReady,
                    adUnavailable: _coinAdManager.isUnavailable,
                    onWatchOne: _earnCoinsWithOneAd,
                    onWatchTwo: _earnCoinsWithTwoAds,
                    onWatchSecond: _showSecondOfTwoAds,
                    onRetry: () {
                      setState(() => _isLoadingSecondAd = true);
                      _coinAdManager.retry();
                    },
                    onCancel: () {
                      setState(() {
                        _isEarningCoins = false;
                        _adsWatchedInSequence = 0;
                        _isLoadingSecondAd = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    // Listening to the TabController keeps the category chips
                    // in sync when the user swipes the content horizontally.
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) => Column(
                        children: [
                          ShopCategoryBar(
                            categories: _categories,
                            selectedIndex: _tabController.index,
                            onSelect: (i) {
                              _tabController.animateTo(i);
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _buildItemGrid()),
                        ],
                      ),
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
        _buildCosmeticGrid(
            ShopCatalog.getItemsByCategory(ShopItemCategory.profileEffect, _hunterLevel)),
        _buildFitnessPlansTab(),
        _buildSkinsTab(),
      ],
    );
  }

  // ── Cosmetics ──────────────────────────────────────────────────────

  Widget _buildCosmeticGrid(List<ShopItem> items) {
    if (items.isEmpty) {
      return const ShopEmptyState(
        icon: Icons.lock_clock_rounded,
        title: 'Nothing here yet',
        subtitle: 'Keep leveling up to unlock new cosmetics.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => ShopEntrance(index: i, child: _buildItemCard(items[i])),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isOwned = _ownedItems.contains(item.id);
    final isEquipped = _isEquipped(item);
    final canAfford = _coins >= item.price;

    final VoidCallback? onTap = isOwned
        ? (isEquipped ? null : () => _equipItem(item))
        : () => _purchaseItem(item);

    return ShopCardShell(
      onTap: onTap,
      highlight: isEquipped,
      highlightColor: HunterTheme.gold,
      child: Column(
        children: [
          Expanded(
            child: ShopPreviewPlate(
              tint: isEquipped ? HunterTheme.gold : null,
              child: Text(item.emoji, style: const TextStyle(fontSize: 42)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10),
                      ),
                    ),
                    if (!isOwned) ShopPricePill(price: item.price, dense: true),
                  ],
                ),
                const SizedBox(height: 9),
                ShopActionButton(
                  dense: true,
                  label: isEquipped
                      ? 'EQUIPPED'
                      : isOwned
                          ? 'EQUIP'
                          : canAfford
                              ? 'BUY'
                              : 'LOCKED',
                  icon: isEquipped
                      ? Icons.check_rounded
                      : isOwned
                          ? Icons.check_circle_outline_rounded
                          : canAfford
                              ? Icons.shopping_bag_rounded
                              : Icons.lock_outline_rounded,
                  style: isEquipped
                      ? ShopButtonStyle.success
                      : isOwned
                          ? ShopButtonStyle.success
                          : canAfford
                              ? ShopButtonStyle.filled
                              : ShopButtonStyle.muted,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fitness Plans ──────────────────────────────────────────────────

  Widget _buildFitnessPlansTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const ShopEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in required',
        subtitle: 'Sign in to unlock and view fitness plans.',
      );
    }

    // Unchanged: the same single pre-existing snapshot stream on the
    // planUnlocks subcollection. No additional listener or read is added —
    // the stream object is now hoisted so its identity is stable across
    // rebuilds (see _planUnlocksStreamFor).
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _planUnlocksStreamFor(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: MembershipTheme.current.accent),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.74,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: PlanCatalog.all.length,
          itemBuilder: (context, i) {
            final plan = PlanCatalog.all[i];
            return ShopEntrance(index: i, child: _buildPlanCard(plan, unlockMap[plan.id]));
          },
        );
      },
    );
  }

  Widget _buildPlanCard(FitnessPlan plan, PlanUnlockState? unlock) {
    final accent = plan.goal.accentColor;
    final isActive = unlock?.isActive ?? false;
    final isExpired = unlock?.isExpired ?? false;
    final isUnlocking = _unlockingPlanId == plan.id;

    int? daysLeft;
    if (isActive && unlock != null) {
      final d = unlock.expiresAt.difference(DateTime.now()).inDays;
      if (d >= 0) daysLeft = d;
    }

    final VoidCallback onTap =
        isActive ? () => _openPlanViewer(plan) : () => _showAdForPlan(plan);

    return ShopCardShell(
      onTap: onTap,
      highlight: isActive,
      highlightColor: accent,
      child: Column(
        children: [
          Expanded(
            child: ShopPreviewPlate(
              tint: accent,
              child: Icon(plan.goal.icon, size: 36, color: accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${plan.durationDays} days',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10),
                      ),
                    ),
                    if (daysLeft != null)
                      ShopStateBadge(
                        label: '${daysLeft}d LEFT',
                        color: accent,
                        icon: Icons.schedule_rounded,
                      )
                    else if (isExpired)
                      ShopStateBadge(label: 'EXPIRED', color: HunterTheme.danger),
                  ],
                ),
                const SizedBox(height: 9),
                ShopActionButton(
                  dense: true,
                  tint: accent,
                  label: isUnlocking
                      ? 'UNLOCKING…'
                      : isActive
                          ? 'VIEW PLAN'
                          : isExpired
                              ? 'UNLOCK AGAIN'
                              : 'WATCH AD',
                  icon: isUnlocking
                      ? null
                      : isActive
                          ? Icons.menu_book_rounded
                          : Icons.play_arrow_rounded,
                  style: isUnlocking
                      ? ShopButtonStyle.muted
                      : isActive
                          ? ShopButtonStyle.filled
                          : ShopButtonStyle.outline,
                  onTap: isUnlocking ? null : onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Skins ──────────────────────────────────────────────────────────

  /// Remaining unlock days for [skin], derived from the already-loaded
  /// `_skinExpiries` map — no additional Firestore read.
  int? _skinRemainingDays(SkinId skin) {
    final expiry = _skinExpiries[skin];
    if (expiry == null) return null;
    final d = expiry.difference(DateTime.now()).inDays;
    return d >= 0 ? d : null;
  }

  Widget _buildSkinsTab() {
    final skins = SkinService.instance.getAvailableSkins();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.60,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: skins.length,
      itemBuilder: (context, i) => ShopEntrance(index: i, child: _buildSkinCard(skins[i])),
    );
  }

  Widget _buildSkinCard(SkinData skin) {
    final activeSkin = SkinService.instance.getCurrentActiveSkin();
    // Equipped state differs by skin kind:
    // - Classic has no distinct appearance of its own (activateSkin
    //   deliberately leaves the appearance flag false for it), so it counts
    //   as equipped purely by being the selected skin.
    // - A custom skin counts as equipped only when it is BOTH selected AND
    //   the active appearance. If the user chose "Use Premium Theme" the skin
    //   stays selected but suppressed, so the card must offer EQUIP again
    //   (letting them return to it) instead of falsely claiming it is active.
    final isEquipped = skin.isDefault
        ? activeSkin == SkinId.classic
        : (activeSkin == skin.id && SkinService.instance.isSkinAppearanceActive);
    final hasAccess = _skinHasAccess(skin.id);
    final isExpired = _skinIsExpired(skin.id);
    final isUnlocking = _unlockingSkinId == skin.id;
    final daysLeft = _skinRemainingDays(skin.id);

    return ShopCardShell(
      highlight: isEquipped,
      highlightColor: HunterTheme.gold,
      child: Column(
        children: [
          Expanded(
            child: ShopPreviewPlate(
              tint: isEquipped ? HunterTheme.gold : null,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 34,
                color: isEquipped ? HunterTheme.gold : MembershipTheme.current.accent,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isEquipped)
                      ShopStateBadge(
                        label: 'ACTIVE',
                        color: HunterTheme.gold,
                        icon: Icons.check_rounded,
                      )
                    else if (daysLeft != null)
                      ShopStateBadge(
                        label: '${daysLeft}d',
                        color: HunterTheme.success,
                        icon: Icons.schedule_rounded,
                      )
                    else if (isExpired)
                      ShopStateBadge(label: 'EXPIRED', color: HunterTheme.danger),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  skin.isDefault
                      ? 'Always available'
                      : hasAccess
                          ? skin.description
                          : '${skin.coinUnlockDuration.inDays}d with coins · ${skin.adUnlockDuration.inDays}d with an ad',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HunterTheme.textTertiary, fontSize: 9.5, height: 1.3),
                ),
                const SizedBox(height: 9),
                _skinActions(
                  skin: skin,
                  isEquipped: isEquipped,
                  hasAccess: hasAccess,
                  isUnlocking: isUnlocking,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skinActions({
    required SkinData skin,
    required bool isEquipped,
    required bool hasAccess,
    required bool isUnlocking,
  }) {
    if (isEquipped) {
      return const ShopActionButton(
        dense: true,
        label: 'EQUIPPED',
        icon: Icons.check_rounded,
        style: ShopButtonStyle.success,
      );
    }
    if (isUnlocking) {
      return const ShopActionButton(
        dense: true,
        label: 'UNLOCKING…',
        style: ShopButtonStyle.muted,
      );
    }
    if (skin.isDefault) {
      return ShopActionButton(
        dense: true,
        label: 'EQUIP',
        icon: Icons.check_circle_outline_rounded,
        style: ShopButtonStyle.outline,
        onTap: _useClassicSkin,
      );
    }
    if (hasAccess) {
      return ShopActionButton(
        dense: true,
        label: 'EQUIP',
        icon: Icons.check_circle_outline_rounded,
        style: ShopButtonStyle.success,
        onTap: () => _equipSkin(skin),
      );
    }
    // Locked / expired — offer both unlock paths side by side.
    final canAfford = _coins >= skin.coinPrice;
    return Row(
      children: [
        Expanded(
          child: ShopActionButton(
            dense: true,
            label: '${skin.coinPrice}',
            icon: Icons.monetization_on_rounded,
            style: canAfford ? ShopButtonStyle.filled : ShopButtonStyle.muted,
            onTap: () => _showSkinPurchaseConfirm(skin),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: ShopActionButton(
            dense: true,
            label: 'AD',
            icon: Icons.play_arrow_rounded,
            style: ShopButtonStyle.outline,
            tint: HunterTheme.gold,
            onTap: () => _showAdForSkin(skin),
          ),
        ),
      ],
    );
  }

  bool _isEquipped(ShopItem item) {
    switch (item.category) {
      case ShopItemCategory.profileEffect:
        return _equippedProfileEffect == item.id;
    }
  }
}
