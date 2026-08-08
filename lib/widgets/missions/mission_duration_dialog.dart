import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Shared mission duration selection dialog — the app's single "START
/// MISSION" entry point. Daily missions, weekly missions and Dungeons all
/// start their runs here; the chosen duration is passed to [onSelected],
/// which drives the shared `MissionEngine`.
Future<void> showMissionDurationDialog({
  required BuildContext context,
  required String title,
  required ValueChanged<int> onSelected,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: HunterTheme.cardColor,
      title: Text(
        'START MISSION',
        style: TextStyle(color: MembershipTheme.current.accent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 16),
          Text(
            'Choose a time to complete this mission',
            style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [2, 5, 10, 15, 30, 45, 60]
                .map(
                  (mins) => ChoiceChip(
                    label: Text('$mins min'),
                    selected: false,
                    onSelected: (_) {
                      Navigator.pop(context);
                      onSelected(mins);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Text(
              '\u26a0\ufe0f You must wait for the timer before you can complete this mission.',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    ),
  );
}
