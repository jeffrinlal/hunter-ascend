import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_monsters.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_session_manager.dart';
import 'package:hunter_ascend/screens/dungeon/widgets/monster_card.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:hunter_ascend/widgets/premium_dialog.dart';

/// Dungeon play screen — a pure VIEWER of the persistent dungeon session.
///
/// Objectives are presented as MONSTERS: every generated objective becomes
/// one enemy whose HP drains as the underlying fitness progress climbs.
/// All business logic lives in [DungeonSessionManager]: it owns the active
/// dungeon, objective snapshots, the tracker and completion state —
/// independent of this widget's lifecycle. This screen only READS the
/// session and reacts to its notifications:
///
/// * monster HP bars, the boss room and the cleared dialog come straight
///   from the manager — no tracking, no persistence, no generation here;
/// * leaving the screen, navigating home or restarting the app changes
///   nothing: the session keeps running and progress keeps accumulating
///   against the snapshots captured when the dungeon started.
///
/// When every monster is defeated the Boss Room opens; the dungeon clears
/// ONLY once the boss reaches 100% (the manager detects it — the screen
/// merely shows the dialogs).
class DungeonPlayScreen extends StatefulWidget {
  const DungeonPlayScreen({super.key, required this.spec});

  final DungeonGateSpec spec;

  @override
  State<DungeonPlayScreen> createState() => _DungeonPlayScreenState();
}

class _DungeonPlayScreenState extends State<DungeonPlayScreen> {
  final DungeonSessionManager _manager = DungeonSessionManager.instance;

  /// Presentation gates — the cleared dialog fires at most once per
  /// entry and the boss-room transition at most once per entry.
  bool _clearedShown = false;
  bool _bossAnnounced = false;

  /// First-notification flag — restored state (already-unlocked boss,
  /// already-cleared dungeon) seeds the gates above instead of replaying
  /// their dialogs.
  bool _seenInitial = false;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onSessionChanged);
    // Defensive restore: the normal path is ENTER DUNGEON on the gate
    // screen, but a direct open (app restart, deep navigation) restores
    // today's session here — same idempotent code path, no regeneration.
    _manager.openSession(letter: widget.spec.letter);
  }

  @override
  void dispose() {
    _manager.removeListener(_onSessionChanged);
    super.dispose();
  }

  // ── Session reactions (presentation only) ────────────────────────────

  void _onSessionChanged() {
    if (!mounted) return;
    final session = _manager.session;
    if (session == null) return;

    if (!_seenInitial) {
      _seenInitial = true;
      // Restoring an in-flight/cleared session never replays dialogs.
      _bossAnnounced = _manager.bossUnlocked;
      _clearedShown = _manager.isCleared;
    }
    setState(() {});

    if (_manager.bossUnlocked && !_bossAnnounced) {
      _bossAnnounced = true;
      _showBossRoomTransition();
    }

    if (_manager.isCleared && !_clearedShown) {
      _clearedShown = true;
      _showClearedDialog();
    }
  }

  /// ⚠️ The Boss Room has opened — fired automatically the moment the
  /// final monster is defeated.
  void _showBossRoomTransition() {
    showPremiumDialog(
      context: context,
      builder: (ctx) => PremiumDialogCard(
        icon: Icons.warning_amber_rounded,
        accent: HunterTheme.gold,
        title: 'THE BOSS ROOM HAS OPENED',
        message: 'Every monster has fallen.\n'
            '${DungeonMonsters.boss.emoji} ${DungeonMonsters.boss.name} '
            'awaits — defeat it to clear the dungeon.',
        actions: [
          PremiumDialogButton.primary(
            'ENTER BOSS ROOM',
            icon: Icons.play_arrow_rounded,
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  /// DUNGEON CLEARED — rewards stay Phase 4 placeholders (display only,
  /// nothing awarded or stored yet). RETURN pops back to the Dungeon
  /// Lobby (the gate screen replaced itself when entering, so one pop
  /// lands there).
  void _showClearedDialog() {
    showPremiumDialog(
      context: context,
      builder: (ctx) => PremiumDialogCard(
        icon: Icons.emoji_events_rounded,
        accent: HunterTheme.gold,
        title: 'DUNGEON CLEARED',
        message: '${widget.spec.name} conquered!\n\n'
            '+${DungeonGeneration.placeholderXp} XP\n'
            '+${DungeonGeneration.placeholderCoins} Coins',
        actions: [
          PremiumDialogButton.primary(
            'RETURN',
            icon: Icons.arrow_back_rounded,
            onTap: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
        _manager,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final rank = dungeonGateRank(widget.spec);

    return MembershipScaffold(
      appBar: const MembershipAppBar(),
      body: SafeArea(
        child: !_manager.hasSession
            ? _buildLoading()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _buildHeader(rank),
                  const SizedBox(height: 22),
                  _sectionLabel('MONSTERS'),
                  const SizedBox(height: 12),
                  for (final monster in _manager.monsters) ...[
                    MonsterCard(objective: monster),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _buildBossRoom(),
                ],
              ),
      ),
    );
  }

  /// The boss room — locked hint until every monster is defeated, then
  /// the transitioned [BossCard] (the boss HP drains exactly like the
  /// monsters' and the dungeon clears at 100%).
  Widget _buildBossRoom() {
    final boss = _manager.boss;
    if (boss == null) return const SizedBox.shrink();

    if (!_manager.bossUnlocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HunterTheme.textTertiary.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_rounded,
                color: HunterTheme.textTertiary, size: 26),
            const SizedBox(height: 8),
            Text(
              'THE BOSS ROOM IS SEALED',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Defeat every monster to open it.',
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    return EntranceFadeSlide(
      child: Column(
        children: [
          BossCard(objective: boss),
          const SizedBox(height: 14),
          Text(
            'Defeat the boss to clear the dungeon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: HunterTheme.textSecondary,
        fontSize: 11.5,
        letterSpacing: 2.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: MembershipTheme.current.accent),
          const SizedBox(height: 18),
          Text(
            'The Association is scouting the gate…',
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(HunterRank rank) {
    final story = _manager.story;
    return Column(
      children: [
        Text(
          widget.spec.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HeaderChip(label: rank.label.toUpperCase(), color: rank.color),
            const SizedBox(width: 8),
            _HeaderChip(
              label: '${widget.spec.difficulty.toUpperCase()} DUNGEON',
              color: HunterTheme.textSecondary,
            ),
          ],
        ),
        if (story.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            story,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small header chip (rank / difficulty) for the play screen.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
