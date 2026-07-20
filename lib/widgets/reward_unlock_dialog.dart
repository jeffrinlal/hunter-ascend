import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';

/// Premium "Rewards Unlocked" celebration dialog.
///
/// Presentation only. Displays every [RankReward] newly unlocked together
/// (grouped into a single dialog, never one dialog per reward) with its icon,
/// name and category. This widget never grants ownership and never equips
/// anything — it purely presents rewards that [RankRewardService] already
/// permanently owns; equipping remains an explicit, separate action the
/// player takes later via [EquippedRewardsService].
///
/// Designed to be shown via [RankCelebrationService] through the shared
/// [MilestoneService] queue — not instantiated directly by screens.
class RewardUnlockDialog extends StatefulWidget {
  final List<RankReward> rewards;

  /// Invoked (after the dialog closes) when the user taps "View Rewards".
  final VoidCallback? onViewRewards;

  const RewardUnlockDialog({
    super.key,
    required this.rewards,
    this.onViewRewards,
  });

  /// Shows the celebration dialog and completes when it is dismissed.
  static Future<void> show(
    BuildContext context, {
    required List<RankReward> rewards,
    VoidCallback? onViewRewards,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) => RewardUnlockDialog(
        rewards: rewards,
        onViewRewards: onViewRewards,
      ),
    );
  }

  @override
  State<RewardUnlockDialog> createState() => _RewardUnlockDialogState();
}

class _RewardUnlockDialogState extends State<RewardUnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = HunterTheme.gold;
    final rewards = widget.rewards;
    final multi = rewards.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: FadeTransition(
        opacity: _entrance,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic)),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 560),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: gold.withOpacity(0.5), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: gold.withOpacity(0.26 * HunterTheme.glowStrength),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRibbon(gold, multi),
                  const SizedBox(height: 8),
                  Text(
                    multi
                        ? '${rewards.length} new rewards unlocked'
                        : 'A new reward has been unlocked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HunterTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Flexible(child: _buildRewardList()),
                  const SizedBox(height: 20),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRibbon(Color gold, bool multi) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.card_giftcard_rounded, color: gold, size: 16),
        const SizedBox(width: 8),
        Text(
          multi ? 'REWARDS UNLOCKED' : 'REWARD UNLOCKED',
          style: TextStyle(
            color: gold,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.card_giftcard_rounded, color: gold, size: 16),
      ],
    );
  }

  Widget _buildRewardList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.rewards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildRewardTile(widget.rewards[i]),
    );
  }

  Widget _buildRewardTile(RankReward reward) {
    final c = reward.color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.withOpacity(0.32), c.withOpacity(0.12)],
              ),
              border: Border.all(color: c.withOpacity(0.6)),
            ),
            child: Icon(reward.type.icon, color: c, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reward.type.label,
                    style: TextStyle(
                      color: c,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
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
              backgroundColor: HunterTheme.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              elevation: 4,
              shadowColor: HunterTheme.gold.withOpacity(0.4),
            ),
          ),
        ),
        if (widget.onViewRewards != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onViewRewards?.call();
              },
              icon: Icon(Icons.workspace_premium_rounded,
                  size: 18, color: HunterTheme.gold),
              label: Text(
                'VIEW REWARDS',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: HunterTheme.gold.withOpacity(0.55), width: 1.3),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
