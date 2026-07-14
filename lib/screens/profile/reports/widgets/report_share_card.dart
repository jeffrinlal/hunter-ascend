// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/report_data.dart';
import '../utils/report_format.dart';
import '../utils/report_palette.dart';

/// A premium, portrait, social-ready Hunter Report card.
///
/// This is NOT a screenshot of the live screen — it is a dedicated layout
/// composed off-screen and captured to an image, sized and spaced for feeds on
/// WhatsApp, Instagram and Facebook (a tall 4:5-ish portrait card).
class ReportShareCard extends StatelessWidget {
  const ReportShareCard({
    super.key,
    required this.hunterName,
    required this.rank,
    required this.level,
    required this.xp,
    required this.missions,
    required this.streak,
    required this.duelWins,
    required this.duelLosses,
    required this.startingWeight,
    required this.currentWeight,
    required this.membership,
    required this.analysis,
    required this.generatedDate,
    required this.reportId,
    this.profilePicture,
  });

  /// Fixed logical width; captured at pixelRatio 3 → ~1290px wide image.
  static const double cardWidth = 430;

  final String hunterName;
  final String rank;
  final int level;
  final int xp;
  final int missions;
  final int streak;
  final int duelWins;
  final int duelLosses;
  final double startingWeight;
  final double currentWeight;
  final String membership;
  final List<MapEntry<String, Rating>> analysis;
  final String generatedDate;
  final String reportId;
  final String? profilePicture;

  @override
  Widget build(BuildContext context) {
    final diff = currentWeight - startingWeight;
    final lost = diff <= 0;
    final weightText = (startingWeight <= 0 && currentWeight <= 0)
        ? 'No data'
        : '${diff.abs().toStringAsFixed(1)} kg ${lost ? "lost" : "gained"}';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF060A14), Color(0xFF0C1526)],
            ),
          ),
          padding: const EdgeInsets.all(26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: ReportPalette.accent.withOpacity(0.4), width: 1.4),
              boxShadow: [
                BoxShadow(color: ReportPalette.accent.withOpacity(0.22), blurRadius: 34),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _brandRow(),
                const SizedBox(height: 22),
                _avatar(),
                const SizedBox(height: 16),
                Text(
                  hunterName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ReportPalette.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                _rankPill(),
                const SizedBox(height: 24),
                _statGrid(),
                const SizedBox(height: 20),
                _divider(),
                const SizedBox(height: 16),
                _weightRow(lost, weightText),
                const SizedBox(height: 16),
                _divider(),
                const SizedBox(height: 16),
                _analysisBlock(),
                const SizedBox(height: 24),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hexagon_outlined,
                color: ReportPalette.accent.withOpacity(0.9), size: 18),
            const SizedBox(width: 8),
            const Text(
              'HUNTER SYSTEM REPORT',
              style: TextStyle(
                color: ReportPalette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$reportId  •  $generatedDate',
          style: const TextStyle(
            color: ReportPalette.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ReportPalette.accent.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(color: ReportPalette.accent.withOpacity(0.4), blurRadius: 20),
        ],
      ),
      child: CircleAvatar(
        radius: 46,
        backgroundColor: const Color(0xFF10192B),
        backgroundImage: profilePicture != null
            ? MemoryImage(base64Decode(profilePicture!))
            : null,
        child: profilePicture == null
            ? const Icon(Icons.person, size: 48, color: ReportPalette.accentBright)
            : null,
      ),
    );
  }

  Widget _rankPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: ReportPalette.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ReportPalette.accent.withOpacity(0.6)),
      ),
      child: Text(
        '$rank RANK  •  ${membership.toUpperCase()}',
        style: const TextStyle(
          color: ReportPalette.accentBright,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _statGrid() {
    return Column(
      children: [
        Row(
          children: [
            _stat('LEVEL', fmtInt(level)),
            _stat('TOTAL XP', fmtInt(xp)),
            _stat('MISSIONS', fmtInt(missions)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat('STREAK', '$streak'),
            _stat('DUEL WINS', fmtInt(duelWins)),
            _stat('DUEL LOSSES', fmtInt(duelLosses)),
          ],
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: ReportPalette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReportPalette.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightRow(bool lost, String weightText) {
    final color = lost ? ReportPalette.mint : ReportPalette.warn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(lost ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          'Weight Progress: $weightText',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _analysisBlock() {
    return Column(
      children: [
        const Text(
          'HUNTER ANALYSIS',
          style: TextStyle(
            color: ReportPalette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...analysis.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        color: ReportPalette.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    e.value.label,
                    style: TextStyle(
                      color: e.value.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          ReportPalette.accent.withOpacity(0),
          ReportPalette.accent.withOpacity(0.4),
          ReportPalette.accent.withOpacity(0),
        ]),
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        const Text(
          'Generated by Hunter Ascend',
          style: TextStyle(
            color: ReportPalette.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Level Up Your Real Life',
          style: TextStyle(
            color: ReportPalette.accentBright.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ReportPalette.textTertiary,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
