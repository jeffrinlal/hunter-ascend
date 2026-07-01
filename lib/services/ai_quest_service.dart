import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


/// Generates AI-personalized fitness missions via the Cloudflare Worker proxy.
///
/// All model API keys live server-side in the worker (never in the client),
/// so this service only sends the user's profile/goals and parses the JSON
/// the worker returns. Returns an empty list on any failure so callers can
/// fall back gracefully without crashing.
class AIQuestService {
  // Prevents infinite retry loops when validating duplicate quest titles.
  static bool _isRetrying = false;

  /// Generates and persists the 6 daily AI missions for the current hunter.
  ///
  /// Tailors difficulty to the user's BMI/goals. Persisted to Firestore by the
  /// caller's flow; returns the parsed quest list (or `[]` if generation fails).
  static Future<List<dynamic>> generateQuests({
    required int level,
    required int streak,
    required double weight,
    required double height,
    required String goals,
  }) async {
    debugPrint("⚡ Generating AI Quests...");
    final bmi = weight / ((height / 100) * (height / 100));
    final String userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    try {
      final response = await http.post(
        Uri.parse(
          'https://hunter-ascend-ai.jefferinlal.workers.dev/mistral',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId,
        },
        body: jsonEncode({
          "model": "mistral-small-latest",
          "messages": [
            {
              "role": "user",
              "content": """
Generate exactly 6 daily quests.

Hunter Information:

Level: $level
Weight: $weight kg
Height: $height cm
BMI: ${bmi.toStringAsFixed(1)}
Current Streak: $streak days
Goals: $goals
Return ONLY JSON.

Format:
[
  {
    "title": "Walk 6000 Steps",
    "xp": 50,
    "category": "fitness"
  }
]

Rules:
- Safe quests only
- Max 10000 steps
- Max 60 minute workout
- No dangerous activities
- No medical advice
- No extreme exercise

Difficulty Rules:

Level 1-5:
- Beginner quests
- 3000-5000 steps
- 10-20 minute workouts

Level 6-10:
- Easy quests
- 5000-7000 steps
- 20-30 minute workouts

Level 11-20:
- Medium quests
- 7000-9000 steps
- 30-45 minute workouts

Level 21-30:
- Hard quests
- Up to 10000 steps
- Up to 60 minute workouts

Level 31+:
- Elite quests
- Maximum allowed difficulty
- More discipline and consistency challenges

- Match difficulty to hunter level
- Higher levels receive harder quests
- Include fitness, nutrition and discipline tasks
- No dangerous activities
- No medical advice
- All 6 quest titles MUST be unique — never generate duplicate titles

Return JSON only.
"""
            }
          ]
        }),
      );

      debugPrint("STATUS: ${response.statusCode}");
      final data = jsonDecode(response.body);

      String content =
      data['choices'][0]['message']['content'];

      content = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final quests = jsonDecode(content);

      debugPrint("AI QUESTS:");
      debugPrint(quests.toString());
      debugPrint("QUEST COUNT: ${quests.length}");

      // Validate: all quest titles must be unique. If the AI returned
      // duplicates, retry generation once rather than allow identical titles
      // (which would break name-based completion tracking).
      if (quests is List && quests.length > 1) {
        final titles = quests.map((q) => q['title']?.toString() ?? '').toSet();
        if (titles.length < quests.length) {
          debugPrint("⚠️ Duplicate quest titles detected — retrying generation");
          // Retry once. If the retry also has duplicates, accept them rather
          // than looping forever (prompt enforcement handles >99% of cases).
          if (!_isRetrying) {
            _isRetrying = true;
            final retryResult = await generateQuests(
              level: level, streak: streak, weight: weight, height: height, goals: goals,
            );
            _isRetrying = false;
            return retryResult;
          }
          _isRetrying = false;
        }
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .update({
        'aiQuestDate': DateTime.now()
            .toIso8601String()
            .split('T')
            .first,
        'aiQuests': quests,
      });

      debugPrint("✅ AI Quests Saved");

      return quests;


    } catch (e) {
      debugPrint("ERROR: $e");
      return [];
    }

  }

  // ── Weekly missions (harder, 7-day goals) ──────────────────────────────
  /// Generates the 3 harder weekly missions (reset every Monday).
  ///
  /// Separate from [generateQuests] because weekly goals use a different prompt
  /// (longer, tougher targets) and a 3× reward scale. Returns `[]` on failure.
  static Future<List<dynamic>> generateWeeklyQuests({
    required String goals,
    required int level,
  }) async {
    debugPrint("⚡ Generating AI Weekly Missions...");
    final String userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    try {
      final response = await http.post(
        Uri.parse('https://hunter-ascend-ai.jefferinlal.workers.dev/mistral'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId,
        },
        body: jsonEncode({
          "model": "mistral-small-latest",
          "messages": [
            {
              "role": "user",
              "content": """
Generate 3 challenging weekly fitness missions for someone focused on $goals. These should be harder goals achievable over 7 days. Keep each mission under 10 words.

Hunter level: $level

Return ONLY a JSON array, no markdown:
[
  {"title": "Run 10km this week", "xp": 150, "category": "fitness"}
]

Rules:
- Safe missions only
- No dangerous activities
- No medical advice
- Each mission is a 7-day goal (harder than a daily task)
"""
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];
      content =
          content.replaceAll('```json', '').replaceAll('```', '').trim();
      final missions = jsonDecode(content);
      debugPrint("AI WEEKLY MISSIONS: $missions");
      return missions is List ? missions : [];
    } catch (e) {
      debugPrint("WEEKLY ERROR: $e");
      return [];
    }
  }
}