import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_monsters.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';

/// One dungeon monster — a generated objective presented as an enemy whose
/// HP drains as the underlying fitness progress climbs. At 100% progress
/// the card shows 💥 MONSTER DEFEATED and greys out.
///
/// The card only DISPLAYS structured data: the monster name comes from the
/// objective's AI-supplied [DungeonObjective.monster] (falling back to
/// [DungeonMonsters]), progress/HP from [DungeonObjective.fraction]. It
/// never tracks and never interprets titles — every objective type is
/// auto-tracked by `DungeonTracker`, so no manual buttons exist.
class MonsterCard extends StatelessWidget {
  const MonsterCard({super.key, required this.objective});

  final DungeonObjective objective;

  @override
  Widget build(BuildContext context) =>
      _MonsterCardFrame(objective: objective, isBoss: false);
}

/// The dungeon boss — same HP mechanics as [MonsterCard] with boss styling
/// (gold HP, BOSS chip). Only built once every monster is defeated.
class BossCard extends StatelessWidget {
  const BossCard({super.key, required this.objective});

  final DungeonObjective objective;

  @override
  Widget build(BuildContext context) =>
      _MonsterCardFrame(objective: objective, isBoss: true);
}

/// Shared layout for monsters and the boss — one implementation, two
/// wrappers, no duplication.
class _MonsterCardFrame extends StatelessWidget {
  const _MonsterCardFrame({required this.objective, required this.isBoss});

  final DungeonObjective objective;
  final bool isBoss;

  /// Number of HP cells — 0% progress = full bar, 100% = empty.
  static const int _hpCells = 10;

  @override
  Widget build(BuildContext context) {
    final name = DungeonMonsters.displayName(objective);
    final emoji = DungeonMonsters.displayEmoji(objective);
    final defeated = objective.isComplete;
    final accent = isBoss ? HunterTheme.gold : MembershipTheme.current.accent;
    final hpCells =
        ((1 - objective.fraction) * _hpCells).ceil().clamp(0, _hpCells);

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
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * value,
                    child: child,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: HunterTheme.gold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: HunterTheme.gold.withOpacity(0.5)),
                    ),
                    child: Text(
                      isBoss ? '💥 BOSS DEFEATED' : '💥 MONSTER DEFEATED',
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

  Widget _buildMedallion(String emoji, Color accent) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.22),
            accent.withOpacity(0.08),
          ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                      color: i < filledCells
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
