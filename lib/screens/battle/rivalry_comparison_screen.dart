import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/battle/rivalry_result_screen.dart';
import 'package:hunter_ascend/screens/duel/create_duel_screen.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/services/rivalry_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// The premium head-to-head Rivalry screen.
///
/// Deliberately NOT a modification of `CompareHuntersScreen`, which stays
/// exactly as it is: this is a separate, differently shaped screen built around
/// the rivalry itself — a live countdown, the XP each hunter has gained SINCE
/// the rivalry started, and a two-column stat duel.
///
/// Every value shown already exists on `HunterData`. No new statistic, no new
/// tracking and no rivalry-specific scoring is introduced. "Total XP" is the
/// monotonic `(level - 1) * 500 + xp` form computed by
/// [RivalryService.totalXpFrom]; "Rank" comes from `RankService`, which derives
/// it from level alone.
class RivalryComparisonScreen extends StatefulWidget {
  const RivalryComparisonScreen({super.key, required this.rivalryId});

  final String rivalryId;

  @override
  State<RivalryComparisonScreen> createState() =>
      _RivalryComparisonScreenState();
}

class _RivalryComparisonScreenState extends State<RivalryComparisonScreen> {
  RivalryData? _rivalry;
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _rival;

  bool _loading = true;
  bool _leaving = false;
  String? _error;

  /// Drives the countdown text only. Purely local — no Firestore, and nothing
  /// is written for the entire duration of a rivalry.
  Timer? _ticker;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Only rebuild while there is actually a countdown to advance.
      final rivalry = _rivalry;
      if (rivalry == null) return;
      if (rivalry.status != RivalryStatus.active || rivalry.hasExpired) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _myUid;
    if (uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'You must be signed in.';
      });
      return;
    }

    try {
      final rivalry = await RivalryService.instance.fetchById(widget.rivalryId);
      if (rivalry == null || !rivalry.isParticipant(uid)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'This Rivalry no longer exists.';
        });
        return;
      }

      final otherUid = rivalry.otherUidFor(uid);
      final hunters = FirebaseFirestore.instance.collection('hunters');
      // Both documents are read together so the two columns always show a
      // consistent snapshot of the same moment.
      final snaps = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
        <Future<DocumentSnapshot<Map<String, dynamic>>>>[
          hunters.doc(uid).get(),
          hunters.doc(otherUid).get(),
        ],
      );

      if (!mounted) return;
      setState(() {
        _rivalry = rivalry;
        _me = snaps[0].data();
        _rival = snaps[1].exists ? snaps[1].data() : null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('RivalryComparisonScreen._load: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the Rivalry. Please try again.';
      });
    }
  }

  /// Removes only this user from the rivalry's `unsettledFor` list, freeing
  /// them to start a new Rivalry. Used when the rival's account is gone.
  Future<void> _leaveRivalry() async {
    final rivalry = _rivalry;
    if (rivalry == null || _leaving) return;
    setState(() => _leaving = true);
    final ok = await RivalryService.instance.settleMySide(rivalry);
    if (!mounted) return;
    setState(() => _leaving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave the Rivalry.')),
      );
      return;
    }
    Navigator.pop(context);
  }

  void _openResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RivalryResultScreen(rivalryId: widget.rivalryId),
      ),
    );
  }

  void _challengeRival() {
    // Launches the EXISTING duel flow. There is no rivalry-specific battle
    // system; a Rivalry and a Duel remain separate features.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateDuelScreen(pushed: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'RIVALRY',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: MembershipTheme.current.accent),
      );
    }
    if (_error != null) {
      return _messageState(
        icon: Icons.error_outline_rounded,
        color: HunterTheme.danger,
        title: 'RIVALRY UNAVAILABLE',
        message: _error!,
      );
    }

    final rivalry = _rivalry!;

    // The rival deleted their account, or abandoned the rivalry by doing so.
    if (_rival == null || rivalry.status == RivalryStatus.abandoned) {
      return _messageState(
        icon: Icons.person_off_outlined,
        color: HunterTheme.danger,
        title: 'YOUR RIVAL LEFT',
        message: 'This Hunter is no longer available. '
            'Leave the Rivalry to challenge someone new.',
        action: _leaving ? null : _leaveRivalry,
        actionLabel: 'LEAVE RIVALRY',
      );
    }

    final me = _me ?? const <String, dynamic>{};
    final rival = _rival!;
    final myUid = _myUid;
    final otherUid = rivalry.otherUidFor(myUid);

    // Scrollable + ellipsised text throughout, so the two columns stay intact
    // on small screens and at large system font scales.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        children: [
          _buildStatusHeader(rivalry),
          const SizedBox(height: 20),
          _buildVersusHeader(
            rivalry: rivalry,
            me: me,
            rival: rival,
            otherUid: otherUid,
          ),
          const SizedBox(height: 22),
          _buildProgressSection(
            rivalry: rivalry,
            me: me,
            rival: rival,
            myUid: myUid,
            otherUid: otherUid,
          ),
          const SizedBox(height: 22),
          _buildStatsSection(me: me, rival: rival),
          const SizedBox(height: 24),
          _buildChallengeButton(),
        ],
      ),
    );
  }

  // ── Status header: countdown, or "ended" ───────────────────────────────

  Widget _buildStatusHeader(RivalryData rivalry) {
    final accent = MembershipTheme.current.accent;
    final ended =
        rivalry.status == RivalryStatus.completed || rivalry.hasExpired;

    if (ended) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HunterTheme.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HunterTheme.gold.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Icon(Icons.emoji_events_rounded, color: HunterTheme.gold, size: 30),
            const SizedBox(height: 10),
            Text(
              'RIVALRY ENDED',
              style: TextStyle(
                color: HunterTheme.gold,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The result is ready.',
              style: TextStyle(
                  color: HunterTheme.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _openResult,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: HunterTheme.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'VIEW RESULT',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // `startAt` is a server timestamp, so for a brief moment right after
    // acceptance the client may still see it unresolved. Show a starting state
    // rather than a misleading all-zero countdown.
    final remaining = rivalry.timeRemaining;
    if (remaining == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.4),
        ),
        child: Column(
          children: [
            Text(
              'RIVALRY STARTING',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${rivalry.durationDays}-day countdown is being set up.',
              style:
                  TextStyle(color: HunterTheme.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            HunterTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Column(
        children: [
          Text(
            'ACTIVE RIVALRY',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timeBlock('${remaining.inDays}', 'DAYS'),
              _timeSeparator(),
              _timeBlock('${remaining.inHours % 24}', 'HRS'),
              _timeSeparator(),
              _timeBlock('${remaining.inMinutes % 60}', 'MIN'),
              _timeSeparator(),
              _timeBlock('${remaining.inSeconds % 60}', 'SEC'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${rivalry.durationDays}-day rivalry remaining',
            style:
                TextStyle(color: HunterTheme.textTertiary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _timeBlock(String value, String label) {
    return Column(
      children: [
        Text(
          value.padLeft(2, '0'),
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _timeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        ':',
        style: TextStyle(
          color: HunterTheme.textTertiary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ── Versus header ─────────────────────────────────────────────────────

  Widget _buildVersusHeader({
    required RivalryData rivalry,
    required Map<String, dynamic> me,
    required Map<String, dynamic> rival,
    required String otherUid,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _hunterColumn(
            data: me,
            fallbackName: 'You',
            label: 'YOU',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 34),
          child: Text(
            'VS',
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: _hunterColumn(
            data: rival,
            fallbackName: rivalry.hunterNameFor(otherUid),
            label: 'RIVAL',
          ),
        ),
      ],
    );
  }

  Widget _hunterColumn({
    required Map<String, dynamic> data,
    required String fallbackName,
    required String label,
  }) {
    final level = (data['level'] as num?)?.toInt() ?? 1;
    final rankColor = RankService.instance.colorForLevel(level);
    final rankLetter = RankService.instance.letterForLevel(level);
    final name = (data['hunterName'] as String?) ?? fallbackName;
    final picture = data['profilePicture'] as String?;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HunterTheme.cardColor,
                border: Border.all(color: rankColor, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: rankColor
                        .withValues(alpha: 0.35 * HunterTheme.glowStrength),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
                image: picture != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(picture)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: picture == null
                  ? Icon(Icons.person,
                      color: HunterTheme.textTertiary, size: 34)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: HunterTheme.background, width: 1.5),
                ),
                child: Text(
                  rankLetter,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'LEVEL $level',
          style: TextStyle(
            color: rankColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ── Rivalry progress ──────────────────────────────────────────────────

  Widget _buildProgressSection({
    required RivalryData rivalry,
    required Map<String, dynamic> me,
    required Map<String, dynamic> rival,
    required String myUid,
    required String otherUid,
  }) {
    final accent = MembershipTheme.current.accent;

    // Progress is always measured as a DELTA from the baseline captured at
    // acceptance, using the monotonic total-XP form. Once the rivalry has been
    // finalized the frozen endScore is used instead, so the number can never
    // change after the fact.
    final int myProgress = rivalry.finalProgressFor(myUid) ??
        rivalry.liveProgressFor(myUid, RivalryService.totalXpFrom(me));
    final int rivalProgress = rivalry.finalProgressFor(otherUid) ??
        rivalry.liveProgressFor(otherUid, RivalryService.totalXpFrom(rival));

    final peak = myProgress > rivalProgress ? myProgress : rivalProgress;
    final String lead;
    if (myProgress > rivalProgress) {
      lead = 'You are ahead by ${myProgress - rivalProgress} XP';
    } else if (rivalProgress > myProgress) {
      lead = 'Your Rival is ahead by ${rivalProgress - myProgress} XP';
    } else {
      lead = 'Dead even';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HunterTheme.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('XP GAINED THIS RIVALRY'),
          const SizedBox(height: 16),
          _progressBar(
            label: 'YOU',
            value: myProgress,
            peak: peak,
            color: accent,
          ),
          const SizedBox(height: 14),
          _progressBar(
            label: 'RIVAL',
            value: rivalProgress,
            peak: peak,
            color: HunterTheme.danger,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              lead,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar({
    required String label,
    required int value,
    required int peak,
    required Color color,
  }) {
    double fraction = 0;
    if (peak > 0) {
      fraction = value / peak;
      if (fraction > 1) fraction = 1;
      if (fraction < 0) fraction = 0;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            Text(
              '+$value XP',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: HunterTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Stat duel ─────────────────────────────────────────────────────────

  Widget _buildStatsSection({
    required Map<String, dynamic> me,
    required Map<String, dynamic> rival,
  }) {
    final myLevel = (me['level'] as num?)?.toInt() ?? 1;
    final rivalLevel = (rival['level'] as num?)?.toInt() ?? 1;

    final myWins = (me['duelWins'] as num?)?.toInt() ?? 0;
    final myLosses = (me['duelLosses'] as num?)?.toInt() ?? 0;
    final rivalWins = (rival['duelWins'] as num?)?.toInt() ?? 0;
    final rivalLosses = (rival['duelLosses'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HunterTheme.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('HEAD TO HEAD'),
          const SizedBox(height: 6),
          _numericRow('LEVEL', myLevel, rivalLevel),
          _numericRow(
            'TOTAL XP',
            RivalryService.totalXpFrom(me),
            RivalryService.totalXpFrom(rival),
          ),
          _textRow(
            'RANK',
            RankService.instance.shortTitleForLevel(myLevel),
            RankService.instance.shortTitleForLevel(rivalLevel),
          ),
          _numericRow(
            'STREAK',
            (me['streak'] as num?)?.toInt() ?? 0,
            (rival['streak'] as num?)?.toInt() ?? 0,
          ),
          _numericRow(
            'QUESTS',
            (me['questsDone'] as num?)?.toInt() ?? 0,
            (rival['questsDone'] as num?)?.toInt() ?? 0,
          ),
          _numericRow(
            'DUNGEONS',
            (me['dungeonsCompleted'] as num?)?.toInt() ?? 0,
            (rival['dungeonsCompleted'] as num?)?.toInt() ?? 0,
          ),
          _numericRow('BATTLES WON', myWins, rivalWins),
          _numericRow(
            'WIN RATE',
            _winRate(myWins, myLosses),
            _winRate(rivalWins, rivalLosses),
            suffix: '%',
          ),
        ],
      ),
    );
  }

  /// Existing derivation, identical to the one Compare Hunters already uses.
  int _winRate(int wins, int losses) {
    final total = wins + losses;
    if (total == 0) return 0;
    return ((wins * 100) / total).round();
  }

  Widget _numericRow(String label, int mine, int theirs,
      {String suffix = ''}) {
    final accent = MembershipTheme.current.accent;
    final iLead = mine > theirs;
    final theyLead = theirs > mine;
    return _row(
      label: label,
      left: '$mine$suffix',
      right: '$theirs$suffix',
      leftColor: iLead ? accent : HunterTheme.textPrimary,
      rightColor: theyLead ? HunterTheme.danger : HunterTheme.textPrimary,
      leftBold: iLead,
      rightBold: theyLead,
    );
  }

  Widget _textRow(String label, String mine, String theirs) {
    return _row(
      label: label,
      left: mine,
      right: theirs,
      leftColor: HunterTheme.textPrimary,
      rightColor: HunterTheme.textPrimary,
      leftBold: false,
      rightBold: false,
    );
  }

  Widget _row({
    required String label,
    required String left,
    required String right,
    required Color leftColor,
    required Color rightColor,
    required bool leftBold,
    required bool rightBold,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              left,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: leftColor,
                fontSize: 14,
                fontWeight: leftBold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              right,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: rightColor,
                fontSize: 14,
                fontWeight: rightBold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: MembershipTheme.current.gradient,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeButton() {
    final tokens = MembershipTheme.current;
    final fg = MembershipTheme.isMax ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: _challengeRival,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tokens.gradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: tokens.accent
                  .withValues(alpha: 0.35 * HunterTheme.glowStrength),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_kabaddi_rounded, color: fg, size: 19),
            const SizedBox(width: 9),
            Text(
              'CHALLENGE RIVAL TO A DUEL',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: action,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: color.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
