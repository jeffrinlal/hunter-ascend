import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ── Data model ────────────────────────────────────────────────────────────

/// A single logged food entry (one meal/snack item) for the calorie tracker.
///
/// Backed by the `calorie_logs` Firestore collection; [toMap]/[fromMap]
/// define that wire format. Immutable so list rebuilds stay cheap.
class MealEntry {
  final String? id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime time;

  MealEntry({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.time,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'time': Timestamp.fromDate(time),
  };

  factory MealEntry.fromMap(Map<String, dynamic> m) => MealEntry(
    name: m['name'] ?? '',
    calories: m['calories'] ?? 0,
    protein: (m['protein'] ?? 0).toDouble(),
    carbs: (m['carbs'] ?? 0).toDouble(),
    fat: (m['fat'] ?? 0).toDouble(),
    time: (m['time'] as Timestamp).toDate(),
  );
}

// ── AI Service ────────────────────────────────────────────────────────────

/// Estimates nutrition for a food (by text or photo) via the AI worker proxy.
///
/// Tries Gemini first, then falls back to Groq, so a single provider outage
/// doesn't break logging. Keys live server-side; this only sends input and
/// parses the returned JSON into a [MealEntry] (null if both providers fail).
class CalorieAIService {
  // ── Text: Gemini first, Groq fallback ────────────────────────────────
  /// Estimates nutrition from a free-text description (e.g. "2 idli").
  /// Gemini first, Groq fallback. Returns null if both fail.
  static Future<MealEntry?> analyzeText(String foodName) async {
    try {
      final result = await _geminiText(foodName);
      if (result != null) return result;
    } catch (e) {
      debugPrint("GEMINI ERROR: $e");
    }

    try {
      final result = await _groqText(foodName);
      if (result != null) return result;
    } catch (e) {
      debugPrint("GROQ ERROR: $e");
    }
    return null;
  }

  // ── Photo: Gemini first, Groq fallback ───────────────────────────────
  /// Estimates nutrition from a base64 meal photo.
  /// Gemini first, Groq fallback. Returns null if both fail.
  static Future<MealEntry?> analyzePhoto(String base64Image) async {
    try {
      final result = await _geminiPhoto(base64Image);
      if (result != null) return result;
    } catch (e) {
      debugPrint("GEMINI PHOTO ERROR: $e");
    }

    try {
      final result = await _groqPhoto(base64Image);
      if (result != null) return result;
    } catch (e) {
      debugPrint("GROQ PHOTO ERROR: $e");
    }

    return null;
  }

  // ── Shared prompt builder (text) ───────────────────────────────────────
  static String _buildTextPrompt(String foodName) => '''
You are a nutrition expert. The user will describe a meal in ANY way — casual language, abbreviations, typos, regional/local dish names, multiple items in one sentence, or vague descriptions with no quantity given.

User input: "$foodName"

Rules:
- If no quantity is given, assume one standard serving.
- If multiple foods are mentioned, sum their totals into one combined meal.
- If the food name is misspelled or informal (e.g. "chiken", "dosa", "maggi"), still identify it correctly using your best judgment.
- If it's a regional/local dish you don't have exact data for, estimate using typical ingredients and portion size.
- Never refuse, never ask a clarifying question — always make your best estimate no matter how vague the input is.

Return ONLY valid JSON, nothing else, no markdown fences, no explanation, no extra text before or after:
{"name":"food name","calories":0,"protein":0,"carbs":0,"fat":0}
''';

  static const String _photoPrompt = '''
Identify the food in this image and estimate its nutritional content as accurately as possible, even if the photo is unclear, partially obscured, or contains multiple food items (sum them into one combined meal).

Never refuse — always make your best estimate.

Return ONLY valid JSON, nothing else, no markdown fences, no explanation:
{"name":"food name","calories":0,"protein":0,"carbs":0,"fat":0}
''';

  // ── Gemini Text ───────────────────────────────────────────────────────
  static Future<MealEntry?> _geminiText(String foodName) async {

    final url = Uri.parse(
        'https://hunter-ascend-ai.jefferinlal.workers.dev/gemini-text'
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id':
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      },
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': _buildTextPrompt(foodName)}]}
        ],
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;
    return _parseGeminiResponse(response.body);
  }

  // ── Gemini Photo ──────────────────────────────────────────────────────
  static Future<MealEntry?> _geminiPhoto(String base64Image) async {

    final url = Uri.parse(
      'https://hunter-ascend-ai.jefferinlal.workers.dev/gemini-photo',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id':
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': _photoPrompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;
    return _parseGeminiResponse(response.body);
  }

  static MealEntry? _parseGeminiResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      final text =
      decoded['candidates'][0]['content']['parts'][0]['text'] as String;
      return _extractMealFromText(text);
    } catch (_) {
      return null;
    }
  }

  // ── Groq Text ─────────────────────────────────────────────────────────
  static Future<MealEntry?> _groqText(String foodName) async {

    final url = Uri.parse(
        'https://hunter-ascend-ai.jefferinlal.workers.dev/groq'
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id':
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      },
      body: jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': [
          {
            'role': 'user',
            'content': _buildTextPrompt(foodName),
          }
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;
    return _parseGroqResponse(response.body);
  }

  // ── Groq Photo ────────────────────────────────────────────────────────
  static Future<MealEntry?> _groqPhoto(String base64Image) async {

    final url = Uri.parse(
        'https://hunter-ascend-ai.jefferinlal.workers.dev/groq'
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id':
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                }
              },
              {
                'type': 'text',
                'text': _photoPrompt,
              }
            ]
          }
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;
    return _parseGroqResponse(response.body);
  }

  static MealEntry? _parseGroqResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      final text = decoded['choices'][0]['message']['content'] as String;
      return _extractMealFromText(text);
    } catch (_) {
      return null;
    }
  }

  // ── Shared robust JSON extraction ──────────────────────────────────────
  static MealEntry? _extractMealFromText(String text) {
    try {
      // Strip markdown fences if present
      String clean = text.replaceAll('```json', '').replaceAll('```', '').trim();

      // Pull out just the {...} block in case there's extra text around it
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(clean);
      if (match != null) clean = match.group(0)!;

      final data = jsonDecode(clean);
      return MealEntry(
        name: data['name']?.toString() ?? 'Unknown Food',
        calories: _toInt(data['calories']),
        protein: _toDouble(data['protein']),
        carbs: _toDouble(data['carbs']),
        fat: _toDouble(data['fat']),
        time: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ── Calorie Tracker Card Widget ───────────────────────────────────────────

/// The calorie-tracking surface embedded in the Nutrition screen: daily totals,
/// AI food logging (text/photo), today's meal list, and a banner ad.
class CalorieTrackerCard extends StatefulWidget {
  const CalorieTrackerCard({super.key});

  @override
  State<CalorieTrackerCard> createState() => _CalorieTrackerCardState();
}

class _CalorieTrackerCardState extends State<CalorieTrackerCard> {
  // ── Premium light palette (fixed) ─────────────────────────────────────
  static const Color _bg = Color(0xFFFAFAFA); // page / input background
  static const Color _card = Color(0xFFFFFFFF); // white card
  static const Color _blue = Color(0xFFFF6B2B); // protein accent (orange)
  static const Color _blueDim = Color(0xFFEFEFEF); // track / secondary surface
  static Color get _border =>
      const Color(0xFFFF6B2B).withOpacity(0.2); // tinted border
  static const Color _green = Color(0xFF34C759); // carbs
  static const Color _red = Color(0xFFFF5A5F); // fats / over-goal (coral)
  static const Color _orange = Color(0xFFFF6B2B); // brand accent
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF666666);
  static const Color _textTertiary = Color(0xFF999999);

  final TextEditingController _foodController = TextEditingController();
  bool _isLoading = false;
  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  // Collapsed meal sections (by category key).
  final Set<String> _collapsedMeals = {};

  // Meal categories in display order with their time windows.
  static const List<Map<String, String>> _mealCategories = [
    {'key': 'breakfast', 'emoji': '🌅', 'label': 'Breakfast'},
    {'key': 'midMorning', 'emoji': '🍎', 'label': 'Mid Morning Snack'},
    {'key': 'lunch', 'emoji': '🍱', 'label': 'Lunch'},
    {'key': 'eveningSnack', 'emoji': '🌆', 'label': 'Evening Snack'},
    {'key': 'dinner', 'emoji': '🍽️', 'label': 'Dinner'},
    {'key': 'lateNight', 'emoji': '🌙', 'label': 'Late Night'},
  ];

  // Cached streams so collapsing/expanding sections (setState) doesn't
  // re-subscribe and flicker. Same queries — created once.
  late final Stream<DocumentSnapshot> _hunterStream;
  late final Stream<List<MealEntry>> _mealsStream;

  // Auto-categorize a meal purely from the time it was logged.
  String _categoryForTime(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (m >= 360 && m < 630) return 'breakfast'; // 6:00–10:30
    if (m >= 630 && m < 750) return 'midMorning'; // 10:30–12:30
    if (m >= 750 && m < 930) return 'lunch'; // 12:30–15:30
    if (m >= 930 && m < 1110) return 'eveningSnack'; // 15:30–18:30
    if (m >= 1110) return 'dinner'; // 18:30–23:59
    return 'lateNight'; // 0:00–5:59
  }

  void loadBannerAd() {
    _bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.challengeBannerAdUnitId,
      onAdLoaded: (_) {
        if (mounted) {
          setState(() {
            _isBannerReady = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        debugPrint('Banner failed: $error');
      },
    );

    _bannerAd!.load();
  }

  @override
  void initState() {
    super.initState();
    loadBannerAd();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _hunterStream =
        FirebaseFirestore.instance.collection('hunters').doc(uid).snapshots();
    _mealsStream = _todayMealsStream();
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  // ── Get calorie goal from BMI ─────────────────────────────────────────
  // ── Get today's meals from Firestore ─────────────────────────────────
  Stream<List<MealEntry>> _todayMealsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    final today = DateTime.now().toString().substring(0, 10);

    return FirebaseFirestore.instance
        .collection('calorie_logs')
        .where('uid', isEqualTo: user.uid)
        .where('date', isEqualTo: today)
        .orderBy('time', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final meal = MealEntry.fromMap(d.data());
      return MealEntry(
        id: d.id,
        name: meal.name,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        time: meal.time,
      );
    }).toList());
  }

  // ── Save meal to Firestore ────────────────────────────────────────────
  Future<void> _saveMeal(MealEntry meal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateTime.now().toString().substring(0, 10);

    await FirebaseFirestore.instance.collection('calorie_logs').add({
      ...meal.toMap(),
      'uid': user.uid,
      'date': today,
    });
  }

  // ── Delete meal ───────────────────────────────────────────────────────
  Future<void> _deleteMeal(String docId) async {
    await FirebaseFirestore.instance
        .collection('calorie_logs')
        .doc(docId)
        .delete();
  }

  // ── Analyze text ─────────────────────────────────────────────────────
  Future<void> _analyzeText() async {
    final text = _foodController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    final meal = await CalorieAIService.analyzeText(text);

    setState(() => _isLoading = false);

    if (meal != null) {
      _foodController.clear();
      await _showConfirmDialog(meal, null);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✗ Could not analyze food. Try again.')),
        );
      }
    }
  }

  // ── Analyze photo ─────────────────────────────────────────────────────
  Future<void> _analyzePhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isLoading = true);

    final file = File(picked.path);
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 400,
      minHeight: 400,
      quality: 40,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) {
      setState(() => _isLoading = false);
      return;
    }

    final base64Image = base64Encode(compressed);
    final meal = await CalorieAIService.analyzePhoto(base64Image);

    setState(() => _isLoading = false);

    if (meal != null) {
      await _showConfirmDialog(meal, base64Image);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✗ Could not analyze photo. Try again.')),
        );
      }
    }
  }

  // ── Confirm dialog before saving ──────────────────────────────────────
  Future<void> _showConfirmDialog(MealEntry meal, String? imageBase64) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [BoxShadow(color: _orange.withOpacity(0.12), blurRadius: 24)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (imageBase64 != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(imageBase64),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withOpacity(0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 6),
                Text("AI ANALYSIS",
                    style: TextStyle(
                        color: _orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ]),
            ),
            const SizedBox(height: 16),
            Text(meal.name,
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _macroChip("${meal.calories}", "KCAL", _orange),
              _macroChip("${meal.protein.toStringAsFixed(1)}g", "PROTEIN", _blue),
              _macroChip("${meal.carbs.toStringAsFixed(1)}g", "CARBS", _green),
              _macroChip("${meal.fat.toStringAsFixed(1)}g", "FAT", _red),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: _blueDim,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border)),
                    child: Center(
                        child: Text("CANCEL",
                            style: TextStyle(
                                color: _textSecondary,
                                fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _saveMeal(MealEntry(
                      name: meal.name,
                      calories: meal.calories,
                      protein: meal.protein,
                      carbs: meal.carbs,
                      fat: meal.fat,
                      time: DateTime.now(),
                    ));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("✓ ${meal.name} logged!")),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: _orange, borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text("LOG MEAL",
                            style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _macroChip(String value, String label, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: _textSecondary, fontSize: 10, letterSpacing: 1)),
    ]);
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: _hunterStream,
      builder: (context, hunterSnap) {
        final hunterData =
            hunterSnap.data?.data() as Map<String, dynamic>? ?? {};
        final calorieGoal = calorieGoalFromData(hunterData);

        return StreamBuilder<List<MealEntry>>(
          stream: _mealsStream,
          builder: (context, mealSnap) {
            final meals = mealSnap.data ?? [];
            final totalCals = meals.fold(0, (sum, m) => sum + m.calories);
            final totalProtein = meals.fold(0.0, (sum, m) => sum + m.protein);
            final totalCarbs = meals.fold(0.0, (sum, m) => sum + m.carbs);
            final totalFat = meals.fold(0.0, (sum, m) => sum + m.fat);
            final progress = (totalCals / calorieGoal).clamp(0.0, 1.0);
            final remaining =
                (calorieGoal - totalCals) < 0 ? 0 : (calorieGoal - totalCals);
            final hunterName =
                (hunterData['hunterName'] ?? 'Hunter').toString();

            // Display-only macro targets derived from the calorie goal
            // (protein 30%, carbs 40%, fat 30%). Presentation only — no logic.
            final proteinGoal = (calorieGoal * 0.30 / 4).round();
            final carbsGoal = (calorieGoal * 0.40 / 4).round();
            final fatGoal = (calorieGoal * 0.30 / 9).round();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                // 1. Header
                _buildHeader(hunterName),
                const SizedBox(height: 20),
                // 2. Calorie ring card
                _buildCalorieRingCard(
                  totalCals: totalCals,
                  calorieGoal: calorieGoal,
                  remaining: remaining,
                  progress: progress,
                  protein: totalProtein,
                  proteinGoal: proteinGoal,
                  fat: totalFat,
                  fatGoal: fatGoal,
                  carbs: totalCarbs,
                  carbsGoal: carbsGoal,
                ),
                const SizedBox(height: 16),
                // 3. Food search + tips (card)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _foodController,
                            style: const TextStyle(
                                color: _textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Type food name...",
                              hintStyle: const TextStyle(
                                  color: _textSecondary, fontSize: 13),
                              filled: true,
                              fillColor: _bg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: _orange, width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _analyzeText(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Search button
                        GestureDetector(
                          onTap: _isLoading ? null : _analyzeText,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: _orange,
                                borderRadius: BorderRadius.circular(12)),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.search,
                                    color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Camera button
                        GestureDetector(
                          onTap:
                              _isLoading ? null : () => _showPhotoOptions(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: _orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _orange.withOpacity(0.4))),
                            child: const Icon(Icons.camera_alt,
                                color: _orange, size: 20),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "💡 FOOD SEARCH TIPS",
                              style: TextStyle(
                                color: _orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Examples: 2 idli • 100g chicken breast •"
                              " 3 eggs and 2 chapati •"
                              "1 bowl curd rice",
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "⚠️ AI estimates calories and macros. Results may vary.",
                              style: TextStyle(
                                color: _textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 4. Auto-categorized meals (by log time)
                _buildMealCategories(meals, mealSnap),
                const SizedBox(height: 20),
                // 5. Ad banner
                if (_isBannerReady)
                  Center(
                    child: SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            );
          },
        );
      },
    );
  }

  // ── Header: greeting ──────────────────────────────────────────────────
  Widget _buildHeader(String hunterName) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Hello $hunterName!",
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(color: _orange.withOpacity(0.06), blurRadius: 14),
        ],
      );

  // ── Calorie ring card ─────────────────────────────────────────────────
  Widget _buildCalorieRingCard({
    required int totalCals,
    required int calorieGoal,
    required int remaining,
    required double progress,
    required double protein,
    required int proteinGoal,
    required double fat,
    required int fatGoal,
    required double carbs,
    required int carbsGoal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _kcalSideInfo("Consumed", totalCals, _orange)),
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        backgroundColor: _blueDim,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? _red : _orange,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$totalCals",
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "of $calorieGoal kcal",
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                  child: _kcalSideInfo("Remaining", remaining, _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          // 3 macro bars side by side
          Row(
            children: [
              Expanded(
                  child: _macroBar("Protein", protein, proteinGoal, _orange)),
              const SizedBox(width: 12),
              Expanded(child: _macroBar("Fats", fat, fatGoal, _red)),
              const SizedBox(width: 12),
              Expanded(child: _macroBar("Carbs", carbs, carbsGoal, _green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kcalSideInfo(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$value",
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text("kcal",
            style: TextStyle(color: _textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: _textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _macroBar(String label, double value, int goal, Color color) {
    final pct = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: _blueDim,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text("${value.toStringAsFixed(0)}g / ${goal}g",
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildMealTile(MealEntry meal, AsyncSnapshot<List<MealEntry>> snap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.restaurant,
            color: _orange,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meal.name,
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(
              "${meal.protein.toStringAsFixed(0)}g P  •  ${meal.carbs.toStringAsFixed(0)}g C  •  ${meal.fat.toStringAsFixed(0)}g F",
              style: TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ]),
        ),
        Text("${meal.calories}",
            style: TextStyle(
                color: _orange, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text("kcal", style: TextStyle(color: _textSecondary, fontSize: 10)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            if (meal.id != null) {
              await _deleteMeal(meal.id!);
            }
          },
          child: Icon(Icons.delete_outline, color: _textTertiary, size: 18),
        ),
      ]),
    );
  }

  // ── Auto-categorized meal sections (grouped by each meal's log time) ──
  Widget _buildMealCategories(
      List<MealEntry> meals, AsyncSnapshot<List<MealEntry>> mealSnap) {
    final Map<String, List<MealEntry>> grouped = {
      for (final c in _mealCategories) c['key']!: <MealEntry>[]
    };
    for (final m in meals) {
      grouped[_categoryForTime(m.time)]!.add(m);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in _mealCategories)
          _buildMealSection(
            c['key']!,
            c['emoji']!,
            c['label']!,
            grouped[c['key']!]!,
            mealSnap,
          ),
      ],
    );
  }

  Widget _buildMealSection(String key, String emoji, String label,
      List<MealEntry> items, AsyncSnapshot<List<MealEntry>> snap) {
    final sectionTotal = items.fold(0, (s, m) => s + m.calories);
    final collapsed = _collapsedMeals.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tap to collapse / expand (no + button)
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedMeals.remove(key);
              } else {
                _collapsedMeals.add(key);
              }
            }),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Text("$emoji  $label",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
                Text("$sectionTotal kcal",
                    style: TextStyle(
                        color: _orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(
                  collapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: _textTertiary,
                  size: 22,
                ),
              ]),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: items.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text("No foods added",
                          style: TextStyle(
                              color: _textTertiary, fontSize: 13)),
                    )
                  : Column(
                      children:
                          items.map((m) => _buildMealTile(m, snap)).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Add Food Photo",
              style: TextStyle(
                  color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _analyzePhoto(ImageSource.camera);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _orange.withOpacity(0.4)),
                  ),
                  child: Column(children: [
                    Icon(Icons.camera_alt, color: _orange, size: 28),
                    SizedBox(height: 6),
                    Text("Camera",
                        style:
                        TextStyle(color: _orange, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _analyzePhoto(ImageSource.gallery);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _orange.withOpacity(0.4)),
                  ),
                  child: Column(children: [
                    Icon(Icons.photo_library, color: _orange, size: 28),
                    SizedBox(height: 6),
                    Text("Gallery",
                        style:
                        TextStyle(color: _orange, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
