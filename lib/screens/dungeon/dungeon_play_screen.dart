import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_cleared_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_rewards.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_session_manager.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/screens/dungeon/widgets/monster_card.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/rank_celebration_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';
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

  /// This gate's rank content template (Phase 6) — monster pool, boss
  /// identity and the rank-scaled clear reward all come from here.
  late final DungeonTemplate _template =
      DungeonTemplates.forGate(widget.spec.letter) ?? DungeonTemplates.eRank;

  /// Presentation gates — the cleared dialog fires at most once per
  /// entry and the boss-room transition at most once per entry.
  bool _clearedShown = false;
  bool _bossAnnounced = false;

  /// First-notification flag — restored state (already-unlocked boss,
  /// already-cleared dungeon) seeds the gates above instead of replaying
  /// their dialogs.
  bool _seenInitial = false;

  /// ONE banner for the whole quest screen — the SAME shared lifecycle
  /// the Missions screen uses ([MissionBannerAd]): one retry on failure,
  /// dispose/reload on tier change, created once in [initState] and never
  /// reloaded by timer ticks. [MissionBannerAd.allTiers] opts out of the
  /// normal Basic-only rule: the ACTIVE dungeon quest banner is part of
  /// the quest experience and shows for Basic, Pro AND Max alike
  /// (presentation only — it never affects gameplay).
  late final MissionBannerAd _banner = MissionBannerAd(
    allTiers: true,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onSessionChanged);
    _banner.load();
    // Defensive restore: the normal path is ENTER DUNGEON on the gate
    // screen, but a direct open (app restart, deep navigation) restores
    // today's session here — same idempotent code path, no regeneration.
    _manager.openSession(letter: widget.spec.letter);
  }

  @override
  void dispose() {
    _manager.removeListener(_onSessionChanged);
    _banner.dispose();
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
      _showClearedReveal();
    }
  }

  /// ⚠️ The Boss Room has opened — fired automatically the moment the
  /// final monster is defeated.
  void _showBossRoomTransition() {
    showPremiumDialog(
      context: context,
      builder:
          (ctx) => PremiumDialogCard(
            icon: Icons.warning_amber_rounded,
            accent: HunterTheme.gold,
            title: 'THE BOSS ROOM HAS OPENED',
            message:
                'Every monster has fallen.\n'
                '${_template.boss.emoji} ${_template.boss.name} '
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

  /// DUNGEON CLEARED — Phase 7 reveal. The dedicated clear presentation
  /// runs through the GLOBAL milestone queue, so it never stacks with the
  /// boss-room transition or with the level-up/rank-up celebrations that
  /// the claim can trigger afterwards.
  ///
  /// Sequence: boss defeated → short transition → DUNGEON CLEARED
  /// (name / rank / boss DEFEATED) → reward reveal (+XP, +Coins) →
  /// RETURN.
  void _showClearedReveal() {
    MilestoneService.enqueue(context, _runClearedSequence);
  }

  /// Shows the cleared reveal once, then celebrates any level-up/rank-up
  /// the claim triggered — through the SAME shared systems the Missions
  /// screen uses after awardXp. The grant itself happens INSIDE the
  /// dialog via [DungeonSessionManager.claimClearReward] (exactly once —
  /// the manager + daily store enforce it; reopening an already-claimed
  /// dungeon runs the dialog in review mode and re-presents the
  /// persisted record without granting anything).
  Future<void> _runClearedSequence(BuildContext ctx) async {
    final manager = DungeonSessionManager.instance;
    final oldLevel = HunterRepository.instance.getCached()?.level ?? 1;

    DungeonClaimResult? claim;
    await showDungeonClearedDialog(
      ctx,
      spec: widget.spec,
      template: _template,
      review: manager.rewardClaimed,
      knownReward: manager.clearReward,
      onClaim: () async {
        claim = await manager.claimClearReward();
        return claim?.reward;
      },
    );
    if (!mounted) return;
    final result = claim;
    if (result == null) return;

    // Celebrations queue AFTER the reveal closes (same queue).
    if (result.xpAward.leveledUp) {
      MilestoneService.celebrateLevelUps(
        context,
        oldLevel,
        result.xpAward.level,
      );
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        RankCelebrationService.instance.celebrateIfRankUp(
          context,
          uid: uid,
          oldLevel: oldLevel,
          newLevel: result.xpAward.level,
        );
      }
    }
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
        child:
            !_manager.hasSession
                ? _buildLoading()
                : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _buildHeader(rank),
                    if (_manager.isCleared) ...[
                      const SizedBox(height: 18),
                      _buildClearedBanner(),
                    ],
                    const SizedBox(height: 22),
                    _sectionLabel('MONSTERS'),
                    const SizedBox(height: 12),
                    for (final monster in _manager.monsters) ...[
                      MonsterCard(
                        objective: monster,
                        template: _template,
                        // START QUEST → the session manager stamps and
                        // persists the timer; no AI, no local countdown
                        // state here.
                        onStartQuest: () => _manager.startQuest(monster),
                        // SEQUENTIAL progression — only the manager's
                        // [nextStartableQuest] offers START QUEST; every
                        // other pending quest renders locked.
                        locked:
                            !identical(monster, _manager.nextStartableQuest),
                      ),
                      const SizedBox(height: 12),
                      // ACTIVE QUEST banner — shown DIRECTLY under the
                      // active quest card, for EVERY membership tier
                      // (Basic/Pro/Max). ONE instance, mounted once, never
                      // covering progress/timer/buttons; it simply leaves
                      // when the quest clears.
                      if (monster == _activeQuestMonster &&
                          _banner.ready &&
                          _banner.ad != null) ...[
                        Center(
                          child: SizedBox(
                            key: const ValueKey('dungeon_quest_banner'),
                            width: _banner.ad!.size.width.toDouble(),
                            height: _banner.ad!.size.height.toDouble(),
                            child: AdWidget(ad: _banner.ad!),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    const SizedBox(height: 8),
                    _buildBossRoom(),
                  ],
                ),
      ),
    );
  }

  /// Already-completed state — the dungeon stays cleared for the rest of
  /// the day and is NEVER regenerated. Claimed → "Completed Today /
  /// Rewards Already Claimed" with RETURN (the reveal re-presents the
  /// persisted record in review mode — nothing is granted again).
  /// Unclaimed (CLAIM LATER or an app restart before claiming) → the
  /// banner re-opens the reveal, whose claim path grants EXACTLY once.
  /// Pro/Max only ever change theming, so the reward is identical for
  /// every tier.
  Widget _buildClearedBanner() {
    final claimed = _manager.rewardClaimed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HunterTheme.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HunterTheme.gold.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          Text(
            '✔ DUNGEON CLEARED',
            style: TextStyle(
              color: HunterTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completed Today',
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            claimed
                ? 'Rewards Already Claimed'
                : 'Your reward is waiting — claim it now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (claimed)
            MembershipButton.secondary(
              'RETURN',
              onTap: () => Navigator.of(context).pop(),
              expanded: true,
              icon: Icons.flag_rounded,
            )
          else
            MembershipButton.primary(
              'CLAIM REWARD',
              onTap: _showClearedReveal,
              expanded: true,
              icon: Icons.card_giftcard_rounded,
            ),
        ],
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
            Icon(Icons.lock_rounded, color: HunterTheme.textTertiary, size: 26),
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
              style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return EntranceFadeSlide(
      child: Column(
        children: [
          BossCard(objective: boss, template: _template),
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

  /// The FIRST monster whose quest is currently running (started, not
  /// cleared yet) — the one active-quest card the banner attaches to.
  /// Only one card hosts the banner so the single [AdWidget] instance is
  /// never mounted twice; extra simultaneous quests simply queue without
  /// a second banner.
  DungeonObjective? get _activeQuestMonster {
    for (final monster in _manager.monsters) {
      if (monster.questStartedAt != null && !monster.questCleared) {
        return monster;
      }
    }
    return null;
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
