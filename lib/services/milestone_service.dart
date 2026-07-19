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

  /// Checks if any step milestones should be celebrated for [stepCount].
  /// Celebrates only once per milestone per calendar day.
  /// Does NOT award XP — the existing 10k step reward is unchanged.
  static Future<void> checkStepMilestones(BuildContext context, int stepCount) async {
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

    // Find new milestones reached.
    for (final milestone in stepMilestones) {
      if (stepCount >= milestone && !celebrated.contains(milestone)) {
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
}

class _QueuedMilestone {
  const _QueuedMilestone({required this.context, required this.data});
  final BuildContext context;
  final MilestoneData data;
}
