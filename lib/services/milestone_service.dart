import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/widgets/milestone_celebration_dialog.dart';

/// Signature for a queued dialog presenter. The job is invoked when it reaches
/// the front of the queue and MUST return a Future that completes when its
/// dialog is dismissed (e.g. the Future returned by `showDialog` /
/// `showGeneralDialog`).
typedef DialogJob = Future<void> Function(BuildContext context);

/// Types of milestones that trigger celebrations.
enum MilestoneType {
  steps,
  quest,
  levelUp,
  streak,
  duelVictory,
  rank,
  sleep,
  custom,
}

/// Data for a single milestone celebration.
class MilestoneData {
  const MilestoneData({
    required this.type,
    required this.title,
    required this.subtitle,
    this.xp,
    this.icon,
  });

  final MilestoneType type;
  final String title;
  final String subtitle;
  final int? xp;
  final IconData? icon;
}

/// Manages milestone celebrations with queuing to prevent stacking.
///
/// Usage:
/// ```dart
/// MilestoneService.show(
///   context,
///   type: MilestoneType.steps,
///   title: '10,000 Steps!',
///   subtitle: 'Outstanding discipline!',
///   xp: 25,
/// );
/// ```
class MilestoneService {
  MilestoneService._();

  // ─────────────────────────────────────────────────────────────────────────
  // Sequential dialog queue
  // ─────────────────────────────────────────────────────────────────────────
  //
  // A single global queue guarantees celebrations never overlap or compete.
  // Milestone dialogs (level-up, streak, steps, duel victory, ...) AND any
  // custom dialog enqueued via [enqueue] (e.g. the achievement-unlock dialog)
  // are shown strictly one at a time, in enqueue order, with a short gap
  // between each. So a duel that triggers a level-up and several achievement
  // unlocks shows: level-up → achievement 1 → achievement 2 → ... with no two
  // dialogs on screen at once.

  static bool _isShowing = false;
  static final Queue<_QueuedDialog> _queue = Queue();

  /// Enqueues an arbitrary dialog [job] to run through the shared queue. Use
  /// this to funnel custom celebration dialogs (such as the achievement unlock
  /// dialog) through the same queue as milestone dialogs so they never overlap.
  static void enqueue(BuildContext context, DialogJob job) {
    _queue.add(_QueuedDialog(context: context, job: job));
    _pump();
  }

  /// Shows a milestone celebration dialog. If another dialog (milestone or
  /// custom) is already visible, this one is queued and shown afterwards.
  static void show(
    BuildContext context, {
    required MilestoneType type,
    required String title,
    required String subtitle,
    int? xp,
    IconData? icon,
  }) {
    final data = MilestoneData(
      type: type,
      title: title,
      subtitle: subtitle,
      xp: xp,
      icon: icon,
    );
    enqueue(context, (ctx) => _showMilestoneDialog(ctx, data));
  }

  /// Presents the milestone dialog and returns a Future that completes when it
  /// is dismissed. Visuals and behaviour are unchanged from before.
  static Future<void> _showMilestoneDialog(BuildContext context, MilestoneData data) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Milestone',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => MilestoneCelebrationDialog(data: data),
      transitionBuilder: (ctx, animation, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Drives the queue: shows the next dialog only when nothing is currently
  /// visible. [_isShowing] is claimed synchronously before awaiting the job so
  /// two dialogs can never race onto the screen together.
  static void _pump() {
    if (_isShowing) return;
    if (_queue.isEmpty) return;

    final next = _queue.removeFirst();
    if (!next.context.mounted) {
      // Skip a stale entry and continue draining the queue.
      _pump();
      return;
    }

    _isShowing = true;
    next.job(next.context).whenComplete(() {
      _isShowing = false;
      // Brief gap between celebrations for a smoother experience.
      Future.delayed(const Duration(milliseconds: 350), _pump);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step Milestone Tracking
  // ─────────────────────────────────────────────────────────────────────────

  static const List<int> stepMilestones = [5000, 10000, 15000, 20000];
  static const String _keyStepMilestonesDate = 'milestone_step_date';
  static const String _keyStepMilestonesCelebrated = 'milestone_step_celebrated';

  /// The previous step count seen this session. `null` means this is the
  /// first update after app startup — we record it without celebrating.
  static int? _previousStepCount;

  /// Checks if any step milestones should be celebrated for [stepCount].
  /// Celebrates only when the user CROSSES a threshold (previousSteps < milestone
  /// AND currentSteps >= milestone). Does NOT trigger on app restore if already
  /// above a milestone. Celebrates only once per milestone per calendar day.
  /// Does NOT award XP — the existing 10k step reward is unchanged.
  static Future<void> checkStepMilestones(BuildContext context, int stepCount) async {
    final previous = _previousStepCount;
    _previousStepCount = stepCount;

    // First update after startup — record baseline, don't celebrate.
    if (previous == null) return;

    // No forward progress — nothing to check.
    if (stepCount <= previous) return;

    final today = DateTime.now().toString().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();

    // Reset celebrated milestones on a new day.
    final savedDate = prefs.getString(_keyStepMilestonesDate) ?? '';
    Set<int> celebrated;
    if (savedDate != today) {
      celebrated = {};
      await prefs.setString(_keyStepMilestonesDate, today);
      await prefs.setStringList(_keyStepMilestonesCelebrated, []);
    } else {
      celebrated = (prefs.getStringList(_keyStepMilestonesCelebrated) ?? [])
          .map((s) => int.tryParse(s) ?? 0)
          .toSet();
    }

    // Find new milestones crossed (previous < milestone <= current).
    for (final milestone in stepMilestones) {
      if (previous < milestone && stepCount >= milestone && !celebrated.contains(milestone)) {
        celebrated.add(milestone);
        await prefs.setStringList(
          _keyStepMilestonesCelebrated,
          celebrated.map((m) => m.toString()).toList(),
        );

        if (!context.mounted) return;

        final formatted = milestone >= 1000
            ? '${(milestone / 1000).toStringAsFixed(0)},000'
            : '$milestone';

        show(
          context,
          type: MilestoneType.steps,
          title: '$formatted Steps!',
          subtitle: _stepSubtitle(milestone),
          icon: Icons.directions_walk_rounded,
        );

        // Only celebrate one milestone per check to avoid flooding.
        return;
      }
    }
  }

  static String _stepSubtitle(int milestone) {
    switch (milestone) {
      case 5000: return 'You\'re building discipline every day.';
      case 10000: return 'Outstanding discipline, Hunter!';
      case 15000: return 'Exceeding expectations. True S-Rank energy.';
      case 20000: return 'Legendary effort. You are unstoppable.';
      default: return 'Keep pushing forward!';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Level-Up Celebrations
  // ─────────────────────────────────────────────────────────────────────────

  /// Enqueues a celebration for each level gained between [oldLevel] and
  /// [newLevel]. Handles multi-level jumps by showing one dialog per level.
  /// Call this after XpService.awardXp() returns with leveledUp == true.
  static void celebrateLevelUps(BuildContext context, int oldLevel, int newLevel) {
    if (newLevel <= oldLevel) return;

    for (int lvl = oldLevel + 1; lvl <= newLevel; lvl++) {
      show(
        context,
        type: MilestoneType.levelUp,
        title: 'Level $lvl Reached!',
        subtitle: 'Your strength continues to grow.',
        icon: Icons.star_rounded,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Streak Milestone Celebrations
  // ─────────────────────────────────────────────────────────────────────────

  /// Streak values that trigger a celebration. Add more entries to celebrate
  /// additional milestones without changing any other code.
  static const Map<int, String> _streakMilestones = {
    7: 'Consistency creates champions.',
    30: 'Your discipline is becoming a habit.',
    100: 'Few hunters reach this level of consistency.',
    365: 'A true Ascended Hunter.',
  };

  static const String _keyStreakMilestonesCelebrated = 'milestone_streak_celebrated';

  /// Checks if [streak] matches a streak milestone and celebrates if it
  /// hasn't been celebrated before. Safe to call on every streak update —
  /// only triggers once per milestone (persisted via SharedPreferences).
  static Future<void> checkStreakMilestone(BuildContext context, int streak) async {
    if (!_streakMilestones.containsKey(streak)) return;

    final prefs = await SharedPreferences.getInstance();
    final celebrated = (prefs.getStringList(_keyStreakMilestonesCelebrated) ?? [])
        .map((s) => int.tryParse(s) ?? 0)
        .toSet();

    if (celebrated.contains(streak)) return;

    // Record before showing to prevent duplicates.
    celebrated.add(streak);
    await prefs.setStringList(
      _keyStreakMilestonesCelebrated,
      celebrated.map((m) => m.toString()).toList(),
    );

    if (!context.mounted) return;

    show(
      context,
      type: MilestoneType.streak,
      title: '$streak Day Streak!',
      subtitle: _streakMilestones[streak]!,
      icon: streak >= 365 ? Icons.emoji_events_rounded : Icons.local_fire_department_rounded,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Weight Goal Celebration
  // ─────────────────────────────────────────────────────────────────────────

  static const String _keyWeightGoalTargetCelebrated = 'milestone_weight_goal_target_celebrated';

  /// Removes account-scoped milestone state after permanent account deletion
  /// so a replacement account does not inherit crossed thresholds or stale
  /// celebrations. App-wide visual settings remain untouched.
  static Future<void> clearAccountData() async {
    _previousStepCount = null;
    _queue.clear();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyStepMilestonesDate),
      prefs.remove(_keyStepMilestonesCelebrated),
      prefs.remove(_keyStreakMilestonesCelebrated),
      prefs.remove(_keyWeightGoalTargetCelebrated),
    ]);
  }

  /// Checks if recording [newWeight] crosses the hunter's target weight.
  /// Celebrates once per target. Only triggers when the user CROSSES the
  /// threshold (previous weight was on the other side of the target).
  ///
  /// Supports both fat loss (target < starting) and muscle gain (target > starting).
  static Future<void> checkWeightGoal(BuildContext context, double newWeight) async {
    final prefs = await SharedPreferences.getInstance();

    // Read targetWeight, startingWeight, and current (previous) weight from cache.
    final hunterData = _getCachedHunterData();
    if (hunterData == null) return;

    final targetWeight = hunterData.targetWeight;
    if (targetWeight == null || targetWeight <= 0) return;

    final startingWeight = hunterData.startingWeight;
    if (startingWeight <= 0) return;

    // The cached weight is the PREVIOUS weight (before this recording).
    final previousWeight = hunterData.weight;
    if (previousWeight <= 0) return;

    // Determine direction: fat loss or muscle gain.
    final isFatLoss = targetWeight < startingWeight;

    // Check if the user just CROSSED the target.
    final bool crossed;
    if (isFatLoss) {
      // Previous was above target, new is at or below.
      crossed = previousWeight > targetWeight && newWeight <= targetWeight;
    } else {
      // Previous was below target, new is at or above.
      crossed = previousWeight < targetWeight && newWeight >= targetWeight;
    }

    if (!crossed) return;

    // Check if this target has already been celebrated.
    final celebratedTarget = prefs.getDouble(_keyWeightGoalTargetCelebrated);
    if (celebratedTarget == targetWeight) return;

    // Record before showing.
    await prefs.setDouble(_keyWeightGoalTargetCelebrated, targetWeight);

    if (!context.mounted) return;

    show(
      context,
      type: MilestoneType.custom,
      title: 'Goal Achieved!',
      subtitle: 'You reached your target weight. Your discipline is paying off.',
      icon: Icons.monitor_weight_outlined,
    );
  }

  /// Reads the cached HunterData from Hive (avoids async/circular deps).
  ///
  /// Uses the same box name/type as [HunterRepository] and [HiveInit]
  /// (`CacheConstants.hunterBox`) so this actually reads the box the app
  /// opens at startup, rather than a box that is never opened.
  static HunterData? _getCachedHunterData() {
    try {
      final box = Hive.box<HunterData>(CacheConstants.hunterBox);
      return box.get('current');
    } catch (_) {
      return null;
    }
  }
}

class _QueuedDialog {
  const _QueuedDialog({required this.context, required this.job});
  final BuildContext context;
  final DialogJob job;
}
