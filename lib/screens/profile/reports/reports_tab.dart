// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:hunter_ascend/core/theme/hunter_theme.dart';

import 'models/report_data.dart';
import 'services/report_service.dart';
import 'utils/report_analysis.dart';
import 'utils/report_format.dart';
import 'utils/report_palette.dart';
import 'widgets/count_up.dart';
import 'widgets/locked_reports_view.dart';
import 'widgets/report_card.dart';
import 'widgets/report_section.dart';
import 'widgets/report_share_card.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// HUNTER SYSTEM REPORT — premium (Pro / Max) tab on the Profile screen.
///
/// Generated ENTIRELY from data that already exists (hunters doc + the
/// weight_history / calorie_logs / runs collections + Firebase Auth account
/// metadata). No new collections, fields, documents, Cloud Functions, or
/// backend services. Range is capped at the last 30 days.
///
/// The screen is theme-aware: it follows the app's light/dark theme via
/// [ReportPalette] (driven by [HunterTheme.isDark]) while preserving the same
/// premium System-Window feel in both. The shareable image, however, stays a
/// fixed premium-dark design (see report_share_card.dart).
/// ─────────────────────────────────────────────────────────────────────────
class ReportsTab extends StatefulWidget {
  const ReportsTab({
    super.key,
    required this.uid,
    required this.hunterData,
  });

  final String uid;
  final Map<String, dynamic> hunterData;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  Future<ReportData>? _future;
  int _rangeDays = ReportService.maxRangeDays; // 7 or 30

  bool get _premium => ReportMembership.isPremium(widget.hunterData);

  @override
  void initState() {
    super.initState();
    // Only premium hunters trigger the Firestore reads — Basic users see the
    // lock screen and cost nothing.
    if (_premium) _future = ReportService.load(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the app theme toggles so the report re-colours itself.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themed(context),
    );
  }

  Widget _themed(BuildContext context) {
    if (!_premium) return LockedReportsView();

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
          FutureBuilder<ReportData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(
                      color: ReportPalette.accent, strokeWidth: 2.5),
                );
              }
              return _ReportContent(
                uid: widget.uid,
                hunterData: widget.hunterData,
                report: snap.data ?? const ReportData.empty(),
                rangeDays: _rangeDays,
                onRangeChanged: (d) => setState(() => _rangeDays = d),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// REPORT CONTENT
// ══════════════════════════════════════════════════════════════════════════

class _ReportContent extends StatefulWidget {
  const _ReportContent({
    required this.uid,
    required this.hunterData,
    required this.report,
    required this.rangeDays,
    required this.onRangeChanged,
  });

  final String uid;
  final Map<String, dynamic> hunterData;
  final ReportData report;
  final int rangeDays;
  final ValueChanged<int> onRangeChanged;

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _anim(int i) {
    final start = (i * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.45).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  // ── Derived hunter values (all from the live hunter document) ───────────
  Map<String, dynamic> get _d => widget.hunterData;
  int get _xp => (_d['xp'] ?? 0) as int;
  int get _level => (_d['level'] ?? 1) as int;
  int get _streak => (_d['streak'] ?? 0) as int;
  int get _duelWins => (_d['duelWins'] ?? 0) as int;
  int get _duelLosses => (_d['duelLosses'] ?? 0) as int;
  int get _questsDone => (_d['questsDone'] ?? 0) as int;
  int get _totalDuels => _duelWins + _duelLosses;
  String get _hunterName => (_d['hunterName'] ?? 'Unknown Hunter').toString();
  String get _rank => rankForXp(_xp);

  double get _startingWeight {
    final w = widget.report;
    if (w.weightOk && w.weights.isNotEmpty) return w.weights.last.weight;
    return (_d['startingWeight'] ?? _d['weight'] ?? 0).toDouble();
  }

  double get _currentWeight {
    final w = widget.report;
    if (w.weightOk && w.weights.isNotEmpty) return w.weights.first.weight;
    return (_d['weight'] ?? 0).toDouble();
  }

  DateTime? get _joinedDate =>
      FirebaseAuth.instance.currentUser?.metadata.creationTime;

  /// Distinct active days (meal / run / weight) within the selected range.
  int get _activeDays {
    final r = widget.report;
    final cutoff = DateTime.now().subtract(Duration(days: widget.rangeDays));
    final days = <String>{};
    for (final m in r.meals) {
      if (m.time.isAfter(cutoff)) days.add(dayKey(m.time));
    }
    for (final run in r.runs) {
      if (run.createdAt.isAfter(cutoff)) days.add(dayKey(run.createdAt));
    }
    for (final w in r.weights) {
      if (w.date.isAfter(cutoff)) days.add(dayKey(w.date));
    }
    return days.length;
  }

  List<MapEntry<String, Rating>> get _analysis => [
        MapEntry('Discipline', ReportAnalysis.discipline(_streak)),
        MapEntry('Consistency', ReportAnalysis.consistency(_activeDays)),
        MapEntry('Combat Activity', ReportAnalysis.combat(_totalDuels)),
        MapEntry(
          'Hunter Potential',
          ReportAnalysis.potential(
            rank: _rank,
            level: _level,
            streak: _streak,
            activeDays: _activeDays,
            totalDuels: _totalDuels,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final generated = fmtDate(now);
    final reportId = localReportId(widget.uid, now);
    final tier = ReportMembership.effectiveTier(_d);
    final membership = ReportMembership.label(tier);

    int i = 0;
    Widget sec(Widget child) =>
        ReportSection(animation: _anim(i++), child: child);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: [
        sec(ReportHero(generatedDate: generated, reportId: reportId)),
        const SizedBox(height: 14),
        sec(RangeToggle(
            rangeDays: widget.rangeDays, onChanged: widget.onRangeChanged)),
        const SizedBox(height: 16),
        sec(_statusCard(membership)),
        const SizedBox(height: 14),
        sec(_statsCard()),
        const SizedBox(height: 14),
        sec(_weightCard()),
        const SizedBox(height: 14),
        sec(_nutritionCard()),
        const SizedBox(height: 14),
        sec(_runningCard()),
        const SizedBox(height: 14),
        sec(_analysisCard()),
        const SizedBox(height: 20),
        sec(_shareButton(membership, generated, reportId)),
      ],
    );
  }

  // ── 1. Hunter Status ────────────────────────────────────────────────────
  Widget _statusCard(String membership) {
    final joined = _joinedDate;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              icon: Icons.shield_moon_outlined, title: 'HUNTER STATUS'),
          const SizedBox(height: 16),
          Row(
            children: [
              _rankCrest(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hunterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ReportPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_rank Rank Hunter',
                      style: TextStyle(
                        color: ReportPalette.accentBright.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _MembershipChip(membership: membership),
            ],
          ),
          const SizedBox(height: 16),
          HairLine(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat('LEVEL', fmtInt(_level))),
              Expanded(child: _miniStat('TOTAL XP', fmtInt(_xp))),
              Expanded(
                child: _miniStat(
                    'JOINED', joined != null ? fmtDate(joined) : '—',
                    small: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankCrest() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          ReportPalette.accent.withOpacity(0.30),
          ReportPalette.accent.withOpacity(0.02),
        ]),
        border:
            Border.all(color: ReportPalette.accent.withOpacity(0.6), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _rank,
        style: TextStyle(
          color: ReportPalette.accentBright,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool small = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: ReportPalette.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ReportPalette.textPrimary,
            fontSize: small ? 12.5 : 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ── 2. Hunter Statistics ────────────────────────────────────────────────
  Widget _statsCard() {
    final stats = <StatSpec>[
      StatSpec('Current Level', _level.toDouble(), Icons.trending_up_rounded),
      StatSpec('Total XP', _xp.toDouble(), Icons.bolt_rounded),
      StatSpec(
          'Missions Completed', _questsDone.toDouble(), Icons.task_alt_rounded),
      StatSpec('Current Streak', _streak.toDouble(),
          Icons.local_fire_department_rounded,
          suffix: _streak == 1 ? ' day' : ' days'),
      StatSpec('Duel Wins', _duelWins.toDouble(), Icons.emoji_events_rounded),
      StatSpec('Duel Losses', _duelLosses.toDouble(), Icons.shield_outlined),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              icon: Icons.query_stats_rounded, title: 'HUNTER STATISTICS'),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              // Responsive: 1 column on very narrow widths, else 2 columns.
              const spacing = 12.0;
              final twoCol = c.maxWidth >= 280;
              final cellW = twoCol ? (c.maxWidth - spacing) / 2 : c.maxWidth;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final s in stats)
                    SizedBox(width: cellW, child: StatCell(spec: s)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 3. Weight Summary ─────────────────────────────────────────────────
  Widget _weightCard() {
    final start = _startingWeight;
    final current = _currentWeight;
    final diff = current - start;
    final lost = diff <= 0;
    final magnitude = diff.abs();
    final diffColor = lost ? ReportPalette.mint : ReportPalette.warn;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              icon: Icons.monitor_weight_outlined, title: 'WEIGHT SUMMARY'),
          const SizedBox(height: 14),
          if (start <= 0 && current <= 0)
            EmptyLine('No weight data recorded yet.')
          else ...[
            Row(
              children: [
                Expanded(
                    child: _weightBlock(
                        'STARTING', start, ReportPalette.textSecondary)),
                Icon(Icons.arrow_forward_rounded,
                    color: ReportPalette.textTertiary, size: 18),
                Expanded(
                    child: _weightBlock(
                        'CURRENT', current, ReportPalette.accentBright)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: diffColor.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      lost
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: diffColor,
                      size: 20),
                  const SizedBox(width: 8),
                  CountUp(
                    value: magnitude,
                    formatter: (v) =>
                        '${v.toStringAsFixed(1)} kg ${lost ? "lost" : "gained"}',
                    style: TextStyle(
                        color: diffColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightBlock(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: ReportPalette.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 6),
        CountUp(
          value: value,
          formatter: (v) => v.toStringAsFixed(1),
          style: TextStyle(
              color: color, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Text('kg',
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  // ── 4. Nutrition Summary ──────────────────────────────────────────────
  Widget _nutritionCard() {
    final r = widget.report;
    final cutoff = DateTime.now().subtract(Duration(days: widget.rangeDays));
    final meals = r.meals.where((m) => m.time.isAfter(cutoff)).toList();

    final totalCals = meals.fold<int>(0, (s, m) => s + m.calories);
    final protein = meals.fold<double>(0, (s, m) => s + m.protein);
    final carbs = meals.fold<double>(0, (s, m) => s + m.carbs);
    final fat = meals.fold<double>(0, (s, m) => s + m.fat);
    final daysTracked = meals.map((m) => dayKey(m.time)).toSet().length;
    final avgDaily = daysTracked > 0 ? totalCals / daysTracked : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.restaurant_rounded,
            title: 'NUTRITION SUMMARY',
            trailing: 'LAST ${widget.rangeDays} DAYS',
          ),
          const SizedBox(height: 14),
          if (!r.nutritionOk)
            EmptyLine('Nutrition data is currently unavailable.')
          else if (meals.isEmpty)
            EmptyLine('No meals logged in the last ${widget.rangeDays} days.')
          else ...[
            Row(
              children: [
                Expanded(
                    child: _numBlock('AVG DAILY', avgDaily, (v) => fmtInt(v),
                        unit: 'kcal', color: ReportPalette.accentBright)),
                Expanded(
                    child: _numBlock(
                        'TOTAL', totalCals.toDouble(), (v) => fmtInt(v),
                        unit: 'kcal', color: ReportPalette.textPrimary)),
                Expanded(
                    child: _numBlock('DAYS TRACKED', daysTracked.toDouble(),
                        (v) => fmtInt(v),
                        color: ReportPalette.textPrimary)),
              ],
            ),
            const SizedBox(height: 14),
            HairLine(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child:
                        _macroPill('PROTEIN', protein, ReportPalette.accent)),
                const SizedBox(width: 8),
                Expanded(child: _macroPill('CARBS', carbs, ReportPalette.mint)),
                const SizedBox(width: 8),
                Expanded(
                    child: _macroPill('FAT', fat, ReportPalette.fatAccent)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _macroPill(String label, double grams, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          CountUp(
            value: grams,
            formatter: (v) => '${v.toStringAsFixed(0)}g',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: ReportPalette.textTertiary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  // ── 5. Running Summary ────────────────────────────────────────────────
  Widget _runningCard() {
    final r = widget.report;
    final cutoff = DateTime.now().subtract(Duration(days: widget.rangeDays));
    final runs = r.runs.where((run) => run.createdAt.isAfter(cutoff)).toList();

    final totalDist = runs.fold<double>(0, (s, run) => s + run.distanceKm);
    final totalSecs = runs.fold<int>(0, (s, run) => s + run.durationSeconds);
    final totalBurn = runs.fold<int>(0, (s, run) => s + run.caloriesBurned);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.directions_run_rounded,
            title: 'RUNNING SUMMARY',
            trailing: 'LAST ${widget.rangeDays} DAYS',
          ),
          const SizedBox(height: 14),
          if (!r.runsOk)
            EmptyLine('Running data is currently unavailable.')
          else if (runs.isEmpty)
            EmptyLine('No runs recorded in the last ${widget.rangeDays} days.')
          else ...[
            Row(
              children: [
                Expanded(
                    child: _numBlock(
                        'DISTANCE', totalDist, (v) => v.toStringAsFixed(1),
                        unit: 'km', color: ReportPalette.accentBright)),
                Expanded(
                    child: _numBlock(
                        'RUNS', runs.length.toDouble(), (v) => fmtInt(v),
                        color: ReportPalette.textPrimary)),
                Expanded(
                    child: _numBlock(
                        'CALORIES', totalBurn.toDouble(), (v) => fmtInt(v),
                        unit: 'kcal', color: ReportPalette.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined,
                    color: ReportPalette.textTertiary, size: 15),
                const SizedBox(width: 6),
                Text('Total active time: ${fmtDuration(totalSecs)}',
                    style: TextStyle(
                        color: ReportPalette.textSecondary, fontSize: 12.5)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _numBlock(String label, double value, String Function(double) fmt,
      {String? unit, required Color color}) {
    return Column(
      children: [
        CountUp(
          value: value,
          formatter: fmt,
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        if (unit != null)
          Text(unit,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10.5)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: ReportPalette.textTertiary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ],
    );
  }

  // ── 6. Hunter Analysis ────────────────────────────────────────────────
  Widget _analysisCard() {
    final ratings = _analysis;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              icon: Icons.insights_rounded, title: 'HUNTER ANALYSIS'),
          const SizedBox(height: 4),
          for (int idx = 0; idx < ratings.length; idx++)
            _analysisRow(ratings[idx].key, ratings[idx].value),
          const SizedBox(height: 10),
          Text(
            'Calculated from your streak, active days, duels, level and rank — '
            'the same inputs always produce the same result.',
            style: TextStyle(
              color: ReportPalette.textTertiary.withOpacity(0.9),
              fontSize: 10.5,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisRow(String label, Rating rating) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: ReportPalette.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: rating.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rating.color.withOpacity(0.5)),
                ),
                child: Text(rating.label,
                    style: TextStyle(
                        color: rating.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: rating.fill),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: ReportPalette.track,
                valueColor: AlwaysStoppedAnimation<Color>(rating.color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. Share ────────────────────────────────────────────────────────────
  Widget _shareButton(String membership, String generated, String reportId) {
    return GestureDetector(
      onTap:
          _sharing ? null : () => _shareReport(membership, generated, reportId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ReportPalette.accent,
              ReportPalette.accent.withOpacity(0.7)
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: ReportPalette.accent.withOpacity(0.4), blurRadius: 20),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_sharing)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.ios_share_rounded,
                  color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _sharing ? 'Generating...' : 'Share Hunter Report',
              style: const TextStyle(
                color: Colors.white,
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

  Future<void> _shareReport(
      String membership, String generated, String reportId) async {
    setState(() => _sharing = true);
    try {
      final controller = ScreenshotController();
      final bytes = await controller.captureFromWidget(
        ReportShareCard(
          hunterName: _hunterName,
          rank: _rank,
          level: _level,
          xp: _xp,
          missions: _questsDone,
          streak: _streak,
          duelWins: _duelWins,
          duelLosses: _duelLosses,
          startingWeight: _startingWeight,
          currentWeight: _currentWeight,
          membership: membership,
          analysis: _analysis,
          generatedDate: generated,
          reportId: reportId,
          profilePicture: _d['profilePicture'] as String?,
        ),
        context: context,
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 120),
      );

      final dir = await Directory.systemTemp.createTemp('hunter_report');
      final file = File('${dir.path}/hunter_ascend_report.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '⚔️ My Hunter Report — $_hunterName ($_rank Rank)\n'
            'Level $_level • ${fmtInt(_xp)} XP • $_streak day streak\n\n'
            'Generated by Hunter Ascend — Level Up Your Real Life\n'
            'https://play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

/// Small membership chip used in the Hunter Status card.
class _MembershipChip extends StatelessWidget {
  _MembershipChip({required this.membership});
  final String membership;

  @override
  Widget build(BuildContext context) {
    final isMax = membership == 'Max';
    final isPro = membership == 'Pro';
    final color = isMax
        ? ReportPalette.purple
        : (isPro ? ReportPalette.gold : ReportPalette.textTertiary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMax
                ? Icons.auto_awesome_rounded
                : (isPro
                    ? Icons.workspace_premium_rounded
                    : Icons.shield_outlined),
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            membership.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
