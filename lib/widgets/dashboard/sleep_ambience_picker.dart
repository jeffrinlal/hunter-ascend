import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/sleep_service.dart';

/// Result returned by the ambience picker when the user confirms selection.
class AmbienceSelection {
  const AmbienceSelection({required this.ambience, required this.duration});
  final SleepAmbience ambience;
  final AmbienceDuration duration;
}

/// Bottom sheet that lets the user pick an ambience sound and playback
/// duration before starting the Sleep Mission.
///
/// Returns an [AmbienceSelection] if confirmed or skipped, or null if dismissed.
class SleepAmbiencePicker extends StatefulWidget {
  const SleepAmbiencePicker({super.key});

  /// Shows the picker as a modal bottom sheet and returns the selection.
  static Future<AmbienceSelection?> show(BuildContext context) {
    return showModalBottomSheet<AmbienceSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SleepAmbiencePicker(),
    );
  }

  @override
  State<SleepAmbiencePicker> createState() => _SleepAmbiencePickerState();
}

class _SleepAmbiencePickerState extends State<SleepAmbiencePicker> {
  late SleepAmbience _selectedAmbience;
  late AmbienceDuration _selectedDuration;

  @override
  void initState() {
    super.initState();
    // Preselect the user's last choice.
    _selectedAmbience = SleepService.instance.lastChosenAmbience;
    _selectedDuration = SleepService.instance.lastChosenDuration;
  }

  void _confirm() {
    SleepService.instance.saveLastChoice(_selectedAmbience, _selectedDuration);
    Navigator.pop(context, AmbienceSelection(
      ambience: _selectedAmbience,
      duration: _selectedDuration,
    ));
  }

  void _skip() {
    // Start immediately with no ambience.
    SleepService.instance.saveLastChoice(SleepAmbience.none, _selectedDuration);
    Navigator.pop(context, const AmbienceSelection(
      ambience: SleepAmbience.none,
      duration: AmbienceDuration.untilStopped,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final showDuration = _selectedAmbience != SleepAmbience.none;

    return Container(
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: HunterTheme.border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: HunterTheme.textTertiary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ──
          Row(children: [
            Icon(Icons.nights_stay_outlined, color: const Color(0xFF6C63FF), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sleep Ambience',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Skip button
            GestureDetector(
              onTap: _skip,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: HunterTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Choose a soundscape or skip to start immediately.',
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 20),

          // ── Ambience Grid ──
          Text(
            'SOUNDSCAPE',
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: SleepAmbience.values.map((a) => _ambienceChip(a)).toList(),
          ),

          // ── Duration (hidden when No Ambience) ──
          if (showDuration) ...[
            const SizedBox(height: 22),
            Text(
              'PLAYBACK DURATION',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AmbienceDuration.values.map((d) => _durationChip(d)).toList(),
            ),
          ],
          const SizedBox(height: 24),

          // ── Confirm ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.bedtime, size: 20),
              label: const Text(
                'BEGIN SLEEP',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ambienceChip(SleepAmbience ambience) {
    final selected = _selectedAmbience == ambience;
    final color = selected ? const Color(0xFF6C63FF) : HunterTheme.textSecondary;

    return GestureDetector(
      onTap: () => setState(() => _selectedAmbience = ambience),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C63FF).withOpacity(0.12) : HunterTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF).withOpacity(0.6) : HunterTheme.border,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(SleepService.ambienceIcon(ambience), color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            SleepService.ambienceName(ambience),
            style: TextStyle(
              color: selected ? const Color(0xFF6C63FF) : HunterTheme.textPrimary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _durationChip(AmbienceDuration duration) {
    final selected = _selectedDuration == duration;

    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = duration),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C63FF).withOpacity(0.12) : HunterTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF).withOpacity(0.6) : HunterTheme.border,
          ),
        ),
        child: Text(
          SleepService.durationLabel(duration),
          style: TextStyle(
            color: selected ? const Color(0xFF6C63FF) : HunterTheme.textPrimary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
