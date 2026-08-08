import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';

/// Monster bestiary. Monster NAMES come from the structured AI response
/// (`DungeonObjective.monster`); this map is the FALLBACK identity for
/// objectives persisted before that schema existed, and the single source
/// of monster EMOJIS (the AI never supplies icons). No UI widget
/// hardcodes monster names — widgets render `DungeonMonsters.displayName /
/// displayEmoji`.
class DungeonMonsterSpec {
  const DungeonMonsterSpec({required this.name, required this.emoji});

  final String name;
  final String emoji;
}

class DungeonMonsters {
  DungeonMonsters._();

  /// One fallback identity per supported objective type.
  static const Map<DungeonObjectiveType, DungeonMonsterSpec> byType = {
    DungeonObjectiveType.steps:
        DungeonMonsterSpec(name: 'Skeleton', emoji: '💀'),
    DungeonObjectiveType.water:
        DungeonMonsterSpec(name: 'Goblin Archer', emoji: '🏹'),
    DungeonObjectiveType.walkingDistance:
        DungeonMonsterSpec(name: 'Goblin Scout', emoji: '👺'),
    DungeonObjectiveType.runningDistance:
        DungeonMonsterSpec(name: 'Giant Spider', emoji: '🕷️'),
    DungeonObjectiveType.calories:
        DungeonMonsterSpec(name: 'Orc Warrior', emoji: '🧌'),
  };

  /// Fallback identity for the boss when the AI omitted one.
  static const DungeonMonsterSpec boss =
      DungeonMonsterSpec(name: 'Dungeon Boss', emoji: '👹');

  /// Defensive fallback so an unknown objective still has a face.
  static const DungeonMonsterSpec fallback =
      DungeonMonsterSpec(name: 'Dungeon Fiend', emoji: '👾');

  static DungeonMonsterSpec forObjective(DungeonObjective objective) =>
      objective.isBoss ? boss : (byType[objective.type] ?? fallback);

  /// Display identity — the AI-supplied [DungeonObjective.monster] wins;
  /// the fallback bestiary covers its absence.
  static String displayName(DungeonObjective objective) =>
      objective.monster ?? forObjective(objective).name;

  /// Monster emojis ALWAYS come from the bestiary.
  static String displayEmoji(DungeonObjective objective) =>
      forObjective(objective).emoji;
}
