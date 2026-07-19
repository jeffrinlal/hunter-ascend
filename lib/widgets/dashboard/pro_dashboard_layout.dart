import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/widgets/dashboard/animated_xp_ring.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/widgets/dashboard/steps_card.dart';
import 'package:hunter_ascend/widgets/glass/glass_card.dart';

/// Premium Dashboard layout for Pro members.
///
/// Purely presentational — all data is passed in from the parent
/// HomeDashboardScreen which owns the business logic and streams.
class ProDashboardLayout extends StatelessWidget {
  final HunterData hunter;
  final int todaySteps;
  final int waterIntakeMl;
  final int waterGoalMl;
  final Widget quickActions;
  final Widget waterCard;

  const ProDashboardLayout({
    super.key,
    required this.hunter,
    required this.todaySteps,
    required this.waterIntakeMl,
    required this.waterGoalMl,
    required this.quickActions,
    required this.waterCard,
  });

  Uint8List? _decodeAvatar(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    return base64Decode(base64);
  }

  String _rankTitle(int level) {
    if (level >= 30) return 'S RANK';
    if (level >= 20) return 'A RANK';
    if (level >= 15) return 'B RANK';
    if (level >= 10) return 'C RANK';
    if (level >= 5)  return 'D RANK';
    return 'E RANK';
  }

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Premium Hero Header ──
        _PremiumHeader(hunter: hunter, accent: accent),
        const SizedBox(height: 24),

        // ── XP Progress Section ──
        GlassCard(
          child: Row(
            children: [
              AnimatedXpRing(xp: hunter.xp, level: hunter.level, size: 100),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${hunter.level}',
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rankTitle(hunter.level),
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${hunter.xp} / 500 XP to next level',
                      style: TextStyle(
                        color: HunterTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Today's Progress ──
        Text(
          "TODAY'S PROGRESS",
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        DashboardStatsGrid(
          stats: [
            DashboardStat(
              label: 'Steps',
              value: '$todaySteps',
              icon: Icons.directions_walk_rounded,
              color: HunterTheme.primary,
            ),
            DashboardStat(
              label: 'Streak',
              value: '${hunter.streak} days',
              icon: Icons.local_fire_department_rounded,
              color: Colors.orange,
            ),
            DashboardStat(
              label: 'Daily XP',
              value: '${hunter.dailyXp}',
              icon: Icons.bolt_rounded,
              color: HunterTheme.gold,
            ),
            DashboardStat(
              label: 'Water',
              value: '${(waterIntakeMl / 1000).toStringAsFixed(1)}L',
              icon: Icons.water_drop_rounded,
              color: Colors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Steps Card ──
        StepsCard(steps: todaySteps),
        const SizedBox(height: 16),

        // ── Quick Actions ──
        quickActions,
        const SizedBox(height: 16),

        // ── Water Card ──
        waterCard,
      ],
    );
  }
}

/// Premium header with gradient background, avatar, and PRO badge.
class _PremiumHeader extends StatelessWidget {
  final HunterData hunter;
  final Color accent;

  const _PremiumHeader({required this.hunter, required this.accent});

  @override
  Widget build(BuildContext context) {
    final avatarBytes = hunter.profilePicture != null && hunter.profilePicture!.isNotEmpty
        ? base64Decode(hunter.profilePicture!)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.12),
            HunterTheme.cardColor,
          ],
        ),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2.5),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 12)],
            ),
            child: avatarBytes != null
                ? ClipOval(child: Image.memory(avatarBytes, fit: BoxFit.cover, width: 64, height: 64))
                : Center(child: Icon(Icons.person, color: accent, size: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        hunter.hunterName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent.withOpacity(0.4)),
                      ),
                      child: Text(
                        'PRO',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${hunter.streak} day streak',
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
