import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/battle/widgets/battle_mode_card.dart';
import 'package:hunter_ascend/screens/battle/rival_search_screen.dart';
import 'package:hunter_ascend/screens/duel/create_duel_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_request_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_lobby_screen.dart';
import 'package:hunter_ascend/screens/profile/public_hunter_profile_screen.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDuelState();
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
    if (activeIndex.value == tabIndex) _loadDuelState();
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
    await _loadDuelState();
  }

  /// ENTER on the Dungeons card → the Dungeon Lobby (Gate Selection
  /// Center). Unchanged.
  void _openDungeons(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DungeonLobbyScreen()),
    );
  }

  // ── Rivals ─────────────────────────────────────────────────────────────

  /// Reads the locally persisted rival UID and routes accordingly.
  ///
  /// * No rival stored → push [RivalSearchScreen].
  /// * Rival stored    → push [PublicHunterProfileScreen] in rival mode.
  ///
  /// Cost: one synchronous SharedPreferences read. No Firestore operations
  /// happen here — the profile screen opens the existing live snapshot only
  /// when it is actually displayed.
  Future<void> _openRivals() async {
    final prefs = await SharedPreferences.getInstance();
    final rivalUid = prefs.getString('rival_uid');
    if (!mounted) return;
    if (rivalUid == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RivalSearchScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicHunterProfileScreen(
            hunterUid: rivalUid,
            isRivalMode: true,
          ),
        ),
      );
    }
  }

  Widget _buildRivalsCard() {
    return BattleModeCard(
      emoji: '👤',
      title: 'RIVALS',
      description: 'Track a rival Hunter, compare stats and issue a direct challenge.',
      tag: 'Social',
      onEnter: _openRivals,
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
