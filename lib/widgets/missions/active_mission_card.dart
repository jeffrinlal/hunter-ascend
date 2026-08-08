import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';

/// Premium active-mission card shared by EVERY mission execution surface
/// (daily missions, weekly missions, Dungeons).
///
/// Presentation-only wrapper around the shared mission lifecycle:
/// - When the timer is not finished it shows the same "timer not finished"
///   snackbar.
/// - When ready it shows the same Hunter Verification dialog and, on
///   confirm, invokes [onComplete] (the surface's reward flow).
/// - [onCancel] runs the surface's cancel logic.
/// The glow controller only repaints the decoration (content, including the
/// AdWidget, is passed as [AnimatedBuilder.child] and is not rebuilt per
/// frame).
class ActiveMissionCard extends StatefulWidget {
  final Duration remaining;
  final String title;
  final int reward;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final BannerAd? banner;
  final bool bannerReady;

  const ActiveMissionCard({
    super.key,
    required this.remaining,
    required this.title,
    required this.reward,
    required this.onComplete,
    required this.onCancel,
    required this.banner,
    required this.bannerReady,
  });

  @override
  State<ActiveMissionCard> createState() => _ActiveMissionCardState();
}

class _ActiveMissionCardState extends State<ActiveMissionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  void _onNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u26a0\ufe0f Timer not finished yet \u2014 mission cannot be completed.',
        ),
      ),
    );
  }

  void _onCompletePressed() {
    showDialog(
      context: context,
      builder: (_) {
        final messages = [
          '\u2694\ufe0f Only you know whether this mission is complete.',
          '\ud83d\udd25 Shortcuts create weak Hunters.',
          '\ud83c\udfc6 Discipline separates Hunters from legends.',
          '\u26a1 Every completed mission should represent real effort.',
        ];
        messages.shuffle();
        return AlertDialog(
          backgroundColor: HunterTheme.background,
          title: const Text(
            'Hunter Verification',
            style: TextStyle(color: Colors.amber),
          ),
          content: Text(
            'Are you sure you completed this mission honestly?\n\nOnly you know the truth.\n\n${messages.first}',
            style: TextStyle(color: HunterTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CONTINUE MISSION'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onComplete();
              },
              child: const Text('COMPLETE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = widget.remaining == Duration.zero;
    final Color c = ready ? HunterTheme.success : MembershipTheme.current.accent;

    final content = Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bolt_rounded, color: c, size: 16),
          const SizedBox(width: 6),
          Text(
            'ACTIVE MISSION',
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.bolt_rounded, color: c, size: 16),
        ]),
        const SizedBox(height: 10),
        Text(
          ready ? 'Ready to Complete' : 'In Progress',
          style: TextStyle(
            color: ready ? HunterTheme.success : Colors.orangeAccent,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              HunterTheme.gold.withOpacity(0.28),
              HunterTheme.gold.withOpacity(0.12),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HunterTheme.gold.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bolt_rounded, color: HunterTheme.gold, size: 16),
            const SizedBox(width: 6),
            Text(
              'Reward  +${widget.reward} XP',
              style: TextStyle(
                color: HunterTheme.gold,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withOpacity(0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              ready ? Icons.check_circle_rounded : Icons.timer_rounded,
              color: c,
              size: 22,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                ready ? "TIME'S UP!" : formatMinutesSeconds(widget.remaining),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ready ? HunterTheme.success : HunterTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ready ? HunterTheme.success : HunterTheme.border,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: ready ? _onCompletePressed : _onNotReady,
            child: Text(
              'COMPLETE MISSION',
              style: TextStyle(
                color: ready ? Colors.black : HunterTheme.textTertiary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.onCancel,
          child: Text(
            'Cancel mission',
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        if (widget.bannerReady && widget.banner != null) ...[
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: widget.banner!.size.width.toDouble(),
              height: widget.banner!.size.height.toDouble(),
              child: AdWidget(ad: widget.banner!),
            ),
          ),
        ],
      ],
    );

    return AnimatedBuilder(
      animation: _glow,
      child: content,
      builder: (context, child) {
        final g = _glow.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.withOpacity(0.14), HunterTheme.cardColor],
            ),
            border: Border.all(
              color: c.withOpacity(0.5 + g * 0.3),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(0.14 + g * 0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
