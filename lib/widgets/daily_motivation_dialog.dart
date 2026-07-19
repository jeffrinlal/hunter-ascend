import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/daily_reward_service.dart';

/// Motivational quotes displayed in the daily morning dialog.
const List<String> _quotes = [
  'The only bad workout is the one that didn\'t happen.',
  'Discipline is choosing between what you want now and what you want most.',
  'A hunter never quits. Rise and conquer.',
  'Your body can stand almost anything. It\'s your mind you have to convince.',
  'Small daily improvements lead to staggering long-term results.',
  'The pain you feel today will be the strength you feel tomorrow.',
  'Champions are made when nobody is watching.',
  'Every rep counts. Every step matters. Every day is a chance to level up.',
  'Weakness is a choice. Strength is earned.',
  'The grind never stops for a true Hunter.',
  'Your future self is watching. Make them proud.',
  'Rest when you must. Quit never.',
  'Legends aren\'t born. They\'re forged through discipline.',
  'One more rep. One more step. One more day.',
  'You didn\'t come this far to only come this far.',
];

/// Daily morning motivation dialog with a motivational quote and XP reward.
///
/// Shows once per calendar day. The user taps "Claim" to receive their
/// daily XP reward, then the dialog closes.
class DailyMotivationDialog extends StatefulWidget {
  const DailyMotivationDialog({super.key});

  /// Shows the dialog if the daily reward hasn't been claimed yet
  /// and the current time is between 5:00 AM and 11:59 AM (local).
  /// Returns without showing anything if already claimed or outside the window.
  static Future<void> showIfEligible(BuildContext context) async {
    // Morning-only: 5:00 AM to 11:59 AM local time.
    final hour = DateTime.now().hour;
    if (hour < 5 || hour >= 12) return;

    await DailyRewardService.instance.initialize();
    if (!DailyRewardService.instance.shouldShowReward) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DailyMotivationDialog(),
    );
  }

  @override
  State<DailyMotivationDialog> createState() => _DailyMotivationDialogState();
}

class _DailyMotivationDialogState extends State<DailyMotivationDialog> {
  bool _isClaiming = false;
  bool _claimed = false;
  late final String _quote;

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
  }

  Future<void> _claim() async {
    if (_isClaiming || _claimed) return;
    setState(() => _isClaiming = true);

    await DailyRewardService.instance.claimReward();

    if (!mounted) return;
    setState(() {
      _isClaiming = false;
      _claimed = true;
    });

    // Brief delay to show the claimed state, then close.
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HunterTheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: HunterTheme.primary.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HunterTheme.gold.withOpacity(0.2),
                    HunterTheme.primary.withOpacity(0.12),
                  ],
                ),
                border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
              ),
              child: Icon(
                Icons.wb_twilight_rounded,
                color: HunterTheme.gold,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            Text(
              'Good Morning, Hunter!',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),

            // ── Quote ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HunterTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HunterTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      color: HunterTheme.primary.withOpacity(0.5), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _quote,
                      style: TextStyle(
                        color: HunterTheme.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Reward Section ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: HunterTheme.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HunterTheme.success.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: HunterTheme.gold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Hunter Reward',
                        style: TextStyle(
                          color: HunterTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+${DailyRewardService.rewardXp} XP',
                    style: TextStyle(
                      color: HunterTheme.success,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Claim Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isClaiming || _claimed ? null : _claim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _claimed
                      ? HunterTheme.success
                      : HunterTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _claimed
                      ? HunterTheme.success
                      : HunterTheme.primary.withOpacity(0.6),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: _claimed ? 0 : 4,
                  shadowColor: HunterTheme.primary.withOpacity(0.4),
                ),
                child: _isClaiming
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_claimed) ...[
                            const Icon(Icons.card_giftcard_rounded, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _claimed ? 'CLAIMED!' : 'CLAIM REWARD',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
