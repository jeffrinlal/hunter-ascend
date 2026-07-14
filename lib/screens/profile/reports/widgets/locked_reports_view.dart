// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'package:hunter_ascend/screens/profile/membership_screen.dart';

import '../utils/report_palette.dart';
import 'report_card.dart';

/// Premium lock screen shown to Basic members explaining why Reports are
/// locked, with Pro / Max upgrade calls-to-action. Theme-aware and fully
/// scroll-safe so it never overflows on small screens or in landscape.
class LockedReportsView extends StatelessWidget {
  LockedReportsView({super.key});

  void _openMembership(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MembershipScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ReportPalette.bgTop, ReportPalette.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          AmbientGlow(),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _lockCrest(),
                      const SizedBox(height: 26),
                      Text(
                        'REPORTS LOCKED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ReportPalette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _titleUnderline(),
                      const SizedBox(height: 22),
                      GlassCard(
                        child: Text(
                          'Reports are available only for Pro and Max members.\n\n'
                          'Your workout history, missions, XP, streaks and overall '
                          'progress are analyzed to generate advanced Hunter Reports.\n\n'
                          'These premium reports help provide detailed insights while '
                          'supporting the continued development of Hunter Ascend.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ReportPalette.textSecondary,
                            fontSize: 14.5,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      _UpgradeButton(
                        label: 'Upgrade to Pro',
                        icon: Icons.workspace_premium_rounded,
                        color: ReportPalette.gold,
                        onTap: () => _openMembership(context),
                      ),
                      const SizedBox(height: 14),
                      _UpgradeButton(
                        label: 'Upgrade to Max',
                        icon: Icons.auto_awesome_rounded,
                        color: ReportPalette.purple,
                        onTap: () => _openMembership(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _lockCrest() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          ReportPalette.accent.withOpacity(0.28),
          ReportPalette.accent.withOpacity(0.02),
        ]),
        border:
            Border.all(color: ReportPalette.accent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: ReportPalette.accent.withOpacity(ReportPalette.isDark ? 0.35 : 0.18),
              blurRadius: 30,
              spreadRadius: 2),
        ],
      ),
      child: Icon(Icons.lock_outline_rounded,
          color: ReportPalette.accentBright, size: 44),
    );
  }

  Widget _titleUnderline() {
    return Container(
      width: 60,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          ReportPalette.accent.withOpacity(0),
          ReportPalette.accent,
          ReportPalette.accent.withOpacity(0),
        ]),
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.22), color.withOpacity(0.10)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.6), width: 1.3),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 18)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: ReportPalette.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
