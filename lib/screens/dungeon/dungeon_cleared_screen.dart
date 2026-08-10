import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_rewards.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';

/// Phase 7 — the dedicated DUNGEON CLEARED result presentation.
///
/// Pure VIEW: every amount comes from the reward/config layer
/// ([DungeonRewardBuilder] + [DungeonTemplates]) and granting happens
/// EXACTLY once in `DungeonSessionManager.claimClearReward` — this
/// widget never awards anything itself, so replaying it can never pay
/// twice. Two modes:
///
/// * CLAIM mode (`review == false`): staged RPG reveal —
///   DUNGEON CLEARED (name / rank / boss DEFEATED) → CLAIM REWARD →
///   +XP & +Coins → 🎁 DUNGEON LOOT → RETURN. Claiming runs through
///   [onClaim]; a failed claim stays on the header stage so the reward
///   remains claimable from the play-screen banner.
/// * REVIEW mode (`review == true`): the dungeon was already cleared
///   today and the reward already claimed — shows "Completed Today /
///   Rewards Already Claimed" with the persisted record and RETURN.
///   Nothing is granted.
///
/// Presentation reuses the app's existing idioms: showGeneralDialog
/// scale + fade transition (same as the milestone celebration),
/// [EntranceFadeSlide] staggered reveals and `HapticFeedback` (same as
/// the milestone / rank-up dialogs). No audio dependency — the app has
/// no SFX system.
class DungeonClearedDialog extends StatefulWidget {
  const DungeonClearedDialog({
    super.key,
    required this.spec,
    required this.template,
    required this.review,
    this.knownReward,
    required this.onClaim,
  });

  final DungeonGateSpec spec;
  final DungeonTemplate template;

  /// Already-completed mode — present only, never grant.
  final bool review;

  /// The persisted claim record (review mode).
  final DungeonClearReward? knownReward;

  /// Runs the exactly-once claim (manager) and returns the granted
  /// reward, or null when the award failed.
  final Future<DungeonClearReward?> Function() onClaim;

  @override
  State<DungeonClearedDialog> createState() => _DungeonClearedDialogState();
}

class _DungeonClearedDialogState extends State<DungeonClearedDialog> {
  /// 0 = cleared header, 1 = reward reveal, 2 = loot reveal.
  int _stage = 0;
  bool _claiming = false;
  DungeonClearReward? _reward;

  @override
  void initState() {
    super.initState();
    _reward = widget.knownReward;
    // Same haptic idiom as the milestone celebration dialog.
    HapticFeedback.mediumImpact();
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    HapticFeedback.mediumImpact();
    final reward = await widget.onClaim();
    if (!mounted) return;
    setState(() => _claiming = false);
    // Failed award — stay claimable; the banner keeps CLAIM REWARD.
    if (reward == null) return;
    setState(() {
      _reward = reward;
      _stage = 1;
    });
    HapticFeedback.lightImpact();
  }

  void _advance(int stage) {
    setState(() => _stage = stage);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final rank = dungeonGateRank(widget.spec);
    final boss = widget.template.boss;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: HunterTheme.gold.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cleared header (always visible) ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HunterTheme.gold.withOpacity(0.12),
                  border: Border.all(
                    color: HunterTheme.gold.withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HunterTheme.gold.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: HunterTheme.gold,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'DUNGEON CLEARED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.spec.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Chip(label: '${rank.label} RANK', color: rank.color),
                  const SizedBox(width: 8),
                  _Chip(label: 'COMPLETED', color: HunterTheme.success),
                ],
              ),
              const SizedBox(height: 14),
              // Boss defeated status.
              Text(
                '${boss.emoji} ${boss.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DEFEATED',
                style: TextStyle(
                  color: HunterTheme.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: HunterTheme.gold.withOpacity(0.25)),
              const SizedBox(height: 18),

              // ── Stage body ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOut,
                child:
                    widget.review
                        ? _buildReview()
                        : switch (_stage) {
                          1 => _buildRewards(),
                          2 => _buildLoot(),
                          _ => _buildClaimStage(),
                        },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stage 0 — claim prompt ───────────────────────────────────────────

  Widget _buildClaimStage() {
    return EntranceFadeSlide(
      key: const ValueKey('stage-claim'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The dungeon has fallen.\nClaim your hunter\'s reward.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: _claiming ? 'CLAIMING…' : 'CLAIM REWARD',
            icon: Icons.card_giftcard_rounded,
            onTap: _claiming ? null : _claim,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _claiming ? null : () => Navigator.of(context).pop(),
            child: Text(
              'CLAIM LATER',
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stage 1 — reward reveal ──────────────────────────────────────────

  Widget _buildRewards() {
    final reward = _reward;
    return EntranceFadeSlide(
      key: const ValueKey('stage-rewards'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stageLabel('REWARDS'),
          const SizedBox(height: 12),
          if (reward != null) ...[
            _RewardRow(
              emoji: '⚡',
              label: '+${reward.xp} XP',
              color: HunterTheme.success,
            ),
            const SizedBox(height: 10),
            _RewardRow(
              emoji: '🪙',
              label: '+${reward.coins} Coins',
              color: HunterTheme.gold,
            ),
          ],
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'CONTINUE',
            icon: Icons.arrow_forward_rounded,
            onTap: () => _advance(2),
          ),
        ],
      ),
    );
  }

  // ── Stage 2 — loot reveal ────────────────────────────────────────────

  Widget _buildLoot() {
    final reward = _reward;
    return EntranceFadeSlide(
      key: const ValueKey('stage-loot'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stageLabel('🎁 DUNGEON LOOT'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: HunterTheme.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HunterTheme.gold.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                Text(
                  reward?.lootEmoji ?? '🎁',
                  style: const TextStyle(fontSize: 34),
                ),
                const SizedBox(height: 8),
                Text(
                  reward?.lootName ?? 'Hunter\'s Reward',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'RETURN',
            icon: Icons.flag_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Review mode — already completed today ────────────────────────────

  Widget _buildReview() {
    final reward = _reward;
    return EntranceFadeSlide(
      key: const ValueKey('stage-review'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Completed Today',
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rewards Already Claimed',
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          if (reward != null) ...[
            const SizedBox(height: 16),
            _RewardRow(
              emoji: '⚡',
              label: '+${reward.xp} XP',
              color: HunterTheme.success,
            ),
            const SizedBox(height: 10),
            _RewardRow(
              emoji: '🪙',
              label: '+${reward.coins} Coins',
              color: HunterTheme.gold,
            ),
            const SizedBox(height: 10),
            _RewardRow(
              emoji: reward.lootEmoji,
              label: reward.lootName,
              color: HunterTheme.textPrimary,
            ),
          ],
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'RETURN',
            icon: Icons.flag_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _stageLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: HunterTheme.textSecondary,
        fontSize: 11.5,
        letterSpacing: 2.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Shows the cleared dialog through the SAME transition as the milestone
/// celebration (scale + fade) and resolves when it is dismissed.
Future<void> showDungeonClearedDialog(
  BuildContext context, {
  required DungeonGateSpec spec,
  required DungeonTemplate template,
  required bool review,
  DungeonClearReward? knownReward,
  required Future<DungeonClearReward?> Function() onClaim,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dungeon Cleared',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder:
        (_, __, ___) => DungeonClearedDialog(
          spec: spec,
          template: template,
          review: review,
          knownReward: knownReward,
          onClaim: onClaim,
        ),
    transitionBuilder: (ctx, animation, _, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

/// Small status chip (rank / completed) inside the cleared card.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// One revealed reward line (+XP / +Coins / loot).
class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold primary action button for the cleared card.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: HunterTheme.gold,
          foregroundColor: Colors.white,
          disabledBackgroundColor: HunterTheme.gold.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: HunterTheme.gold.withOpacity(0.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2,
                color: enabled ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
