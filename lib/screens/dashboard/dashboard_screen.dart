import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/widgets/dashboard/steps_card.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hunter_ascend/services/ai_quest_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:hunter_ascend/widgets/skeleton_loaders.dart';
import 'package:hunter_ascend/screens/map/map_screen.dart';
import 'package:hunter_ascend/screens/nutrition/nutrition_screen.dart';
import 'dart:typed_data';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/update_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:url_launcher/url_launcher.dart';


// ── Shield Rank Badge Painter ──────────────────────────────────────────────

/// Draws the rank shield badge behind a hunter's rank letter.
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

/// Compact rank-shield badge widget (wraps [RankShieldPainter]).
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

/// Home dashboard: hunter stats, steps, water, and daily/weekly missions.
/// The [questsOnly] flag renders the Missions-tab variant (missions only).
class DashboardScreen extends StatefulWidget {
  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;
  final List<Map<String, dynamic>> bioQuests;
  final bool questsOnly;

  const DashboardScreen({
    super.key,
    required this.fatLoss,
    required this.discipline,
    required this.muscleGain,
    required this.selfImprovement,
    this.bioQuests = const [],
    this.questsOnly = false,
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

  // ── Step reward / offset state (cached in memory) ────────
  // Loaded once during initStepCounter and refreshed on day change so we do
  // not issue a Firestore .get() on every pedometer event. The guard flag
  // ensures the +25 XP daily reward is granted at most once per day even if
  // several pedometer events arrive before Firestore finishes updating.
  bool _stepRewardGrantedToday = false;
  int _stepOffset = 0;
  String _stepOffsetDate = '';

  bool questStarted = false;
  String activeQuest = "";
  bool _isCompletingQuest = false;
  bool _isCompletingWeeklyQuest = false;
  bool _isRecoveringStreak = false;
  String? _cachedProfilePicData;
  Uint8List? _cachedProfileBytes;

  // ── Water intake ─────────────────────────────────────────
  int waterIntakeMl = 0;
  int selectedCupSize = 250;
  int waterGoalMl = 2000;

  // ── Weekly missions ──────────────────────────────────────
  List<Map<String, dynamic>> weeklyMissions = [];
  bool _weeklyLoading = false;
  bool weeklyQuestStarted = false;
  String weeklyActiveTitle = "";
  int weeklyQuestReward = 0;
  DateTime? weeklyQuestEndTime;
  Timer? _weeklyCountdownTimer;
  Duration weeklyQuestRemaining = Duration.zero;
  int questReward = 0;
  DateTime? questEndTime;
  Timer? _questCountdownTimer;
  Duration questRemaining = Duration.zero;
  Duration timeUntilReset = Duration.zero;
  Timer? countdownTimer;
  // The calendar day the missions are currently loaded for. Used by the
  // already-running per-minute countdown timer to detect a midnight rollover
  // and refresh today's missions exactly once when the day changes.
  String _missionDay = DateTime.now().toString().substring(0, 10);
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

    // Day rollover: when the calendar day changes, reload today's missions and
    // run the daily reset once. _missionDay is updated first so this never
    // fires more than once per day, even if the timer ticks again mid-refresh.
    final today = now.toString().substring(0, 10);
    if (today != _missionDay) {
      _missionDay = today;
      // Both DashboardScreen instances (Home + Missions) run this timer, so
      // gate the reload to the Missions tab — the only one that displays daily
      // missions. Without this, both instances would hit _loadAIQuests() at
      // midnight and generate AI quests twice (two AI calls + two Firestore
      // writes), since each reads aiQuestDate == yesterday before either write.
      if (widget.questsOnly) {
        _loadAIQuests().then((_) => checkDailyReset());
      }
    }
  }



  List<Map<String, dynamic>> generatedQuests = [];

  /// How long a generation lock is considered active before it's treated as
  /// stale (e.g. the holder crashed). After this duration, any caller may
  /// take ownership of the lock and retry generation.
  static const Duration _aiLockTimeout = Duration(minutes: 5);

  Future<void> _loadAIQuests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('hunters').doc(uid);
    final doc = await ref.get();

    if (!mounted) return;
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

    // Atomically acquire a timestamp-based generation lock. Only one caller
    // (across both DashboardScreen instances and across devices) can hold
    // the lock at a time. The lock stores the time generation started as a
    // Firestore Timestamp. If the lock is older than _aiLockTimeout, it is
    // treated as stale (holder crashed) and can be taken over.
    bool claimed = false;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final d = snap.data() ?? {};

      // Another caller already finished generation for today.
      if ((d['aiQuestDate'] ?? '') == today) {
        claimed = false;
        return;
      }

      // Check existing lock.
      final lockValue = d['aiQuestGeneratingAt'];
      if (lockValue != null) {
        DateTime? lockTime;
        if (lockValue is Timestamp) {
          lockTime = lockValue.toDate();
        }
        // If the lock is recent (within timeout), another caller is actively
        // generating — back off.
        if (lockTime != null &&
            DateTime.now().difference(lockTime) < _aiLockTimeout) {
          claimed = false;
          return;
        }
        // Lock is stale (older than timeout) — the holder crashed or timed
        // out. Take ownership by overwriting it below.
      }

      // Acquire the lock with the current timestamp.
      txn.update(ref, {'aiQuestGeneratingAt': Timestamp.now()});
      claimed = true;
    });

    if (!mounted) return;

    if (!claimed) {
      // Another instance is generating or already finished. Wait briefly for
      // it to complete, then re-read the saved quests.
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final refreshed = await ref.get();
      if (!mounted) return;
      final refreshedData = refreshed.data() ?? {};

      // Only load quests if generation has actually completed for today.
      // If the generator is still mid-call, Firestore still contains
      // yesterday's data — loading it would show stale quests.
      if ((refreshedData['aiQuestDate'] ?? '') != today) return;

      final quests = List<Map<String, dynamic>>.from(
        refreshedData['aiQuests'] ?? [],
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

    // We hold the lock. Call the AI. On success, AIQuestService writes
    // aiQuestDate + aiQuests to Firestore. On failure, we release the lock
    // so another caller can retry.
    try {
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

      if (!mounted) return;

      if (quests.isEmpty) {
        // AI returned nothing — release the lock so a retry can happen.
        await ref.update({'aiQuestGeneratingAt': FieldValue.delete()});
        return;
      }

      setState(() {
        generatedQuests = quests.map<Map<String, dynamic>>((q) {
          return {
            "name": q["title"],
            "xp": q["xp"],
            "icon": Icons.auto_awesome,
          };
        }).toList();
      });

      // Generation succeeded — AIQuestService already wrote aiQuestDate + aiQuests.
      // Clear the lock.
      await ref.update({'aiQuestGeneratingAt': FieldValue.delete()});

      // First time this user ever receives missions: record an immutable
      // discipline-start date (write-once). savedDate.isEmpty means the user has
      // never had missions generated before (a genuine new user), so existing
      // users — who already have an aiQuestDate — are never backfilled, and the
      // field is never written again once set.
      if (savedDate.toString().isEmpty && data['disciplineStartDate'] == null) {
        await ref.update({
          'disciplineStartDate': DateTime.now().toString().substring(0, 10),
        });
      }
    } catch (e) {
      debugPrint("_loadAIQuests generation failed: $e");
      // Release the lock so another caller (or a retry) can attempt generation.
      try {
        await ref.update({'aiQuestGeneratingAt': FieldValue.delete()});
      } catch (_) {}
    }
  }
  List<String> completedQuests = [];

  final TextEditingController customQuestController = TextEditingController();
  StreamSubscription<StepCount>? _stepSubscription;

  // ── Ads ──────────────────────────────────────────────────
  BannerAd? bannerAd;
  bool isBannerReady = false;
  BannerAd? weeklyBannerAd;
  bool weeklyBannerReady = false;
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
    if (!widget.questsOnly) {
      initStepCounter();
    }


    if (!widget.questsOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkBrokenStreak();
        checkDisciplinePunishment();
      });
    }

    loadHunterData().then((_) async {
      await _loadAIQuests();
      await checkDailyReset();
      if (!widget.questsOnly) await _maybeRequestReview();
    });
    _restoreDashboardActiveQuest();
    if (!widget.questsOnly) _loadWaterIntake();
    if (widget.questsOnly) _loadWeeklyMissions();
    if (widget.questsOnly) _restoreWeeklyActiveQuest();
    if (widget.questsOnly) loadWeeklyBannerAd();

    if (!widget.questsOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForAppUpdate();
      });
    }
  }

  @override
  void dispose() {
    _questCountdownTimer?.cancel();
    _weeklyCountdownTimer?.cancel();
    _stepSubscription?.cancel();
    countdownTimer?.cancel();

    bannerAd?.dispose();
    weeklyBannerAd?.dispose();
    rewardedAd?.dispose();
    punishmentAd?.dispose();
    customQuestController.dispose();
    super.dispose();
  }

  // ── Ads ──────────────────────────────────────────────────
  void loadBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;

    bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) => setState(() => isBannerReady = true),
      onAdFailedToLoad: (ad, error) { debugPrint("BANNER FAILED: $error"); ad.dispose(); },
    );
    bannerAd!.load();
  }

  void loadWeeklyBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;

    weeklyBannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) => setState(() => weeklyBannerReady = true),
      onAdFailedToLoad: (ad, error) {
        debugPrint("WEEKLY BANNER FAILED: $error");
        ad.dispose();
      },
    );
    weeklyBannerAd!.load();
  }

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-5435480116436845/4406856317',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { rewardedAd = ad; setState(() => isRewardedAdReady = true); },
        onAdFailedToLoad: (error) { debugPrint("REWARDED FAILED: $error"); isRewardedAdReady = false; },
      ),
    );
  }

  void loadPunishmentAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-5435480116436845/7002658082',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { punishmentAd = ad; setState(() => isPunishmentAdReady = true); },
        onAdFailedToLoad: (error) { debugPrint("PUNISHMENT AD FAILED: $error"); isPunishmentAdReady = false; },
      ),
    );
  }

  void showStreakRecoveryAd() async {
    if (_isRecoveringStreak) return;
    _isRecoveringStreak = true;
    try {
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
        final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
        await FirebaseFirestore.instance.runTransaction((txn) async {
          final snap = await txn.get(ref);
          final d = snap.data() ?? {};
          int curXp = (d['xp'] ?? 0) as int;
          curXp = (curXp - 100).clamp(0, 999999);
          txn.update(ref, {'xp': curXp});
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

    // Ad is available — Max members with remaining skips bypass it.
    final skipAd = await MembershipService.instance.shouldSkipRewardedAd();
    if (!mounted) return;
    if (skipAd) {
      await _grantStreakRecovery();
      return;
    }

    rewardedAd!.show(onUserEarnedReward: (ad, reward) async {
      await _grantStreakRecovery();
    });
    rewardedAd = null; isRewardedAdReady = false; loadRewardedAd();
    } catch (e) {
      debugPrint("showStreakRecoveryAd: $e");
    } finally {
      _isRecoveringStreak = false;
    }
  }

  /// Grants the streak recovery reward. Used by both the rewarded ad callback
  /// and the ad-skip path so the logic is never duplicated.
  Future<void> _grantStreakRecovery() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    final data = doc.data() as Map<String, dynamic>;
    final previousStreak = data['previousStreak'] ?? 0;
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
      'streak': previousStreak, 'previousStreak': 0, 'lastRecoveryDate': Timestamp.now(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🔥 Streak Restored ($previousStreak Days)")));
  }

  // ── Steps ────────────────────────────────────────────────
// ── Steps ────────────────────────────────────────────────
  Future<void> initStepCounter() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      return;
    }

    // Load today's step offset + reward state ONCE up front so the per-event
    // handler does not need a Firestore .get() on every pedometer event.
    await _loadStepState();

    _stepSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final today = DateTime.now().toString().substring(0, 10);

        // New day — save boot-count as today's offset and refresh reward state.
        if (_stepOffsetDate != today) {
          _stepOffset = event.steps;
          _stepOffsetDate = today;
          _stepRewardGrantedToday = false;
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'stepOffset': _stepOffset,
            'stepOffsetDate': today,
          });
        }

        final todayCount = (event.steps - _stepOffset).clamp(0, 999999);

        // Award XP at 10k. The in-memory guard is flipped synchronously before
        // the await, so any further events queued behind this one see it set
        // and cannot grant a second reward for the same day.
        if (todayCount >= 10000 && !_stepRewardGrantedToday) {
          _stepRewardGrantedToday = true;
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'xp': FieldValue.increment(25),
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
      onError: (error) => debugPrint("❌ Step counter error: $error"),
      cancelOnError: false,
    );
  }

  // Loads today's cached step offset + reward state from Firestore. Called once
  // during initialization (and effectively refreshed in-memory on day change),
  // replacing the previous per-event .get().
  Future<void> _loadStepState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toString().substring(0, 10);
    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};

    _stepOffset = data['stepOffset'] ?? 0;
    _stepOffsetDate = data['stepOffsetDate'] ?? '';
    _stepRewardGrantedToday = data['lastStepRewardDate'] == today;
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
    final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data() ?? {};
      int streak = data['streak'] ?? 0;
      String lastQuestDate = data['lastQuestDate'] ?? '';

      if (lastQuestDate.isEmpty) {
        streak = 1;
      } else {
        final parts = lastQuestDate.split('-');
        final lastDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final difference = today.difference(lastDate).inDays;
        if (difference == 0) return; // already updated today — no-op
        else if (difference == 1) streak++;
        else {
          txn.update(ref, {'previousStreak': streak});
          streak = 1;
        }
      }
      txn.update(ref, {'streak': streak, 'lastQuestDate': todayString});
    });
  }

  // ── Discipline ───────────────────────────────────────────
  Future<void> checkDisciplinePunishment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    // Genuine new users are not eligible for discipline until they have had a
    // real previous mission day. disciplineStartDate is the immutable first day
    // missions were received; discipline begins the day AFTER it (today must be
    // strictly past it). A missing field means a legacy/existing user, whose
    // behavior is left exactly as before.
    final disciplineStartDate = (data['disciplineStartDate'] ?? '').toString();
    if (disciplineStartDate.isNotEmpty && today.compareTo(disciplineStartDate) <= 0) return;
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
      int penalty = mode == 'strict' ? 20 : 5;
      final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      bool applied = false;
      await FirebaseFirestore.instance.runTransaction((txn) async {
        applied = false;
        final snap = await txn.get(ref);
        final d = snap.data() ?? {};
        // Re-check inside the transaction: if another client already applied
        // the penalty, skip to guarantee exactly-once-per-day semantics.
        if (d['lastPunishmentDate'] == today) return;
        int curXp = (d['xp'] ?? 0) as int;
        curXp = (curXp - penalty).clamp(0, 999999);
        txn.update(ref, {'xp': curXp, 'lastPunishmentDate': today});
        applied = true;
      });
      await loadHunterData();
      if (!mounted) return;
      if (!applied) return;
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
                "You failed yesterday's mission.\n\n-${mode == 'strict' ? 20 : 5} XP has been deducted.",
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
    // Max members with available skips bypass the ad entirely.
    final skipAd = await MembershipService.instance.shouldSkipRewardedAd();
    if (!mounted) return;
    if (skipAd) {
      await _grantPunishmentCompletion(user.uid, today);
      return;
    }

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => PopScope(
        // Strict Mode: block the Android hardware back button so the only way
        // to continue is to watch the rewarded ad. Casual stays dismissible.
        canPop: mode != 'strict',
        child: Dialog(
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
                  await _grantPunishmentCompletion(user.uid, today);
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
      ),
    );
  }

  /// Grants the punishment completion reward. Used by both the rewarded ad
  /// callback and the ad-skip path so the logic is never duplicated.
  Future<void> _grantPunishmentCompletion(String uid, String today) async {
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .update({'lastPunishmentDate': today});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Debt repaid. Continue your journey.")),
      );
    }
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
                    if (!mounted) return;
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
                          Text("Penalty only if zero missions done", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12)),
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
                    if (!mounted) return;
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
                          Text("Penalty if any mission is missed", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12)),
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

    if (!mounted) return;
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
                "MISSION REMINDER",
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Choose when to be reminded\nto complete your daily missions.",
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
        title: Text("START MISSION", style: TextStyle(color: _blue)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(questName, style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            const SizedBox(height: 16),
            Text("Choose a time to complete this mission", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12)),
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
                "⚠️ You must wait for the timer before you can complete this mission.",
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
    if (_isCompletingQuest) return;
    if (!await ConnectivityService.isOnline()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
      return;
    }
    _isCompletingQuest = true;
    try {
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
    final int reward = questReward; // capture before any state changes
    setState(() {
      questStarted = false; completedQuests.add(activeQuest);
    });

    // Persist XP/level atomically. The reward is applied to the LATEST Firestore
    // values inside a transaction (not stale local state), so newer XP from the
    // step reward, map run, or discipline penalty can never be overwritten.
    if (user != null) {
      final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      int newXp = xp;
      int newLevel = level;
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};
        int curXp = (data['xp'] ?? 0) as int;
        int curLevel = (data['level'] ?? 1) as int;
        final int startLevel = curLevel;
        curXp += reward;
        while (curXp >= 500) { curXp -= 500; curLevel++; }
        txn.update(ref, {'xp': curXp, 'level': curLevel});
        newXp = curXp;
        newLevel = curLevel;
        leveledUp = curLevel > startLevel;
      });
      if (mounted) setState(() { xp = newXp; level = newLevel; });
      else { xp = newXp; level = newLevel; }
    }
    await updateStreak(); await saveCompletedQuest(completedQuestName);

    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          Text("MISSION COMPLETE", style: TextStyle(color: _blue, fontSize: 24, fontWeight: FontWeight.bold)),
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
    } catch (e) {
      debugPrint("completeQuest: $e");
    } finally {
      _isCompletingQuest = false;
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
    if (!widget.questsOnly) await checkDisciplineMode();
  }

  // ── App Review prompt ────────────────────────────────────
  // Shows the native in-app review once, only after the user reaches a
  // 3-day streak (never on first launch), then records it in Firestore so
  // it never shows again.
  Future<void> _maybeRequestReview() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref =
          FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final streak = (data['streak'] ?? 0) as int;
      final alreadyRequested = data['reviewRequested'] == true;
      if (streak >= 3 && !alreadyRequested) {
        final inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        }
        await ref.update({'reviewRequested': true});
      }
    } catch (_) {
      // Review prompt is non-critical; ignore any failures.
    }
  }
  Future<void> _checkForAppUpdate() async {
    final update = await UpdateService.checkForUpdate();

    if (update == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !(update['forceUpdate'] ?? false),
      builder: (context) {
        return AlertDialog(
          title: Text(update['title'] ?? "Update Available"),
          content: Text(update['message'] ?? "A new version is available."),
          actions: [
            if (!(update['forceUpdate'] ?? false))
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Later"),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(
                  "https://play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend",
                );

                await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );

                if (!(update['forceUpdate'] ?? false) && mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Update Now"),
            ),
          ],
        );
      },
    );
  }

  Future<void> checkDailyReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    if ((data['lastQuestResetDate'] ?? '') == today) return;

    // Read yesterday's actual completed/total counts straight from Firestore
    // instead of local widget state — local state may already reflect TODAY's
    // regenerated quest list by the time this runs (see _loadAIQuests), and
    // relying on Firestore also avoids any mismatch between the Home tab's
    // and Missions tab's separate local copies of this data.
    final yesterdaysCompleted = List.from(data['completedQuests'] ?? []);
    final yesterdaysAiQuests = List.from(data['aiQuests'] ?? []);
    final customCount = (await FirebaseFirestore.instance.collection('custom_quests').where('uid', isEqualTo: user.uid).get()).docs.length;

    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
      'yesterdayCompletedCount': yesterdaysCompleted.length,
      'yesterdayTotalQuests': yesterdaysAiQuests.length + customCount,
      'completedQuests': [],
      'lastQuestResetDate': today,
    });
    if (!mounted) return;
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
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({'completedQuests': FieldValue.arrayUnion([questName]), 'questsDone': FieldValue.increment(1)});
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (!widget.questsOnly) ...[
                _buildTopBar(),
                const SizedBox(height: 20),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                  builder: (context, snap) {
                    final loading = !snap.hasData;
                    if (loading) return buildDashboardSkeleton();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHunterCard(),
                        const SizedBox(height: 16),
                        StepsCard(steps: todaySteps),
                        const SizedBox(height: 16),
                        _buildQuickActions(),
                        const SizedBox(height: 16),
                        _buildWaterCard(),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
              // Daily missions render only in the Missions tab (questsOnly),
              // not on the main Dashboard.
              if (widget.questsOnly) ...[
                if (questStarted) _buildActiveQuestCard(),
                _buildQuestsSection(),
                if (weeklyQuestStarted) _buildActiveWeeklyQuestCard(),
                _buildWeeklyMissionsSection(),
                const SizedBox(height: 30),
              ],
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
            stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
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

  // Decodes the profile-picture Base64 only when the data actually changes and
  // caches the result, so the avatar image is not re-decoded (and recreated) on
  // every StreamBuilder emission / parent rebuild.
  Uint8List _profilePicBytes(String base64Data) {
    if (base64Data != _cachedProfilePicData) {
      _cachedProfilePicData = base64Data;
      _cachedProfileBytes = base64Decode(base64Data);
    }
    return _cachedProfileBytes!;
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
                  stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final pic = data?['profilePicture'];
                    if (pic != null) {
                      return ClipOval(
                        child: Image.memory(
                          _profilePicBytes(pic),
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                        ),
                      );
                    }
                    return Center(
                      child: Icon(Icons.person, color: _blue, size: 40),
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

          // Level + XP — read live from the hunter document so XP/level update
          // immediately when Firestore changes, instead of using the local
          // fields which are only refreshed on (re)initialization.
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('hunters').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final liveXp = (data?['xp'] ?? xp) as int;
              final liveLevel = (data?['level'] ?? level) as int;
              return Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("LEVEL $liveLevel", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
                    Text("$liveXp / 500 XP", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
                  ]),

                  const SizedBox(height: 8),

                  // XP bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: liveXp / 500),
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
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Steps Card ───────────────────────────────────────────
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
        Text("⚡ ACTIVE MISSION ⚡", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
              questRemaining == Duration.zero ? "TIME'S UP!" : formatMinutesSeconds(questRemaining),
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
                const SnackBar(content: Text("⚠️ Timer not finished yet — mission cannot be completed.")),
              );
            } : () {
              showDialog(context: context, builder: (_) {
                final messages = [
                  "⚔️ Only you know whether this mission is complete.",
                  "🔥 Shortcuts create weak Hunters.",
                  "🏆 Discipline separates Hunters from legends.",
                  "⚡ Every completed mission should represent real effort.",
                ];
                messages.shuffle();
                return AlertDialog(
                  backgroundColor: HunterTheme.background,
                  title: const Text("Hunter Verification", style: TextStyle(color: Colors.amber)),
                  content: Text("Are you sure you completed this mission honestly?\n\nOnly you know the truth.\n\n${messages.first}", style: TextStyle(color: HunterTheme.textPrimary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("CONTINUE MISSION")),
                    ElevatedButton(onPressed: () { Navigator.pop(context); completeQuest(); }, child: const Text("COMPLETE")),
                  ],
                );
              });
            },
            child: Text("COMPLETE MISSION", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cancelActiveQuest,
          child: Text("Cancel mission", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, decoration: TextDecoration.underline)),
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
                        "DAILY MISSIONS (AI)",
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
                      '\u23f3 Resets in ${timeUntilReset.inHours}h ${timeUntilReset.inMinutes.remainder(60)}m',
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
                  Text("No missions yet", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text("Tap + to create your first custom mission.", textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textSecondary)),
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
                    title: const Text("Delete Mission?"),
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

  // ── Water intake (Firestore under hunters collection) ────
  Future<void> _loadWaterIntake() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef =
        FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final today = DateTime.now().toString().substring(0, 10);
    final savedDate = (data['waterIntakeDate'] ?? '').toString();
    final cup = ((data['selectedCupSize'] ?? 250) as num).toInt();
    final goal = ((data['waterGoalMl'] ?? 2000) as num).toInt();

    if (savedDate != today) {
      // New day → reset intake, keep cup size.
      await docRef.update({'waterIntakeMl': 0, 'waterIntakeDate': today});
      if (mounted) {
        setState(() {
          waterIntakeMl = 0;
          selectedCupSize = cup;
          waterGoalMl = goal;
        });
      }
    } else {
      final ml = ((data['waterIntakeMl'] ?? 0) as num).toInt();
      if (mounted) {
        setState(() {
          waterIntakeMl = ml;
          selectedCupSize = cup;
          waterGoalMl = goal;
        });
      }
    }
  }

  Future<void> _saveWaterIntake() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateTime.now().toString().substring(0, 10);
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
      'waterIntakeMl': waterIntakeMl,
      'waterIntakeDate': today,
    });
  }

  void _addWater() {
    setState(() => waterIntakeMl += selectedCupSize);
    _saveWaterIntake();
  }

  void _removeWater() {
    setState(() {
      final v = waterIntakeMl - selectedCupSize;
      waterIntakeMl = v < 0 ? 0 : v;
    });
    _saveWaterIntake();
  }

  void _setCupSize(int size) {
    setState(() => selectedCupSize = size);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({'selectedCupSize': size});
    }
  }

  Widget _waterCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HunterTheme.primary,
          boxShadow: [
            BoxShadow(
              color: HunterTheme.primary.withOpacity(0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _cupPill(int size) {
    final selected = selectedCupSize == size;
    return GestureDetector(
      onTap: () => _setCupSize(size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? HunterTheme.primary : HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HunterTheme.primary, width: 1.3),
        ),
        child: Text(
          '${size}ml',
          style: TextStyle(
            color: selected ? Colors.white : HunterTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showWaterGoalSheet() {
    final controller = TextEditingController(text: '$waterGoalMl');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HunterTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget presetPill(int v) {
              final selected = controller.text.trim() == '$v';
              return GestureDetector(
                onTap: () => setSheetState(() => controller.text = '$v'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        selected ? HunterTheme.primary : HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: HunterTheme.primary, width: 1.3),
                  ),
                  child: Text(
                    '${v}ml',
                    style: TextStyle(
                      color: selected ? Colors.white : HunterTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Daily Water Goal',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: HunterTheme.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2000',
                      hintStyle: TextStyle(color: HunterTheme.textTertiary),
                      suffixText: 'ml',
                      suffixStyle: TextStyle(color: HunterTheme.textSecondary),
                      filled: true,
                      fillColor: HunterTheme.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: HunterTheme.primary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: HunterTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Min 500 ml · Max 5000 ml',
                    style: TextStyle(
                        color: HunterTheme.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [1500, 2000, 2500, 3000].map(presetPill).toList(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HunterTheme.textSecondary,
                            side: BorderSide(
                                color:
                                    HunterTheme.textSecondary.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final entered =
                                int.tryParse(controller.text.trim()) ??
                                    waterGoalMl;
                            final clamped = entered < 500
                                ? 500
                                : (entered > 5000 ? 5000 : entered);
                            setState(() => waterGoalMl = clamped);
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              FirebaseFirestore.instance
                                  .collection('hunters')
                                  .doc(user.uid)
                                  .update({'waterGoalMl': clamped});
                            }
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HunterTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWaterCard() {
    final progress = (waterIntakeMl / waterGoalMl).clamp(0.0, 1.0);
    final dropCount = (waterGoalMl / selectedCupSize).ceil().clamp(1, 60).toInt();
    final filledDrops =
        (waterIntakeMl / selectedCupSize).floor().clamp(0, dropCount).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HunterTheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: HunterTheme.primary.withOpacity(0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '💧 WATER INTAKE',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '$waterIntakeMl ml / $waterGoalMl ml',
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showWaterGoalSheet,
                child: Icon(Icons.edit, size: 16, color: HunterTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(HunterTheme.primary),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              dropCount,
              (i) => Icon(
                Icons.water_drop,
                size: 20,
                color: i < filledDrops
                    ? HunterTheme.primary
                    : const Color(0xFFE0E0E0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _waterCircleButton(Icons.remove, _removeWater),
              const SizedBox(width: 24),
              Text(
                '$selectedCupSize ml',
                style: TextStyle(
                  color: HunterTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 24),
              _waterCircleButton(Icons.add, _addWater),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [150, 250, 350, 500].map(_cupPill).toList(),
          ),
        ],
      ),
    );
  }

  // ── Weekly missions (AI, reset every Monday 00:00) ───────
  Future<void> _loadWeeklyMissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef =
        FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final currentWeek = currentWeekId();
    final savedWeek = (data['weeklyMissionsDate'] ?? '').toString();
    final generated = data['weeklyMissionsGenerated'] == true;

    if (savedWeek == currentWeek &&
        generated &&
        data['weeklyMissions'] != null) {
      final list = (data['weeklyMissions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => weeklyMissions = list);
    } else {
      await _generateWeeklyMissions(data, currentWeek);
    }
  }

  Future<void> _generateWeeklyMissions(
      Map<String, dynamic> data, String currentWeek) async {
    if (mounted) setState(() => _weeklyLoading = true);

    final paths = <String>[];
    if (data['fatLoss'] == true || widget.fatLoss) paths.add('fat loss');
    if (data['muscleGain'] == true || widget.muscleGain) {
      paths.add('muscle gain');
    }
    if (data['discipline'] == true || widget.discipline) {
      paths.add('discipline');
    }
    if (data['selfImprovement'] == true || widget.selfImprovement) {
      paths.add('self improvement');
    }
    final goals = paths.isEmpty ? 'general fitness' : paths.join(', ');
    final lvl = ((data['level'] ?? 1) as num).toInt();

    final raw =
        await AIQuestService.generateWeeklyQuests(goals: goals, level: lvl);
    var missions = raw.take(3).map<Map<String, dynamic>>((q) {
      final m = q as Map;
      return {
        'title': (m['title'] ?? 'Weekly Mission').toString(),
        'completed': false,
        'xpReward': ((m['xp'] ?? 150) as num).toInt() * 3, // 3x daily
      };
    }).toList();

    if (missions.isEmpty) {
      missions = [
        {'title': 'Walk 25,000 steps this week', 'completed': false, 'xpReward': 450},
        {'title': 'Complete 4 workout sessions', 'completed': false, 'xpReward': 450},
        {'title': 'Sleep 7+ hours for 5 days', 'completed': false, 'xpReward': 450},
      ];
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({
        'weeklyMissions': missions,
        'weeklyMissionsDate': currentWeek,
        'weeklyMissionsGenerated': true,
      });
    }
    if (mounted) {
      setState(() {
        weeklyMissions = missions;
        _weeklyLoading = false;
      });
    }
  }

  void startWeeklyQuest(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text("START MISSION", style: TextStyle(color: _blue)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const SizedBox(height: 16),
            Text("Choose a time to complete this mission", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [2, 5, 10, 15, 30, 45, 60].map((mins) => ChoiceChip(
                label: Text("$mins min"),
                selected: false,
                onSelected: (_) {
                  Navigator.pop(context);
                  _startWeeklyQuestWithTimer(title, mins);
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
                "\u26a0\ufe0f You must wait for the timer before you can complete this mission.",
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

  void _startWeeklyQuestWithTimer(String title, int minutes) {
    final endTime = DateTime.now().add(Duration(minutes: minutes));
    int boostedReward;
    if (minutes >= 60)      boostedReward = 50;
    else if (minutes >= 45) boostedReward = 40;
    else if (minutes >= 30) boostedReward = 30;
    else if (minutes >= 15) boostedReward = 20;
    else if (minutes >= 10) boostedReward = 15;
    else if (minutes >= 5)  boostedReward = 10;
    else                    boostedReward = 5;
    boostedReward *= 3; // weekly missions reward 3x daily

    setState(() {
      weeklyQuestStarted = true;
      weeklyActiveTitle = title;
      weeklyQuestReward = boostedReward;
      weeklyQuestEndTime = endTime;
      weeklyQuestRemaining = Duration(minutes: minutes);
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeWeeklyMissionTitle': title,
        'activeWeeklyMissionXp': weeklyQuestReward,
        'activeWeeklyMissionEndTime': Timestamp.fromDate(endTime),
      });
    }

    _weeklyCountdownTimer?.cancel();
    _weeklyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (weeklyQuestEndTime == null) return;
      final diff = weeklyQuestEndTime!.difference(DateTime.now());
      setState(() => weeklyQuestRemaining = diff.isNegative ? Duration.zero : diff);
    });
  }

  Future<void> _cancelActiveWeeklyQuest() async {
    _weeklyCountdownTimer?.cancel();
    setState(() {
      weeklyQuestStarted = false;
      weeklyActiveTitle = "";
      weeklyQuestReward = 0;
      weeklyQuestEndTime = null;
      weeklyQuestRemaining = Duration.zero;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeWeeklyMissionTitle': FieldValue.delete(),
        'activeWeeklyMissionXp': FieldValue.delete(),
        'activeWeeklyMissionEndTime': FieldValue.delete(),
      });
    }
  }

  Future<void> _restoreWeeklyActiveQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final title = data['activeWeeklyMissionTitle'];
    final reward = data['activeWeeklyMissionXp'];
    final endTimeStamp = data['activeWeeklyMissionEndTime'] as Timestamp?;
    if (title == null) return;
    final endTime = endTimeStamp?.toDate();
    if (!mounted) return;
    setState(() {
      weeklyQuestStarted = true;
      weeklyActiveTitle = title;
      weeklyQuestReward = reward ?? 0;
      weeklyQuestEndTime = endTime;
      weeklyQuestRemaining = endTime == null ? Duration.zero : (endTime.isBefore(DateTime.now()) ? Duration.zero : endTime.difference(DateTime.now()));
    });
    if (endTime != null && endTime.isAfter(DateTime.now())) {
      _weeklyCountdownTimer?.cancel();
      _weeklyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (weeklyQuestEndTime == null) return;
        final diff = weeklyQuestEndTime!.difference(DateTime.now());
        setState(() => weeklyQuestRemaining = diff.isNegative ? Duration.zero : diff);
      });
    }
  }

  Future<void> completeWeeklyQuest() async {
    if (_isCompletingWeeklyQuest) return;
    if (!await ConnectivityService.isOnline()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
      return;
    }
    _isCompletingWeeklyQuest = true;
    try {
    bool leveledUp = false;
    _weeklyCountdownTimer?.cancel();
    final completedTitle = weeklyActiveTitle;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeWeeklyMissionTitle': FieldValue.delete(),
        'activeWeeklyMissionXp': FieldValue.delete(),
        'activeWeeklyMissionEndTime': FieldValue.delete(),
      });
    }
    final int reward = weeklyQuestReward; // capture before any state changes
    setState(() {
      weeklyQuestStarted = false;
      for (final m in weeklyMissions) {
        if (m['title'] == completedTitle) m['completed'] = true;
      }
    });

    // Persist XP/level atomically (see completeQuest): apply the reward to the
    // LATEST Firestore values in a transaction so newer XP from the step reward,
    // map run, or discipline penalty is never overwritten by stale local state.
    if (user != null) {
      final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      int newXp = xp;
      int newLevel = level;
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};
        int curXp = (data['xp'] ?? 0) as int;
        int curLevel = (data['level'] ?? 1) as int;
        final int startLevel = curLevel;
        curXp += reward;
        while (curXp >= 500) { curXp -= 500; curLevel++; }
        txn.update(ref, {'xp': curXp, 'level': curLevel});
        newXp = curXp;
        newLevel = curLevel;
        leveledUp = curLevel > startLevel;
      });
      if (mounted) setState(() { xp = newXp; level = newLevel; });
      else { xp = newXp; level = newLevel; }
      await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'weeklyMissions': weeklyMissions,
        'questsDone': FieldValue.increment(1),
      });
    }

    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          Text("MISSION COMPLETE", style: TextStyle(color: _blue, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("+$weeklyQuestReward XP", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
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
    } catch (e) {
      debugPrint("completeWeeklyQuest: $e");
    } finally {
      _isCompletingWeeklyQuest = false;
    }
  }

  Widget _buildActiveWeeklyQuestCard() {
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
        Text("\u26a1 ACTIVE MISSION \u26a1", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(
          weeklyQuestRemaining == Duration.zero ? "Status: Ready to Complete" : "Status: In Progress",
          style: TextStyle(color: weeklyQuestRemaining == Duration.zero ? HunterTheme.success : Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(weeklyActiveTitle, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Text("Reward: +$weeklyQuestReward XP", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _blueDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: weeklyQuestRemaining == Duration.zero ? HunterTheme.success.withOpacity(0.5) : _blue.withOpacity(0.4)),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(weeklyQuestRemaining == Duration.zero ? Icons.check_circle_outline : Icons.timer_outlined, color: weeklyQuestRemaining == Duration.zero ? HunterTheme.success : _blue, size: 22),
            const SizedBox(width: 10),
            Text(
              weeklyQuestRemaining == Duration.zero ? "TIME'S UP!" : formatMinutesSeconds(weeklyQuestRemaining),
              style: TextStyle(color: weeklyQuestRemaining == Duration.zero ? HunterTheme.success : HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ]),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: weeklyQuestRemaining == Duration.zero ? _blue : _blueDim, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: weeklyQuestRemaining != Duration.zero ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("\u26a0\ufe0f Timer not finished yet \u2014 mission cannot be completed.")),
              );
            } : () {
              showDialog(context: context, builder: (_) {
                final messages = [
                  "\u2694\ufe0f Only you know whether this mission is complete.",
                  "\ud83d\udd25 Shortcuts create weak Hunters.",
                  "\ud83c\udfc6 Discipline separates Hunters from legends.",
                  "\u26a1 Every completed mission should represent real effort.",
                ];
                messages.shuffle();
                return AlertDialog(
                  backgroundColor: HunterTheme.background,
                  title: const Text("Hunter Verification", style: TextStyle(color: Colors.amber)),
                  content: Text("Are you sure you completed this mission honestly?\n\nOnly you know the truth.\n\n${messages.first}", style: TextStyle(color: HunterTheme.textPrimary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("CONTINUE MISSION")),
                    ElevatedButton(onPressed: () { Navigator.pop(context); completeWeeklyQuest(); }, child: const Text("COMPLETE")),
                  ],
                );
              });
            },
            child: Text("COMPLETE MISSION", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cancelActiveWeeklyQuest,
          child: Text("Cancel mission", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, decoration: TextDecoration.underline)),
        ),
        if (weeklyBannerReady) ...[
          const SizedBox(height: 12),
          Center(child: SizedBox(width: weeklyBannerAd!.size.width.toDouble(), height: weeklyBannerAd!.size.height.toDouble(), child: AdWidget(ad: weeklyBannerAd!))),
        ],
      ]),
    );
  }

  Widget _buildWeeklyMissionsSection() {
    final completedCount = weeklyMissions.where((m) => m['completed'] == true).length;
    final total = weeklyMissions.isEmpty ? 3 : weeklyMissions.length;
    final reset = untilNextMonday();

    return Column(
      children: [
        Row(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text("WEEKLY MISSIONS (AI)", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                  child: Text("$completedCount/$total", style: TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: HunterTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '\u23f3 Resets in ${reset.inDays}d ${reset.inHours.remainder(24)}h ${reset.inMinutes.remainder(60)}m',
                  style: TextStyle(color: HunterTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 14),
        if (_weeklyLoading)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: HunterTheme.primary)))
        else if (weeklyMissions.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
            child: Column(children: [
              Icon(Icons.local_fire_department, color: _blue, size: 40),
              const SizedBox(height: 10),
              Text("No weekly missions yet", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          )
        else
          ...weeklyMissions.map((m) => _buildQuestTile(
            name: (m['title'] ?? '').toString(),
            xp: ((m['xpReward'] ?? 0) as num).toInt(),
            icon: Icons.local_fire_department,
            isCompleted: m['completed'] == true,
            isCustom: false,
            onTap: () => startWeeklyQuest((m['title'] ?? '').toString()),
          )),
      ],
    );
  }

  // ── Quick actions (Nutrition + Map) ──────────────────────
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _quickActionCard(
            icon: Icons.restaurant_menu,
            label: 'Nutrition',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NutritionScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickActionCard(
            icon: Icons.map,
            label: 'Map',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: HunterTheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: HunterTheme.primary.withOpacity(0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: HunterTheme.primary, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuestDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Custom Mission"),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: customQuestController, decoration: const InputDecoration(hintText: "Mission Name")),

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
            child: const Text("ADD MISSION"),
          ),
        ],
      ),
    );
  }
}