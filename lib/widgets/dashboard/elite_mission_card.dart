import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Max dashboard's redesigned "Today's Mission" (steps) card.
///
/// Purely presentational — takes the same [steps] value as [StepsCard] and
/// [PremiumMissionCard] but renders it with a pulsing neon glow border, a
/// purple elite accent, and a different internal layout, so it is visually
/// distinct from both the Basic linear-bar card and the Pro radial-gauge
/// card. No Firestore/business logic here.
class EliteMissionCard extends StatefulWidget {
  final int steps;

  const EliteMissionCard({super.key, required this.steps});

  @override
  State<EliteMissionCard> createState() => _EliteMissionCardState();
}

class _EliteMissionCardState extends State<EliteMissionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.steps / 10000).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final accent = HunterTheme.purple;
    final complete = widget.steps >= 10000;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final glowStrength = 0.14 + (_glow.value * 0.2);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: HunterTheme.cardColor,
            border: Border.all(color: accent.withOpacity(0.5 + _glow.value * 0.3), width: 1.6),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(glowStrength), blurRadius: 26, spreadRadius: 1),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.bolt_rounded, color: accent, size: 16),
                const SizedBox(width: 6),
                Flexible(child: Text('ELITE MISSION', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const Spacer(),
                Text('$percent%', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(value: 1, strokeWidth: 6, color: HunterTheme.border),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            color: accent,
                          ),
                        ),
                      ),
                      Icon(Icons.directions_run_rounded, color: accent, size: 20),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.steps} / 10,000 steps', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        complete ? '⚡ Mission complete — +25 XP' : 'Push further, Hunter.',
                        style: TextStyle(color: complete ? accent : HunterTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
