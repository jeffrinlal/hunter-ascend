import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'Theme/hunter_theme.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_quest_service.dart';
import 'global_rankings_screen.dart';
import 'profile_screen.dart';
import 'duel_screen.dart';
import 'create_duel_screen.dart';
import 'duel_request_screen.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'map_screen.dart';
import 'nutrition_screen.dart';


// ── Shield Rank Badge Painter ──────────────────────────────────────────────

class RankShieldPainter extends CustomPainter {
  final String rank; // "E", "D", "C", "B", "A", "S"

  RankShieldPainter(this.rank);

  Color get _shieldFill {
    switch (rank) {
      case 'S': return HunterTheme.amberSurface;
      case 'A': return HunterTheme.redSurface;
      case 'B': return HunterTheme.amberSurface;
      case 'C': return HunterTheme.background;
      case 'D': return HunterTheme.greenSurface;
      default:  return HunterTheme.background; // E
    }
  }

  Color get _strokeColor {
    switch (rank) {
      case 'S': return HunterTheme.goldDeep;
      case 'A': return HunterTheme.redSurface;
      case 'B': return HunterTheme.amberSurface;
      case 'C': return HunterTheme.border;
      case 'D': return HunterTheme.greenSurface;
      default:  return HunterTheme.border; // E
    }
  }

  Color get _letterColor {
    switch (rank) {
      case 'S': return HunterTheme.gold;
      case 'A': return HunterTheme.danger;
      case 'B': return HunterTheme.primary;
      case 'C': return HunterTheme.primary;
      case 'D': return HunterTheme.success;
      default:  return HunterTheme.textSecondary; // E
    }
  }

  Color get _innerStroke {
    switch (rank) {
      case 'S': return HunterTheme.goldDark;
      case 'A': return HunterTheme.redSurface;
      case 'B': return HunterTheme.amberSurface;
      case 'C': return HunterTheme.border;
      case 'D': return HunterTheme.greenSurface;
      default:  return HunterTheme.border; // E
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shield outer path
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.5, h * 0.04);
    shieldPath.lineTo(w * 0.91, h * 0.17);
    shieldPath.lineTo(w * 0.91, h * 0.51);
    shieldPath.quadraticBezierTo(w * 0.91, h * 0.78, w * 0.5, h * 0.97);
    shieldPath.quadraticBezierTo(w * 0.09, h * 0.78, w * 0.09, h * 0.51);
    shieldPath.lineTo(w * 0.09, h * 0.17);
    shieldPath.close();

    // Fill shield
    canvas.drawPath(shieldPath, Paint()..color = _shieldFill);

    // Outer border
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = _strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = rank == 'S' || rank == 'A' ? 2.0 : 1.5,
    );

    // Inner shield bevel
    final innerPath = Path();
    innerPath.moveTo(w * 0.5, h * 0.11);
    innerPath.lineTo(w * 0.83, h * 0.23);
    innerPath.lineTo(w * 0.83, h * 0.51);
    innerPath.quadraticBezierTo(w * 0.83, h * 0.73, w * 0.5, h * 0.89);
    innerPath.quadraticBezierTo(w * 0.17, h * 0.73, w * 0.17, h * 0.51);
    innerPath.lineTo(w * 0.17, h * 0.23);
    innerPath.close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = _innerStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Top horizontal line
    _drawLine(canvas, w * 0.28, h * 0.28, w * 0.72, h * 0.28, _strokeColor, 0.8);

    // Side vertical lines (D rank and above)
    if (rank != 'E') {
      _drawLine(canvas, w * 0.21, h * 0.36, w * 0.21, h * 0.67, _strokeColor, 1.5);
      _drawLine(canvas, w * 0.79, h * 0.36, w * 0.79, h * 0.67, _strokeColor, 1.5);
    }

    // Bottom line (A, S)
    if (rank == 'A' || rank == 'S') {
      _drawLine(canvas, w * 0.28, h * 0.75, w * 0.72, h * 0.75, _strokeColor, 0.8);
    }

    // Corner rivets
    _drawRivet(canvas, w * 0.22, h * 0.21, _strokeColor, rank == 'S' || rank == 'A' ? 3.0 : 2.5);
    _drawRivet(canvas, w * 0.78, h * 0.21, _strokeColor, rank == 'S' || rank == 'A' ? 3.0 : 2.5);

    // Wing curls (B, A, S)
    if (rank == 'B' || rank == 'A' || rank == 'S') {
      final wingPaint = Paint()
        ..color = _strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = rank == 'S' ? 1.5 : 1.2
        ..strokeCap = StrokeCap.round;
      final leftWing = Path();
      leftWing.moveTo(w * 0.21, h * 0.46);
      leftWing.quadraticBezierTo(w * 0.1, h * 0.51, w * 0.21, h * 0.58);
      canvas.drawPath(leftWing, wingPaint);
      final rightWing = Path();
      rightWing.moveTo(w * 0.79, h * 0.46);
      rightWing.quadraticBezierTo(w * 0.9, h * 0.51, w * 0.79, h * 0.58);
      canvas.drawPath(rightWing, wingPaint);
    }

    // Star accent (C rank)
    if (rank == 'C') {
      _drawStar(canvas, w * 0.5, h * 0.19, 5, _strokeColor, filled: true);
    }

    // Crown (A, S)
    if (rank == 'A' || rank == 'S') {
      _drawCrown(canvas, w, h);
    }

    // Gold jewel dots on crown (S only)
    if (rank == 'S') {
      _drawRivet(canvas, w * 0.37, h * 0.105, _letterColor, 2.0);
      _drawRivet(canvas, w * 0.5,  h * 0.16,  _letterColor, 2.0);
      _drawRivet(canvas, w * 0.63, h * 0.105, _letterColor, 2.0);
    }

    // Rank letter
    final textPainter = TextPainter(
      text: TextSpan(
        text: rank,
        style: TextStyle(
          color: _letterColor,
          fontSize: w * 0.42,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, h * 0.42),
    );
  }

  void _drawLine(Canvas canvas, double x1, double y1, double x2, double y2, Color color, double width) {
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()..color = color..strokeWidth = width,
    );
  }

  void _drawRivet(Canvas canvas, double cx, double cy, Color color, double r) {
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, double cx, double cy, int points, Color color, {bool filled = false}) {
    final outerR = 6.0;
    final innerR = 3.0;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = filled ? PaintingStyle.fill : PaintingStyle.stroke);
  }

  void _drawCrown(Canvas canvas, double w, double h) {
    final crownPaint = Paint()
      ..color = _strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = rank == 'S' ? 1.8 : 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final crown = Path();
    crown.moveTo(w * 0.32, h * 0.17);
    crown.lineTo(w * 0.37, h * 0.10);
    crown.lineTo(w * 0.50, h * 0.16);
    crown.lineTo(w * 0.63, h * 0.10);
    crown.lineTo(w * 0.68, h * 0.17);
    canvas.drawPath(crown, crownPaint);
  }

  @override
  bool shouldRepaint(RankShieldPainter old) => old.rank != rank;
}

// ── Shield Widget ──────────────────────────────────────────────────────────

class RankShieldBadge extends StatelessWidget {
  final String rankLetter;
  final double size;

  const RankShieldBadge({super.key, required this.rankLetter, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.18),
      painter: RankShieldPainter(rankLetter),
    );
  }
}

// ── Dashboard Screen ───────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;
  final List<Map<String, dynamic>> bioQuests;

  const DashboardScreen({
    super.key,
    required this.fatLoss,
    required this.discipline,
    required this.muscleGain,
    required this.selfImprovement,
    this.bioQuests = const [],
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  // ── Colors ──────────────────────────────────────────────
  static Color get _bg => HunterTheme.background;
  static Color get _card => HunterTheme.cardColor;
  static Color get _blue => HunterTheme.primary;
  static Color get _blueDim => HunterTheme.border;
  static Color get _border => HunterTheme.border;
  // ── State ────────────────────────────────────────────────
  int xp = 0;
  int level = 1;
  int todaySteps = 0;
  bool questStarted = false;
  String activeQuest = "";
  int questReward = 0;
  DateTime? questEndTime;
  Timer? _questCountdownTimer;
  Duration questRemaining = Duration.zero;
  Duration timeUntilReset = Duration.zero;
  Timer? countdownTimer;
  void updateQuestCountdown() {
    final now = DateTime.now();

    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day + 1,
    );

    setState(() {
      timeUntilReset = tomorrow.difference(now);
    });
  }



  List<Map<String, dynamic>> generatedQuests = [];
  Future<void> _loadAIQuests() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .get();

    final data = doc.data() ?? {};

    final today = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;

    final savedDate = data['aiQuestDate'] ?? '';


    if (savedDate == today) {


      final quests = List<Map<String, dynamic>>.from(
        data['aiQuests'] ?? [],
      );

      setState(() {
        generatedQuests = quests.map<Map<String, dynamic>>((q) {
          return {
            "name": q["title"],
            "xp": q["xp"],
            "icon": Icons.auto_awesome,
          };
        }).toList();
      });

      return;
    }


    final hunter = doc.data()!;

    List<String> goals = [];

    if (hunter['fatLoss'] == true) goals.add('Fat Loss');
    if (hunter['discipline'] == true) goals.add('Discipline');
    if (hunter['muscleGain'] == true) goals.add('Muscle Gain');
    if (hunter['selfImprovement'] == true) goals.add('Self Improvement');

    final goalString = goals.join(', ');

    final quests = await AIQuestService.generateQuests(
      level: hunter['level'] ?? 1,
      streak: hunter['streak'] ?? 0,
      weight: (hunter['weight'] ?? 85).toDouble(),
      height: (hunter['height'] ?? 167).toDouble(),
      goals: goalString,
    );

    setState(() {
      generatedQuests = quests.map<Map<String, dynamic>>((q) {
        return {
          "name": q["title"],
          "xp": q["xp"],
          "icon": Icons.auto_awesome,
        };
      }).toList();
    });
  }
  List<String> completedQuests = [];

  final TextEditingController customQuestController = TextEditingController();
  StreamSubscription<StepCount>? _stepSubscription;

  // ── Ads ──────────────────────────────────────────────────
  BannerAd? bannerAd;
  bool isBannerReady = false;
  RewardedAd? rewardedAd;
  bool isRewardedAdReady = false;
  RewardedAd? punishmentAd;
  bool isPunishmentAdReady = false;

  // ── Helpers ──────────────────────────────────────────────
  String get hunterRank {
    if (level >= 30) return "S RANK";
    if (level >= 20) return "A RANK";
    if (level >= 15) return "B RANK";
    if (level >= 10) return "C RANK";
    if (level >= 5)  return "D RANK";
    return "E RANK";
  }

  String get rankLetter {
    if (level >= 30) return "S";
    if (level >= 20) return "A";
    if (level >= 15) return "B";
    if (level >= 10) return "C";
    if (level >= 5)  return "D";
    return "E";
  }

  Color get rankColor {
    if (level >= 30) return HunterTheme.gold;
    if (level >= 20) return HunterTheme.danger;
    if (level >= 15) return HunterTheme.primary;
    if (level >= 10) return HunterTheme.primary;
    if (level >= 5)  return HunterTheme.success;
    return HunterTheme.textSecondary;
  }

  String getStreakTitle(int streak) {
    if (streak >= 100) return "👑 Shadow Monarch";
    if (streak >= 60)  return "⚔️ S-Rank Hunter";
    if (streak >= 30)  return "🏅 Elite Hunter";
    if (streak >= 14)  return "🎯 Dedicated Hunter";
    if (streak >= 7)   return "🔥 Consistent Hunter";
    if (streak >= 1)   return "🛡️ New Hunter";
    return "";
  }
  Future<String> generateUniqueHunterId() async {
    while (true) {
      final id = 'HA${100000 + math.Random().nextInt(900000)}';

      final existing = await FirebaseFirestore.instance
          .collection('hunters')
          .where('hunterId', isEqualTo: id)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return id;
      }
    }
  }

  // ── Init ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    updateQuestCountdown();

    countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => updateQuestCountdown(),
    );

    loadBannerAd();
    loadRewardedAd();
    loadPunishmentAd();
    initStepCounter();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkBrokenStreak();
      checkDisciplinePunishment();
    });

    loadHunterData().then((_) async {
      await _loadAIQuests();
      await checkDailyReset();
    });
    _restoreDashboardActiveQuest();
  }

  @override
  void dispose() {
    _questCountdownTimer?.cancel();
    _stepSubscription?.cancel();
    countdownTimer?.cancel();

    rewardedAd?.dispose();
    punishmentAd?.dispose();
    super.dispose();
  }

  // ── Ads ──────────────────────────────────────────────────
  void loadBannerAd() {
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5435480116436845/4995463929',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => isBannerReady = true),
        onAdFailedToLoad: (ad, error) { print("BANNER FAILED: $error"); ad.dispose(); },
      ),
    );
    bannerAd!.load();
  }

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-5435480116436845/4406856317',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { rewardedAd = ad; setState(() => isRewardedAdReady = true); },
        onAdFailedToLoad: (error) { print("REWARDED FAILED: $error"); isRewardedAdReady = false; },
      ),
    );
  }

  void loadPunishmentAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-5435480116436845/7002658082',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { punishmentAd = ad; setState(() => isPunishmentAdReady = true); },
        onAdFailedToLoad: (error) { print("PUNISHMENT AD FAILED: $error"); isPunishmentAdReady = false; },
      ),
    );
  }

  void showStreakRecoveryAd() async {
    if (!isRewardedAdReady || rewardedAd == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      final mode = data['disciplineMode'] ?? 'casual';

      if (mode == 'strict') {
        int currentXp = data['xp'] ?? 0;

        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .update({
          'xp': (currentXp - 100).clamp(0, 999999),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ Ad unavailable. -100 XP penalty applied.",
              ),
            ),
          );
        }
      }

      return;
    }
    rewardedAd!.show(onUserEarnedReward: (ad, reward) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
      final data = doc.data() as Map<String, dynamic>;
      final previousStreak = data['previousStreak'] ?? 0;
      await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'streak': previousStreak, 'previousStreak': 0, 'lastRecoveryDate': Timestamp.now(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🔥 Streak Restored ($previousStreak Days)")));
    });
    rewardedAd = null; isRewardedAdReady = false; loadRewardedAd();
  }

  // ── Steps ────────────────────────────────────────────────
// ── Steps ────────────────────────────────────────────────
  Future<void> initStepCounter() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      return;
    }

    _stepSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final today = DateTime.now().toString().substring(0, 10);
        final doc = await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .get();
        final data = doc.data() ?? {};

        int offset = data['stepOffset'] ?? 0;
        String offsetDate = data['stepOffsetDate'] ?? '';

        // New day — save boot-count as today's offset
        if (offsetDate != today) {
          offset = event.steps;
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'stepOffset': offset,
            'stepOffsetDate': today,
          });
        }

        final todayCount = (event.steps - offset).clamp(0, 999999);

        // Award XP at 10k
        if (todayCount >= 10000 && data['lastStepRewardDate'] != today) {
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'xp': (data['xp'] ?? 0) + 25,
            'lastStepRewardDate': today,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("🏆 Daily Step Goal Complete! +25 XP")),
            );
          }
        }
        if (!mounted) return;

        setState(() => todaySteps = todayCount);
      },
      onError: (error) => print("❌ Step counter error: $error"),
      cancelOnError: false,
    );
  }
  // ── Streak ───────────────────────────────────────────────
  Future<void> checkBrokenStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final lastRecoveryDate = data['lastRecoveryDate'];
    if (lastRecoveryDate != null) {
      final daysSinceRecovery = DateTime.now().difference((lastRecoveryDate as Timestamp).toDate()).inDays;
      if (daysSinceRecovery < 3) return;
    }
    final streak = data['streak'] ?? 0;
    final lastQuestDate = data['lastQuestDate'] ?? '';
    if (streak == 0 || lastQuestDate.isEmpty) return;
    final parts = lastQuestDate.split('-');
    final lastDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    if (DateTime.now().difference(lastDate).inDays <= 1) return;
    if (!mounted) return;
    final mode = data['disciplineMode'] ?? 'casual';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🔥 STREAK BROKEN"),
        content: Text(
          "Previous Streak: $streak Days\n\nWatch an ad to restore it?",
        ),
        actions: [
          if (mode != 'strict')
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ACCEPT LOSS"),
            ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showStreakRecoveryAd();
            },
            child: const Text("WATCH AD"),
          ),
        ],
      ),
    );
  }

  Future<void> updateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    final data = doc.data() as Map<String, dynamic>;
    int streak = data['streak'] ?? 0;
    String lastQuestDate = data['lastQuestDate'] ?? '';
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";
    if (lastQuestDate.isEmpty) {
      streak = 1;
    } else {
      final parts = lastQuestDate.split('-');
      final lastDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final difference = today.difference(lastDate).inDays;
      if (difference == 0) return;
      else if (difference == 1) streak++;
      else {
        await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({'previousStreak': streak});
        streak = 1;
      }
    }
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({'streak': streak, 'lastQuestDate': todayString});
  }

  // ── Discipline ───────────────────────────────────────────
  Future<void> checkDisciplinePunishment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    if (data['lastPunishmentDate'] == today) return;
    final mode = data['disciplineMode'] ?? 'casual';
    final lastReset = data['lastQuestResetDate'];
    if (lastReset == null || lastReset.toString().isEmpty) return;
    final completed = data['yesterdayCompletedCount'] ?? 0;
    final total = data['yesterdayTotalQuests'] ?? 0;

// New user or no quests set up yet — skip punishment
    if (total == 0) return;

    bool punish = mode == 'casual' ? completed == 0 : completed < total;
    if (!punish) return;

    if (!mounted) return;

// ── Ad not available → deduct XP once ──
    if (!isPunishmentAdReady || punishmentAd == null) {
      int currentXp = data['xp'] ?? 0;
      int penalty = mode == 'strict' ? 100 : 25;
      currentXp = (currentXp - penalty).clamp(0, 999999);
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({'xp': currentXp, 'lastPunishmentDate': today});
      await loadHunterData();
      if (!mounted) return;
      showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HunterTheme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded, color: HunterTheme.danger, size: 48),
              const SizedBox(height: 16),
              Text("DISCIPLINE FAILURE",
                  style: TextStyle(color: HunterTheme.danger, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text(
                "You failed yesterday's mission.\n\n-${mode == 'strict' ? 100 : 25} XP has been deducted.",
                textAlign: TextAlign.center,
                style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: HunterTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text("ACCEPT",
                        style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
      return;
    }

// ── Ad available → must watch, no escape ──
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [BoxShadow(color: HunterTheme.danger.withValues(alpha: 0.1), blurRadius: 24)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HunterTheme.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(Icons.warning_amber_rounded, color: HunterTheme.danger, size: 32),
            ),
            const SizedBox(height: 16),
            Text("DISCIPLINE FAILURE",
                style: TextStyle(color: HunterTheme.danger, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text(
              "You failed yesterday's mission.\n\nWatch the full ad to repay your debt.\nThere is no other way.",
              textAlign: TextAlign.center,
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                bool rewardEarned = false;
                punishmentAd!.fullScreenContentCallback = FullScreenContentCallback(
                  onAdDismissedFullScreenContent: (ad) async {
                    ad.dispose();
                    punishmentAd = null;
                    isPunishmentAdReady = false;
                    loadPunishmentAd();
                    if (!rewardEarned) {
                      // Closed early — show popup again
                      await Future.delayed(const Duration(seconds: 1));
                      if (mounted) checkDisciplinePunishment();
                    }
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) async {
                    ad.dispose();
                    punishmentAd = null;
                    isPunishmentAdReady = false;
                    loadPunishmentAd();
                    // Ad failed — retry after delay
                    await Future.delayed(const Duration(seconds: 3));
                    if (mounted) checkDisciplinePunishment();
                  },
                );
                punishmentAd!.show(onUserEarnedReward: (ad, reward) async {
                  rewardEarned = true;
                  await FirebaseFirestore.instance
                      .collection('hunters')
                      .doc(user.uid)
                      .update({'lastPunishmentDate': today});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Debt repaid. Continue your journey.")),
                    );
                  }
                });
                punishmentAd = null;
                isPunishmentAdReady = false;
                loadPunishmentAd();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: HunterTheme.danger,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text("WATCH AD TO CONTINUE",
                      style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> checkDisciplineMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final mode = data['disciplineMode'];
    if (mode != null && mode.toString().isNotEmpty) return;
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 1), () { if (mounted) showDisciplineModeDialog(); });
  }

  Future<void> showDisciplineModeDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    final data = doc.data()!;
    final mode = data['disciplineMode'] ?? '';
    final changedAt = data['disciplineModeChangedAt'] as Timestamp?;
    bool locked = false; int remainingDays = 0;
    if (changedAt != null) {
      final daysPassed = DateTime.now().difference(changedAt.toDate()).inDays;
      locked = daysPassed < 30;
      if (locked) remainingDays = 30 - daysPassed;
    }
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HunterTheme.border, width: 1.5),
            boxShadow: [
              BoxShadow(color: HunterTheme.primary.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header icon ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HunterTheme.border,
                  shape: BoxShape.circle,
                  border: Border.all(color: HunterTheme.primary, width: 1.5),
                  boxShadow: [BoxShadow(color: HunterTheme.primary.withOpacity(0.3), blurRadius: 16)],
                ),
                child: Icon(Icons.shield, color: HunterTheme.primary, size: 32),
              ),
              const SizedBox(height: 16),

              // ── Title ──
              Text(
                "DISCIPLINE MODE",
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),

              if (mode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: HunterTheme.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Current: ${mode.toUpperCase()}",
                    style: TextStyle(color: HunterTheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Locked state ──
              if (locked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                  ),
                  child: Column(children: [
                    const Icon(Icons.lock, color: Colors.orange, size: 28),
                    const SizedBox(height: 8),
                    const Text("MODE LOCKED", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      "$remainingDays days remaining",
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HunterTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("UNDERSTOOD", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ]

              // ── Mode selection ──
              else ...[
                Text(
                  "Choose how hard you want to be pushed.\nThis locks for 30 days once set.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),

                // CASUAL card
                GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
                      'disciplineMode': 'casual',
                      'disciplineModeChangedAt': Timestamp.now(),
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HunterTheme.success.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HunterTheme.success.withOpacity(0.4), width: 1.2),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HunterTheme.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.spa, color: HunterTheme.success, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("CASUAL", style: TextStyle(color: HunterTheme.success, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                          SizedBox(height: 3),
                          Text("Penalty only if zero quests done", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12)),
                        ]),
                      ),
                      Icon(Icons.chevron_right, color: HunterTheme.success, size: 20),
                    ]),
                  ),
                ),

                const SizedBox(height: 10),

                // STRICT card
                GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
                      'disciplineMode': 'strict',
                      'disciplineModeChangedAt': Timestamp.now(),
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HunterTheme.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HunterTheme.danger.withOpacity(0.4), width: 1.2),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HunterTheme.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.bolt, color: HunterTheme.danger, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("STRICT", style: TextStyle(color: HunterTheme.danger, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                          SizedBox(height: 3),
                          Text("Penalty if any quest is missed", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12)),
                        ]),
                      ),
                      Icon(Icons.chevron_right, color: HunterTheme.danger, size: 20),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );;
  }

  // ── Notification Dialog ──────────────────────────────────
  Future<void> _showNotificationDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('hunters').doc(user.uid).get();
    final data = doc.data() ?? {};
    final currentTime = data['notificationTime'] ?? '';

    final options = [
      {
        'label': 'Morning',
        'sub': '8:00 AM',
        'icon': Icons.wb_sunny_outlined,
        'color': HunterTheme.gold,
        'hour': 8,
        'minute': 0,
      },
      {
        'label': 'Afternoon',
        'sub': '2:00 PM',
        'icon': Icons.wb_cloudy_outlined,
        'color': HunterTheme.primary,
        'hour': 14,
        'minute': 0,
      },
      {
        'label': 'Evening',
        'sub': '7:00 PM',
        'icon': Icons.nights_stay_outlined,
        'color': HunterTheme.purpleLight,
        'hour': 19,
        'minute': 0,
      },
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [
              BoxShadow(color: _blue.withValues(alpha: 0.15), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _blueDim,
                  shape: BoxShape.circle,
                  border: Border.all(color: _blue, width: 1.5),
                ),
                child: Icon(Icons.notifications_active, color: _blue, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                "QUEST REMINDER",
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Choose when to be reminded\nto complete your daily quests.",
                textAlign: TextAlign.center,
                style: TextStyle(color: HunterTheme.textTertiary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),

              // Time options
              ...options.map((opt) {
                final isSelected = currentTime == opt['label'];
                final color = opt['color'] as Color;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);

                    await FirebaseFirestore.instance
                        .collection('hunters')
                        .doc(user.uid)
                        .update({'notificationTime': opt['label']});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "🔔 Reminder set for ${opt['label']} (${opt['sub']})",
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.12)
                          : _bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.6)
                            : _border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(opt['icon'] as IconData, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              color: isSelected ? color : HunterTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            opt['sub'] as String,
                            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12),
                          ),
                        ]),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: color, size: 20),
                    ]),
                  ),
                );
              }),

              // Turn off button (only if active)
              if (currentTime.isNotEmpty) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseFirestore.instance
                        .collection('hunters')
                        .doc(user.uid)
                        .update({'notificationTime': ''});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("🔕 Reminders turned off")),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: HunterTheme.danger.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HunterTheme.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "TURN OFF REMINDERS",
                        style: TextStyle(
                          color: HunterTheme.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Quest logic ──────────────────────────────────────────
  void startQuest(String questName, int reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text("START QUEST", style: TextStyle(color: _blue)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(questName, style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            const SizedBox(height: 16),
            Text("Choose a time to complete this quest", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [2, 5, 10, 15, 30, 45, 60].map((mins) => ChoiceChip(
                label: Text("$mins min"),
                selected: false,
                onSelected: (_) {
                  Navigator.pop(context);
                  _startQuestWithTimer(questName, reward, mins);
                },
              )).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                "⚠️ You must wait for the timer before you can complete this quest.",
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ],
      ),
    );
  }

  void _startQuestWithTimer(String questName, int reward, int minutes) {
    final endTime = DateTime.now().add(Duration(minutes: minutes));
    int boostedReward;
    if (minutes >= 60)      boostedReward = 50;
    else if (minutes >= 45) boostedReward = 40;
    else if (minutes >= 30) boostedReward = 30;
    else if (minutes >= 15) boostedReward = 20;
    else if (minutes >= 10) boostedReward = 15;
    else if (minutes >= 5)  boostedReward = 10;
    else                    boostedReward = 5;

    setState(() {
      questStarted = true;
      activeQuest = questName;
      questReward = boostedReward;
      questEndTime = endTime;
      questRemaining = Duration(minutes: minutes);
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeDashboardQuestName': questName,
        'activeDashboardQuestXp': questReward,
        'activeDashboardQuestEndTime': Timestamp.fromDate(endTime),
      });
    }

    _questCountdownTimer?.cancel();
    _questCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (questEndTime == null) return;
      final diff = questEndTime!.difference(DateTime.now());
      setState(() => questRemaining = diff.isNegative ? Duration.zero : diff);
    });
  }

  String _formatQuestTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }


  Future<void> _cancelActiveQuest() async {
    _questCountdownTimer?.cancel();
    setState(() {
      questStarted = false;
      activeQuest = "";
      questReward = 0;
      questEndTime = null;
      questRemaining = Duration.zero;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeDashboardQuestName': FieldValue.delete(),
        'activeDashboardQuestXp': FieldValue.delete(),
        'activeDashboardQuestEndTime': FieldValue.delete(),
      });
    }
  }
  Future<void> _restoreDashboardActiveQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final name = data['activeDashboardQuestName'];
    final reward = data['activeDashboardQuestXp'];
    final endTimeStamp = data['activeDashboardQuestEndTime'] as Timestamp?;
    if (name == null) return;

    final endTime = endTimeStamp?.toDate();
    if (!mounted) return;

    setState(() {
      questStarted = true;
      activeQuest = name;
      questReward = reward ?? 0;
      questEndTime = endTime;
      questRemaining = endTime == null ? Duration.zero : (endTime.isBefore(DateTime.now()) ? Duration.zero : endTime.difference(DateTime.now()));
    });

    if (endTime != null && endTime.isAfter(DateTime.now())) {
      _questCountdownTimer?.cancel();
      _questCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (questEndTime == null) return;
        final diff = questEndTime!.difference(DateTime.now());
        setState(() => questRemaining = diff.isNegative ? Duration.zero : diff);
      });
    }
  }


  Future<void> completeQuest() async {
    bool leveledUp = false;
    _questCountdownTimer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeDashboardQuestName': FieldValue.delete(),
        'activeDashboardQuestXp': FieldValue.delete(),
        'activeDashboardQuestEndTime': FieldValue.delete(),
      });
    }
    final completedQuestName = activeQuest; // save before clearing
    setState(() {
      xp += questReward; questStarted = false; completedQuests.add(activeQuest);
      if (xp >= 500) { level++; xp -= 500; leveledUp = true; }
    });
    await updateHunterOnline(); await updateStreak(); await saveCompletedQuest(completedQuestName);

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          Text("QUEST COMPLETE", style: TextStyle(color: _blue, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("+$questReward XP", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () { if (context.mounted) Navigator.pop(context); });

    if (leveledUp) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => Scaffold(
          backgroundColor: HunterTheme.background,
          body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bolt, color: _blue, size: 140),
            const SizedBox(height: 30),
            Text("LEVEL UP", style: TextStyle(color: _blue, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 20),
            Text("LEVEL $level", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 28)),
          ])),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () { if (context.mounted) Navigator.pop(context); });
    }
  }

  Future<void> loadHunterData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    if (!mounted) return;
    setState(() {
      xp = data['xp'] ?? 0;
      level = data['level'] ?? 1;
      completedQuests = List<String>.from(data['completedQuests'] ?? []);
    });
    await checkDisciplineMode();
  }

  Future<void> checkDailyReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    if ((data['lastQuestResetDate'] ?? '') == today) return;
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
      'yesterdayCompletedCount': completedQuests.length,
      'yesterdayTotalQuests': generatedQuests.length + (await FirebaseFirestore.instance.collection('custom_quests').where('uid', isEqualTo: user.uid).get()).docs.length,
      'completedQuests': [],
      'lastQuestResetDate': today,
    });
    setState(() => completedQuests.clear());
  }

  Future<void> updateHunterOnline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({'level': level, 'xp': xp});
  }

  Future<void> saveCompletedQuest(String questName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({'completedQuests': FieldValue.arrayUnion([questName])});
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildTopBar(),
              const SizedBox(height: 20),
              _buildHunterCard(),
              const SizedBox(height: 16),
              _buildStepsCard(),
              const SizedBox(height: 24),
              if (questStarted) _buildActiveQuestCard(),
              _buildQuestsSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showNotificationDialog(),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('hunters')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasNotif = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                hasNotif = (data['notificationTime'] ?? '').toString().isNotEmpty;
              }
              return Stack(
                children: [
                  Icon(
                    hasNotif ? Icons.notifications_active : Icons.notifications_none,
                    color: hasNotif ? _blue : HunterTheme.textSecondary,
                    size: 24,
                  ),
                  if (hasNotif)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: HunterTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const Spacer(),
        RichText(
          text: TextSpan(children: [
            TextSpan(text: "HUNTER ", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
            TextSpan(text: "ASCEND", style: TextStyle(color: _blue, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
        const Spacer(),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
          builder: (context, snapshot) {
            int streak = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              streak = (snapshot.data!.data() as Map<String, dynamic>)['streak'] ?? 0;
            }
            return Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
              const SizedBox(width: 3),
              Text("$streak", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ]);
          },
        ),
      ],
    );
  }

  // ── Hunter Card ──────────────────────────────────────────
  Widget _buildHunterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.15), blurRadius: 20, spreadRadius: 1)],
      ),
      child: Column(
        children: [
          // Avatar row
          Row(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _blue, width: 2),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 16)],
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('hunters')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final pic = data?['profilePicture'];
                    if (pic != null) {
                      return ClipOval(
                        child: Image.memory(
                          base64Decode(pic),
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                        ),
                      );
                    }
                    return ClipOval(
                      child: Image.asset(
                        'assets/avatars/avatar_1.png',
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                  builder: (context, snapshot) {
                    String name = "Hunter";
                    if (snapshot.hasData && snapshot.data!.exists) {
                      name = (snapshot.data!.data() as Map<String, dynamic>)['hunterName'] ?? "Hunter";
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("$hunterRank HUNTER", style: TextStyle(color: rankColor, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ]);
                  },
                ),
              ),

              // ── Shield Badge replaces old rank badge ──
              RankShieldBadge(rankLetter: rankLetter, size: 56),
            ],
          ),

          const SizedBox(height: 16),

          // Level + XP
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("LEVEL $level", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
            Text("$xp / 500 XP", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
          ]),

          const SizedBox(height: 8),

          // XP bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: xp / 500),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: value, minHeight: 8,
                backgroundColor: _blueDim,
                valueColor: AlwaysStoppedAnimation<Color>(_blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Steps Card ───────────────────────────────────────────
  Widget _buildStepsCard() {
    final percent = ((todaySteps / 10000) * 100).clamp(0, 100).toInt();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.1), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.directions_walk, color: _blue, size: 20),
            ),
            const SizedBox(width: 10),
            Text("TODAY'S MISSION", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, letterSpacing: 1)),
            const Spacer(),
            Text("$percent%", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Text("10,000 STEPS", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (todaySteps / 10000).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: _blueDim,
              valueColor: AlwaysStoppedAnimation<Color>(_blue),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("$todaySteps / 10,000", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              todaySteps >= 10000 ? "🏆 Goal Completed! +25 XP" : "🎯 Keep going!",
              style: TextStyle(color: todaySteps >= 10000 ? Colors.amber : HunterTheme.textTertiary, fontSize: 12),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Active Quest Card ────────────────────────────────────
  Widget _buildActiveQuestCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue, width: 1.5),
        color: _card,
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.2), blurRadius: 16)],
      ),
      child: Column(children: [
        Text("⚡ ACTIVE QUEST ⚡", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(
          questRemaining == Duration.zero ? "Status: Ready to Complete" : "Status: In Progress",
          style: TextStyle(color: questRemaining == Duration.zero ? HunterTheme.success : Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(activeQuest, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Text("Reward: +$questReward XP", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _blueDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: questRemaining == Duration.zero ? HunterTheme.success.withOpacity(0.5) : _blue.withOpacity(0.4)),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(questRemaining == Duration.zero ? Icons.check_circle_outline : Icons.timer_outlined, color: questRemaining == Duration.zero ? HunterTheme.success : _blue, size: 22),
            const SizedBox(width: 10),
            Text(
              questRemaining == Duration.zero ? "TIME'S UP!" : _formatQuestTime(questRemaining),
              style: TextStyle(color: questRemaining == Duration.zero ? HunterTheme.success : HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ]),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: questRemaining == Duration.zero ? _blue : _blueDim, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: questRemaining != Duration.zero ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("⚠️ Timer not finished yet — quest cannot be completed.")),
              );
            } : () {
              showDialog(context: context, builder: (_) {
                final messages = [
                  "⚔️ Only you know whether this mission is complete.",
                  "🔥 Shortcuts create weak Hunters.",
                  "🏆 Discipline separates Hunters from legends.",
                  "⚡ Every completed quest should represent real effort.",
                ];
                messages.shuffle();
                return AlertDialog(
                  backgroundColor: HunterTheme.background,
                  title: const Text("Hunter Verification", style: TextStyle(color: Colors.amber)),
                  content: Text("Are you sure you completed this mission honestly?\n\nOnly you know the truth.\n\n${messages.first}", style: TextStyle(color: HunterTheme.textPrimary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("CONTINUE QUEST")),
                    ElevatedButton(onPressed: () { Navigator.pop(context); completeQuest(); }, child: const Text("COMPLETE")),
                  ],
                );
              });
            },
            child: Text("COMPLETE QUEST", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cancelActiveQuest,
          child: Text("Cancel quest", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, decoration: TextDecoration.underline)),
        ),
        if (isBannerReady) ...[
          const SizedBox(height: 12),
          Center(child: SizedBox(width: bannerAd!.size.width.toDouble(), height: bannerAd!.size.height.toDouble(), child: AdWidget(ad: bannerAd!))),
        ],
      ]),
    );
  }

  // ── Quests Section ───────────────────────────────────────
  Widget _buildQuestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('custom_quests').where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
      builder: (context, customSnapshot) {
        final customDocs = customSnapshot.data?.docs ?? [];
        final totalQuests = generatedQuests.length + customDocs.length;
        final completedCount = completedQuests.length;

        return Column(
          children: [
            // Header
            Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [
                      Text(
                        "DAILY QUESTS (AI)",
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _blueDim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$completedCount/$totalQuests",
                          style: TextStyle(
                            color: _blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: HunterTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⏳ ${timeUntilReset.inHours}h ${timeUntilReset.inMinutes.remainder(60)}m',
                      style: TextStyle(
                        color: HunterTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                builder: (context, snapshot) {
                  String mode = "MODE";
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    if (data['disciplineMode'] != null) mode = data['disciplineMode'].toString().toUpperCase();
                  }
                  return GestureDetector(
                    onTap: showDisciplineModeDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shield, size: 14, color: _blue),
                        const SizedBox(width: 4),
                        Text(mode, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11)),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAddQuestDialog(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                  child: Icon(Icons.add, color: _blue, size: 20),
                ),
              ),
            ]),

            const SizedBox(height: 14),

            if (totalQuests == 0)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Column(children: [
                  Icon(Icons.bolt, color: _blue, size: 40),
                  SizedBox(height: 10),
                  Text("No quests yet", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("Tap + to create your first custom quest.", textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textSecondary)),
                ]),
              ),

            // Generated quests
            ...generatedQuests.map((quest) => _buildQuestTile(
              name: quest["name"],
              xp: quest["xp"],
              icon: quest["icon"],
              isCompleted: completedQuests.contains(quest["name"]),
              isCustom: false,
              onTap: () => startQuest(quest["name"], quest["xp"]),
            )),

            // Custom quests
            ...customDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildQuestTile(
                name: data['name'],
                xp: data['xp'],
                icon: Icons.edit_note,
                isCompleted: completedQuests.contains(data['name']),
                isCustom: true,
                onTap: () => startQuest(data['name'], data['xp']),
                onDelete: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete Quest?"),
                    content: Text(data['name']),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                      ElevatedButton(onPressed: () async { await doc.reference.delete(); if (mounted) Navigator.pop(context); }, child: const Text("DELETE")),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildQuestTile({
    required String name,
    required int xp,
    required IconData icon,
    required bool isCompleted,
    required bool isCustom,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _card,
          border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.4) : (isCustom ? Colors.amber.withOpacity(0.4) : _border), width: 1.2),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.1) : (isCustom ? Colors.amber.withOpacity(0.1) : _blueDim),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isCompleted ? Colors.green : (isCustom ? Colors.amber : _blue), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCompleted ? "✓ $name" : name,
              style: TextStyle(color: isCompleted ? HunterTheme.textTertiary : HunterTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                  decoration: isCompleted ? TextDecoration.lineThrough : null),
            ),
          ),
          if (isCompleted)
            const Text("DONE", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child:Text("TAP TO START", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20)),
            ),
        ]),
      ),
    );
  }

  void _showAddQuestDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Custom Quest"),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: customQuestController, decoration: const InputDecoration(hintText: "Quest Name")),

          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (customQuestController.text.trim().isEmpty) return;
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              await FirebaseFirestore.instance.collection('custom_quests').add({
                'uid': user.uid, 'name': customQuestController.text.trim(),
                'xp': 0, 'createdAt': Timestamp.now(),
              });
              customQuestController.clear();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("ADD QUEST"),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ───────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 68 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: HunterTheme.background,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [


        _navItem(Icons.home_filled, true, () {}),

        _navItem(
          Icons.restaurant_menu,
          false,
              () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NutritionScreen(),
            ),
          ),
        ),

// Duel item continues here...

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('duel_requests')
              .where('toUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, duelReqSnapshot) {
            final hasPending = (duelReqSnapshot.data?.docs ?? []).isNotEmpty;
            return _navItem(Icons.sports_kabaddi, false, () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final duelSnapshot = await FirebaseFirestore.instance.collection('duels').where('participants', arrayContains: user.uid).limit(1).get();
              bool hasActiveDuel = false; String? duelId;
              if (duelSnapshot.docs.isNotEmpty) {
                final doc = duelSnapshot.docs.first; final data = doc.data();
                bool isPlayer1 = data['player1'] == user.uid;
                bool shouldShowResult = data['status'] == 'completed' && ((isPlayer1 && data['player1ViewedResult'] == false) || (!isPlayer1 && data['player2ViewedResult'] == false));
                if (data['status'] == 'active' || shouldShowResult) { hasActiveDuel = true; duelId = doc.id; }
              }
              if (hasActiveDuel) { Navigator.push(context, MaterialPageRoute(builder: (_) => DuelScreen(duelId: duelId!))); return; }
              final pendingRequest = await FirebaseFirestore.instance.collection('duel_requests').where('toUid', isEqualTo: user.uid).where('status', isEqualTo: 'pending').limit(1).get();
              if (pendingRequest.docs.isNotEmpty) { Navigator.push(context, MaterialPageRoute(builder: (_) => const DuelRequestScreen())); return; }
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDuelScreen()));
            }, hasDuelAlert: hasPending);
          },
        ),
        _navItem(Icons.leaderboard, false, () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GlobalRankingsScreen()),
        )),

        _navItem(Icons.map, false, () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        )),


        _navItem(Icons.person, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
      ]),
    );
  }

  Widget _navItem(IconData icon, bool active, VoidCallback onTap, {bool hasDuelAlert = false}) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: active ? _blue : HunterTheme.textTertiary, size: active ? 28 : 24),
          if (hasDuelAlert)
            Positioned(
              right: -4,
              top: -4,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                onEnd: () => setState(() {}),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HunterTheme.danger,
                    border: Border.all(color: HunterTheme.background, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: HunterTheme.danger.withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.bolt, color: HunterTheme.textPrimary, size: 7),
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }
}