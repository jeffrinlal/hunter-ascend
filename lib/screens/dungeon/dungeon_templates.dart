import 'package:hunter_ascend/screens/dungeon/dungeon_monsters.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// Hard target bounds for ONE objective type — the monster range and the
/// (harder) boss range. Even if the AI ignores the prompt, generated
/// targets are clamped into these bounds, so objectives stay achievable
/// in a single day at the template's rank.
class DungeonTargetBounds {
  const DungeonTargetBounds({
    required this.monsterMin,
    required this.monsterMax,
    required this.bossMin,
    required this.bossMax,
  });

  final double monsterMin;
  final double monsterMax;
  final double bossMin;
  final double bossMax;

  /// The clamp/prompt range for one objective class (monster vs boss).
  (double, double) range({required bool isBoss}) =>
      isBoss ? (bossMin, bossMax) : (monsterMin, monsterMax);
}

/// Clean per-rank difficulty configuration — replaces scattered
/// hardcoded if/else ranges. One profile per [DungeonTemplate]: the
/// difficulty LABEL shown in the UI, the objective TYPES this rank may
/// generate (always a subset of the auto-tracked metrics), and the hard
/// target bounds per type.
class DungeonDifficultyProfile {
  const DungeonDifficultyProfile({
    required this.label,
    required this.allowedTypes,
    required this.targets,
  });

  /// Human-readable difficulty ("Beginner", "Easy", ... "Extreme").
  final String label;

  /// Objective types the AI may use at this rank — ALWAYS a subset of
  /// the auto-tracked [DungeonObjectiveType] values. Lower ranks get the
  /// gentler subset; running distance joins from D rank upward.
  final List<DungeonObjectiveType> allowedTypes;

  /// Hard bounds per allowed type (covers every entry of [allowedTypes]).
  final Map<DungeonObjectiveType, DungeonTargetBounds> targets;

  /// Prompt/clamp range for one type + objective class.
  (double, double) targetRange(
    DungeonObjectiveType type, {
    required bool isBoss,
  }) => targets[type]!.range(isBoss: isBoss);
}

/// One reusable dungeon CONTENT definition (Phase 6). The gameplay engine
/// (generation, session manager, tracker, play screen) is shared by ALL
/// ranks — a template only supplies content: identity, monster pool,
/// boss, difficulty configuration and reward. Adding/changing a dungeon
/// means editing ONE entry in [DungeonTemplates.all].
class DungeonTemplate {
  const DungeonTemplate({
    required this.id,
    required this.rankLetter,
    required this.name,
    required this.description,
    required this.theme,
    required this.lore,
    required this.monsters,
    required this.boss,
    required this.difficulty,
    required this.rewardXp,
    required this.rewardTier,
    required this.coinsMin,
    required this.coinsMax,
  });

  /// Stable content identifier (e.g. "goblin_cave").
  final String id;

  /// Hunter Rank letter this dungeon is keyed on ('E'…'S') — resolved
  /// through the existing [RankService] ladder, never a second system.
  final String rankLetter;

  /// Dungeon name ("Goblin Cave").
  final String name;

  /// Short blurb for the lobby gate card.
  final String description;

  /// Flavor theme line shown with the dungeon ("Damp torch-lit caves…").
  final String theme;

  /// Immersive lore paragraph shown on the gate entry screen.
  final String lore;

  /// Predefined monster POOL — the AI may write each monster's objective
  /// but NEVER invents monster identity: generation restricts names to
  /// this pool (unknown names are remapped onto it).
  final List<DungeonMonsterSpec> monsters;

  /// The dungeon's single boss — identity is ALWAYS app-controlled.
  final DungeonMonsterSpec boss;

  /// Difficulty configuration (label, allowed types, target bounds).
  final DungeonDifficultyProfile difficulty;

  /// Clear reward in XP — awarded exactly once through the centralized
  /// XpService (Phase 5 claim path). Higher ranks pay more; membership
  /// tier never changes it.
  final int rewardXp;

  // ── Phase 7: rank-scaled clear reward configuration ────────────────────

  /// Reward tier label (Basic → Highest) — presentation copy for the
  /// clear screen, mirrors the ascending reward ranges.
  final String rewardTier;

  /// Inclusive coin range for the clear reward. The app has no coin
  /// economy yet — the picked amount is recorded with the claim for
  /// display/future integration (see `DungeonClearReward`).
  final int coinsMin;
  final int coinsMax;

  /// Canonical rank for [rankLetter] (letter, label, color, minLevel all
  /// come from the existing ladder — no duplicated rank math).
  HunterRank get rank =>
      RankService.ranks.firstWhere((r) => r.letter == rankLetter);

  /// The level at which this dungeon naturally unlocks.
  int get recommendedLevel => rank.minLevel;

  /// Case-insensitive pool membership check (used to sanitize AI output).
  bool hasMonster(String? name) => monsterByName(name) != null;

  DungeonMonsterSpec? monsterByName(String? name) {
    if (name == null) return null;
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final m in monsters) {
      if (m.name.toLowerCase() == key) return m;
    }
    return null;
  }

  /// Emoji for a pool monster name (null when the name is not in the
  /// pool — the legacy bestiary covers that case).
  String? monsterEmoji(String? name) => monsterByName(name)?.emoji;
}

/// The dungeon content registry — ONE declarative table for all six
/// ranks. The lobby, gate screen, generator and play screen all consume
/// these templates; new content = a new entry here.
class DungeonTemplates {
  DungeonTemplates._();

  static const List<DungeonTemplate> all = [
    // ── E Rank ────────────────────────────────────────────────────────────
    DungeonTemplate(
      id: 'goblin_cave',
      rankLetter: 'E',
      name: 'Goblin Cave',
      description: 'A beginner gate suitable for new hunters.',
      theme: 'Damp torch-lit caves crawling with goblins.',
      lore:
          'A mysterious gate has appeared.\n'
          'Hunters have reported weak monsters inside.',
      monsters: [
        DungeonMonsterSpec(name: 'Goblin Scout', emoji: '👺'),
        DungeonMonsterSpec(name: 'Goblin Archer', emoji: '🏹'),
        DungeonMonsterSpec(name: 'Goblin Warrior', emoji: '⚔️'),
      ],
      boss: DungeonMonsterSpec(name: 'Goblin King', emoji: '👹'),
      difficulty: DungeonDifficultyProfile(
        label: 'Beginner',
        allowedTypes: [
          DungeonObjectiveType.steps,
          DungeonObjectiveType.water,
          DungeonObjectiveType.walkingDistance,
          DungeonObjectiveType.calories,
        ],
        targets: {
          DungeonObjectiveType.steps: DungeonTargetBounds(
            monsterMin: 1000,
            monsterMax: 6000,
            bossMin: 3000,
            bossMax: 8000,
          ),
          DungeonObjectiveType.water: DungeonTargetBounds(
            monsterMin: 500,
            monsterMax: 2000,
            bossMin: 1000,
            bossMax: 2500,
          ),
          DungeonObjectiveType.walkingDistance: DungeonTargetBounds(
            monsterMin: 0.5,
            monsterMax: 2,
            bossMin: 1,
            bossMax: 3,
          ),
          DungeonObjectiveType.calories: DungeonTargetBounds(
            monsterMin: 50,
            monsterMax: 200,
            bossMin: 100,
            bossMax: 300,
          ),
        },
      ),
      rewardXp: 100,
      rewardTier: 'Basic',
      coinsMin: 10,
      coinsMax: 20,
    ),

    // ── D Rank ────────────────────────────────────────────────────────────
    DungeonTemplate(
      id: 'spider_nest',
      rankLetter: 'D',
      name: 'Spider Nest',
      description: 'Requires greater discipline.',
      theme: 'Silk-choked tunnels where the brood hunts in silence.',
      lore:
          'A freezing wind howls from beyond the gate.\n'
          'The brood inside hunts in eerie silence.',
      monsters: [
        DungeonMonsterSpec(name: 'Spiderling', emoji: '🕸️'),
        DungeonMonsterSpec(name: 'Venom Spider', emoji: '🕷️'),
        DungeonMonsterSpec(name: 'Giant Spider', emoji: '🦂'),
      ],
      boss: DungeonMonsterSpec(name: 'Spider Queen', emoji: '🕷️'),
      difficulty: DungeonDifficultyProfile(
        label: 'Easy',
        allowedTypes: [
          DungeonObjectiveType.steps,
          DungeonObjectiveType.water,
          DungeonObjectiveType.walkingDistance,
          DungeonObjectiveType.runningDistance,
          DungeonObjectiveType.calories,
        ],
        targets: {
          DungeonObjectiveType.steps: DungeonTargetBounds(
            monsterMin: 3000,
            monsterMax: 9000,
            bossMin: 6000,
            bossMax: 12000,
          ),
          DungeonObjectiveType.water: DungeonTargetBounds(
            monsterMin: 750,
            monsterMax: 2500,
            bossMin: 1500,
            bossMax: 3000,
          ),
          DungeonObjectiveType.walkingDistance: DungeonTargetBounds(
            monsterMin: 1,
            monsterMax: 3,
            bossMin: 2,
            bossMax: 4,
          ),
          DungeonObjectiveType.runningDistance: DungeonTargetBounds(
            monsterMin: 0.5,
            monsterMax: 2,
            bossMin: 1,
            bossMax: 3,
          ),
          DungeonObjectiveType.calories: DungeonTargetBounds(
            monsterMin: 100,
            monsterMax: 300,
            bossMin: 200,
            bossMax: 450,
          ),
        },
      ),
      rewardXp: 150,
      rewardTier: 'Improved',
      coinsMin: 20,
      coinsMax: 35,
    ),

    // ── C Rank ────────────────────────────────────────────────────────────
    DungeonTemplate(
      id: 'skeleton_crypt',
      rankLetter: 'C',
      name: 'Skeleton Crypt',
      description: 'Dangerous gate for experienced hunters.',
      theme: 'Ancient burial halls where the dead refuse to rest.',
      lore:
          'Few hunters return from this gate unchanged.\n'
          'The darkness within remembers every intruder.',
      monsters: [
        DungeonMonsterSpec(name: 'Skeleton Soldier', emoji: '💀'),
        DungeonMonsterSpec(name: 'Skeleton Archer', emoji: '🏹'),
        DungeonMonsterSpec(name: 'Skeleton Knight', emoji: '🛡️'),
      ],
      boss: DungeonMonsterSpec(name: 'Skeleton King', emoji: '💀'),
      difficulty: DungeonDifficultyProfile(
        label: 'Moderate',
        allowedTypes: [
          DungeonObjectiveType.steps,
          DungeonObjectiveType.water,
          DungeonObjectiveType.walkingDistance,
          DungeonObjectiveType.runningDistance,
          DungeonObjectiveType.calories,
        ],
        targets: {
          DungeonObjectiveType.steps: DungeonTargetBounds(
            monsterMin: 5000,
            monsterMax: 12000,
            bossMin: 8000,
            bossMax: 15000,
          ),
          DungeonObjectiveType.water: DungeonTargetBounds(
            monsterMin: 1000,
            monsterMax: 3000,
            bossMin: 2000,
            bossMax: 3500,
          ),
          DungeonObjectiveType.walkingDistance: DungeonTargetBounds(
            monsterMin: 2,
            monsterMax: 4,
            bossMin: 3,
            bossMax: 6,
          ),
          DungeonObjectiveType.runningDistance: DungeonTargetBounds(
            monsterMin: 1,
            monsterMax: 3,
            bossMin: 2,
            bossMax: 5,
          ),
          DungeonObjectiveType.calories: DungeonTargetBounds(
            monsterMin: 150,
            monsterMax: 400,
            bossMin: 300,
            bossMax: 600,
          ),
        },
      ),
      rewardXp: 220,
      rewardTier: 'Moderate',
      coinsMin: 35,
      coinsMax: 50,
    ),

    // ── B Rank ────────────────────────────────────────────────────────────
    DungeonTemplate(
      id: 'orc_fortress',
      rankLetter: 'B',
      name: 'Orc Fortress',
      description: 'Elite hunter challenge.',
      theme: 'A war-forged stronghold guarded by orc legions.',
      lore:
          'An elite-class gate. The monsters inside are\n'
          'commanded by something far smarter than beasts.',
      monsters: [
        DungeonMonsterSpec(name: 'Orc Scout', emoji: '🧌'),
        DungeonMonsterSpec(name: 'Orc Warrior', emoji: '🪓'),
        DungeonMonsterSpec(name: 'Orc Berserker', emoji: '⚔️'),
      ],
      boss: DungeonMonsterSpec(name: 'Orc Warlord', emoji: '🧌'),
      difficulty: DungeonDifficultyProfile(
        label: 'Hard',
        allowedTypes: [
          DungeonObjectiveType.steps,
          DungeonObjectiveType.water,
          DungeonObjectiveType.walkingDistance,
          DungeonObjectiveType.runningDistance,
          DungeonObjectiveType.calories,
        ],
        targets: {
          DungeonObjectiveType.steps: DungeonTargetBounds(
            monsterMin: 7000,
            monsterMax: 15000,
            bossMin: 10000,
            bossMax: 18000,
          ),
          DungeonObjectiveType.water: DungeonTargetBounds(
            monsterMin: 1500,
            monsterMax: 3500,
            bossMin: 2500,
            bossMax: 4000,
          ),
          DungeonObjectiveType.walkingDistance: DungeonTargetBounds(
            monsterMin: 3,
            monsterMax: 6,
            bossMin: 4,
            bossMax: 8,
          ),
          DungeonObjectiveType.runningDistance: DungeonTargetBounds(
            monsterMin: 2,
            monsterMax: 5,
            bossMin: 3,
            bossMax: 7,
          ),
          DungeonObjectiveType.calories: DungeonTargetBounds(
            monsterMin: 250,
            monsterMax: 500,
            bossMin: 400,
            bossMax: 750,
          ),
        },
      ),
      rewardXp: 320,
      rewardTier: 'High',
      coinsMin: 50,
      coinsMax: 75,
    ),

    // ── A Rank ────────────────────────────────────────────────────────────
    DungeonTemplate(
      id: 'shadow_temple',
      rankLetter: 'A',
      name: 'Shadow Temple',
      description: 'Extremely dangerous.',
      theme: 'A lightless shrine where shadows move on their own.',
      lore:
          'The Association has flagged this gate as\n'
          'extremely dangerous. Only seasoned hunters dare approach.',
      monsters: [
        DungeonMonsterSpec(name: 'Shadow Assassin', emoji: '🗡️'),
        DungeonMonsterSpec(name: 'Shadow Knight', emoji: '🌫️'),
        DungeonMonsterSpec(name: 'Shadow Beast', emoji: '👻'),
      ],
      boss: DungeonMonsterSpec(name: 'Shadow Lord', emoji: '🌑'),
      difficulty: DungeonDifficultyProfile(
        label: 'Very Hard',
        allowedTypes: [
          DungeonObjectiveType.steps,
          DungeonObjectiveType.water,
          DungeonObjectiveType.walkingDistance,
          DungeonObjectiveType.runningDistance,
          DungeonObjectiveType.calories,
        ],
        targets: {
          DungeonObjectiveType.steps: DungeonTargetBounds(
            monsterMin: 9000,
            monsterMax: 18000,
            bossMin: 12000,
            bossMax: 22000,
          ),
          DungeonObjectiveType.water: DungeonTargetBounds(
            monsterMin: 2000,
            monsterMax: 4000,
            bossMin: 3000,
            bossMax: 4500,
          ),
          DungeonObjectiveType.walkingDistance: DungeonTargetBounds(
            monsterMin: 4,
            monsterMax: 8,
            bossMin: 6,
            bossMax: 10,
          ),
          DungeonObjectiveType.runningDistance: DungeonTargetBounds(
            monsterMin: 3,
            monsterMax: 6,
            bossMin: 5,
            bossMax: 9,
          ),
          DungeonObjectiveType.calories: DungeonTargetBounds(
            monsterMin: 350,
            monsterMax: 650,
            bossMin: 550,
            bossMax: 900,
          ),
        },
      ),
      rewardXp: 450,
      rewardTier: 'Very High',
      coinsMin: 75,
      coinsMax: 100,
    ),

    // ── S Rank ────────────────────────────────────────────────────────────
    DungeonTemplate(
      id: 'demon_castle',
      rankLetter: 'S',
      name: 'Demon Castle',
      description: 'Only the strongest hunters survive.',
      theme: 'A burning citadel crowned by the Demon Monarch\'s throne.',
      lore:
          'A gate of legend. Those who entered speak of\n'
          'a presence older than hunters themselves.',
      monsters: [
        DungeonMonsterSpec(name: 'Demon Soldier', emoji: '😈'),
        DungeonMonsterSpec(name: 'Demon Knight', emoji: '🔥'),
        DungeonMonsterSpec(name: 'Demon Beast', emoji: '🐺'),
      ],
      boss: DungeonMonsterSpec(name: 'Demon Monarch', emoji: '👿'),
      difficulty: DungeonDifficultyProfile(
        label: 'Extreme',
        allowedTypes: [
          DungeonObjectiveType.steps,
          DungeonObjectiveType.water,
          DungeonObjectiveType.walkingDistance,
          DungeonObjectiveType.runningDistance,
          DungeonObjectiveType.calories,
        ],
        targets: {
          DungeonObjectiveType.steps: DungeonTargetBounds(
            monsterMin: 12000,
            monsterMax: 22000,
            bossMin: 15000,
            bossMax: 25000,
          ),
          DungeonObjectiveType.water: DungeonTargetBounds(
            monsterMin: 2500,
            monsterMax: 4500,
            bossMin: 3500,
            bossMax: 5000,
          ),
          DungeonObjectiveType.walkingDistance: DungeonTargetBounds(
            monsterMin: 5,
            monsterMax: 10,
            bossMin: 8,
            bossMax: 12,
          ),
          DungeonObjectiveType.runningDistance: DungeonTargetBounds(
            monsterMin: 4,
            monsterMax: 8,
            bossMin: 6,
            bossMax: 12,
          ),
          DungeonObjectiveType.calories: DungeonTargetBounds(
            monsterMin: 450,
            monsterMax: 800,
            bossMin: 700,
            bossMax: 1100,
          ),
        },
      ),
      rewardXp: 600,
      rewardTier: 'Highest',
      coinsMin: 100,
      coinsMax: 150,
    ),
  ];

  /// Template for a gate letter ('E'…'S'), null for unknown letters.
  static DungeonTemplate? forGate(String letter) {
    for (final template in all) {
      if (template.rankLetter == letter) return template;
    }
    return null;
  }

  /// The entry-level template (also the last-resort fallback for an
  /// unknown gate letter — the dungeon always stays playable).
  static DungeonTemplate get eRank => all.first;
}
