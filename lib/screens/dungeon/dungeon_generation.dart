import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';

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

/// Rank-based dungeon generation (Phase 6) through the SAME AI pipeline
/// the app already uses for daily/weekly missions (see `AIQuestService`):
/// the server-side Cloudflare Worker proxy (API keys never on device),
/// the mistral request shape, the markdown-fence-stripping parse and the
/// "return fallback on any failure" error handling. ONE shared generator
/// serves every rank — all rank differences come from the
/// [DungeonTemplate] it receives (content, difficulty bounds, monster
/// pool), never from a second engine.
///
/// The prompt returns STRUCTURED objectives — {type, target, unit, title,
/// monster} — restricted to the metrics Hunter Ascend tracks
/// automatically. Tracking keys entirely off `type`; the free-text
/// `title` is display-only, so different AI wording can never break
/// progress detection. Monster IDENTITY is app-controlled: the AI may
/// write each monster's objective, but names are sanitized onto the
/// template's predefined pool and the boss name is always the template's.
class DungeonGeneration {
  DungeonGeneration._();

  /// Same worker endpoint + model as [AIQuestService] — single AI path.
  static const String _endpoint =
      'https://hunter-ascend-ai.jefferinlal.workers.dev/mistral';
  static const String _model = 'mistral-small-latest';

  /// Validation bounds for the AI-provided quest `durationSeconds` —
  /// invalid values are replaced by [fallbackDurationSeconds], NEVER by
  /// another AI call. The bounds follow the existing mission timing
  /// ladder (missions run in 5-minute tiers from 5 to 60 minutes).
  static const int kMinQuestDurationSeconds = 60; // 1 minute
  static const int kMaxQuestDurationSeconds = 3600; // 60 minutes

  /// Safe duration when the AI omits/returns an invalid value — the
  /// middle tier of the existing mission timing ladder (15 minutes).
  static const int kDefaultQuestDurationSeconds = 900;

  /// Validates one AI-provided duration: inside the bounds it is used
  /// as-is, anything else falls back to [kDefaultQuestDurationSeconds].
  static int sanitizeDuration(dynamic raw) {
    final seconds =
        raw is int
            ? raw
            : int.tryParse('${(raw is double) ? raw.round() : raw}');
    if (seconds == null ||
        seconds < kMinQuestDurationSeconds ||
        seconds > kMaxQuestDurationSeconds) {
      return kDefaultQuestDurationSeconds;
    }
    return seconds;
  }

  /// Generates 2–3 monster objectives + one harder boss objective for ANY
  /// rank gate in ONE request. Falls back to a fixed template dungeon
  /// whenever generation fails, so the dungeon is always playable
  /// (mirrors the graceful-fallback philosophy of AIQuestService).
  static Future<GeneratedDungeon> generateDungeon({
    required DungeonTemplate template,
  }) async {
    debugPrint(
      '⚔️ [Dungeon] Generating ${template.rankLetter}-Rank dungeon for '
      '${template.name}...',
    );
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json', 'X-User-Id': userId},
        body: jsonEncode({
          "model": _model,
          "messages": [
            {"role": "user", "content": _buildPrompt(template)},
          ],
        }),
      );

      debugPrint('[Dungeon] STATUS: ${response.statusCode}');
      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();

      final generated = _parse(jsonDecode(content), template);
      if (generated != null) {
        debugPrint('[Dungeon] MONSTERS: ${generated.monsters.length} + 1 boss');
        return generated;
      }
    } catch (e) {
      debugPrint('[Dungeon] GENERATION ERROR: $e');
    }
    debugPrint('[Dungeon] Using fallback dungeon for ${template.name}');
    return fallbackDungeon(template);
  }

  /// Dungeon-specific prompt built ENTIRELY from the template: difficulty
  /// label, the predefined monster pool (the AI must NOT invent names),
  /// the fixed boss name, the allowed objective types and the rank's
  /// target bounds. Structure mirrors AIQuestService's prompts: plain
  /// instruction text, an explicit JSON format example, safety rules and
  /// a "Return JSON only" closer. One request returns the story, the
  /// monsters' objectives AND the boss objective — all STRUCTURED
  /// ({type, target, unit, title, monster}) so tracking never has to
  /// interpret natural language.
  static String _buildPrompt(DungeonTemplate template) {
    final pool = template.monsters.map((m) => m.name).join(', ');
    final typeLines = template.difficulty.allowedTypes
        .map(
          (t) =>
              '- ${t.name == 'walkingDistance'
                  ? 'walking_distance'
                  : t.name == 'runningDistance'
                  ? 'running_distance'
                  : t.name}: today\'s ${t.label.toLowerCase()} '
              '(${_promptMeasure(t)})',
        )
        .join('\n');
    final targetLines = template.difficulty.allowedTypes
        .map((t) {
          final (mMin, mMax) = template.difficulty.targetRange(
            t,
            isBoss: false,
          );
          final (bMin, bMax) = template.difficulty.targetRange(t, isBoss: true);
          return '- ${_promptTypeKey(t)}: monsters ${_fmt(t, mMin)}-${_fmt(t, mMax)} '
              '${t.unit}, boss ${_fmt(t, bMin)}-${_fmt(t, bMax)} ${t.unit}';
        })
        .join('\n');
    final exampleMonster = template.monsters.first.name;
    final exampleSecond =
        template.monsters.length > 1 ? template.monsters[1].name : pool;

    return """
Generate a ${template.difficulty.label.toLowerCase()} fitness dungeon for a monster-hunter fitness app.

Dungeon: ${template.name} (${template.rankLetter}-Rank gate)
Difficulty: ${template.difficulty.label}.
Theme: ${template.theme}

Generate:
- A short 1-2 sentence story introducing the dungeon and its monsters.
- 2-3 monster objectives (each objective becomes one monster).
- ONE boss objective, HARDER than every monster objective.

Monster identity is FIXED — use ONLY these monster names (one per
objective, no repeats, no new names): $pool.
The boss is ALWAYS named "${template.boss.name}".

Objectives must be fitness related and ONLY use metrics the app tracks
automatically. Allowed objective types (use EXACTLY these type values,
nothing else):
$typeLines

Do NOT generate pushups, squats, burpees, plank, yoga, stretching, sleep
or any other type — the app cannot track those automatically.

Every objective must be a JSON object with EXACTLY these fields:
"monster" (one of the fixed monster names above),
"type" (one of the allowed types),
"target" (a number),
"unit" (matching the type),
"title" (short display text under 8 words, e.g. "Drink 2L Water"),
"durationSeconds" (the quest timer length in whole seconds, between 60 and 3600 — longer/harder objectives get longer timers).

Return ONLY JSON, no markdown:
{
  "story": "...",
  "objectives": [
    {"monster": "$exampleMonster", "type": "${_promptTypeKey(template.difficulty.allowedTypes.first)}", "target": 0, "unit": "${template.difficulty.allowedTypes.first.unit}", "title": "...", "durationSeconds": 600},
    {"monster": "$exampleSecond", "type": "water", "target": 2000, "unit": "ml", "title": "Drink 2L Water", "durationSeconds": 300}
  ],
  "boss": {"monster": "${template.boss.name}", "type": "walking_distance", "target": 2, "unit": "km", "title": "Walk 2 km"}
}

Target rules (objectives must be possible within one day):
$targetLines

Rules:
- 2 or 3 monster objectives, plus exactly 1 boss objective
- The boss objective must be harder than every monster objective
- Safe activities only, scaled to the ${template.difficulty.label.toLowerCase()} difficulty
- No impossible objectives
- No medical advice
- Titles unique
Return JSON only.
""";
  }

  static String _promptTypeKey(DungeonObjectiveType type) => switch (type) {
    DungeonObjectiveType.walkingDistance => 'walking_distance',
    DungeonObjectiveType.runningDistance => 'running_distance',
    _ => type.name,
  };

  static String _promptMeasure(DungeonObjectiveType type) => switch (type) {
    DungeonObjectiveType.steps => 'step count',
    DungeonObjectiveType.water => 'water intake in ml',
    DungeonObjectiveType.walkingDistance => 'walking distance in km',
    DungeonObjectiveType.runningDistance => 'running distance in km',
    DungeonObjectiveType.calories => 'calories burned in kcal',
  };

  /// Whole numbers for counts, one decimal for km.
  static String _fmt(DungeonObjectiveType type, double value) =>
      type.unit == 'km' ? value.toStringAsFixed(1) : value.toStringAsFixed(0);

  /// Validates AI output into a playable dungeon. Mirrors AIQuestService's
  /// defensive parsing: anything malformed is skipped, duplicates are
  /// dropped, and counts are clamped to the contract (2–3 monsters, 1
  /// boss). Monster NAMES are sanitized onto the template's predefined
  /// pool — the AI never controls monster identity. Returns null when the
  /// monster set itself is unusable so the caller falls back to the
  /// always-valid template dungeon.
  static GeneratedDungeon? _parse(dynamic raw, DungeonTemplate template) {
    if (raw is! Map) return null;

    final story = (raw['story'] ?? '').toString().trim();
    final monsters = _parseObjectives(
      raw['objectives'],
      isBoss: false,
      template: template,
    );
    if (monsters.isEmpty) return null;

    // The boss is parsed by the SAME code path as monster objectives —
    // only the isBoss flag and the harder target bounds differ.
    final boss =
        _parseObjectives(
          [raw['boss']],
          isBoss: true,
          template: template,
        ).firstOrNull ??
        fallbackBoss(template);
    return GeneratedDungeon(monsters: monsters, boss: boss, story: story);
  }

  /// The ONE objective parser — used for the monsters list and for the
  /// boss alike (identical structured format). Unsupported types are
  /// rejected outright, targets are clamped to the TEMPLATE's difficulty
  /// bounds, and duplicate titles are dropped.
  static List<DungeonObjective> _parseObjectives(
    dynamic raw, {
    required bool isBoss,
    required DungeonTemplate template,
  }) {
    if (raw is! List) return [];
    final seenTitles = <String>{};
    final objectives = <DungeonObjective>[];

    for (final item in raw) {
      if (objectives.length >= (isBoss ? 1 : 3)) break;
      if (item is! Map) continue;

      final title = (item['title'] ?? '').toString().trim();
      final type = DungeonObjectiveType.tryParse(
        (item['type'] ?? '').toString(),
      );
      final target = double.tryParse('${item['target']}');
      if (title.isEmpty || type == null || target == null) continue;
      // The template decides which types this rank may generate.
      if (!template.difficulty.allowedTypes.contains(type)) continue;
      if (!seenTitles.add(title.toLowerCase())) continue;

      objectives.add(
        DungeonObjective(
          title: title,
          type: type,
          target: _clampTarget(
            type,
            target,
            isBoss: isBoss,
            template: template,
          ),
          isBoss: isBoss,
          monster: _sanitizeMonster(
            item['monster'],
            isBoss,
            objectives.length,
            template,
          ),
          // Structured quest timer (monsters only — the boss keeps its
          // pure-progress completion). Validated here; invalid values use
          // the safe fallback, never another AI call.
          durationSeconds:
              isBoss ? 0 : sanitizeDuration(item['durationSeconds']),
        ),
      );
    }

    // Honor the 2–3 contract: a single lone monster objective is rejected
    // so the fallback dungeon (which is always valid) is used instead.
    if (!isBoss && objectives.length < 2) return [];
    return objectives;
  }

  /// Monster identity is APP-CONTROLLED: the boss always carries the
  /// template's boss name; monsters must come from the template pool —
  /// anything invented or missing is remapped onto the pool in order.
  static String _sanitizeMonster(
    dynamic raw,
    bool isBoss,
    int index,
    DungeonTemplate template,
  ) {
    if (isBoss) return template.boss.name;
    final name = (raw ?? '').toString().trim();
    if (template.hasMonster(name)) return template.monsterByName(name)!.name;
    final pool = template.monsters;
    return pool[index % pool.length].name;
  }

  /// Hard bounds come from the TEMPLATE's difficulty configuration — even
  /// if the AI ignores the prompt, objectives stay achievable at the
  /// gate's rank and are expressed in the type's canonical unit (the
  /// `unit` field itself is never trusted for tracking; type decides both
  /// the source and the unit).
  static double _clampTarget(
    DungeonObjectiveType type,
    double target, {
    required bool isBoss,
    required DungeonTemplate template,
  }) {
    final (min, max) = template.difficulty.targetRange(type, isBoss: isBoss);
    return target.clamp(min, max);
  }

  /// Fixed template dungeon used when AI generation fails (offline,
  /// outage, malformed output). Built from the template's OWN monster
  /// pool and difficulty bounds, so every rank always has a completable
  /// fallback with zero AI traffic.
  static GeneratedDungeon fallbackDungeon(DungeonTemplate template) {
    final types = template.difficulty.allowedTypes;
    final first = _fallbackObjective(
      types.first,
      template.monsters[0].name,
      template: template,
    );
    final second = _fallbackObjective(
      types.length > 1 ? types[1] : types.first,
      template.monsters[template.monsters.length > 1 ? 1 : 0].name,
      template: template,
    );
    return GeneratedDungeon(
      monsters: [first, second],
      boss: fallbackBoss(template),
      story:
          'Monsters stir beyond the gate. '
          'Defeat them all, hunter, then face their boss.',
    );
  }

  /// Boss used when the AI returns monsters but no usable boss objective
  /// (also covers dungeons persisted before the boss system existed).
  /// Identity is always the template's boss.
  static DungeonObjective fallbackBoss(DungeonTemplate template) {
    final types = template.difficulty.allowedTypes;
    final type =
        types.contains(DungeonObjectiveType.walkingDistance)
            ? DungeonObjectiveType.walkingDistance
            : types.first;
    final (min, max) = template.difficulty.targetRange(type, isBoss: true);
    final target = _rounded(type, (min + max) / 2);
    return DungeonObjective(
      title: _fallbackTitle(type, target),
      type: type,
      target: target,
      isBoss: true,
      monster: template.boss.name,
    );
  }

  static DungeonObjective _fallbackObjective(
    DungeonObjectiveType type,
    String monster, {
    required DungeonTemplate template,
  }) {
    final (min, max) = template.difficulty.targetRange(type, isBoss: false);
    final target = _rounded(type, (min + max) / 2);
    return DungeonObjective(
      title: _fallbackTitle(type, target),
      type: type,
      target: target,
      monster: monster,
      // Fallback dungeons still play the quest flow — same safe duration.
      durationSeconds: kDefaultQuestDurationSeconds,
    );
  }

  /// Whole numbers for counts, one decimal for km.
  static double _rounded(DungeonObjectiveType type, double value) =>
      type.unit == 'km'
          ? (value * 10).roundToDouble() / 10
          : value.roundToDouble();

  static String _fallbackTitle(DungeonObjectiveType type, double target) {
    final shown =
        type.unit == 'km'
            ? target.toStringAsFixed(1)
            : target.toStringAsFixed(0);
    return switch (type) {
      DungeonObjectiveType.steps => 'Walk $shown Steps',
      DungeonObjectiveType.water => 'Drink $shown ml Water',
      DungeonObjectiveType.walkingDistance => 'Walk $shown km',
      DungeonObjectiveType.runningDistance => 'Run $shown km',
      DungeonObjectiveType.calories => 'Burn $shown kcal',
    };
  }
}
