import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/sleep_service.dart';
import 'package:hunter_ascend/widgets/glass/glass_card.dart';

/// Sleep Mission card for the Dashboard.
///
/// Displays idle state (ready to sleep) or active state (elapsed timer,
/// ambience, stop button). The elapsed timer is timestamp-based — it
/// uses a 1-second periodic Timer only for display refresh, not for
/// time tracking. Actual duration is always calculated from
/// DateTime.now() - sleepStartTime.
class SleepCard extends StatefulWidget {
  /// Called when the user taps "Start Sleep" — parent should show
  /// the ambience picker.
  final VoidCallback onStartTap;

  /// Called when the user taps "Stop Sleep" — parent handles the
  /// result (XP snackbar, etc.).
  final Future<void> Function() onStopTap;

  const SleepCard({
    super.key,
    required this.onStartTap,
    required this.onStopTap,
  });

  @override
  State<SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<SleepCard> {
  Timer? _displayTimer;
  Duration _elapsed = Duration.zero;
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    SleepService.instance.stateNotifier.addListener(_onStateChanged);
    _syncState();
  }

  @override
  void dispose() {
    SleepService.instance.stateNotifier.removeListener(_onStateChanged);
    _displayTimer?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    _syncState();
  }

  void _syncState() {
    if (SleepService.instance.isActive) {
      _elapsed = SleepService.instance.elapsed;
      _startDisplayTimer();
    } else {
      _displayTimer?.cancel();
      _displayTimer = null;
      _elapsed = Duration.zero;
    }
    setState(() {});
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = SleepService.instance.elapsed;
      });
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatTime(DateTime time) {
    final h = time.hour;
    final m = time.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = SleepService.instance.isActive;
    final hasRewardedToday = SleepService.instance.hasRewardedToday;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF6C63FF).withOpacity(0.15)
                  : HunterTheme.border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive ? Icons.bedtime : Icons.nights_stay_outlined,
              color: isActive ? const Color(0xFF6C63FF) : HunterTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SLEEP MISSION',
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (hasRewardedToday && !isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: HunterTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'DONE',
                style: TextStyle(
                  color: HunterTheme.success,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),

        if (isActive) ...[
          // ── Active state ──
          Text(
            'Sleeping...',
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Started at + ambience
          Row(children: [
            Icon(Icons.access_time, color: HunterTheme.textTertiary, size: 14),
            const SizedBox(width: 6),
            Text(
              'Started at ${_formatTime(SleepService.instance.startTime!)}',
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
            ),
            if (SleepService.instance.selectedAmbience != null &&
                SleepService.instance.selectedAmbience != SleepAmbience.none) ...[
              const SizedBox(width: 14),
              Icon(
                SleepService.ambienceIcon(SleepService.instance.selectedAmbience!),
                color: HunterTheme.textTertiary,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                SleepService.ambienceName(SleepService.instance.selectedAmbience!),
                style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
              ),
            ],
          ]),
          const SizedBox(height: 14),

          // Elapsed timer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.25)),
            ),
            child: Center(
              child: Text(
                _formatDuration(_elapsed),
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // XP tier hint
          Text(
            SleepService.xpTierDescription(_elapsed.inMinutes),
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Stop button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isStopping ? null : _handleStop,
              icon: _isStopping
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.stop_circle_outlined, size: 20),
              label: Text(
                _isStopping ? 'Completing...' : 'STOP SLEEP',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
          // ── Idle state ──
          Text(
            hasRewardedToday ? 'Rest Complete' : 'Ready to rest?',
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasRewardedToday
                ? 'You\'ve already earned sleep XP today. Come back tomorrow!'
                : 'Track your sleep to earn XP. Aim for 8-10 hours.',
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),

          // XP reward tiers
          if (!hasRewardedToday) ...[
            _xpTierRow('4-6h', '+10 XP'),
            _xpTierRow('6-8h', '+25 XP'),
            _xpTierRow('8-10h', '+40 XP (optimal)'),
            const SizedBox(height: 14),
          ],

          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasRewardedToday ? null : widget.onStartTap,
              icon: Icon(
                hasRewardedToday ? Icons.check_circle : Icons.bedtime_outlined,
                size: 20,
              ),
              label: Text(
                hasRewardedToday ? 'COMPLETED TODAY' : 'START SLEEP',
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasRewardedToday
                    ? HunterTheme.success.withOpacity(0.15)
                    : HunterTheme.primary,
                foregroundColor: hasRewardedToday
                    ? HunterTheme.success
                    : Colors.white,
                disabledBackgroundColor: HunterTheme.success.withOpacity(0.15),
                disabledForegroundColor: HunterTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );

    return GlassCard(child: content);
  }

  Widget _xpTierRow(String duration, String xp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(Icons.circle, size: 6, color: HunterTheme.textTertiary),
        const SizedBox(width: 8),
        Text(duration, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(xp, style: TextStyle(color: HunterTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _handleStop() async {
    setState(() => _isStopping = true);
    await widget.onStopTap();
    if (mounted) setState(() => _isStopping = false);
  }
}
