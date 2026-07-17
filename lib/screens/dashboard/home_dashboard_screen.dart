import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/widgets/dashboard/steps_card.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:hunter_ascend/screens/dashboard/dashboard_screen.dart';
import 'package:hunter_ascend/widgets/glass/glass_card.dart';
import 'package:hunter_ascend/widgets/glass/glass_background.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';


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
  static Color get _blue => HunterTheme.primary;
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
    initStepCounter();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkBrokenStreak();
      checkDisciplinePunishment();
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


  /// Grants the streak recovery reward.
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
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({
            'stepOffset': _stepOffset,
            'stepOffsetDate': today,
          });
        }

        final todayCount = (event.steps - _stepOffset).clamp(0, 999999);

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
              BoxShadow(color: HunterTheme.primary.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
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
                  border: Border.all(color: HunterTheme.primary, width: 1.5),
                  boxShadow: [BoxShadow(color: HunterTheme.primary.withOpacity(0.3), blurRadius: 16)],
                ),
                child: Icon(Icons.shield, color: HunterTheme.primary, size: 32),
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
                    style: TextStyle(color: HunterTheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
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
                      backgroundColor: HunterTheme.primary,
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
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    _buildCount++;
    debugPrint('[HIVE-UI] _themedBuild #$_buildCount called');

    final stream = HunterRepository.instance.watch();
    final cached = HunterRepository.instance.getCached();
    debugPrint('[HIVE-UI] stream.hashCode=${identityHashCode(stream)}, cached=${cached != null ? "Lv${cached.level}" : "null"}');

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
                    debugPrint('[HIVE-UI] StreamBuilder: state=${snap.connectionState}, hasData=${snap.hasData}, data=${snap.data != null ? "Lv${snap.data!.level}" : "null"}');
                    final hunter = snap.data;
                    if (hunter == null) return buildDashboardSkeleton();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(hunter),
                        const SizedBox(height: 20),
                        _buildHunterCard(hunter),
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
            ),
          ),
        ),
      ),
    );
  }


  // ── Top Bar ──────────────────────────────────────────────
  Widget _buildTopBar(HunterData hunter) {
    final hasNotif = (hunter.notificationTime ?? '').isNotEmpty;
    final streak = hunter.streak;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showNotificationDialog(),
          child: Stack(
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
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
          const SizedBox(width: 3),
          Text("$streak", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
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

  // ── Hunter Card ──────────────────────────────────────────
  Widget _buildHunterCard(HunterData hunter) {
    final pic = hunter.profilePicture;
    final name = hunter.hunterName;
    final liveXp = hunter.xp;
    final liveLevel = hunter.level;

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _blue, width: 2),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 16)],
                ),
                child: pic != null
                    ? ClipOval(
                        child: Image.memory(
                          _profilePicBytes(pic),
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                        ),
                      )
                    : Center(child: Icon(Icons.person, color: _blue, size: 40)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("$hunterRank HUNTER", style: TextStyle(color: rankColor, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ]),
              ),
              RankShieldBadge(rankLetter: rankLetter, size: 56),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("LEVEL $liveLevel", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
                Text("$liveXp / 500 XP", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
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
          ),
        ],
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

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '\ud83d\udca7 WATER INTAKE',
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
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        borderRadius: 14,
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
}
