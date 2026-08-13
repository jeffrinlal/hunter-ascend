import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/battle/step_clash_result_screen.dart';
import 'package:hunter_ascend/services/step_clash_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:pedometer/pedometer.dart';

/// Active Step Clash battle screen.
///
/// - Subscribes to `Pedometer.stepCountStream` independently (broadcast stream).
/// - Syncs progress to Firestore every [StepClashService.syncInterval].
/// - Listens to the shared document for other participants' progress.
/// - Detects early win (goal reached) or timer expiry.
class StepClashScreen extends StatefulWidget {
  const StepClashScreen({super.key, required this.battleId});
  final String battleId;

  @override
  State<StepClashScreen> createState() => _StepClashScreenState();
}

class _StepClashScreenState extends State<StepClashScreen> {
  StepClashData? _clash;
  bool _loading = true;
  String? _error;

  // Pedometer state.
  int? _startPedometer; // raw value at battle start
  int _currentPedometer = 0;
  int _mySteps = 0;
  int _lastSyncedSteps = 0; // steps at last Firestore sync
  StreamSubscription<StepCount>? _pedometerSub;

  // Timers.
  Timer? _syncTimer;
  Timer? _ticker;

  // Guards.
  bool _finalizing = false;
  bool _forfeiting = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pedometerSub?.cancel();
    _syncTimer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final clash = await StepClashService.instance.fetchById(widget.battleId);
    if (!mounted) return;
    if (clash == null) {
      setState(() {
        _loading = false;
        _error = 'Battle not found.';
      });
      return;
    }

    setState(() {
      _clash = clash;
      _loading = false;
    });

    if (clash.status == StepClashStatus.active) {
      _startBattle(clash);
    } else if (clash.status == StepClashStatus.completed || clash.hasExpired) {
      _goToResult();
    }
    // If waiting, show waiting state — no pedometer needed yet.
  }

  void _startBattle(StepClashData clash) {
    // Restore startSnapshot if already stored, else capture on first pedometer event.
    final existing = clash.startSnapshot[_uid];
    if (existing != null) _startPedometer = existing;

    _pedometerSub = Pedometer.stepCountStream.listen(
      (event) {
        _currentPedometer = event.steps;
        if (_startPedometer == null) {
          _startPedometer = event.steps;
        }
        final steps =
            (_currentPedometer - _startPedometer!).clamp(0, clash.goalSteps);
        if (!mounted) return;
        setState(() => _mySteps = steps);

        // Step-threshold sync: if we've gained enough steps since last sync,
        // push an update immediately (makes the battle feel live while walking).
        if ((steps - _lastSyncedSteps).abs() >=
            StepClashService.syncStepThreshold) {
          _sync();
        }

        // Early win: reached goal.
        if (steps >= clash.goalSteps && !_finalizing) {
          _syncAndFinalize();
        }
      },
      onError: (e) => debugPrint('StepClash pedometer: $e'),
    );

    // Time-based periodic Firestore sync (every 30s, as a safety net in case
    // the user isn't walking fast enough to hit the step threshold).
    _syncTimer = Timer.periodic(StepClashService.syncInterval, (_) => _sync());

    // UI countdown ticker.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final c = _clash;
      if (c == null) return;
      setState(() {}); // re-render countdown
      // Check expiry.
      if (c.hasExpired && !_finalizing) {
        _syncAndFinalize();
      }
    });
  }

  Future<void> _sync() async {
    final clash = _clash;
    if (clash == null || _startPedometer == null) return;
    if (clash.status != StepClashStatus.active) return;
    if (clash.isForfeited(_uid)) return;
    await StepClashService.instance.syncProgress(
      clash,
      rawPedometerNow: _currentPedometer,
      startPedometer: _startPedometer!,
    );
    _lastSyncedSteps = _mySteps;
  }

  Future<void> _syncAndFinalize() async {
    if (_finalizing) return;
    _finalizing = true;
    await _sync();
    final clash = _clash;
    if (clash == null) return;
    final result = await StepClashService.instance.finalize(clash);
    if (!mounted) return;
    if (result != null) _goToResult();
    _finalizing = false;
  }

  void _goToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StepClashResultScreen(battleId: widget.battleId),
      ),
    );
  }

  Future<void> _forfeit() async {
    if (_forfeiting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HunterTheme.cardColor,
        title: Text('Give Up?',
            style: TextStyle(color: HunterTheme.textPrimary)),
        content: Text(
          'You will forfeit this Step Clash. Other players will continue.',
          style: TextStyle(color: HunterTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: HunterTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Give Up', style: TextStyle(color: HunterTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _forfeiting = true);
    await _sync(); // sync final progress before forfeiting
    final clash = _clash;
    if (clash == null) return;
    await StepClashService.instance.forfeit(clash);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
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
            const Text('👣', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'STEP CLASH',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
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
          child:
              CircularProgressIndicator(color: MembershipTheme.current.accent));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: TextStyle(color: HunterTheme.textSecondary, fontSize: 14)),
      );
    }

    final clash = _clash!;

    // If waiting, show waiting UI.
    if (clash.status == StepClashStatus.waiting) {
      return _waitingBody(clash);
    }

    // Active battle: live stream for others' progress.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('step_clashes')
          .doc(widget.battleId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasData && snap.data!.exists) {
          final live = StepClashData.fromSnapshot(snap.data!);
          // Check if finalized externally.
          if (live.status == StepClashStatus.completed) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _goToResult());
            return const SizedBox.shrink();
          }
          return _activeBattleBody(live);
        }
        return _activeBattleBody(clash);
      },
    );
  }

  Widget _waitingBody(StepClashData clash) {
    final accent = MembershipTheme.current.accent;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded, color: accent, size: 48),
            const SizedBox(height: 20),
            Text(
              'WAITING FOR PLAYERS',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${clash.pendingInvitees.length} player(s) haven\'t accepted yet.',
              style: TextStyle(
                  color: HunterTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...clash.pendingInvitees.map((uid) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    clash.nameFor(uid),
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                )),
            const SizedBox(height: 32),
            if (clash.creatorUid == _uid)
              GestureDetector(
                onTap: () async {
                  await StepClashService.instance.cancel(clash);
                  if (mounted) Navigator.pop(context);
                },
                child: Text(
                  'CANCEL',
                  style: TextStyle(
                    color: HunterTheme.danger,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activeBattleBody(StepClashData clash) {
    final accent = MembershipTheme.current.accent;
    final remaining = clash.timeRemaining;
    final goal = clash.goalSteps;

    // Build ranking: inject own live steps into the progress map for display.
    final liveProgress = Map<String, int>.from(clash.progress);
    liveProgress[_uid] = _mySteps;
    final ranking = <(String uid, int steps)>[];
    for (final uid in clash.participants) {
      if (!clash.forfeited.contains(uid)) {
        ranking.add((uid, liveProgress[uid] ?? 0));
      }
    }
    ranking.sort((a, b) => b.$2.compareTo(a.$2));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          // ── Timer + Goal ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '${_fmt(remaining.inMinutes)}:${_fmt(remaining.inSeconds % 60)}',
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Goal: ${_fmtSteps(goal)} steps',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Participant ranking ──
          ...List.generate(ranking.length, (i) {
            final (uid, steps) = ranking[i];
            final isMe = uid == _uid;
            final name = isMe ? 'YOU' : clash.nameFor(uid);
            final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
            final medal = i == 0
                ? '🥇'
                : i == 1
                    ? '🥈'
                    : i == 2
                        ? '🥉'
                        : '  ';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMe
                      ? accent.withValues(alpha: 0.6)
                      : HunterTheme.border,
                  width: isMe ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isMe ? accent : HunterTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '$steps / ${_fmtSteps(goal)}',
                        style: TextStyle(
                          color: HunterTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: HunterTheme.border,
                      valueColor: AlwaysStoppedAnimation(
                        isMe ? accent : HunterTheme.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── Forfeited players ──
          if (clash.forfeited.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...clash.forfeited.map((uid) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('🏳️', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        '${clash.nameFor(uid)} forfeited',
                        style: TextStyle(
                          color: HunterTheme.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 28),

          // ── Give Up button ──
          if (!clash.isForfeited(_uid))
            GestureDetector(
              onTap: _forfeiting ? null : _forfeit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: HunterTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: HunterTheme.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🏳️', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'GIVE UP',
                      style: TextStyle(
                        color: HunterTheme.danger,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(int n) => n.toString().padLeft(2, '0');
  String _fmtSteps(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)},000' : '$n';
}
