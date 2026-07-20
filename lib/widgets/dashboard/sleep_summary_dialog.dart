import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/sleep_service.dart';

/// Dialog shown after completing a sleep session. Displays duration,
/// XP earned, and a banner ad for Basic users.
class SleepSummaryDialog extends StatefulWidget {
  final SleepResult result;

  const SleepSummaryDialog({super.key, required this.result});

  /// Shows the sleep summary as a modal dialog.
  static Future<void> show(BuildContext context, SleepResult result) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => SleepSummaryDialog(result: result),
    );
  }

  @override
  State<SleepSummaryDialog> createState() => _SleepSummaryDialogState();
}

class _SleepSummaryDialogState extends State<SleepSummaryDialog> {
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;

    _bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) {
        if (mounted) setState(() => _isBannerReady = true);
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _bannerAd = null;
      },
    );
    _bannerAd!.load();
  }

  String _formatDuration() {
    final hours = widget.result.durationMinutes ~/ 60;
    final mins = widget.result.durationMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final hasXp = result.xpAwarded > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasXp
                ? HunterTheme.purple.withOpacity(0.4)
                : HunterTheme.border,
          ),
          boxShadow: [
            if (hasXp)
              BoxShadow(
                color: HunterTheme.purple.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasXp
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [HunterTheme.purple.withOpacity(0.22), HunterTheme.purple.withOpacity(0.08)],
                      )
                    : null,
                color: hasXp ? null : HunterTheme.surface,
                border: hasXp ? Border.all(color: HunterTheme.purple.withOpacity(0.4)) : null,
              ),
              child: Icon(
                hasXp ? Icons.nights_stay : Icons.bedtime_outlined,
                color: hasXp ? HunterTheme.purple : HunterTheme.textTertiary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ──
            Text(
              hasXp ? 'Sleep Complete!' : 'Sleep Tracked',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // ── Duration ──
            Text(
              'Duration: ${_formatDuration()}',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),

            // ── XP Award ──
            if (hasXp)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: HunterTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HunterTheme.success.withOpacity(0.3)),
                ),
                child: Text(
                  '+${result.xpAwarded} XP${result.leveledUp ? '  \ud83c\udf89 LEVEL UP!' : ''}',
                  style: TextStyle(
                    color: HunterTheme.success,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                result.durationMinutes < 240
                    ? 'Sleep 4+ hours to earn XP'
                    : 'Already rewarded today',
                style: TextStyle(
                  color: HunterTheme.textTertiary,
                  fontSize: 13,
                ),
              ),

            // ── Banner Ad ──
            if (_isBannerReady && _bannerAd != null) ...[
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Continue Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasXp ? HunterTheme.purple : HunterTheme.surface,
                  foregroundColor: hasXp ? Colors.white : HunterTheme.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
