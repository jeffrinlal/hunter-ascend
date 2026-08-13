import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/battle/widgets/battle_mode_card.dart';
import 'package:hunter_ascend/screens/battle/rival_request_screen.dart';
import 'package:hunter_ascend/screens/battle/rival_search_screen.dart';
import 'package:hunter_ascend/screens/battle/rivalry_comparison_screen.dart';
import 'package:hunter_ascend/screens/battle/rivalry_result_screen.dart';
import 'package:hunter_ascend/screens/battle/step_clash_create_screen.dart';
import 'package:hunter_ascend/screens/battle/step_clash_screen.dart';
import 'package:hunter_ascend/screens/battle/step_clash_result_screen.dart';
import 'package:hunter_ascend/screens/duel/create_duel_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_request_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_lobby_screen.dart';
import 'package:hunter_ascend/services/rivalry_service.dart';
import 'package:hunter_ascend/services/step_clash_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// The duel state the Fitness Duels card currently represents.
///
/// This is NOT a new state system — it is exactly the state machine
/// `MainShell._openDuels()` already evaluated before this change (active duel
/// → unviewed completed result → pending incoming request → nothing). The only
/// difference is that the state is now RENDERED on the hub's card instead of
/// being used to silently navigate away from the hub.
enum _DuelCardState {
  /// Another hunter has challenged this user and the request is pending.
  incomingRequest,

  /// This user is currently in an active duel.
  activeDuel,

  /// A duel finished but this user has not seen the result yet.
  unviewedResult,

  /// Nothing in flight — the normal "start a duel" entry point.
  none,
}

/// Battle Hub — the entry point for all battle modes, hosted behind the
/// Battles bottom-nav tab.
///
/// ── Navigation contract ──
/// The Battles bottom-nav item ALWAYS opens this hub. It never jumps straight
/// to a duel, a duel request or a dungeon. Before Dungeons existed, "Battles"
/// effectively meant "Duels", so `MainShell._openDuels()` queried Firestore on
/// every tap and pushed `DuelScreen` / `DuelRequestScreen` over the hub —
/// which meant a user with an active duel could never reach the hub at all,
/// and therefore could never reach Dungeons. Battles is now a hub of several
/// modes, so that special-casing has been removed; the hub itself surfaces the
/// duel state and decides what to open.
///
/// * FITNESS DUELS (PvP) → state-aware, see [_DuelCardState].
/// * DUNGEONS (PvE)      → pushes [DungeonLobbyScreen], unchanged.
/// * Weekly Raids / Guild Battles / World Boss → disabled teaser cards.
class BattleHubScreen extends StatefulWidget {
  const BattleHubScreen({
    super.key,
    this.duelRequestStream,
    this.rivalRequestStream,
    this.activeIndex,
    this.tabIndex,
  });

  /// The EXISTING duel-request snapshot stream already owned by `MainShell`
  /// for the nav badge (`duel_requests where toUid == uid && status ==
  /// 'pending' limit 1`). It is passed in and shared rather than re-created,
  /// so the incoming-challenge state costs **no additional Firestore
  /// listener and no additional read** — the badge and this card are driven
  /// by one and the same subscription.
  final Stream<QuerySnapshot>? duelRequestStream;

  /// The EXISTING rival-request snapshot stream already owned by `MainShell`
  /// for the nav badge (`rivalries where toUid == uid && status == 'pending'
  /// limit 1`). Shared for the same reason as [duelRequestStream]: the Rivals
  /// card's incoming-request state costs **no additional Firestore listener
  /// and no additional read**, and the card can never disagree with the dot.
  final Stream<QuerySnapshot<Map<String, dynamic>>>? rivalRequestStream;

  /// Bottom-nav active tab index + this screen's own index. Used only to know
  /// when the hub becomes visible so the active-duel state can be re-read
  /// (IndexedStack keeps this State alive, so `initState` alone would go
  /// stale). Same mechanism the Leaderboard tab already uses.
  final ValueListenable<int>? activeIndex;
  final int? tabIndex;

  @override
  State<BattleHubScreen> createState() => _BattleHubScreenState();
}

class _BattleHubScreenState extends State<BattleHubScreen> {
  /// Resolved active / unviewed-result duel, or null when there is none.
  String? _duelId;

  /// True when [_duelId] refers to a finished duel whose result this user has
  /// not viewed yet (as opposed to a live one).
  bool _isUnviewedResult = false;

  /// Guards against overlapping reads (e.g. rapid tab switching).
  bool _loadingDuelState = false;

  /// The single rivalry that currently concerns this user — pending in either
  /// direction, active, or completed and not yet finished with. Null when the
  /// user is free to start a new one.
  RivalryData? _rivalry;

  bool _loadingRivalryState = false;

  /// Active or waiting Step Clash involving this user.
  StepClashData? _stepClash;
  bool _loadingStepClashState = false;

  @override
  void initState() {
    super.initState();
    _loadHubState();
    widget.activeIndex?.addListener(_onActiveIndexChanged);
  }

  @override
  void dispose() {
    widget.activeIndex?.removeListener(_onActiveIndexChanged);
    super.dispose();
  }

  /// Re-reads the duel state whenever the Battles tab becomes visible, so a
  /// duel accepted/finished elsewhere is reflected on return.
  void _onActiveIndexChanged() {
    final activeIndex = widget.activeIndex;
    final tabIndex = widget.tabIndex;
    if (activeIndex == null || tabIndex == null) return;
    if (activeIndex.value == tabIndex) _loadHubState();
  }

  /// Re-reads both mode states in parallel.
  Future<void> _loadHubState() async {
    await Future.wait<void>(<Future<void>>[
      _loadDuelState(),
      _loadRivalryState(),
      _loadStepClashState(),
    ]);
  }

  /// Resolves the user's current rivalry with ONE index-free query:
  /// `rivalries where unsettledFor array-contains uid limit 1`.
  ///
  /// A single bare `array-contains` needs no composite index, and because each
  /// participant removes their own uid once they are done, the query returns
  /// exactly the document that still matters to this user and never has to sift
  /// through old completed rivalries.
  ///
  /// Like the duel state, this is a read on entry rather than a live listener:
  /// a rivalry only changes when this user sends, accepts, declines or settles
  /// one, and every one of those paths routes back through this screen.
  Future<void> _loadRivalryState() async {
    if (_loadingRivalryState) return;
    _loadingRivalryState = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _loadingRivalryState = false;
      return;
    }
    try {
      final rivalry =
          await RivalryService.instance.fetchCurrentRivalry(user.uid);
      if (!mounted) return;
      setState(() => _rivalry = rivalry);
    } catch (e) {
      debugPrint('BattleHub._loadRivalryState: $e');
    } finally {
      _loadingRivalryState = false;
    }
  }

  /// Resolves the user's current Step Clash state.
  Future<void> _loadStepClashState() async {
    if (_loadingStepClashState) return;
    _loadingStepClashState = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _loadingStepClashState = false;
      return;
    }
    try {
      final clash =
          await StepClashService.instance.fetchActive(user.uid);
      if (!mounted) return;
      setState(() => _stepClash = clash);
    } catch (e) {
      debugPrint('BattleHub._loadStepClashState: $e');
    } finally {
      _loadingStepClashState = false;
    }
  }

  // ── Duel state resolution ──────────────────────────────────────────────
  //
  // These are the SAME two queries `MainShell._openDuels()` already ran on
  // every Battles tap — relocated, not added. The third query it ran (for
  // pending duel requests) is gone entirely: that state now comes from the
  // existing badge listener passed in via `widget.duelRequestStream`. So this
  // change performs strictly FEWER Firestore operations per Battles entry
  // than before, and adds no listener.
  //
  // A live listener is deliberately NOT used here: an active duel changes
  // only when this user accepts/creates/finishes one, all of which route back
  // through this screen, so a read on entry is sufficient and far cheaper
  // than a permanent subscription.
  Future<void> _loadDuelState() async {
    if (_loadingDuelState) return;
    _loadingDuelState = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _loadingDuelState = false;
      return;
    }
    try {
      String? duelId;
      bool unviewedResult = false;

      // 1) A currently active duel wins.
      final active = await FirebaseFirestore.instance
          .collection('duels')
          .where('participants', arrayContains: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (active.docs.isNotEmpty) {
        duelId = active.docs.first.id;
      } else {
        // 2) Otherwise a completed duel whose result this user hasn't seen.
        final completed = await FirebaseFirestore.instance
            .collection('duels')
            .where('participants', arrayContains: user.uid)
            .where('status', isEqualTo: 'completed')
            .limit(10)
            .get();

        for (final doc in completed.docs) {
          final data = doc.data();
          final isPlayer1 = data['player1'] == user.uid;
          final shouldShowResult = isPlayer1
              ? data['player1ViewedResult'] == false
              : data['player2ViewedResult'] == false;
          if (shouldShowResult) {
            duelId = doc.id;
            unviewedResult = true;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _duelId = duelId;
        _isUnviewedResult = unviewedResult;
      });
    } catch (e) {
      debugPrint('BattleHub._loadDuelState: $e');
    } finally {
      _loadingDuelState = false;
    }
  }

  /// State priority: incoming request → active duel → unviewed result → none.
  _DuelCardState _resolveState({required bool hasPendingRequest}) {
    if (hasPendingRequest) return _DuelCardState.incomingRequest;
    if (_duelId != null) {
      return _isUnviewedResult
          ? _DuelCardState.unviewedResult
          : _DuelCardState.activeDuel;
    }
    return _DuelCardState.none;
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const SizedBox(height: 6),
            _buildHero(),
            const SizedBox(height: 26),

            // ── Active modes ─────────────────────────────────────────────
            _buildFitnessDuelsCard(),
            const SizedBox(height: 14),
            BattleModeCard(
              emoji: '🕳',
              title: 'DUNGEONS',
              description:
                  'Complete PvE fitness adventures and conquer dangerous gates.',
              tag: 'PvE',
              onEnter: () => _openDungeons(context),
            ),
            const SizedBox(height: 14),
            _buildRivalsCard(),
            const SizedBox(height: 14),
            _buildStepClashCard(),

            // ── Upcoming modes (Phase 1: presentation only) ─────────────
            const SizedBox(height: 32),
            _buildSectionHeader('COMING SOON'),
            const SizedBox(height: 12),
            const BattleHubTeaserCard(emoji: '👹', title: 'Weekly Raids'),
            const SizedBox(height: 10),
            const BattleHubTeaserCard(emoji: '🛡', title: 'Guild Battles'),
            const SizedBox(height: 10),
            const BattleHubTeaserCard(emoji: '🌍', title: 'World Boss'),
          ],
        ),
      ),
    );
  }

  /// The Fitness Duels card, reflecting the user's current duel state.
  ///
  /// Wrapped in a `StreamBuilder` on the SHARED duel-request stream so an
  /// incoming challenge appears live — the same subscription that drives the
  /// nav badge, so the two can never disagree and no extra listener exists.
  Widget _buildFitnessDuelsCard() {
    final stream = widget.duelRequestStream;
    if (stream == null) {
      // Standalone construction (e.g. tests) — no request stream available,
      // so fall back to the read-driven states only.
      return _fitnessDuelsCardFor(_resolveState(hasPendingRequest: false));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final hasPending = snap.hasData && snap.data!.docs.isNotEmpty;
        return _fitnessDuelsCardFor(
          _resolveState(hasPendingRequest: hasPending),
        );
      },
    );
  }

  Widget _fitnessDuelsCardFor(_DuelCardState state) {
    switch (state) {
      case _DuelCardState.incomingRequest:
        return BattleModeCard(
          emoji: '⚔️',
          title: 'INCOMING CHALLENGE',
          description:
              'A hunter has challenged you to a duel. Accept or decline.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(const DuelRequestScreen()),
        );
      case _DuelCardState.activeDuel:
        return BattleModeCard(
          emoji: '⚔️',
          title: 'ACTIVE BATTLE',
          description: 'You are in an active duel. Continue your battle.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(DuelScreen(duelId: _duelId!)),
        );
      case _DuelCardState.unviewedResult:
        return BattleModeCard(
          emoji: '⚔️',
          title: 'BATTLE RESULT',
          description: 'Your duel has finished. View the result.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(DuelScreen(duelId: _duelId!)),
        );
      case _DuelCardState.none:
        return BattleModeCard(
          emoji: '⚔️',
          title: 'FITNESS DUELS',
          description:
              'Challenge real hunters in competitive fitness battles.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(const CreateDuelScreen(pushed: true)),
        );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// Pushes a duel destination and re-reads the duel state on return, so the
  /// card reflects what just happened (accepted a request, viewed a result,
  /// created a duel) without the user having to leave and re-enter the tab.
  Future<void> _openAndRefresh(Widget destination) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
    if (!mounted) return;
    await _loadHubState();
  }

  /// ENTER on the Dungeons card → the Dungeon Lobby (Gate Selection
  /// Center). Unchanged.
  void _openDungeons(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DungeonLobbyScreen()),
    );
  }

  // ── Step Clash ───────────────────────────────────────────────────────────

  Widget _buildStepClashCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Check if the user has a pending invite (they're in pendingInvitees).
    final hasPendingInvite = _stepClash != null &&
        _stepClash!.pendingInvitees.contains(uid);
    final state =
        StepClashService.cardStateFor(_stepClash, uid,
            hasIncomingInvite: hasPendingInvite);

    switch (state) {
      case StepClashCardState.incoming:
        return BattleModeCard(
          emoji: '👣',
          title: 'INCOMING STEP CLASH',
          description:
              'A Hunter has challenged you to a step competition. Accept or decline.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(
            StepClashScreen(battleId: _stepClash!.id),
          ),
        );
      case StepClashCardState.waiting:
        return BattleModeCard(
          emoji: '👣',
          title: 'STEP CLASH WAITING',
          description: 'Waiting for all players to accept.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(
            StepClashScreen(battleId: _stepClash!.id),
          ),
        );
      case StepClashCardState.active:
        return BattleModeCard(
          emoji: '👣',
          title: 'ACTIVE STEP CLASH',
          description: 'Your step battle is live. Keep moving!',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(
            StepClashScreen(battleId: _stepClash!.id),
          ),
        );
      case StepClashCardState.resultAvailable:
        return BattleModeCard(
          emoji: '👣',
          title: 'STEP CLASH RESULT',
          description: 'Your step battle has ended. View the result.',
          tag: 'PvP',
          onEnter: () => _openAndRefresh(
            StepClashResultScreen(battleId: _stepClash!.id),
          ),
        );
      case StepClashCardState.none:
        return BattleModeCard(
          emoji: '👣',
          title: 'STEP CLASH',
          description:
              'Challenge Hunters to competitive step battles. First to the goal wins.',
          tag: 'PvP',
          onEnter: () =>
              _openAndRefresh(const StepClashCreateScreen()),
        );
    }
  }

  // ── Rivals ─────────────────────────────────────────────────────────────
  //
  // A Rivalry is a time-limited competitive relationship between TWO hunters,
  // so it is persisted remotely in `rivalries/{pairId}` and never locally. The
  // previous SharedPreferences `rival_uid` approach is gone entirely: a locally
  // chosen rival cannot be agreed on by both users, cannot produce a single
  // shared result, and cannot survive a reinstall or a device change.

  /// The Rivals card, reflecting this user's current rivalry state.
  ///
  /// Wrapped in a `StreamBuilder` on the SHARED rival-request stream so an
  /// incoming request appears live — the same subscription that drives the nav
  /// badge, so the two can never disagree and no extra listener exists. The
  /// stream document is preferred when present because it is live; everything
  /// else comes from the state read on entry.
  Widget _buildRivalsCard() {
    final stream = widget.rivalRequestStream;
    if (stream == null) {
      // Standalone construction (e.g. tests) — no request stream available, so
      // fall back to the read-driven state only.
      return _rivalsCardFor(_rivalry);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final incoming = RivalryService.liveIncomingRequest(snap.data);
        return _rivalsCardFor(incoming ?? _rivalry);
      },
    );
  }

  Widget _rivalsCardFor(RivalryData? rivalry) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final state = RivalryService.cardStateFor(rivalry, uid);

    // `cardStateFor` already returns `none` for a null or non-participant
    // document, so this branch also promotes `rivalry` to non-null below.
    if (rivalry == null || state == RivalCardState.none) {
      return BattleModeCard(
        emoji: '👤',
        title: 'RIVALS',
        description:
            'Challenge a Hunter to a time-limited Rivalry and out-train them.',
        tag: 'Social',
        onEnter: () => _openAndRefresh(const RivalSearchScreen()),
      );
    }

    switch (state) {
      case RivalCardState.incomingRequest:
        return BattleModeCard(
          emoji: '🔥',
          title: 'INCOMING RIVAL REQUEST',
          description:
              '${rivalry.hunterNameFor(rivalry.fromUid)} wants to become your '
              'Rival for ${rivalry.durationDays} days. Accept or decline.',
          tag: 'Social',
          onEnter: () => _openAndRefresh(RivalRequestScreen(rivalry: rivalry)),
        );
      case RivalCardState.requestSent:
        return BattleModeCard(
          emoji: '🔥',
          title: 'RIVAL REQUEST SENT',
          description:
              'Waiting for ${rivalry.hunterNameFor(rivalry.toUid)} to accept '
              'your ${rivalry.durationDays}-day Rivalry.',
          tag: 'Social',
          onEnter: () => _openAndRefresh(RivalRequestScreen(rivalry: rivalry)),
        );
      case RivalCardState.active:
        return BattleModeCard(
          emoji: '🔥',
          title: 'ACTIVE RIVALRY',
          description:
              'Your Rivalry is running. Compare progress and stay ahead.',
          tag: 'Social',
          onEnter: () => _openAndRefresh(
            RivalryComparisonScreen(rivalryId: rivalry.id),
          ),
        );
      case RivalCardState.resultAvailable:
        return BattleModeCard(
          emoji: '🏆',
          title: 'RIVALRY RESULT',
          description: 'Your Rivalry has ended. View the result.',
          tag: 'Social',
          onEnter: () => _openAndRefresh(
            RivalryResultScreen(rivalryId: rivalry.id),
          ),
        );
      case RivalCardState.rivalLeft:
        return BattleModeCard(
          emoji: '👤',
          title: 'YOUR RIVAL LEFT',
          description:
              'This Hunter is no longer available. Close the Rivalry to find '
              'someone new.',
          tag: 'Social',
          onEnter: () => _openAndRefresh(
            RivalryResultScreen(rivalryId: rivalry.id),
          ),
        );
      case RivalCardState.none:
        // Unreachable: handled above. Kept so the switch stays exhaustive.
        return BattleModeCard(
          emoji: '👤',
          title: 'RIVALS',
          description:
              'Challenge a Hunter to a time-limited Rivalry and out-train them.',
          tag: 'Social',
          onEnter: () => _openAndRefresh(const RivalSearchScreen()),
        );
    }
  }

  // ── Presentation helpers ───────────────────────────────────────────────

  Widget _buildHero() {
    final tokens = MembershipTheme.current;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tokens.gradient,
              ).createShader(bounds),
              child: const Text(
                'BATTLE HUB',
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
          'Choose your battle.',
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: MembershipTheme.current.gradient,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 12,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
