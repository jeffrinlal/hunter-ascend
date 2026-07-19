import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/widgets/milestone_celebration_dialog.dart';

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

  static bool _isShowing = false;
  static final Queue<_QueuedMilestone> _queue = Queue();

  /// Shows a milestone celebration dialog. If another celebration is already
  /// visible, the new one is queued and shown after the current one closes.
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

    if (_isShowing) {
      _queue.add(_QueuedMilestone(context: context, data: data));
      return;
    }

    _present(context, data);
  }

  static void _present(BuildContext context, MilestoneData data) {
    if (!context.mounted) {
      _processQueue();
      return;
    }

    _isShowing = true;

    showGeneralDialog(
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
    ).then((_) {
      _isShowing = false;
      _processQueue();
    });
  }

  static void _processQueue() {
    if (_queue.isEmpty) return;
    final next = _queue.removeFirst();
    // Brief delay between celebrations.
    Future.delayed(const Duration(milliseconds: 400), () {
      _present(next.context, next.data);
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
}

class _QueuedMilestone {
  const _QueuedMilestone({required this.context, required this.data});
  final BuildContext context;
  final MilestoneData data;
}
