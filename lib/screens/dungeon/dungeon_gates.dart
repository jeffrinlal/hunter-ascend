import 'package:hunter_ascend/services/rank_service.dart';

/// Display metadata for one dungeon gate (Phase 3: presentation only).
///
/// This is UI copy for the gate entry experience — NOT a data model: it
/// holds no IDs, nothing is persisted and nothing reads it outside the
/// dungeon screens. Later phases (AI-generated dungeons, objectives,
/// rewards, daily resets) will enrich or replace these fields; the lobby
/// and gate screen only ever consume this descriptor, so they won't need
/// redesigning.
class DungeonGateSpec {
  const DungeonGateSpec({
    required this.letter,
    required this.name,
    required this.difficulty,
    required this.description,
    required this.lore,
  });

  /// Rank key into the centralized [RankService] ladder ('E'…'S').
  final String letter;

  /// Flavor name of the dungeon behind the gate (e.g. "Goblin Cave").
  final String name;

  /// Human-readable difficulty ("Easy", "Nightmare", ...).
  final String difficulty;

  /// Short blurb for the lobby gate card.
  final String description;

  /// Immersive lore paragraph shown on the gate entry screen.
  final String lore;
}

/// All gates shown in the Dungeon Lobby, ordered ascending by rank.
/// Adding a gate later = adding a row here.
const List<DungeonGateSpec> kDungeonGates = [
  DungeonGateSpec(
    letter: 'E',
    name: 'Goblin Cave',
    difficulty: 'Easy',
    description: 'A beginner gate suitable for new hunters.',
    lore: 'A mysterious gate has appeared.\n'
        'Hunters have reported weak monsters inside.',
  ),
  DungeonGateSpec(
    letter: 'D',
    name: 'Frost Wolf Den',
    difficulty: 'Moderate',
    description: 'Requires greater discipline.',
    lore: 'A freezing wind howls from beyond the gate.\n'
        'The packs inside hunt in eerie silence.',
  ),
  DungeonGateSpec(
    letter: 'C',
    name: 'Crimson Catacombs',
    difficulty: 'Hard',
    description: 'Dangerous gate for experienced hunters.',
    lore: 'Few hunters return from this gate unchanged.\n'
        'The darkness within remembers every intruder.',
  ),
  DungeonGateSpec(
    letter: 'B',
    name: 'Iron Citadel',
    difficulty: 'Very Hard',
    description: 'Elite hunter challenge.',
    lore: 'An elite-class gate. The monsters inside are\n'
        'commanded by something far smarter than beasts.',
  ),
  DungeonGateSpec(
    letter: 'A',
    name: 'Abyssal Rift',
    difficulty: 'Extreme',
    description: 'Extremely dangerous.',
    lore: 'The Association has flagged this gate as\n'
        'extremely dangerous. Only seasoned hunters dare approach.',
  ),
  DungeonGateSpec(
    letter: 'S',
    name: 'Throne of Shadows',
    difficulty: 'Nightmare',
    description: 'Only the strongest hunters survive.',
    lore: 'A gate of legend. Those who entered speak of\n'
        'a presence older than hunters themselves.',
  ),
];

/// Resolves the canonical [HunterRank] a gate is keyed on — letter, label
/// and color all come from the existing rank ladder (no second ranking
/// system).
HunterRank dungeonGateRank(DungeonGateSpec spec) =>
    RankService.ranks.firstWhere((r) => r.letter == spec.letter);
