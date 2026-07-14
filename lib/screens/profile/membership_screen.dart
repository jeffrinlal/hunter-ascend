import 'package:flutter/material.dart';
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/billing_service.dart';
import 'package:hunter_ascend/screens/legal/legal_document_screen.dart';
import 'package:hunter_ascend/screens/legal/legal_content.dart';

/// The state of a plan card's action button.
enum _PlanButtonState {
  idle,
  loading,
  pendingPurchase,
  purchaseSuccessful,
  purchaseFailed,
  restoreRunning,
  restoreComplete,
  restoreFailed,
}

/// The relationship between a plan card and the user's current plan.
enum _PlanRelation {
  currentPlan,
  upgrade,
  downgrade,
  subscribe,
}


/// Premium "Hunter Membership" screen — Phase 9 production polish.
///
/// UI ONLY: displays the hunter's current membership tier (read from
/// [MembershipService]) and the three available tiers (Basic / Pro / Max)
/// with dynamic pricing from Google Play, clear plan relationship indicators,
/// comprehensive button states, and a Manage Subscription link for paid users.
///
/// This screen never writes membership data — it only reads from
/// [MembershipService] and communicates purchases through [BillingService].
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final List<Animation<double>> _cardFade;
  late final List<Animation<Offset>> _cardSlide;

  StreamSubscription<BillingResult>? _purchaseSubscription;

  /// Current button state for each plan card (indexed by tier ordinal).
  final Map<MembershipTier, _PlanButtonState> _buttonStates = {
    MembershipTier.basic: _PlanButtonState.idle,
    MembershipTier.pro: _PlanButtonState.idle,
    MembershipTier.max: _PlanButtonState.idle,
  };

  /// Which product is currently being purchased (null if none).
  MembershipTier? _purchasingTier;


  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    const cardCount = 3;
    _cardFade = List.generate(cardCount, (index) {
      final start = index * 0.15;
      final end = (start + 0.6).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _cardSlide = List.generate(cardCount, (index) {
      final start = index * 0.15;
      final end = (start + 0.6).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    MembershipService.instance.loadMembership().whenComplete(() {
      if (mounted) setState(() {});
    });

    _entranceController.forward();

    _purchaseSubscription = BillingService.instance.purchaseResults.listen(
      _handlePurchaseResult,
    );
  }


  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  // ── Plan Relationship Logic ────────────────────────────────────────────

  /// Determines the relationship of a given tier to the user's current tier.
  _PlanRelation _planRelation(MembershipTier cardTier) {
    final membership = MembershipService.instance;
    MembershipTier currentTier;
    if (membership.isMax) {
      currentTier = MembershipTier.max;
    } else if (membership.isPro) {
      currentTier = MembershipTier.pro;
    } else {
      currentTier = MembershipTier.basic;
    }

    if (cardTier == currentTier) return _PlanRelation.currentPlan;

    // Tier ordering: basic(0) < pro(1) < max(2)
    if (cardTier.index > currentTier.index) return _PlanRelation.upgrade;
    if (cardTier.index < currentTier.index) return _PlanRelation.downgrade;
    return _PlanRelation.subscribe;
  }

  /// Returns the button label based on plan relation and button state.
  String _buttonLabel(MembershipTier tier) {
    final state = _buttonStates[tier]!;
    final relation = _planRelation(tier);

    switch (state) {
      case _PlanButtonState.loading:
        return 'Processing...';
      case _PlanButtonState.pendingPurchase:
        return 'Payment Processing...';
      case _PlanButtonState.purchaseSuccessful:
        return 'Activated!';
      case _PlanButtonState.purchaseFailed:
        return 'Try Again';
      case _PlanButtonState.restoreRunning:
        return 'Restoring...';
      case _PlanButtonState.restoreComplete:
        return 'Restored!';
      case _PlanButtonState.restoreFailed:
        return 'Restore Failed';
      case _PlanButtonState.idle:
        switch (relation) {
          case _PlanRelation.currentPlan:
            return 'Current Plan';
          case _PlanRelation.upgrade:
            return 'Upgrade';
          case _PlanRelation.downgrade:
            return 'Downgrade';
          case _PlanRelation.subscribe:
            return 'Subscribe';
        }
    }
  }


  /// Whether the button should be enabled for this tier.
  bool _buttonEnabled(MembershipTier tier) {
    final state = _buttonStates[tier]!;
    final relation = _planRelation(tier);

    // Current plan is always disabled.
    if (relation == _PlanRelation.currentPlan) return false;

    // Downgrade plans don't have a purchase button (they show Manage
    // Subscription instead), but disable defensively.
    if (relation == _PlanRelation.downgrade) return false;

    // Basic tier has no purchase action.
    if (tier == MembershipTier.basic) return false;

    // Disabled during active processing states.
    if (state == _PlanButtonState.loading ||
        state == _PlanButtonState.pendingPurchase ||
        state == _PlanButtonState.restoreRunning ||
        state == _PlanButtonState.purchaseSuccessful ||
        state == _PlanButtonState.restoreComplete) {
      return false;
    }

    // If another tier is being purchased, disable this button.
    if (_purchasingTier != null && _purchasingTier != tier) return false;

    return true;
  }

  // ── Purchase Handling ──────────────────────────────────────────────────

  void _handlePurchaseResult(BillingResult result) {
    if (!mounted) return;

    final tier = _purchasingTier;

    switch (result.status) {
      case BillingStatus.success:
        setState(() {
          if (tier != null) {
            _buttonStates[tier] = _PlanButtonState.purchaseSuccessful;
          }
          _purchasingTier = null;
        });
        _showSuccessDialog();
        // Reset to idle after a delay.
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _buttonStates.updateAll((_, __) => _PlanButtonState.idle);
            });
          }
        });
        break;

      case BillingStatus.pending:
        setState(() {
          if (tier != null) {
            _buttonStates[tier] = _PlanButtonState.pendingPurchase;
          }
        });
        break;

      case BillingStatus.userCanceled:
        setState(() {
          if (tier != null) {
            _buttonStates[tier] = _PlanButtonState.idle;
          }
          _purchasingTier = null;
        });
        break;

      case BillingStatus.error:
        setState(() {
          if (tier != null) {
            _buttonStates[tier] = _PlanButtonState.purchaseFailed;
          }
          _purchasingTier = null;
        });
        _showErrorSnackBar(result.error ?? 'Purchase failed. Please try again.');
        // Reset to idle after a delay so user can retry.
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _buttonStates.updateAll((k, v) =>
                  v == _PlanButtonState.purchaseFailed ? _PlanButtonState.idle : v);
            });
          }
        });
        break;

      case BillingStatus.storeUnavailable:
      case BillingStatus.productNotFound:
      case BillingStatus.duplicatePurchase:
        setState(() {
          if (tier != null) {
            _buttonStates[tier] = _PlanButtonState.idle;
          }
          _purchasingTier = null;
        });
        if (result.status == BillingStatus.duplicatePurchase) {
          _showInfoSnackBar('You already own this subscription.');
        }
        break;
    }
  }


  /// Initiates a purchase for the given tier.
  Future<void> _startPurchase(MembershipTier tier) async {
    if (_purchasingTier != null) return;

    // Never allow downgrade purchases — users must manage via Google Play.
    if (_planRelation(tier) == _PlanRelation.downgrade) return;

    if (!BillingService.instance.isAvailable) {
      _showBillingUnavailableDialog();
      return;
    }

    final ProductDetails? product;
    final String planName;
    if (tier == MembershipTier.pro) {
      product = BillingService.instance.proProduct;
      planName = 'Pro';
    } else {
      product = BillingService.instance.maxProduct;
      planName = 'Max';
    }

    if (product == null) {
      _showErrorSnackBar('$planName is not available yet. Please try again later.');
      return;
    }

    setState(() {
      _purchasingTier = tier;
      _buttonStates[tier] = _PlanButtonState.loading;
    });

    final result = await BillingService.instance.purchase(product);

    if (result.status == BillingStatus.error ||
        result.status == BillingStatus.storeUnavailable) {
      if (mounted) {
        setState(() {
          _buttonStates[tier] = _PlanButtonState.purchaseFailed;
          _purchasingTier = null;
        });
        _showErrorSnackBar(result.error ?? 'Could not start purchase.');
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _buttonStates.updateAll((k, v) =>
                  v == _PlanButtonState.purchaseFailed ? _PlanButtonState.idle : v);
            });
          }
        });
      }
    }
  }


  /// Handles the Restore Purchases button tap.
  Future<void> _handleRestore() async {
    if (!BillingService.instance.isAvailable) {
      _showBillingUnavailableDialog();
      return;
    }

    final result = await BillingService.instance.restorePurchases();

    if (!mounted) return;

    if (result.status == BillingStatus.error) {
      _showErrorSnackBar(result.error ?? 'Restore failed. Please try again.');
    } else if (result.status == BillingStatus.success) {
      await MembershipService.instance.reload();
      if (!mounted) return;
      setState(() {});

      if (MembershipService.instance.hasPremium) {
        _showSuccessSnackBar('Membership restored successfully!');
      } else {
        _showInfoSnackBar('No active subscriptions found.');
      }
    }
  }

  /// Opens the Google Play subscription management page.
  Future<void> _openManageSubscription() async {
    // Official Google Play subscription management deep link.
    const url = 'https://play.google.com/store/account/subscriptions';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Could not open subscription management.');
      }
    }
  }


  // ── Feedback Dialogs & Snackbars ───────────────────────────────────────

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HunterTheme.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: HunterTheme.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Membership Activated!',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your ${MembershipService.instance.membershipName} membership is now active. Enjoy your premium features!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HunterTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Awesome!',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showBillingUnavailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HunterTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.store_rounded,
                  color: HunterTheme.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Store Unavailable',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Google Play Billing is not available on this device. Please ensure you have the Google Play Store installed and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HunterTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: HunterTheme.danger.withOpacity(0.5)),
        ),
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: HunterTheme.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: HunterTheme.success.withOpacity(0.5)),
        ),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: HunterTheme.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: HunterTheme.primary.withOpacity(0.35)),
        ),
        content: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: HunterTheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ── Dynamic Pricing ────────────────────────────────────────────────────

  /// Returns the price string from Google Play ProductDetails, or a fallback.
  String _priceForTier(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.basic:
        return 'FREE';
      case MembershipTier.pro:
        final product = BillingService.instance.proProduct;
        return product != null ? '${product.price}/month' : 'Loading...';
      case MembershipTier.max:
        final product = BillingService.instance.maxProduct;
        return product != null ? '${product.price}/month' : 'Loading...';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final membership = MembershipService.instance;
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        title: const Text('MEMBERSHIP'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxContentWidth = isTablet ? 720.0 : double.infinity;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(),
                      const SizedBox(height: 24),
                      _CurrentPlanBanner(membership: membership),
                      const SizedBox(height: 28),

                      // ── Plan Cards ──
                      _AnimatedPlanCard(
                        fade: _cardFade[0],
                        slide: _cardSlide[0],
                        child: _PlanCard(
                          tier: MembershipTier.basic,
                          icon: Icons.shield_outlined,
                          accentColor: HunterTheme.textSecondary,
                          title: 'Basic',
                          price: _priceForTier(MembershipTier.basic),
                          relation: _planRelation(MembershipTier.basic),
                          buttonState: _buttonStates[MembershipTier.basic]!,
                          features: const [
                            'Daily AI-generated missions',
                            'Weekly missions',
                            'Run tracking & XP',
                            'Calorie tracking',
                            'Default avatar frame',
                            'Banner ads',
                            'Rewarded ads',
                          ],
                          buttonLabel: _buttonLabel(MembershipTier.basic),
                          buttonEnabled: _buttonEnabled(MembershipTier.basic),
                          onPressed: null,
                          onManageSubscription: _openManageSubscription,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AnimatedPlanCard(
                        fade: _cardFade[1],
                        slide: _cardSlide[1],
                        child: _PlanCard(
                          tier: MembershipTier.pro,
                          icon: Icons.workspace_premium_rounded,
                          accentColor: HunterTheme.gold,
                          title: 'Pro',
                          price: _priceForTier(MembershipTier.pro),
                          relation: _planRelation(MembershipTier.pro),
                          buttonState: _buttonStates[MembershipTier.pro]!,
                          features: const [
                            'No banner ads',
                            'Unlimited profile changes',
                            'Gold badge on leaderboard',
                            'Gold avatar frame',
                            'Gold avatar glow',
                            'Rewarded ads (with skip option)',
                          ],
                          buttonLabel: _buttonLabel(MembershipTier.pro),
                          buttonEnabled: _buttonEnabled(MembershipTier.pro),
                          onPressed: () => _startPurchase(MembershipTier.pro),
                          onManageSubscription: _openManageSubscription,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _AnimatedPlanCard(
                        fade: _cardFade[2],
                        slide: _cardSlide[2],
                        child: _PlanCard(
                          tier: MembershipTier.max,
                          icon: Icons.auto_awesome_rounded,
                          accentColor: HunterTheme.purple,
                          title: 'Max',
                          price: _priceForTier(MembershipTier.max),
                          relation: _planRelation(MembershipTier.max),
                          buttonState: _buttonStates[MembershipTier.max]!,
                          features: const [
                            'Everything in Pro',
                            'No banner ads',
                            'No rewarded ads',
                            'Animated avatar frame',
                            'Animated avatar glow',
                            'Monthly rewarded ad skips',
                            'Unlimited profile changes',
                          ],
                          buttonLabel: _buttonLabel(MembershipTier.max),
                          buttonEnabled: _buttonEnabled(MembershipTier.max),
                          onPressed: () => _startPurchase(MembershipTier.max),
                          onManageSubscription: _openManageSubscription,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Manage Subscription (Pro/Max only) ──
                      if (membership.hasPremium) ...[
                        _ManageSubscriptionButton(
                          onTap: _openManageSubscription,
                        ),
                        const SizedBox(height: 16),
                      ],


                      // ── Pending Purchase Banner ──
                      if (_buttonStates.values.any(
                          (s) => s == _PlanButtonState.pendingPurchase)) ...[
                        _PendingPurchaseBanner(),
                        const SizedBox(height: 16),
                      ],

                      // ── Subscription disclaimer ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: HunterTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HunterTheme.border),
                        ),
                        child: Text(
                          'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. '
                          'Your Google Play account will be charged for renewal within 24 hours prior to the end of the current period. '
                          'You can manage and cancel your subscriptions in your Google Play Store account settings.',
                          style: TextStyle(
                            color: HunterTheme.textTertiary,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Restore Purchases ──
                      ValueListenableBuilder<bool>(
                        valueListenable: BillingService.instance.isRestoring,
                        builder: (context, restoring, _) => Semantics(
                          button: true,
                          label: restoring
                              ? 'Restoring purchases, please wait'
                              : 'Restore Purchases',
                          child: GestureDetector(
                            onTap: restoring ? null : _handleRestore,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: HunterTheme.border),
                              ),
                              child: Center(
                                child: restoring
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: HunterTheme.textSecondary,
                                              semanticsLabel: 'Restoring purchases',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Restoring...',
                                            style: TextStyle(
                                              color: HunterTheme.textSecondary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Restore Purchases',
                                        style: TextStyle(
                                          color: HunterTheme.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),


                      // ── Legal links ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const LegalDocumentScreen(
                                  title: 'Privacy Policy',
                                  content: privacyPolicyText,
                                ),
                              ));
                            },
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: HunterTheme.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: HunterTheme.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const LegalDocumentScreen(
                                  title: 'Terms of Service',
                                  content: termsOfServiceText,
                                ),
                              ));
                            },
                            child: Text(
                              'Terms of Service',
                              style: TextStyle(
                                color: HunterTheme.textTertiary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Screen header: "HUNTER MEMBERSHIP" title with a supporting subtitle.
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [HunterTheme.primary, HunterTheme.gold],
          ).createShader(bounds),
          child: const Text(
            'HUNTER MEMBERSHIP',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Support Hunter Ascend and unlock exclusive cosmetics and premium features.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}


/// Displays the hunter's current membership tier with status and expiry.
class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({required this.membership});

  final MembershipService membership;

  Color _badgeColor() {
    if (membership.isMax) return HunterTheme.purple;
    if (membership.isPro) return HunterTheme.gold;
    return HunterTheme.textSecondary;
  }

  IconData _badgeIcon() {
    if (membership.isMax) return Icons.auto_awesome_rounded;
    if (membership.isPro) return Icons.workspace_premium_rounded;
    return Icons.shield_outlined;
  }

  String? _expiryText() {
    if (membership.isBasic) return null;
    final expiry = membership.membershipExpiry;
    if (expiry == null) return null;
    final now = DateTime.now();
    if (expiry.isBefore(now)) return 'Expired';
    final day = expiry.day.toString().padLeft(2, '0');
    final month = expiry.month.toString().padLeft(2, '0');
    final year = expiry.year;
    return 'Renews $day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor();
    final isActive = membership.isBasic || membership.subscriptionActive;
    final expiryText = _expiryText();

    return Semantics(
      label: 'Current plan: ${membership.membershipName}. '
          '${isActive ? "Active" : "Inactive"}. '
          '${expiryText ?? ""}',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeColor.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withOpacity(HunterTheme.isDark ? 0.2 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: HunterTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HunterTheme.success.withOpacity(0.4)),
                  ),
                  child: Text(
                    'CURRENT PLAN',
                    style: TextStyle(
                      color: HunterTheme.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_badgeIcon(), color: badgeColor, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        membership.membershipName,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                // Active/inactive status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? HunterTheme.success : HunterTheme.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: isActive ? HunterTheme.success : HunterTheme.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (expiryText != null) ...[
                  const Spacer(),
                  Icon(Icons.calendar_today_rounded,
                      color: HunterTheme.textTertiary, size: 12),
                  const SizedBox(width: 5),
                  Text(
                    expiryText,
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// Pending purchase banner shown when Google Play is processing a payment.
class _PendingPurchaseBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Purchase pending. Google Play is processing your payment.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HunterTheme.amberSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: HunterTheme.gold,
                semanticsLabel: 'Processing payment',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Processing',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Google Play is processing your purchase. This may take a moment. '
                    'Please do not close the app.',
                    style: TextStyle(
                      color: HunterTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Manage Subscription button for Pro/Max users.
class _ManageSubscriptionButton extends StatelessWidget {
  const _ManageSubscriptionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Manage your subscription on Google Play',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: HunterTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HunterTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_rounded,
                  color: HunterTheme.textSecondary, size: 18),
              const SizedBox(width: 10),
              Text(
                'Manage Subscription',
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded,
                  color: HunterTheme.textTertiary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}


/// Inline "Manage Subscription" button shown inside a plan card when the
/// plan is a downgrade from the user's current tier. Replaces the purchase
/// button entirely so users cannot accidentally downgrade in-app.
class _DowngradeManageButton extends StatelessWidget {
  const _DowngradeManageButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'To change your plan, manage your subscription on Google Play',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: HunterTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HunterTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_rounded,
                  color: HunterTheme.textTertiary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Manage Subscription',
                style: TextStyle(
                  color: HunterTheme.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded,
                  color: HunterTheme.textTertiary, size: 12),
            ],
          ),
        ),
      ),
    );
  }
}


/// Wraps a plan card with the staggered fade + slide-up entrance animation.
class _AnimatedPlanCard extends StatelessWidget {
  const _AnimatedPlanCard({
    required this.fade,
    required this.slide,
    required this.child,
  });

  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// A single premium membership plan card (Basic, Pro, or Max).
class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.tier,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.price,
    required this.relation,
    required this.buttonState,
    required this.features,
    required this.buttonLabel,
    required this.buttonEnabled,
    required this.onPressed,
    this.onManageSubscription,
  });

  final MembershipTier tier;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String price;
  final _PlanRelation relation;
  final _PlanButtonState buttonState;
  final List<String> features;
  final String buttonLabel;
  final bool buttonEnabled;
  final VoidCallback? onPressed;
  final VoidCallback? onManageSubscription;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}


class _PlanCardState extends State<_PlanCard> {
  bool _hovered = false;
  bool _pressed = false;

  double get _scale => _pressed ? 0.985 : (_hovered ? 1.01 : 1.0);

  bool get _isCurrent => widget.relation == _PlanRelation.currentPlan;

  /// Returns the relationship badge text (e.g. "CURRENT", "UPGRADE").
  String? get _relationBadgeText {
    switch (widget.relation) {
      case _PlanRelation.currentPlan:
        return 'CURRENT';
      case _PlanRelation.upgrade:
        return 'UPGRADE';
      case _PlanRelation.downgrade:
        return 'DOWNGRADE';
      case _PlanRelation.subscribe:
        return null; // No badge for subscribe (it's the default action).
    }
  }

  Color get _relationBadgeColor {
    switch (widget.relation) {
      case _PlanRelation.currentPlan:
        return HunterTheme.success;
      case _PlanRelation.upgrade:
        return widget.accentColor;
      case _PlanRelation.downgrade:
        return HunterTheme.textTertiary;
      case _PlanRelation.subscribe:
        return widget.accentColor;
    }
  }

  /// Whether to show a loading indicator inside the button.
  bool get _showButtonLoading =>
      widget.buttonState == _PlanButtonState.loading ||
      widget.buttonState == _PlanButtonState.pendingPurchase;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Semantics(
      label: '${widget.title} plan. ${widget.price}. '
          '${_isCurrent ? "This is your current plan." : ""}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isCurrent
                      ? accent.withOpacity(0.9)
                      : HunterTheme.border,
                  width: _isCurrent ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(
                        _hovered ? 0.28 : (_isCurrent ? 0.22 : 0.12)),
                    blurRadius: _hovered ? 26 : 18,
                    spreadRadius: _isCurrent ? 1 : 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(HunterTheme.isDark ? 0.3 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(widget.icon, color: accent, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: HunterTheme.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                if (_relationBadgeText != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _relationBadgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: _relationBadgeColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      _relationBadgeText!,
                                      style: TextStyle(
                                        color: _relationBadgeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.price,
                              style: TextStyle(
                                color: accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  ...widget.features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: accent, size: 17),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                color: HunterTheme.textSecondary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Action Button ──
                  // For downgrade plans, hide the purchase button and show
                  // "Manage Subscription" instead.
                  if (widget.relation == _PlanRelation.downgrade)
                    _DowngradeManageButton(
                      onTap: widget.onManageSubscription,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: Semantics(
                        button: true,
                        enabled: widget.buttonEnabled,
                        label: widget.buttonLabel,
                        child: ElevatedButton(
                          onPressed: widget.buttonEnabled ? widget.onPressed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _buttonBackground(accent),
                            foregroundColor: _buttonForeground(accent),
                            disabledBackgroundColor: _buttonDisabledBackground(accent),
                            disabledForegroundColor: _buttonDisabledForeground(accent),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: _isCurrent
                                    ? accent.withOpacity(0.5)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: _showButtonLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _isCurrent ? accent : Colors.white,
                                        semanticsLabel: 'Loading',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.buttonLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  widget.buttonLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ── Button color helpers ─────────────────────────────────────────────

  Color _buttonBackground(Color accent) {
    if (_isCurrent) return accent.withOpacity(0.15);
    if (widget.buttonState == _PlanButtonState.purchaseSuccessful) {
      return HunterTheme.success;
    }
    if (widget.buttonState == _PlanButtonState.purchaseFailed) {
      return HunterTheme.danger.withOpacity(0.15);
    }
    return accent;
  }

  Color _buttonForeground(Color accent) {
    if (_isCurrent) return accent;
    if (widget.buttonState == _PlanButtonState.purchaseFailed) {
      return HunterTheme.danger;
    }
    return Colors.white;
  }

  Color _buttonDisabledBackground(Color accent) {
    if (_isCurrent) return accent.withOpacity(0.15);
    if (widget.buttonState == _PlanButtonState.purchaseSuccessful) {
      return HunterTheme.success;
    }
    return HunterTheme.surface;
  }

  Color _buttonDisabledForeground(Color accent) {
    if (_isCurrent) return accent;
    if (widget.buttonState == _PlanButtonState.purchaseSuccessful) {
      return Colors.white;
    }
    return HunterTheme.textFaint;
  }
}
