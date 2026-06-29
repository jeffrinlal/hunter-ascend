import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


/// Generates AI-personalized fitness missions via the Cloudflare Worker proxy.
///
/// All model API keys live server-side in the worker (never in the client),
/// so this service only sends the user's profile/goals and parses the JSON
/// the worker returns. Returns an empty list on any failure so callers can
/// fall back gracefully without crashing.
class AIQuestService {
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
    print("⚡ Generating AI Quests...");
    final bmi = weight / ((height / 100) * (height / 100));
    try {
      final response = await http.post(
        Uri.parse(
          'https://hunter-ascend-ai.jefferinlal.workers.dev/mistral',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': 'test-user',
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

Return JSON only.
"""
            }
          ]
        }),
      );

      print("STATUS: ${response.statusCode}");
      final data = jsonDecode(response.body);

      String content =
      data['choices'][0]['message']['content'];

      content = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final quests = jsonDecode(content);

      print("AI QUESTS:");
      print(quests);
      print("QUEST COUNT: ${quests.length}");
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

      print("✅ AI Quests Saved");

      return quests;


    } catch (e) {
      print("ERROR: $e");
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
    print("⚡ Generating AI Weekly Missions...");
    try {
      final response = await http.post(
        Uri.parse('https://hunter-ascend-ai.jefferinlal.workers.dev/mistral'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': 'test-user',
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
      print("AI WEEKLY MISSIONS: $missions");
      return missions is List ? missions : [];
    } catch (e) {
      print("WEEKLY ERROR: $e");
      return [];
    }
  }
}