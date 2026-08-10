import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// Display metadata for one dungeon gate (lobby card + gate entry screen).
///
/// Phase 6: this is UI copy DERIVED from the shared [DungeonTemplates]
/// registry — the same single content source the gameplay engine consumes,
/// so lobby copy and gameplay can never drift apart. It holds no IDs and
/// nothing is persisted; the screens only ever consume this descriptor.
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

  /// Human-readable difficulty ("Beginner", "Extreme", ...).
  final String difficulty;

  /// Short blurb for the lobby gate card.
  final String description;

  /// Immersive lore paragraph shown on the gate entry screen.
  final String lore;
}

/// All gates shown in the Dungeon Lobby, ordered ascending by rank —
/// derived from [DungeonTemplates.all], so adding a gate later = adding
/// one template entry, nothing else.
final List<DungeonGateSpec> kDungeonGates = [
  for (final template in DungeonTemplates.all)
    DungeonGateSpec(
      letter: template.rankLetter,
      name: template.name,
      difficulty: template.difficulty.label,
      description: template.description,
      lore: template.lore,
    ),
];

/// Resolves the canonical [HunterRank] a gate is keyed on — letter, label
/// and color all come from the existing rank ladder (no second ranking
/// system).
HunterRank dungeonGateRank(DungeonGateSpec spec) =>
    RankService.ranks.firstWhere((r) => r.letter == spec.letter);
