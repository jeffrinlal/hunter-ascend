import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_daily_store.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gate_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/widgets/dungeon_gate_card.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/services/rewarded_ad_manager.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:hunter_ascend/widgets/premium_dialog.dart';

/// Dungeon Lobby — the Hunter Association's Gate Selection Center.
///
/// Six rank-keyed gate cards plus the player's current hunter rank
/// (resolved via the existing [RankService], never a second ranking
/// system). ENTER GATE opens the immersive [DungeonGateScreen] entry
/// experience.
///
/// Phase 5 — daily dungeons: gate status is layered on top of the rank
/// check via [DungeonDailyStore]. A gate cleared today shows CLEARED with
/// its ENTER button disabled; on the next calendar day the date comparison
/// resets it automatically (no timers, no extra reads).
///
/// Phase 6 — Force Open Gate: the single gate TWO ranks above the hunter
/// (capped at the top gate) can be temporarily stabilized with the app's
/// existing [RewardedAdManager]. The unlock is in-memory only and expires
/// the moment the hunter leaves or completes the dungeon — no permanent
/// unlocks, no persistence, no Firestore.
///
/// Designed so later phases plug in without redesign:
///
/// * Gate unlock logic lives in ONE helper ([_statusFor]) — rewarded-ad
///   openings, daily resets and progression checks replace its body only.
/// * Gate metadata is the shared declarative list ([kDungeonGates]) — new
///   gates mean a new row, nothing else.
/// * Card behavior is injected via `onEnter`, so gameplay screens slot in
///   behind the gates without touching presentation.
class DungeonLobbyScreen extends StatefulWidget {
  const DungeonLobbyScreen({super.key});

  @override
  State<DungeonLobbyScreen> createState() => _DungeonLobbyScreenState();
}

class _DungeonLobbyScreenState extends State<DungeonLobbyScreen>
    with WidgetsBindingObserver {
  /// Seconds shown in the gate-stabilization countdown once the rewarded
  /// ad finishes loading.
  static const int _kCountdownSeconds = 5;

  /// Daily state per gate letter — the "Cleared Today" layer on top of the
  /// rank-gate logic. Keyed exactly like [DungeonDailyStore].
  Map<String, DungeonDailyState> _daily = {};

  // ── Phase 6: Force Open Gate (existing rewarded-ad manager, reused) ───

  /// Rewarded ad manager — same usage pattern as the membership screen.
  late final RewardedAdManager _adManager;

  /// Gate letter temporarily stabilized for THIS dungeon session only.
  /// Cleared again as soon as the hunter returns from the dungeon.
  String? _stabilizedLetter;

  /// Gate letter the reward callback granted while the ad was on screen.
  String? _pendingStabilizeLetter;

  /// Countdown state: `-1` = ad not ready yet, `>0` = counting down,
  /// `0` = countdown done → the ENTER GATE button is live.
  int _countdown = -1;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Re-read on app resume so a midnight rollover while backgrounded
    // flips cleared gates back to AVAILABLE as soon as the user returns.
    WidgetsBinding.instance.addObserver(this);
    _loadDailyState();

    // Preload the rewarded ad so Force Open is ready as soon as possible
    // (loading/availability/retries all handled by the existing manager).
    _adManager = RewardedAdManager(
      onAdStatusChanged: _onAdStatusChanged,
    );
    _adManager.loadAd();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _adManager.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadDailyState();
  }

  Future<void> _loadDailyState() async {
    final daily = await DungeonDailyStore.loadAll();
    if (!mounted) return;
    setState(() => _daily = daily);
  }

  // ── Rewarded ad lifecycle (Force Open) ────────────────────────────────

  /// Ad status changed → rebuild; a freshly loaded ad starts the 5-second
  /// stabilization countdown, a consumed/failed ad resets it.
  void _onAdStatusChanged() {
    if (!mounted) return;
    setState(() {
      if (_adManager.isReady) {
        if (_countdown < 0) _startCountdown();
      } else {
        _cancelCountdown();
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _kCountdownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown -= 1;
        if (_countdown <= 0) {
          _countdown = 0;
          timer.cancel();
        }
      });
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdown = -1;
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
      appBar: const MembershipAppBar(),
      body: SafeArea(
        child: StreamBuilder<HunterData?>(
          // Same shared broadcast stream every screen uses — no new
          // Firestore listener is created here.
          stream: HunterRepository.instance.watch(),
          initialData: HunterRepository.instance.getCached(),
          builder: (context, snapshot) {
            final hunter = snapshot.data;
            if (hunter == null) {
              return Center(
                child: CircularProgressIndicator(
                  color: MembershipTheme.current.accent,
                ),
              );
            }
            return _buildLobby(context, hunter);
          },
        ),
      ),
    );
  }

  Widget _buildLobby(BuildContext context, HunterData hunter) {
    final playerRank = RankService.instance.rankForLevel(hunter.level);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _buildHero(),
        const SizedBox(height: 20),
        _buildRankBanner(playerRank),
        const SizedBox(height: 8),
        Text(
          _nextResetLabel(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        // Gate cards — status comes from [_statusFor] (rank check layered
        // with the daily "Cleared Today" state).
        for (final spec in kDungeonGates) ...[
          _buildGate(context, spec, playerRank),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  // ── Gate construction ──────────────────────────────────────────────────

  Widget _buildGate(
    BuildContext context,
    DungeonGateSpec spec,
    HunterRank playerRank,
  ) {
    final gate = dungeonGateRank(spec);
    final stabilized = _stabilizedLetter == spec.letter;

    // Phase 6: exactly one gate — two ranks above the hunter, capped at the
    // top gate — is the Force Open candidate (unless already stabilized).
    if (!stabilized && _forceOpenLetterFor(playerRank) == spec.letter) {
      return _buildForceOpenGate(context, spec, gate);
    }

    final clearedToday = _daily[spec.letter]?.completedToday ?? false;
    final status = _statusFor(gate, playerRank, clearedToday, stabilized);

    return DungeonGateCard(
      rank: gate,
      difficulty: 'DIFFICULTY: ${spec.difficulty.toUpperCase()}',
      description: spec.description,
      status: status,
      buttonLabel: _buttonLabel(status),
      lockReason: stabilized
          ? '🟡 Gate stabilized — this session only.'
          : _lockReason(gate, status),
      onEnter: status == DungeonGateStatus.available
          ? () => _enterGate(context, spec, stabilized: stabilized)
          : null,
    );
  }

  /// Phase 6 Force Open card. Button phases: `PREPARING GATE...` while the
  /// rewarded ad loads → `WATCH AD (n)` during the 5-second stabilization
  /// countdown → live `ENTER GATE` once the countdown completes.
  Widget _buildForceOpenGate(
    BuildContext context,
    DungeonGateSpec spec,
    HunterRank gate,
  ) {
    final adReady = _adManager.isReady;
    final canEnter = adReady && _countdown == 0;
    final label = !adReady
        ? 'PREPARING GATE...'
        : (_countdown > 0 ? 'WATCH AD ($_countdown)' : 'ENTER GATE');

    return DungeonGateCard(
      rank: gate,
      difficulty: 'DIFFICULTY: ${spec.difficulty.toUpperCase()}',
      description: spec.description,
      status: DungeonGateStatus.higherRank,
      buttonLabel: label,
      forceOpen: true,
      onEnter: canEnter ? () => _watchAdForGate(spec) : null,
    );
  }

  /// The gate this hunter may force-open: TWO ranks above their current
  /// rank, capped at the top gate (an A hunter force-opens S; an S hunter
  /// has nothing above). Returns null when no gate qualifies.
  String? _forceOpenLetterFor(HunterRank playerRank) {
    final index =
        kDungeonGates.indexWhere((g) => g.letter == playerRank.letter);
    if (index < 0) return null; // Past S rank — every gate is already free.
    if (index + 2 < kDungeonGates.length) {
      return kDungeonGates[index + 2].letter;
    }
    if (index + 1 < kDungeonGates.length) {
      return kDungeonGates[index + 1].letter;
    }
    return null;
  }

  /// Single choke point for gate unlock resolution: gates at or below the
  /// player's rank are free, a stabilized gate is temporarily free (Phase 6,
  /// session only), and a cleared gate stays closed until the daily reset
  /// (Phase 5). Later phases replace ONLY this body.
  DungeonGateStatus _statusFor(
    HunterRank gate,
    HunterRank playerRank,
    bool clearedToday,
    bool stabilized,
  ) {
    if (stabilized) return DungeonGateStatus.available;
    if (clearedToday) return DungeonGateStatus.clearedToday;
    if (gate.tier <= playerRank.tier) return DungeonGateStatus.available;
    return DungeonGateStatus.locked;
  }

  String _buttonLabel(DungeonGateStatus status) => switch (status) {
        DungeonGateStatus.available => 'ENTER GATE',
        // Spec: the ENTER button itself stays — it becomes untappable once
        // today's rewards are claimed.
        DungeonGateStatus.clearedToday => 'ENTER GATE',
        // Unused — force-open cards build their own dynamic label.
        DungeonGateStatus.higherRank => 'WATCH AD',
        DungeonGateStatus.locked => 'LOCKED',
      };

  String? _lockReason(HunterRank gate, DungeonGateStatus status) =>
      switch (status) {
        DungeonGateStatus.available => null,
        DungeonGateStatus.clearedToday =>
          '✅ CLEARED — Rewards Claimed • Resets Tomorrow',
        // Unused — force-open cards render the ⚠ FORCE OPEN notice instead.
        DungeonGateStatus.higherRank => null,
        DungeonGateStatus.locked => 'Reach ${gate.label} Hunter.',
      };

  /// Next daily reset countdown — same "in Xh Ym" format the missions
  /// screen uses for its daily reset.
  String _nextResetLabel() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    return 'Next reset in ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
  }

  /// ENTER GATE → the immersive gate entry screen. A [stabilized] (force-open)
  /// gate loses its access the moment the hunter returns — leaving or
  /// completing the dungeon ends the session unlock.
  void _enterGate(
    BuildContext context,
    DungeonGateSpec spec, {
    bool stabilized = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DungeonGateScreen(spec: spec),
      ),
    ).then((_) {
      if (stabilized && mounted) {
        setState(() => _stabilizedLetter = null);
      }
    });
  }

  // ── Force Open ad flow ─────────────────────────────────────────────────

  /// ENTER GATE on a force-open candidate → watch the rewarded ad through
  /// the existing manager. Only the reward callback unlocks the gate —
  /// closing the ad early grants nothing.
  void _watchAdForGate(DungeonGateSpec spec) {
    if (!_adManager.isReady || _countdown > 0) return;

    _adManager.showAd(
      onRewardEarned: () => _pendingStabilizeLetter = spec.letter,
      onAdDismissed: () {
        if (!mounted) return;
        setState(() {});
        final letter = _pendingStabilizeLetter;
        _pendingStabilizeLetter = null;
        if (letter == null) return; // Closed before the reward — no unlock.
        setState(() => _stabilizedLetter = letter);
        _showStabilizedDialog(spec);
      },
      onAdFailed: () {
        if (!mounted) return;
        _pendingStabilizeLetter = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not show rewarded ad. Please try again.'),
          ),
        );
      },
    );
    setState(() {});
  }

  /// "Gate Stabilized — Enter now." confirmation before entering the
  /// temporarily unlocked gate.
  void _showStabilizedDialog(DungeonGateSpec spec) {
    showPremiumDialog(
      context: context,
      builder: (ctx) => PremiumDialogCard(
        icon: Icons.verified_user_rounded,
        accent: HunterTheme.gold,
        title: 'GATE STABILIZED',
        message: 'The Hunter Association has temporarily stabilized '
            '${spec.name}.\n\nEnter now — access lasts for this dungeon '
            'session only.',
        actions: [
          PremiumDialogButton.primary('ENTER NOW', onTap: () {
            Navigator.of(ctx).pop();
            if (mounted) _enterGate(context, spec, stabilized: true);
          }),
        ],
      ),
    );
  }

  // ── Presentation helpers ───────────────────────────────────────────────

  Widget _buildHero() {
    final tokens = MembershipTheme.current;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕳', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tokens.gradient,
              ).createShader(bounds),
              child: const Text(
                'DUNGEONS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a gate to enter.',
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildRankBanner(HunterRank playerRank) {
    return MembershipSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'CURRENT HUNTER RANK',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            playerRank.label,
            style: TextStyle(
              color: playerRank.color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
