import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';

/// One fully generated dungeon run — the monsters' objectives, the single
/// boss objective and the AI story flavor. Everything comes from ONE AI
/// request (or one fallback set); nothing downstream ever calls the AI
/// again for the same day.
class GeneratedDungeon {
  const GeneratedDungeon({
    required this.monsters,
    required this.boss,
    this.story = '',
  });

  /// Normal objectives — each automatically becomes one monster.
  final List<DungeonObjective> monsters;

  /// The final objective, slightly harder than the monsters'. The dungeon
  /// only clears once this reaches 100%.
  final DungeonObjective boss;

  /// Short AI story line shown on the play screen ('' when absent).
  final String story;
}

/// Generates E-Rank dungeons through the SAME AI pipeline the app already
/// uses for daily/weekly missions (see `AIQuestService`): the server-side
/// Cloudflare Worker proxy (API keys never on device), the mistral request
/// shape, the markdown-fence-stripping parse and the "return fallback on
/// any failure" error handling. Only the PROMPT is dungeon-specific.
///
/// The prompt returns STRUCTURED objectives — {type, target, unit, title,
/// monster} — restricted to the metrics Hunter Ascend tracks
/// automatically. Tracking keys entirely off `type`; the free-text
/// `title` is display-only, so different AI wording can never break
/// progress detection.
class DungeonGeneration {
  DungeonGeneration._();

  /// Same worker endpoint + model as [AIQuestService] — single AI path.
  static const String _endpoint =
      'https://hunter-ascend-ai.jefferinlal.workers.dev/mistral';
  static const String _model = 'mistral-small-latest';

  /// Placeholder rewards shown on the Dungeon Cleared screen (display
  /// only, never awarded or stored).
  static const int placeholderXp = 100;
  static const int placeholderCoins = 25;

  /// Generates 2–3 monster objectives + one harder boss objective for the
  /// E-Rank gate in ONE request. Falls back to a fixed beginner dungeon
  /// whenever generation fails, so the dungeon is always playable
  /// (mirrors the graceful-fallback philosophy of AIQuestService).
  static Future<GeneratedDungeon> generateERankDungeon({
    required DungeonGateSpec gate,
  }) async {
    debugPrint('⚔️ [Dungeon] Generating E-Rank dungeon for ${gate.name}...');
    final String userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId,
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {"role": "user", "content": _buildPrompt(gate)},
          ],
        }),
      );

      debugPrint('[Dungeon] STATUS: ${response.statusCode}');
      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];
      content =
          content.replaceAll('```json', '').replaceAll('```', '').trim();

      final generated = _parse(jsonDecode(content));
      if (generated != null) {
        debugPrint(
            '[Dungeon] MONSTERS: ${generated.monsters.length} + 1 boss');
        return generated;
      }
    } catch (e) {
      debugPrint('[Dungeon] GENERATION ERROR: $e');
    }
    debugPrint('[Dungeon] Using fallback beginner dungeon');
    return fallbackDungeon();
  }

  /// Dungeon-specific prompt. Structure mirrors AIQuestService's prompts:
  /// plain instruction text, an explicit JSON format example, safety rules
  /// and a "Return JSON only" closer. One request returns the story, the
  /// monsters' objectives AND the boss objective — all STRUCTURED
  /// ({type, target, unit, title, monster}) so tracking never has to
  /// interpret natural language.
  static String _buildPrompt(DungeonGateSpec gate) => """
Generate a beginner fitness dungeon for a monster-hunter fitness app.

Dungeon: ${gate.name}
Difficulty: Easy.

Generate:
- A short 1-2 sentence story introducing the dungeon and its monsters.
- 2-3 monster objectives (each objective becomes one monster).
- ONE boss objective, slightly HARDER than the monster objectives.

Objectives must be fitness related, beginner friendly and ONLY use metrics
the app tracks automatically. Allowed objective types (use EXACTLY these
type values, nothing else):
- steps: today's step count
- water: water intake in ml
- walking_distance: walking distance in km
- running_distance: running distance in km
- calories: calories burned in kcal

Do NOT generate pushups, squats, burpees, plank, yoga, stretching, sleep
or any other type — the app cannot track those automatically.

Every objective must be a JSON object with EXACTLY these fields:
"monster" (the monster's name, 1-3 words),
"type" (one of the allowed types),
"target" (a number),
"unit" (steps | ml | km | kcal, matching the type),
"title" (short display text under 8 words, e.g. "Drink 2L Water").

Return ONLY JSON, no markdown:
{
  "story": "Goblins have infested the cave. Clear them out, hunter.",
  "objectives": [
    {"monster": "Goblin Scout", "type": "steps", "target": 8000, "unit": "steps", "title": "Walk 8000 Steps"},
    {"monster": "Goblin Archer", "type": "water", "target": 2000, "unit": "ml", "title": "Drink 2L Water"}
  ],
  "boss": {"monster": "Goblin King", "type": "walking_distance", "target": 2, "unit": "km", "title": "Walk 2 km"}
}

Target rules (objectives must be possible):
- steps: monsters 1000-6000, boss 3000-8000
- water: in ml — monsters 500-2000, boss 1000-2500
- walking_distance, running_distance: in km — monsters 0.5-2, boss 1-3
- calories: in kcal burned — monsters 50-200, boss 100-300

Rules:
- 2 or 3 monster objectives, plus exactly 1 boss objective
- The boss objective must be harder than every monster objective
- Beginner friendly, safe activities only
- No impossible objectives
- No medical advice
- Monster names and titles unique
Return JSON only.
""";

  /// Validates AI output into a playable dungeon. Mirrors AIQuestService's
  /// defensive parsing: anything malformed is skipped, duplicates are
  /// dropped, and counts are clamped to the contract (2–3 monsters, 1
  /// boss). Returns null when the monster set itself is unusable so the
  /// caller falls back to the always-valid starter dungeon.
  static GeneratedDungeon? _parse(dynamic raw) {
    if (raw is! Map) return null;

    final story = (raw['story'] ?? '').toString().trim();
    final monsters = _parseObjectives(raw['objectives'], isBoss: false);
    if (monsters.isEmpty) return null;

    // The boss is parsed by the SAME code path as monster objectives —
    // only the isBoss flag and the harder target bounds differ.
    final boss =
        _parseObjectives([raw['boss']], isBoss: true).firstOrNull ??
            fallbackBoss();
    return GeneratedDungeon(monsters: monsters, boss: boss, story: story);
  }

  /// The ONE objective parser — used for the monsters list and for the
  /// boss alike (identical structured format). Unsupported types are
  /// rejected outright, targets are clamped per type, and duplicate
  /// titles are dropped.
  static List<DungeonObjective> _parseObjectives(dynamic raw,
      {required bool isBoss}) {
    if (raw is! List) return [];
    final seenTitles = <String>{};
    final objectives = <DungeonObjective>[];

    for (final item in raw) {
      if (objectives.length >= (isBoss ? 1 : 3)) break;
      if (item is! Map) continue;

      final title = (item['title'] ?? '').toString().trim();
      final monster = (item['monster'] ?? '').toString().trim();
      final type = DungeonObjectiveType.tryParse(
        (item['type'] ?? '').toString(),
      );
      final target = double.tryParse('${item['target']}');
      if (title.isEmpty || type == null || target == null) continue;
      if (!seenTitles.add(title.toLowerCase())) continue;

      objectives.add(DungeonObjective(
        title: title,
        type: type,
        target: _clampTarget(type, target, isBoss: isBoss),
        isBoss: isBoss,
        monster: monster.isEmpty ? null : monster,
      ));
    }

    // Honor the 2–3 contract: a single lone monster objective is rejected
    // so the fallback dungeon (which is always valid) is used instead.
    if (!isBoss && objectives.length < 2) return [];
    return objectives;
  }

  /// Hard bounds per type — even if the AI ignores the prompt, objectives
  /// stay beginner-friendly, achievable and expressed in the type's
  /// canonical unit (the `unit` field itself is never trusted for
  /// tracking; type decides both the source and the unit).
  static double _clampTarget(
    DungeonObjectiveType type,
    double target, {
    required bool isBoss,
  }) {
    final (min, max) = switch (type) {
      DungeonObjectiveType.steps =>
        isBoss ? (3000.0, 8000.0) : (1000.0, 6000.0),
      DungeonObjectiveType.water =>
        isBoss ? (1000.0, 2500.0) : (500.0, 2000.0),
      DungeonObjectiveType.walkingDistance ||
      DungeonObjectiveType.runningDistance =>
        isBoss ? (1.0, 3.0) : (0.5, 2.0),
      DungeonObjectiveType.calories =>
        isBoss ? (100.0, 300.0) : (50.0, 200.0),
    };
    return target.clamp(min, max);
  }

  /// Fixed beginner dungeon used when AI generation fails (offline,
  /// outage, malformed output). Every objective uses a metric the app
  /// tracks automatically, so the run is completable on any device.
  static GeneratedDungeon fallbackDungeon() => GeneratedDungeon(
        monsters: [
          DungeonObjective(
            title: 'Walk 3000 Steps',
            type: DungeonObjectiveType.steps,
            target: 3000,
            monster: 'Goblin Scout',
          ),
          DungeonObjective(
            title: 'Drink 1000 ml Water',
            type: DungeonObjectiveType.water,
            target: 1000,
            monster: 'Goblin Archer',
          ),
        ],
        boss: fallbackBoss(),
        story: 'Monsters stir beyond the gate. '
            'Defeat them all, hunter, then face their boss.',
      );

  /// Boss used when the AI returns monsters but no usable boss objective
  /// (also covers dungeons persisted before the boss system existed).
  static DungeonObjective fallbackBoss() => DungeonObjective(
        title: 'Walk 2 km',
        type: DungeonObjectiveType.walkingDistance,
        target: 2,
        isBoss: true,
        monster: 'Dungeon Boss',
      );
}
