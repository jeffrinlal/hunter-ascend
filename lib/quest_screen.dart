import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

/// Standalone daily-quests screen used by the Quests tab in the bottom nav.
///
/// It reuses DashboardScreen's existing daily-quest section via
/// [DashboardScreen.questsOnly] — a single source of truth, so no quest or
/// Firebase logic is duplicated. Only the non-quest dashboard sections
/// (header, hunter card, steps, quick actions) are hidden.
class QuestScreen extends StatelessWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen(questsOnly: true);
  }
}
