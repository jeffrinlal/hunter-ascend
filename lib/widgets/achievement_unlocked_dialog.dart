import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/achievement.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Premium "Achievement Unlocked" celebration dialog.
///
/// Shows the unlocked achievement's icon, name, description, rarity and XP
/// reward with a premium unlock animation. A banner ad — the SAME component
/// used on the Missions screen (`AdsService.createBannerAd` +
/// [AppConstants.dashboardBannerAdUnitId], gated by
/// [MembershipService.showBannerAds]) — is shown near the bottom above the
/// action buttons, with reserved space so the layout never jumps.
class AchievementUnlockedDialog extends StatefulWidget {
  final Achievement achievement;

  /// Invoked (after the dialog closes) when the user taps "View Achievement".
  final VoidCallback? onView;

  const AchievementUnlockedDialog({
    super.key,
    required this.achievement,
    this.onView,
  });

  /// Shows the celebration dialog and completes when it is dismissed.
  static Future<void> show(
    BuildContext context, {
    required Achievement achievement,
    VoidCallback? onView,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) => AchievementUnlockedDialog(
        achievement: achievement,
        onView: onView,
      ),
    );
  }

  @override
  State<AchievementUnlockedDialog> createState() =>
      _AchievementUnlockedDialogState();
}

class _AchievementUnlockedDialogState extends State<AchievementUnlockedDialog>
    with TickerProviderStateMixin {
  // ── Unlock animation ──
  late final AnimationController _entrance;
  late final AnimationController _pulse;

  // ── Banner ad (reused from the Missions screen) ──
  BannerAd? _bannerAd;
  bool _isBannerReady = false;
  bool _bannerFailed = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadBannerAd();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // Mirrors the Missions screen banner: same helper, same ad unit, same
  // membership gate. No new banner implementation is introduced here.
  void _loadBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;
    _bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) {
        if (mounted) setState(() => _isBannerReady = true);
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _bannerAd = null;
        if (mounted) setState(() => _bannerFailed = true);
      },
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final rc = a.rarity.color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _entrance,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: _entrance,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: HunterTheme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: rc.withOpacity(0.55), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: rc.withOpacity(0.28 * HunterTheme.glowStrength),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBanner(rc),
                const SizedBox(height: 18),
                _buildMedallion(a, rc),
                const SizedBox(height: 18),
                Text(
                  a.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                _rarityBadge(a, rc),
                const SizedBox(height: 14),
                Text(
                  a.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _buildReward(a),
                const SizedBox(height: 22),
                _buildAdSlot(),
                _buildActions(rc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── "ACHIEVEMENT UNLOCKED" ribbon ──
  Widget _buildBanner(Color rc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome_rounded, color: rc, size: 15),
        const SizedBox(width: 8),
        Text(
          'ACHIEVEMENT UNLOCKED',
          style: TextStyle(
            color: rc,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.auto_awesome_rounded, color: rc, size: 15),
      ],
    );
  }

  // ── Glowing, animated medallion ──
  Widget _buildMedallion(Achievement a, Color rc) {
    final legendary = a.rarity == AchievementRarity.legendary;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value; // 0..1
        final glow = (0.35 + 0.35 * t) * a.rarity.glow * HunterTheme.glowStrength;
        return Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [rc.withOpacity(0.34), rc.withOpacity(0.10)],
            ),
            border: Border.all(color: rc.withOpacity(0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: rc.withOpacity(glow),
                blurRadius: legendary ? 30 + 12 * t : 20 + 6 * t,
                spreadRadius: legendary ? 2 + 2 * t : 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Icon(a.icon, color: rc, size: 50),
    );
  }

  Widget _rarityBadge(Achievement a, Color rc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: rc.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rc.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: rc, size: 13),
          const SizedBox(width: 6),
          Text(
            '${a.rarity.label} • ${a.category.label}',
            style: TextStyle(
              color: rc,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reward (XP and/or badge/title label) ──
  Widget _buildReward(Achievement a) {
    final hasXp = a.rewardXp > 0;
    final hasReward = a.reward != null && a.reward!.isNotEmpty;
    if (!hasXp && !hasReward) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: HunterTheme.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunterTheme.gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'REWARD',
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasXp) ...[
                Icon(Icons.bolt_rounded, color: HunterTheme.gold, size: 18),
                const SizedBox(width: 4),
                Text(
                  '+${a.rewardXp} XP',
                  style: TextStyle(
                    color: HunterTheme.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              if (hasXp && hasReward)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 1,
                    height: 16,
                    color: HunterTheme.gold.withOpacity(0.3),
                  ),
                ),
              if (hasReward) ...[
                Icon(Icons.card_giftcard_rounded,
                    color: HunterTheme.gold, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    a.reward!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HunterTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Banner ad slot with reserved space ──
  //
  // Reserves the standard banner height while loading so the dialog does not
  // jump when the ad appears. On Pro/Max (ads disabled) or on load failure the
  // space collapses gracefully, keeping the dialog balanced.
  Widget _buildAdSlot() {
    if (!MembershipService.instance.showBannerAds || _bannerFailed) {
      return const SizedBox.shrink();
    }

    final width = _bannerAd?.size.width.toDouble() ?? 320.0;
    final height = _bannerAd?.size.height.toDouble() ?? 50.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: _isBannerReady && _bannerAd != null
              ? AdWidget(ad: _bannerAd!)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: HunterTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HunterTheme.border),
                  ),
                ),
        ),
      ),
    );
  }

  // ── Action buttons: View Achievement + Continue ──
  Widget _buildActions(Color rc) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'CONTINUE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: HunterTheme.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              elevation: 4,
              shadowColor: HunterTheme.primary.withOpacity(0.4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onView?.call();
            },
            icon: Icon(Icons.emoji_events_rounded, size: 18, color: rc),
            label: Text(
              'VIEW ACHIEVEMENT',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: rc.withOpacity(0.55), width: 1.3),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
