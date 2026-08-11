import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/widgets/dashboard/pro_dashboard_layout.dart';
import 'package:hunter_ascend/widgets/dashboard/max_dashboard_layout.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/achievements_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:hunter_ascend/widgets/skeleton_loaders.dart';
import 'package:hunter_ascend/screens/map/map_screen.dart';
import 'package:hunter_ascend/screens/nutrition/nutrition_screen.dart';
import 'dart:typed_data';
import 'package:hunter_ascend/services/notification_service.dart';
import 'package:hunter_ascend/services/update_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/xp_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hunter_ascend/screens/dashboard/dashboard_screen.dart';
import 'package:hunter_ascend/screens/dashboard/missions_screen.dart';
import 'package:hunter_ascend/widgets/glass/glass_background.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/widgets/equipped_badge_chip.dart';
import 'package:hunter_ascend/screens/shop/coin_shop_screen.dart';
import 'package:hunter_ascend/services/feature_unlock_service.dart';


/// Home dashboard: hunter stats, steps, water, streak, notifications, quick actions.
/// Owns: Hunter card, XP, Level, Rank, Steps, Water, Notifications, Quick actions,
/// Map/Nutrition navigation, Profile picture cache, Pedometer, Streak logic,
/// Streak recovery rewarded ad, Punishment rewarded ad, Review prompt,
/// Update checker, Discipline mode startup check.
class HomeDashboardScreen extends StatefulWidget {
  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;
  final List<Map<String, dynamic>> bioQuests;

  const HomeDashboardScreen({
    super.key,
    required this.fatLoss,
    required this.discipline,
    required this.muscleGain,
    required this.selfImprovement,
    this.bioQuests = const [],
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}


class _HomeDashboardScreenState extends State<HomeDashboardScreen> {

  // ── Colors ──────────────────────────────────────────────
  static Color get _bg => HunterTheme.background;
  static Color get _card => HunterTheme.cardColor;
  static Color get _blue => MembershipTheme.current.accent;
  static Color get _blueDim => HunterTheme.border;
  static Color get _border => HunterTheme.border;

  // ── State ────────────────────────────────────────────────
  int xp = 0;
  int level = 1;
  int todaySteps = 0;

  // ── Step reward / offset state (cached in memory) ────────
  bool _stepRewardGrantedToday = false;
  int _stepOffset = 0;
  String _stepOffsetDate = '';

  // Last `todaySteps` value already folded into `totalStepsAllTime` this
  // session — used to accumulate only the NEW steps since the previous
  // pedometer event (backs the `walk_million` achievement) without ever
  // double-counting today's count on every single event.
  int _lastAccumulatedTodaySteps = 0;

  // In-memory running estimate of `totalStepsAllTime`, seeded from the
  // server value in `_loadStepState` and kept in sync locally as new steps
  // are folded in — used purely to detect crossing a 100k boundary so the
  // achievement celebration can be shown promptly without re-reading the
  // hunter doc on every single pedometer tick.
  int _totalStepsAllTimeCache = 0;

  bool _isRecoveringStreak = false;
  String? _cachedProfilePicData;
  Uint8List? _cachedProfileBytes;

  // ── Water intake ─────────────────────────────────────────
  int waterIntakeMl = 0;
  int selectedCupSize = 250;
  int waterGoalMl = 2000;


  StreamSubscription<StepCount>? _stepSubscription;

  // ── Ads ──────────────────────────────────────────────────
  RewardedAd? rewardedAd;
  bool isRewardedAdReady = false;
  RewardedAd? punishmentAd;
  bool isPunishmentAdReady = false;

  // ── Helpers ──────────────────────────────────────────────
  // Hunter Rank is resolved through the centralized RankService (single source
  // of truth) — no rank thresholds are computed locally.
  String get hunterRank => RankService.instance.longTitleForLevel(level);

  String get rankLetter => RankService.instance.letterForLevel(level);

  Color get rankColor => RankService.instance.colorForLevel(level);

  String getStreakTitle(int streak) {
    if (streak >= 100) return "Shadow Monarch";
    if (streak >= 60)  return "S-Rank Hunter";
    if (streak >= 30)  return "Elite Hunter";
    if (streak >= 14)  return "Dedicated Hunter";
    if (streak >= 7)   return "Consistent Hunter";
    if (streak >= 1)   return "New Hunter";
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
      if (existing.docs.isEmpty) return id;
    }
  }


  // ── Init ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    MembershipService.instance.tierNotifier.addListener(_onMembershipTierChanged);

    loadRewardedAd();
    loadPunishmentAd();
    
    // Preload feature unlock ads
    FeatureUnlockService.instance.loadNutritionAd();
    FeatureUnlockService.instance.loadMapAd();
    
    initStepCounter();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkBrokenStreak();
      () async {
        try {
          await MissionsScreen.resetDailyQuestsIfNeeded();
        } catch (e) {
          debugPrint('daily quest reset before discipline: $e');
        }
        if (mounted) checkDisciplinePunishment();
      }();
    });

    loadHunterData().then((_) async {
      await _maybeRequestReview();
    });

    _loadWaterIntake();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdate();
    });
  }

  @override
  void dispose() {
    MembershipService.instance.tierNotifier.removeListener(_onMembershipTierChanged);
    _stepSubscription?.cancel();
    rewardedAd?.dispose();
    punishmentAd?.dispose();
    super.dispose();
  }


  /// Handles membership tier changes. Home has no banner ads to manage,
  /// but still listens for consistency with the rewarded ad state.
  void _onMembershipTierChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // ── Ads ──────────────────────────────────────────────────
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AppConstants.streakRecoveryRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { rewardedAd = ad; if (mounted) setState(() => isRewardedAdReady = true); },
        onAdFailedToLoad: (error) { debugPrint("REWARDED FAILED: $error"); isRewardedAdReady = false; },
      ),
    );
  }

  void loadPunishmentAd() {
    RewardedAd.load(
      adUnitId: AppConstants.punishmentRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { punishmentAd = ad; if (mounted) setState(() => isPunishmentAdReady = true); },
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
          curXp = (curXp - 20).clamp(0, 999999);
          txn.update(ref, {'xp': curXp});
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "\u26a0\ufe0f Ad unavailable. -20 XP penalty applied.",
              ),
            ),
          );
        }
      }

      return;
    }

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


  /// Grants the streak recovery reward (discipline restore).
  Future<void> _grantStreakRecovery() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final previousStreak = data['previousStreak'] ?? 0;
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
      'streak': previousStreak, 'previousStreak': 0, 'lastRecoveryDate': Timestamp.now(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("\ud83d\udd25 Streak Restored ($previousStreak Days)")));
    // Immediately re-evaluate/celebrate — backs special_never_give_up and
    // hidden_comeback, both of which depend on previousStreak/streak.
    if (mounted) {
      await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
    }
  }

  // ── Steps ────────────────────────────────────────────────
  Future<void> initStepCounter() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    await _loadStepState();

    _stepSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final today = DateTime.now().toString().substring(0, 10);

        if (_stepOffsetDate != today) {
          _stepOffset = event.steps;
          _stepOffsetDate = today;
          _stepRewardGrantedToday = false;
          _lastAccumulatedTodaySteps = 0;
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'stepOffset': _stepOffset,
            'stepOffsetDate': today,
          });
        }

        final todayCount = (event.steps - _stepOffset).clamp(0, 999999);

        // Fold only the NEW steps since the last pedometer event into the
        // lifetime all-time total (backs the `walk_million` achievement).
        // Uses an in-memory watermark (_lastAccumulatedTodaySteps) to avoid
        // double-counting on every tick. On app restart mid-day this resets
        // to 0, which means the first batch of today's steps may be counted
        // again — acceptable imprecision for a million-step achievement.
        final newSteps = todayCount - _lastAccumulatedTodaySteps;
        if (newSteps > 0) {
          _lastAccumulatedTodaySteps = todayCount;
          try {
            await FirebaseFirestore.instance
                .collection('hunters')
                .doc(user.uid)
                .update({'totalStepsAllTime': FieldValue.increment(newSteps)});
          } catch (e) {
            debugPrint('totalStepsAllTime increment: $e');
          }
        }

        if (todayCount >= 10000 && !_stepRewardGrantedToday) {
          _stepRewardGrantedToday = true;
          await XpService.instance.awardXp(amount: 25);
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'lastStepRewardDate': today,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("\ud83c\udfc6 Daily Step Goal Complete! +25 XP")),
            );
          }
        }
        if (!mounted) return;
        setState(() => todaySteps = todayCount);
        // Check for step milestone celebrations.
        MilestoneService.checkStepMilestones(context, todayCount);
        // Re-evaluate achievements only when a new 100k all-time-step
        // milestone boundary is actually crossed — NOT on every single
        // pedometer tick, which would otherwise trigger a Firestore read +
        // achievement scan many times per minute while walking. The
        // background HunterRepository listener (bound in main.dart) will
        // still eventually pick up `walk_million` even if this particular
        // boundary check is missed for any reason — this is purely for
        // showing the celebration promptly.
        if (newSteps > 0) {
          final newTotal = _totalStepsAllTimeCache + newSteps;
          if (_totalStepsAllTimeCache ~/ 100000 != newTotal ~/ 100000) {
            unawaited(AchievementsService.instance.checkAndCelebrateForCurrentUser(context));
          }
          _totalStepsAllTimeCache = newTotal;
        }
      },
      onError: (error) => debugPrint("\u274c Step counter error: $error"),
      cancelOnError: false,
    );
  }


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
    _lastAccumulatedTodaySteps = 0; // In-memory only; resets each app start.
    _totalStepsAllTimeCache = ((data['totalStepsAllTime'] ?? 0) as num).toInt();
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
        title: const Text("\ud83d\udd25 STREAK BROKEN"),
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


  // ── Discipline ───────────────────────────────────────────
  Future<void> checkDisciplinePunishment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    final disciplineStartDate = (data['disciplineStartDate'] ?? '').toString();
    if (disciplineStartDate.isNotEmpty && today.compareTo(disciplineStartDate) <= 0) return;
    if (data['lastPunishmentDate'] == today) return;
    final mode = data['disciplineMode'] ?? 'casual';
    final lastReset = data['lastQuestResetDate'];
    if (lastReset == null || lastReset.toString().isEmpty) return;
    final completed = data['yesterdayCompletedCount'] ?? 0;
    final total = data['yesterdayTotalQuests'] ?? 0;

    if (total == 0) return;

    bool punish = mode == 'casual' ? completed == 0 : completed < total;
    if (!punish) return;

    if (!mounted) return;

    // Ad not available -> deduct XP once
    if (!isPunishmentAdReady || punishmentAd == null) {
      int penalty = mode == 'strict' ? 20 : 5;
      final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      bool applied = false;
      await FirebaseFirestore.instance.runTransaction((txn) async {
        applied = false;
        final snap = await txn.get(ref);
        final d = snap.data() ?? {};
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
                    color: MembershipTheme.current.accent,
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


    // Ad available -> must watch, no escape
    final skipAd = await MembershipService.instance.shouldSkipRewardedAd();
    if (!mounted) return;
    if (skipAd) {
      await _grantPunishmentCompletion(user.uid, today);
      return;
    }

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => PopScope(
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
                      await Future.delayed(const Duration(seconds: 1));
                      if (mounted) checkDisciplinePunishment();
                    }
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) async {
                    ad.dispose();
                    punishmentAd = null;
                    isPunishmentAdReady = false;
                    loadPunishmentAd();
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


  Future<void> _grantPunishmentCompletion(String uid, String today) async {
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .update({'lastPunishmentDate': today});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("\u2705 Debt repaid. Continue your journey.")),
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
              BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HunterTheme.border,
                  shape: BoxShape.circle,
                  border: Border.all(color: MembershipTheme.current.accent, width: 1.5),
                  boxShadow: [BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.3), blurRadius: 16)],
                ),
                child: Icon(Icons.shield, color: MembershipTheme.current.accent, size: 32),
              ),
              const SizedBox(height: 16),
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
                    style: TextStyle(color: MembershipTheme.current.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              const SizedBox(height: 20),


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
                      backgroundColor: MembershipTheme.current.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("UNDERSTOOD", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ]
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
    );
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
        'color': MembershipTheme.current.accent,
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
                    await NotificationService().scheduleForPreference(opt['label'] as String);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "\ud83d\udd14 Reminder set for ${opt['label']} (${opt['sub']})",
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
                    await NotificationService().scheduleForPreference('');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("\ud83d\udd15 Daily reminders turned off")),
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
                        "TURN OFF DAILY REMINDERS",
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
                const SizedBox(height: 8),
                Text(
                  "Streak protection reminders remain enabled to help you maintain your streak.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    });
    await checkDisciplineMode();
  }

  // ── App Review prompt ────────────────────────────────────
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
    } catch (_) {}
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
                await launchUrl(uri, mode: LaunchMode.externalApplication);
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


  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        SkinService.instance.activeSkinNotifier,
        SkinService.instance.skinAppearanceActiveNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final stream = HunterRepository.instance.watch();
    final cached = HunterRepository.instance.getCached();

    return Scaffold(
      backgroundColor: _bg,
      body: GlassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                StreamBuilder<HunterData?>(
                  stream: stream,
                  initialData: cached,
                  builder: (context, snap) {
                    final hunter = snap.data;
                    if (hunter == null) return buildDashboardSkeleton();

                    // ── Skin visual identity (Phase 3, revised) ──
                    //
                    // Architecture: skins do NOT swap in an entirely separate
                    // dashboard layout (that would mean maintaining
                    // ShadowDashboard.dart/CyberDashboard.dart/etc. forever)
                    // and do NOT rely solely on a decorative overlay either.
                    // Instead, each of the 5 dashboard sections (Hero, Quest,
                    // Stats, Water, Quick Actions) is wrapped in a
                    // `Skin*Section` resolver (see
                    // lib/core/skins/dashboard/skin_dashboard_sections.dart),
                    // passing this tier's own existing widget as `fallback`.
                    // The resolver renders that fallback completely
                    // unmodified for Classic (or when the skin is suppressed
                    // in favor of a Premium Theme), and swaps in a genuinely
                    // different, skin-specific widget for that section
                    // otherwise — same tier-based layout below either way.

                    // ── Tier-based layout selection ──
                    // Each tier (Basic here, plus Pro/Max below) independently
                    // wraps its own Hero/Quest/Stats/Water/QuickActions call
                    // sites in the skin-section resolvers, so a skin applies
                    // identically regardless of membership tier.
                    final membership = MembershipService.instance;
                    if (membership.isMax) {
                      return MaxDashboardLayout(
                        hunter: hunter,
                        todaySteps: todaySteps,
                        waterIntakeMl: waterIntakeMl,
                        waterGoalMl: waterGoalMl,
                        selectedCupSize: selectedCupSize,
                        onAddWater: _addWater,
                        onRemoveWater: _removeWater,
                        onSetCupSize: _setCupSize,
                        onEditWaterGoal: _showWaterGoalSheet,
                        onNutritionTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NutritionScreen()),
                        ),
                        onMapTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapScreen()),
                        ),
                        onNotificationTap: () => _showNotificationDialog(),
                      );
                    }
                    if (membership.isPro) {
                      return ProDashboardLayout(
                        hunter: hunter,
                        todaySteps: todaySteps,
                        waterIntakeMl: waterIntakeMl,
                        waterGoalMl: waterGoalMl,
                        selectedCupSize: selectedCupSize,
                        onAddWater: _addWater,
                        onRemoveWater: _removeWater,
                        onSetCupSize: _setCupSize,
                        onEditWaterGoal: _showWaterGoalSheet,
                        onNutritionTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NutritionScreen()),
                        ),
                        onMapTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapScreen()),
                        ),
                        onNotificationTap: () => _showNotificationDialog(),
                      );
                    }

                    // ── Basic (default) layout — premium redesign ──
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(hunter),
                        const SizedBox(height: 18),
                        _buildHunterCard(hunter),
                        const SizedBox(height: 14),
                        _buildSkinStatsIfActive(hunter),
                        _buildStepsCard(),
                        const SizedBox(height: 14),
                        _buildQuickActions(),
                        const SizedBox(height: 14),
                        _buildWaterCard(),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ══ Basic dashboard premium identity ═════════════════════════════════════
  //
  // The Basic tier gets its own clean, airy "frosted card" identity — a soft
  // accent-tinted gradient over the theme card colour, a hairline border and a
  // gentle elevation shadow. Fully theme-aware (reads HunterTheme tokens, so it
  // adapts to light/dark and every unlocked theme) and deliberately simpler
  // than the Pro/Max layouts.

  /// A premium Basic-tier surface. Distinct from the shared GlassCard used
  /// elsewhere so Basic has its own look.
  Widget _basicCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double radius = 20,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MembershipTheme.current.accent.withOpacity(0.055),
            HunterTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: HunterTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(HunterTheme.isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _blue, size: 18),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _miniDivider() =>
      Container(width: 1, height: 34, color: HunterTheme.border);

  // ── Top Bar ──────────────────────────────────────────────
  Widget _buildTopBar(HunterData hunter) {
    final streak = hunter.streak;

    return Row(
      children: [
        // Coin Shop button
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CoinShopScreen(),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: HunterTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: HunterTheme.gold.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'Shop',
                  style: TextStyle(
                    color: HunterTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: "HUNTER ",
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            TextSpan(
              text: "ASCEND",
              style: TextStyle(
                color: _blue,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ]),
        ),
        const Spacer(),
        // Streak pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              "$streak",
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ]),
        ),
      ],
    );
  }


  Uint8List _profilePicBytes(String base64Data) {
    if (base64Data != _cachedProfilePicData) {
      _cachedProfilePicData = base64Data;
      _cachedProfileBytes = base64Decode(base64Data);
    }
    return _cachedProfileBytes!;
  }

  // ── Skin-only stats section ───────────────────────────────
  //
  // Basic's stat summary (Steps/Water/Streak) has always lived INSIDE the
  // hunter hero card (the mini-stat row), unlike Pro/Max which already have
  // a separate, independent stats section. To keep Classic's hero card
  // exactly as it always was (mini-stat row included, per the "Classic must
  // preserve the existing UI exactly" requirement), this method is a true
  // no-op — renders nothing, takes zero layout space — whenever no skin is
  // active. Only when a non-classic skin IS the active appearance does it
  // render that skin's own dedicated Stats widget, built from the exact
  // same values (todaySteps, waterIntakeMl, hunter.streak) Basic's hero
  // mini-stat row already uses.
  Widget _buildSkinStatsIfActive(HunterData hunter) {
    return ValueListenableBuilder<SkinId>(
      valueListenable: SkinService.instance.activeSkinNotifier,
      builder: (context, activeSkin, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SkinService.instance.skinAppearanceActiveNotifier,
          builder: (context, appearanceActive, __) {
            final skinActive = appearanceActive && activeSkin != SkinId.classic;
            if (!skinActive) return const SizedBox.shrink();

            final data = StatsSectionData(stats: [
              DashboardStat(label: 'Steps', value: '$todaySteps', icon: Icons.directions_walk_rounded, color: _blue),
              DashboardStat(label: 'Water', value: '${(waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: Colors.cyan),
              DashboardStat(label: 'Streak', value: '${hunter.streak}', icon: Icons.local_fire_department_rounded, color: Colors.orange),
            ]);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: dashboardSkinSectionsFor(activeSkin).stats(data),
            );
          },
        );
      },
    );
  }

  // ── Hunter Card (premium hero) ───────────────────────────
  Widget _buildHunterCard(HunterData hunter) {
    final pic = hunter.profilePicture;
    final name = hunter.hunterName;
    final liveXp = hunter.xp;
    final liveLevel = hunter.level;
    final xpProgress = (liveXp / 500).clamp(0.0, 1.0);

    // Phase 3 (revised): the Classic-tier hero card is passed as `fallback`
    // to SkinHeroSection, which renders it completely unmodified unless a
    // non-classic skin is the active appearance — in which case that
    // skin's own hero widget (a genuinely different structure, not a
    // decorative overlay) is rendered instead. See
    // lib/core/skins/dashboard/skin_dashboard_sections.dart.
    final basicHeroCard = _basicCard(
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with a gradient ring + soft glow.
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: MembershipTheme.current.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(color: _blue.withOpacity(0.35 * HunterTheme.glowStrength), blurRadius: 16, spreadRadius: 1),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: HunterTheme.cardColor),
                  child: pic != null
                      ? ClipOval(
                          child: Image.memory(
                            _profilePicBytes(pic),
                            fit: BoxFit.cover,
                            width: 66,
                            height: 66,
                          ),
                        )
                      : Center(child: Icon(Icons.person, color: _blue, size: 34)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      EquippedBadgeChip(badgeId: hunter.equippedBadgeId, size: 16),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rankColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rankColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      hunterRank,
                      style: TextStyle(color: rankColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              RankShieldBadge(rankLetter: rankLetter, size: 54),
            ],
          ),
          const SizedBox(height: 18),
          // XP / Level presentation.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("LEVEL ", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  Text("$liveLevel", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withOpacity(0.3)),
                ),
                child: Text("$liveXp / 500 XP", style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Animated gradient XP bar with glow.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: xpProgress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 10, color: HunterTheme.border),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: MembershipTheme.current.gradient),
                        boxShadow: [
                          BoxShadow(color: _blue.withOpacity(0.5 * HunterTheme.glowStrength), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Daily summary at a glance.
          Row(
            children: [
              Expanded(child: _miniStat(Icons.directions_walk_rounded, "$todaySteps", "Steps")),
              _miniDivider(),
              Expanded(child: _miniStat(Icons.water_drop_rounded, "${(waterIntakeMl / 1000).toStringAsFixed(1)}L", "Water")),
              _miniDivider(),
              Expanded(child: _miniStat(Icons.local_fire_department_rounded, "${hunter.streak}", "Streak")),
            ],
          ),
        ],
      ),
    );

    return SkinHeroSection(
      data: HeroSectionData(
        hunter: hunter,
        rankTitle: hunterRank,
        accentColor: MembershipTheme.current.accent,
      ),
      fallback: basicHeroCard,
    );
  }

  // ── Steps card (premium step counter) ────────────────────
  Widget _buildStepsCard() {
    const goal = 10000;
    final progress = (todaySteps / goal).clamp(0.0, 1.0);
    final reached = todaySteps >= goal;
    final remaining = (goal - todaySteps).clamp(0, goal);

    final basicStepsCard = _basicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_blue.withOpacity(0.18), _blue.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blue.withOpacity(0.25)),
                ),
                child: Icon(Icons.directions_walk_rounded, color: _blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("STEPS TODAY", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text("$todaySteps", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                        Text("  / 10,000", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              if (reached)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: HunterTheme.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: HunterTheme.success.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, color: HunterTheme.success, size: 14),
                    const SizedBox(width: 4),
                    Text("Goal", style: TextStyle(color: HunterTheme.success, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 10, color: HunterTheme.border),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: MembershipTheme.current.gradient),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reached ? "Daily goal complete — nice work!" : "$remaining steps to your daily goal",
            style: TextStyle(
              color: reached ? HunterTheme.success : HunterTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    // Phase 3 (revised): Steps is Basic's quest/mission-equivalent section.
    return SkinQuestSection(
      data: QuestSectionData(todaySteps: todaySteps, goal: goal),
      fallback: basicStepsCard,
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

  /// Increments the lifetime water-log counter (backs `hydration_100`) and,
  /// exactly once per calendar day the goal is first reached, extends the
  /// consecutive-day goal-hit streak (backs `hydration_streak`) — mirroring
  /// the same day-guard pattern used for nutrition tracking. Runs after the
  /// water amount itself has already been saved; any failure here is
  /// logged but never affects the water log that already succeeded.
  Future<void> _updateHydrationAchievementTracking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateTime.now().toString().substring(0, 10);
    final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};
        final lastHitDate = data['lastWaterGoalHitDate']?.toString();
        final curStreak = ((data['waterGoalStreak'] ?? 0) as num).toInt();
        final curLogCount = ((data['waterLogCount'] ?? 0) as num).toInt();

        final updates = <String, dynamic>{'waterLogCount': curLogCount + 1};

        final goalHitNow = waterGoalMl > 0 && waterIntakeMl >= waterGoalMl;
        if (goalHitNow && lastHitDate != today) {
          // A goal hit on a fresh day extends the streak; any gap (checked
          // via lastWaterGoalHitDate not being yesterday) restarts it at 1
          // rather than silently continuing an already-broken streak.
          final yesterday = DateTime.now().subtract(const Duration(days: 1)).toString().substring(0, 10);
          final isConsecutive = lastHitDate == yesterday;
          updates['waterGoalStreak'] = isConsecutive ? curStreak + 1 : 1;
          updates['lastWaterGoalHitDate'] = today;
        }

        txn.update(ref, updates);
      });
    } catch (e) {
      debugPrint('updateHydrationAchievementTracking: $e');
      return;
    }
    if (mounted) {
      await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
    }
  }

  void _addWater() {
    setState(() => waterIntakeMl += selectedCupSize);
    _saveWaterIntake();
    unawaited(_updateHydrationAchievementTracking());
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: MembershipTheme.current.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: MembershipTheme.current.accent.withOpacity(0.35 * HunterTheme.glowStrength),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon,
            color: MembershipTheme.isMax ? Colors.white : Colors.black,
            size: 24),
      ),
    );
  }

  Widget _cupPill(int size) {
    final selected = selectedCupSize == size;
    return GestureDetector(
      onTap: () => _setCupSize(size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: MembershipTheme.current.gradient)
              : null,
          color: selected ? null : HunterTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : HunterTheme.border,
          ),
        ),
        child: Text(
          '${size}ml',
          style: TextStyle(
            color: selected
                ? (MembershipTheme.isMax ? Colors.white : Colors.black)
                : HunterTheme.textSecondary,
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
                    color: selected
                        ? MembershipTheme.current.accent
                        : HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: MembershipTheme.current.accent, width: 1.3),
                  ),
                  child: Text(
                    '${v}ml',
                    style: TextStyle(
                      color: selected
                          ? (MembershipTheme.isPro ? Colors.black : Colors.white)
                          : MembershipTheme.current.accent,
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
                            color: MembershipTheme.current.accent.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: MembershipTheme.current.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Min 500 ml \u00b7 Max 5000 ml',
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
                            backgroundColor: MembershipTheme.current.accent,
                            foregroundColor: MembershipTheme.isPro
                                ? Colors.black
                                : Colors.white,
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

    final basicWaterCard = _basicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_blue.withOpacity(0.18), _blue.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blue.withOpacity(0.25)),
                ),
                child: Icon(Icons.water_drop_rounded, color: _blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HYDRATION',
                      style: TextStyle(
                        color: HunterTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$waterIntakeMl / $waterGoalMl ml',
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showWaterGoalSheet,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MembershipTheme.current.accent.withOpacity(0.10),
                  ),
                  child: Icon(Icons.edit_rounded, size: 15, color: MembershipTheme.current.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 10, color: HunterTheme.border),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: MembershipTheme.current.gradient),
                      boxShadow: [
                        BoxShadow(color: _blue.withOpacity(0.5 * HunterTheme.glowStrength), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
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
                    ? MembershipTheme.current.accent
                    : HunterTheme.border,
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
                  color: HunterTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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

    return SkinWaterSection(
      data: WaterSectionData(
        waterIntakeMl: waterIntakeMl,
        waterGoalMl: waterGoalMl,
        selectedCupSize: selectedCupSize,
        onAdd: _addWater,
        onRemove: _removeWater,
        onSetCupSize: _setCupSize,
        onEditGoal: _showWaterGoalSheet,
      ),
      fallback: basicWaterCard,
    );
  }


  // ── Quick actions (Nutrition + Map) ──────────────────────
  //
  // Quick Actions' `isLocked` values are resolved SYNCHRONOUSLY from the
  // hunter document that HunterRepository already keeps live-cached, exactly
  // like the other 4 sections whose data is already available in this build
  // method. Previously these two values came from async FeatureUnlockService
  // calls wrapped in FutureBuilders, which meant every rebuild of this
  // section issued two fresh `hunters/{uid}` reads for Basic users — and this
  // section rebuilds on every theme/skin/tier notifier tick, every setState
  // and every hunter-doc emission. The cached checks cost ZERO reads, add no
  // listener, and stay fresh because this whole section is rendered inside
  // the `StreamBuilder<HunterData?>` on HunterRepository.watch(), so a newly
  // granted unlock arrives with the next emission.
  //
  // Access is still gated server-side: tapping an unlocked card navigates to
  // NutritionScreen / MapScreen, each of which re-validates with the
  // authoritative async `isNutritionUnlocked()` / `isMapUnlocked()` check.
  // Pro/Max keep their existing no-read short-circuit.
  Widget _buildQuickActions() {
    final nutritionUnlocked =
        FeatureUnlockService.instance.isNutritionUnlockedCached();
    final mapUnlocked = FeatureUnlockService.instance.isMapUnlockedCached();

    final basicQuickActionsRow = Row(
      children: [
        Expanded(
          child: _quickActionCard(
            icon: Icons.restaurant_menu,
            label: 'Nutrition',
            isLocked: !nutritionUnlocked,
            onTap: nutritionUnlocked
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NutritionScreen()),
                    )
                : () => _showUnlockDialog('Nutrition'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickActionCard(
            icon: Icons.map,
            label: 'Map',
            isLocked: !mapUnlocked,
            onTap: mapUnlocked
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    )
                : () => _showUnlockDialog('Map'),
          ),
        ),
      ],
    );

    return ValueListenableBuilder<SkinId>(
      valueListenable: SkinService.instance.activeSkinNotifier,
      builder: (context, activeSkin, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SkinService.instance.skinAppearanceActiveNotifier,
          builder: (context, appearanceActive, __) {
            final skinActive = appearanceActive && activeSkin != SkinId.classic;
            if (!skinActive) return basicQuickActionsRow;

            // Skin branch: same two cached values, handed to the skin's own
            // widget as a single combined data contract. The Future.wait that
            // used to sit here is gone along with its two reads — both values
            // are already resolved synchronously above.
            final data = QuickActionsSectionData(
              nutrition: QuickActionItem(
                icon: Icons.restaurant_menu,
                label: 'Nutrition',
                isLocked: !nutritionUnlocked,
                onTap: nutritionUnlocked
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionScreen()))
                    : () => _showUnlockDialog('Nutrition'),
              ),
              map: QuickActionItem(
                icon: Icons.map,
                label: 'Map',
                isLocked: !mapUnlocked,
                onTap: mapUnlocked
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()))
                    : () => _showUnlockDialog('Map'),
              ),
            );
            return dashboardSkinSectionsFor(activeSkin).quickActions(data);
          },
        );
      },
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required bool isLocked,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _basicCard(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        radius: 18,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLocked
                          ? [
                              HunterTheme.textTertiary.withOpacity(0.1),
                              HunterTheme.textTertiary.withOpacity(0.05),
                            ]
                          : [
                              MembershipTheme.current.accent.withOpacity(0.18),
                              MembershipTheme.current.accent.withOpacity(0.06),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLocked
                          ? HunterTheme.border
                          : MembershipTheme.current.accent.withOpacity(0.25),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isLocked
                        ? HunterTheme.textTertiary
                        : MembershipTheme.current.accent,
                    size: 24,
                  ),
                ),
                if (isLocked)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: HunterTheme.cardColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isLocked
                    ? HunterTheme.textTertiary
                    : HunterTheme.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show unlock dialog for locked features
  void _showUnlockDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.15),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🔒 $featureName Locked',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Watch 1 rewarded ad to unlock\n$featureName for 30 days',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  if (featureName == 'Nutrition') {
                    await FeatureUnlockService.instance.showNutritionUnlockFlow(context);
                  } else {
                    await FeatureUnlockService.instance.showMapUnlockFlow(context);
                  }
                  // Refresh UI after unlock
                  if (mounted) setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade700],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'WATCH AD TO UNLOCK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
