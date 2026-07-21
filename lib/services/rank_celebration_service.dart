import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/rank_reward_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/rank_up_dialog.dart';
import 'package:hunter_ascend/widgets/reward_unlock_dialog.dart';

/// Presentation-only orchestrator for Rank-Up and Reward-Unlock celebrations.
///
/// ## What this service does NOT do
/// - It never computes rank — [RankService] remains the single source of
///   truth; this service only *reads* `RankService.tierForLevel`/`.ranks`.
/// - It never grants rewards — [RankRewardService] remains the single source
///   of truth for ownership; this service only *reads*
///   `RankRewardService.isOwned`/`.rewardsForTier` and calls the service's
///   existing, idempotent `syncForLevel` to make sure grants for the crossed
///   tiers have completed before it reads them (no new granting logic).
/// - It never equips anything — [EquippedRewardsService] is not referenced
///   at all. Rewards are only ever *displayed* here.
/// - It never touches XP, level, or any Firestore progression field.
///
/// ## Integration with the existing celebration queue
/// Every dialog is funneled through [MilestoneService.enqueue] — the SAME
/// queue that already serializes Level-Up, streak, quest and Achievement
/// Unlock dialogs. This guarantees Rank-Up and Reward-Unlock dialogs can
/// never overlap with, or race, any other celebration.
class RankCelebrationService {
  RankCelebrationService._();
  static final RankCelebrationService instance = RankCelebrationService._();

  static const String _prefsKeyPrefix = 'rankCelebration_lastCelebratedTier_';

  /// Removes the current hunter's rank-celebration marker after permanent
  /// account deletion so a replacement account cannot retain local progress.
  Future<void> clearAccountData(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsKeyPrefix$uid');
  }

  /// Detects whether [oldLevel] -> [newLevel] crossed one or more Hunter Rank
  /// boundaries for [uid] and, if so, enqueues:
  ///   1. Exactly ONE Rank-Up dialog spanning the whole jump — from the
  ///      highest rank held before this award to the final rank reached —
  ///      even if multiple tiers were crossed in a single XP gain. A
  ///      multi-tier jump shows an extra subtitle ("You advanced through
  ///      multiple Hunter Ranks.") instead of one dialog per intermediate
  ///      rank.
  ///   2. At most ONE grouped Reward-Unlock dialog covering every reward
  ///      newly owned across all crossed tiers (never one dialog per reward).
  ///
  /// Safe to call after every XP award, exactly like `celebrateLevelUps` —
  /// it is a complete no-op unless a rank boundary was actually crossed.
  /// Already-celebrated tiers are never replayed (persisted per-uid via
  /// SharedPreferences), so re-entrant calls, retries, or multiple call sites
  /// can never show the same Rank-Up celebration twice.
  Future<void> celebrateIfRankUp(
    BuildContext context, {
    required String uid,
    required int oldLevel,
    required int newLevel,
  }) async {
    if (newLevel <= oldLevel) return;

    // Rank tiers are resolved ENTIRELY via RankService — never recomputed here.
    final oldTier = RankService.instance.tierForLevel(oldLevel);
    final newTier = RankService.instance.tierForLevel(newLevel);
    if (newTier <= oldTier) return; // level increased but no rank boundary crossed

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix$uid';
    final lastCelebratedTier = prefs.getInt(key) ?? -1;
    if (newTier <= lastCelebratedTier) return; // already celebrated up to here

    // The tier to celebrate FROM is whichever is higher: where they actually
    // were, or the last tier already acknowledged (defensive against overlap
    // between concurrent/retried calls).
    final celebrateFromTier =
        lastCelebratedTier > oldTier ? lastCelebratedTier : oldTier;

    // Record BEFORE showing anything (mirrors the streak/achievement dedup
    // pattern elsewhere) so a dismissed dialog, hot-restart, or navigation
    // away can never cause this exact rank-up to replay.
    await prefs.setInt(key, newTier);

    if (!context.mounted) return;

    // Ensure rewards for the crossed tiers have actually been granted before
    // reading ownership. RankRewardService.syncForLevel is the service's own
    // existing, idempotent, public method — calling it does not add or alter
    // any granting logic; it only guarantees the (already-async) grant for
    // this level has completed before we ask "what did we just unlock?".
    await RankRewardService.instance.syncForLevel(uid, newLevel);

    // ── Rank-Up dialog: exactly ONE, spanning the entire jump ──
    // Even if multiple tiers were crossed in this single XP gain, only the
    // highest rank held beforehand and the final rank reached are shown —
    // never one dialog per intermediate tier.
    final tiersCrossed = newTier - celebrateFromTier;
    final previousRank = RankService.ranks[celebrateFromTier];
    final newRank = RankService.ranks[newTier];
    MilestoneService.enqueue(
      context,
      (ctx) => RankUpDialog.show(
        ctx,
        previousRank: previousRank,
        newRank: newRank,
        subtitle: tiersCrossed > 1
            ? 'You advanced through multiple Hunter Ranks.'
            : null,
      ),
    );

    // ── Reward-Unlock dialog: ONE grouped dialog for every reward newly
    // owned across ALL crossed tiers, never one dialog per reward ──
    final newlyUnlocked = <RankReward>[];
    for (int t = celebrateFromTier + 1; t <= newTier; t++) {
      for (final reward in RankRewardService.instance.rewardsForTier(t)) {
        if (RankRewardService.instance.isOwned(reward.id)) {
          newlyUnlocked.add(reward);
        }
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      MilestoneService.enqueue(
        context,
        (ctx) => RewardUnlockDialog.show(ctx, rewards: newlyUnlocked),
      );
    }
  }
}
