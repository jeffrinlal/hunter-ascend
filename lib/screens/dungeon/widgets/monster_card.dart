import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_monsters.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';

/// One dungeon monster — a generated objective presented as an enemy whose
/// HP drains as the underlying fitness progress climbs. Each monster is a
/// QUEST: the hunter presses START QUEST to run its AI-provided timer, and
/// the monster is defeated (💥 QUEST COMPLETE) only when BOTH requirements
/// hold — the fitness objective reached AND the countdown finished.
///
/// The card only DISPLAYS structured data: the monster name comes from the
/// objective's app-controlled [DungeonObjective.monster] (sanitized onto
/// the [DungeonTemplate] pool at generation, falling back to
/// [DungeonMonsters] for legacy rows), progress/HP from
/// [DungeonObjective.fraction] and every quest state from
/// [DungeonObjective.questState]. It never tracks and never interprets
/// titles — every objective type is auto-tracked by `DungeonTracker`, and
/// the countdown is always derived from the persisted START QUEST
/// timestamp, so rebuilds and navigation never restart it.
class MonsterCard extends StatelessWidget {
  const MonsterCard({
    super.key,
    required this.objective,
    this.template,
    this.onStartQuest,
    this.locked = false,
  });

  final DungeonObjective objective;

  /// The run's rank template (Phase 6) — supplies pool/boss emojis.
  final DungeonTemplate? template;

  /// START QUEST press — handled by `DungeonSessionManager.startQuest`.
  final VoidCallback? onStartQuest;

  /// SEQUENTIAL progression: true while this quest must wait (another
  /// quest is active or an earlier one is still uncleared) — the card
  /// shows a locked state instead of START QUEST.
  final bool locked;

  @override
  Widget build(BuildContext context) => _MonsterCardFrame(
    objective: objective,
    isBoss: false,
    template: template,
    onStartQuest: onStartQuest,
    locked: locked,
  );
}

/// The dungeon boss — same HP mechanics as [MonsterCard] with boss styling
/// (gold HP, BOSS chip). Only built once every monster is defeated.
class BossCard extends StatelessWidget {
  const BossCard({super.key, required this.objective, this.template});

  final DungeonObjective objective;
  final DungeonTemplate? template;

  @override
  Widget build(BuildContext context) =>
      _MonsterCardFrame(objective: objective, isBoss: true, template: template);
}

/// Shared layout for monsters and the boss — one implementation, two
/// wrappers, no duplication. The quest block (START QUEST / countdown /
/// waiting-for-timer states) renders for monsters only; the boss keeps
/// its pure-progress completion.
class _MonsterCardFrame extends StatelessWidget {
  const _MonsterCardFrame({
    required this.objective,
    required this.isBoss,
    this.template,
    this.onStartQuest,
    this.locked = false,
  });

  final DungeonObjective objective;
  final bool isBoss;
  final DungeonTemplate? template;
  final VoidCallback? onStartQuest;
  final bool locked;

  /// Number of HP cells — 0% progress = full bar, 100% = empty.
  static const int _hpCells = 10;

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final emoji = _displayEmoji();
    // Monsters fall when their QUEST clears (objective + timer); the
    // boss keeps its original progress-only defeat.
    final defeated = isBoss ? objective.isComplete : objective.questCleared;
    final accent = isBoss ? HunterTheme.gold : MembershipTheme.current.accent;
    final hpCells = ((1 - objective.fraction) * _hpCells).ceil().clamp(
      0,
      _hpCells,
    );

    return MembershipCard(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Card content greys out once the monster is defeated.
          Opacity(
            opacity: defeated ? 0.45 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMedallion(emoji, accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameRow(name, accent),
                      const SizedBox(height: 3),
                      Text(
                        objective.title,
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        objective.progressLabel,
                        style: TextStyle(
                          color: HunterTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildHpBar(hpCells, accent),
                      // Quest block (monsters with a timer only) — START
                      // QUEST before, ACTIVE + countdown while running,
                      // objective-reached waiting state after.
                      if (!isBoss && objective.hasQuestTimer && !defeated) ...[
                        const SizedBox(height: 12),
                        _buildQuestBlock(accent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 💥 MONSTER DEFEATED overlay — one-shot pop when the card flips
          // to the defeated state.
          if (defeated)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder:
                    (context, value, child) {
                      final safeOpacity = value.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: safeOpacity,
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * value,
                          child: child,
                        ),
                      );
                    },
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: HunterTheme.gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: HunterTheme.gold.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      isBoss ? '💥 BOSS DEFEATED' : '💥 QUEST COMPLETE',
                      style: TextStyle(
                        color: HunterTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Display identity — the app-controlled [DungeonObjective.monster]
  /// name wins; the legacy bestiary covers its absence. The boss always
  /// shows the template's boss name when a template is present.
  String _displayName() {
    if (isBoss) {
      return template?.boss.name ?? DungeonMonsters.displayName(objective);
    }
    return DungeonMonsters.displayName(objective);
  }

  /// Monster emojis come from the template pool when the name belongs to
  /// it; the legacy bestiary supplies every other face.
  String _displayEmoji() {
    if (isBoss) {
      return template?.boss.emoji ?? DungeonMonsters.displayEmoji(objective);
    }
    return template?.monsterEmoji(objective.monster) ??
        DungeonMonsters.displayEmoji(objective);
  }

  Widget _buildMedallion(String emoji, Color accent) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.22), accent.withOpacity(0.08)],
        ),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _buildNameRow(String name, Color accent) {
    return Row(
      children: [
        if (isBoss) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: HunterTheme.gold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HunterTheme.gold.withOpacity(0.5)),
            ),
            child: Text(
              'BOSS',
              style: TextStyle(
                color: HunterTheme.gold,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            name.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  /// Quest lifecycle block — rendered from the EXPLICIT quest state
  /// ([DungeonObjective.questState]), never from text, mirroring the
  /// Mission flow (START MISSION → ACTIVE MISSION + countdown →
  /// completion):
  ///
  /// * notStarted → AI-provided "QUEST TIME" (mm:ss — NO duration
  ///   selection) + START QUEST,
  /// * active → ACTIVE QUEST chip + live countdown, or the Mission-style
  ///   "TIME'S UP!" once the timer hits zero with the objective still
  ///   outstanding (the quest does NOT complete on the timer alone),
  /// * objectiveReachedWaitingForTimer → objective done, timer still
  ///   running: the quest does NOT complete early,
  /// * completed → nothing (the defeat overlay covers the card).
  Widget _buildQuestBlock(Color accent) {
    switch (objective.questState) {
      case DungeonQuestState.notStarted:
        // SEQUENTIAL progression — a locked quest waits for the one
        // before it: no START QUEST button, just the lock notice.
        if (locked) {
          return Row(
            children: [
              Icon(
                Icons.lock_rounded,
                size: 13,
                color: HunterTheme.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'LOCKED — defeat the previous monster first',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: HunterTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'QUEST TIME',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // Before START QUEST the remaining label IS the full
                // AI-generated duration ("10:00").
                Text(
                  objective.remainingQuestLabel,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MembershipButton.primary(
              'START QUEST',
              onTap: onStartQuest ?? () {},
              expanded: true,
              icon: Icons.play_arrow_rounded,
            ),
          ],
        );
      case DungeonQuestState.active:
        // Mission-style "TIME'S UP!" when the countdown already hit zero
        // but the fitness objective is still outstanding — completion
        // waits for the objective, the timer never re-runs.
        final timerDone = objective.timerFinished;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _QuestChip(label: 'ACTIVE QUEST', color: accent),
                const Spacer(),
                Text(
                  timerDone ? '' : 'TIME REMAINING',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                if (!timerDone) const SizedBox(width: 8),
                Text(
                  timerDone ? "TIME'S UP!" : objective.remainingQuestLabel,
                  style: TextStyle(
                    color:
                        timerDone ? HunterTheme.gold : HunterTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            if (timerDone) ...[
              const SizedBox(height: 4),
              Text(
                'Timer finished — complete the objective to defeat this '
                'monster.',
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      case DungeonQuestState.objectiveReachedWaitingForTimer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: HunterTheme.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  'OBJECTIVE COMPLETE',
                  style: TextStyle(
                    color: HunterTheme.gold,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Timer Remaining: ${objective.remainingQuestLabel}',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      case DungeonQuestState.completed:
        return const SizedBox.shrink();
    }
  }

  /// Segmented HP bar — cells drain left to right as progress climbs.
  Widget _buildHpBar(int filledCells, Color accent) {
    return Row(
      children: [
        Text(
          'HP',
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _hpCells; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 9,
                    margin: EdgeInsets.only(right: i < _hpCells - 1 ? 3 : 0),
                    decoration: BoxDecoration(
                      color:
                          i < filledCells
                              ? accent
                              : HunterTheme.textTertiary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small status chip for the quest block (e.g. ACTIVE).
class _QuestChip extends StatelessWidget {
  const _QuestChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
