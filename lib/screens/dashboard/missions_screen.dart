import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hunter_ascend/services/ai_quest_service.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/widgets/dashboard/sleep_card.dart';
import 'package:hunter_ascend/widgets/dashboard/sleep_ambience_picker.dart';
import 'package:hunter_ascend/widgets/dashboard/sleep_summary_dialog.dart';
import 'package:hunter_ascend/screens/dashboard/sleep_start_screen.dart';
import 'package:hunter_ascend/services/sleep_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/xp_service.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/models/custom_quest.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/data/repositories/quest_repository.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';


/// Missions screen: daily quests, weekly missions, AI quest generation,
/// active quest timers, custom quest dialog, banner ads.
class MissionsScreen extends StatefulWidget {
  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;
  final List<Map<String, dynamic>> bioQuests;

  const MissionsScreen({
    super.key,
    required this.fatLoss,
    required this.discipline,
    required this.muscleGain,
    required this.selfImprovement,
    this.bioQuests = const [],
  });

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}


class _MissionsScreenState extends State<MissionsScreen> {

  // ── Colors ──────────────────────────────────────────────
  static Color get _bg => HunterTheme.background;
  static Color get _card => HunterTheme.cardColor;
  static Color get _blue => HunterTheme.primary;

  // ── State ────────────────────────────────────────────────
  int xp = 0;
  int level = 1;

  bool questStarted = false;
  String activeQuest = "";
  bool _isCompletingQuest = false;
  bool _isCompletingWeeklyQuest = false;

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
  String _missionDay = DateTime.now().toString().substring(0, 10);


  void updateQuestCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    setState(() {
      timeUntilReset = tomorrow.difference(now);
    });

    final today = now.toString().substring(0, 10);
    if (today != _missionDay) {
      _missionDay = today;
      _loadAIQuests().then((_) => checkDailyReset());
    }
  }

  List<Map<String, dynamic>> generatedQuests = [];

  static const Duration _aiLockTimeout = Duration(minutes: 5);


  Future<void> _loadAIQuests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('hunters').doc(uid);
    final doc = await ref.get();

    if (!mounted) return;
    final data = doc.data() ?? {};

    final today = DateTime.now().toIso8601String().split('T').first;
    final savedDate = data['aiQuestDate'] ?? '';

    if (savedDate == today) {
      final quests = List<Map<String, dynamic>>.from(data['aiQuests'] ?? []);
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

    // Atomically acquire a timestamp-based generation lock.
    bool claimed = false;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final d = snap.data() ?? {};

      if ((d['aiQuestDate'] ?? '') == today) {
        claimed = false;
        return;
      }

      final lockValue = d['aiQuestGeneratingAt'];
      if (lockValue != null) {
        DateTime? lockTime;
        if (lockValue is Timestamp) {
          lockTime = lockValue.toDate();
        }
        if (lockTime != null &&
            DateTime.now().difference(lockTime) < _aiLockTimeout) {
          claimed = false;
          return;
        }
      }

      txn.update(ref, {'aiQuestGeneratingAt': Timestamp.now()});
      claimed = true;
    });

    if (!mounted) return;


    if (!claimed) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final refreshed = await ref.get();
      if (!mounted) return;
      final refreshedData = refreshed.data() ?? {};

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

    // We hold the lock. Call the AI.
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

      await ref.update({'aiQuestGeneratingAt': FieldValue.delete()});

      if (savedDate.toString().isEmpty && data['disciplineStartDate'] == null) {
        await ref.update({
          'disciplineStartDate': DateTime.now().toString().substring(0, 10),
        });
      }
    } catch (e) {
      debugPrint("_loadAIQuests generation failed: $e");
      try {
        await ref.update({'aiQuestGeneratingAt': FieldValue.delete()});
      } catch (_) {}
    }
  }


  List<String> completedQuests = [];

  final TextEditingController customQuestController = TextEditingController();

  // ── Ads ──────────────────────────────────────────────────
  BannerAd? bannerAd;
  bool isBannerReady = false;
  BannerAd? weeklyBannerAd;
  bool weeklyBannerReady = false;


  // ── Init ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    MembershipService.instance.tierNotifier.addListener(_onMembershipTierChanged);

    updateQuestCountdown();
    countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => updateQuestCountdown(),
    );

    loadBannerAd();
    loadWeeklyBannerAd();

    loadHunterData().then((_) async {
      await _loadAIQuests();
      await checkDailyReset();
    });

    _restoreDashboardActiveQuest();
    _loadWeeklyMissions();
    _restoreWeeklyActiveQuest();

    // Initialize sleep mission state.
    SleepService.instance.initialize();
  }

  @override
  void dispose() {
    MembershipService.instance.tierNotifier.removeListener(_onMembershipTierChanged);
    _questCountdownTimer?.cancel();
    _weeklyCountdownTimer?.cancel();
    countdownTimer?.cancel();
    bannerAd?.dispose();
    weeklyBannerAd?.dispose();
    customQuestController.dispose();
    super.dispose();
  }


  void _onMembershipTierChanged() {
    if (!mounted) return;
    final showAds = MembershipService.instance.showBannerAds;
    if (!showAds) {
      if (bannerAd != null) {
        bannerAd!.dispose();
        bannerAd = null;
        isBannerReady = false;
      }
      if (weeklyBannerAd != null) {
        weeklyBannerAd!.dispose();
        weeklyBannerAd = null;
        weeklyBannerReady = false;
      }
    } else {
      if (bannerAd == null) loadBannerAd();
      if (weeklyBannerAd == null) loadWeeklyBannerAd();
    }
    setState(() {});
  }

  // ── Ads ──────────────────────────────────────────────────
  void loadBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;
    bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) { if (mounted) setState(() => isBannerReady = true); },
      onAdFailedToLoad: (ad, error) {
        debugPrint("BANNER FAILED: $error");
        ad.dispose();
        bannerAd = null;
        // Retry once after a short delay.
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && bannerAd == null) {
              bannerAd = AdsService.createBannerAd(
                adUnitId: AppConstants.dashboardBannerAdUnitId,
                onAdLoaded: (ad) { if (mounted) setState(() => isBannerReady = true); },
                onAdFailedToLoad: (ad, error) { debugPrint("BANNER RETRY FAILED: $error"); ad.dispose(); bannerAd = null; },
              );
              bannerAd!.load();
            }
          });
        }
      },
    );
    bannerAd!.load();
  }

  void loadWeeklyBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;
    weeklyBannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) { if (mounted) setState(() => weeklyBannerReady = true); },
      onAdFailedToLoad: (ad, error) {
        debugPrint("WEEKLY BANNER FAILED: $error");
        ad.dispose();
        weeklyBannerAd = null;
        // Retry once after a short delay.
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && weeklyBannerAd == null) {
              weeklyBannerAd = AdsService.createBannerAd(
                adUnitId: AppConstants.dashboardBannerAdUnitId,
                onAdLoaded: (ad) { if (mounted) setState(() => weeklyBannerReady = true); },
                onAdFailedToLoad: (ad, error) { debugPrint("WEEKLY BANNER RETRY FAILED: $error"); ad.dispose(); weeklyBannerAd = null; },
              );
              weeklyBannerAd!.load();
            }
          });
        }
      },
    );
    weeklyBannerAd!.load();
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
    final completedQuestName = activeQuest;
    final int reward = questReward;
    setState(() {
      questStarted = false; completedQuests.add(activeQuest);
    });

    if (user != null) {
      final oldLevel = level;
      final result = await XpService.instance.awardXp(amount: reward);
      if (result != null) {
        if (mounted) setState(() { xp = result.xp; level = result.level; });
        else { xp = result.xp; level = result.level; }
        leveledUp = result.leveledUp;
        if (leveledUp && mounted) {
          MilestoneService.celebrateLevelUps(context, oldLevel, result.level);
        }
      }
    }
    await updateStreak().then((newStreak) {
      if (newStreak != null && mounted) {
        MilestoneService.checkStreakMilestone(context, newStreak);
      }
    });
    await saveCompletedQuest(completedQuestName);

    if (!mounted) return;
    MilestoneService.show(
      context,
      type: MilestoneType.quest,
      title: 'Quest Complete!',
      subtitle: 'Excellent work, Hunter.',
      xp: reward,
    );

    } catch (e) {
      debugPrint("completeQuest: $e");
    } finally {
      _isCompletingQuest = false;
    }
  }

  Future<int?> updateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    final today = DateTime.now();
    final todayString = "${today.year}-${today.month}-${today.day}";

    int? newStreak;
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
        if (difference == 0) return;
        else if (difference == 1) streak++;
        else {
          txn.update(ref, {'previousStreak': streak});
          streak = 1;
        }
      }
      txn.update(ref, {'streak': streak, 'lastQuestDate': todayString});
      newStreak = streak;
    });
    return newStreak;
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
  }

  Future<void> checkDailyReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    if ((data['lastQuestResetDate'] ?? '') == today) return;

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

  Future<void> saveCompletedQuest(String questName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({'completedQuests': FieldValue.arrayUnion([questName]), 'questsDone': FieldValue.increment(1)});
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
        'xpReward': ((m['xp'] ?? 150) as num).toInt() * 3,
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
    final int reward = weeklyQuestReward;
    setState(() {
      weeklyQuestStarted = false;
      for (final m in weeklyMissions) {
        if (m['title'] == completedTitle) m['completed'] = true;
      }
    });

    if (user != null) {
      final oldLevel = level;
      final result = await XpService.instance.awardXp(amount: reward);
      if (result != null) {
        if (mounted) setState(() { xp = result.xp; level = result.level; });
        else { xp = result.xp; level = result.level; }
        leveledUp = result.leveledUp;
        if (leveledUp && mounted) {
          MilestoneService.celebrateLevelUps(context, oldLevel, result.level);
        }
      }
      await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'weeklyMissions': weeklyMissions,
        'questsDone': FieldValue.increment(1),
      });
    }

    if (!mounted) return;
    MilestoneService.show(
      context,
      type: MilestoneType.quest,
      title: 'Quest Complete!',
      subtitle: 'Excellent work, Hunter.',
      xp: reward,
    );

    } catch (e) {
      debugPrint("completeWeeklyQuest: $e");
    } finally {
      _isCompletingWeeklyQuest = false;
    }
  }

  // ── Discipline mode dialog (shown from Missions tab header) ──
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


  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  // ── Sleep Mission ─────────────────────────────────────────
  void _onSleepStartTap() async {
    final selection = await SleepAmbiencePicker.show(context);
    if (selection == null || !mounted) return;

    await SleepService.instance.startSleep(
      ambience: selection.ambience,
      duration: selection.duration,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => SleepStartScreen(
          ambience: selection.ambience,
          duration: selection.duration,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _onSleepStopTap() async {
    final result = await SleepService.instance.stopSleep();
    if (!mounted || result == null) return;

    SleepSummaryDialog.show(context, result);
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              EntranceFadeSlide(child: _MissionHero()),
              const SizedBox(height: 20),
              EntranceFadeSlide(
                delay: const Duration(milliseconds: 60),
                child: SleepCard(
                  onStartTap: _onSleepStartTap,
                  onStopTap: _onSleepStopTap,
                ),
              ),
              const SizedBox(height: 20),
              if (questStarted) ...[
                _ActiveMissionCard(
                  remaining: questRemaining,
                  title: activeQuest,
                  reward: questReward,
                  onComplete: completeQuest,
                  onCancel: _cancelActiveQuest,
                  banner: bannerAd,
                  bannerReady: isBannerReady,
                ),
                const SizedBox(height: 20),
              ],
              EntranceFadeSlide(
                delay: const Duration(milliseconds: 100),
                child: _buildQuestsSection(),
              ),
              if (weeklyQuestStarted) ...[
                const SizedBox(height: 20),
                _ActiveMissionCard(
                  remaining: weeklyQuestRemaining,
                  title: weeklyActiveTitle,
                  reward: weeklyQuestReward,
                  onComplete: completeWeeklyQuest,
                  onCancel: _cancelActiveWeeklyQuest,
                  banner: weeklyBannerAd,
                  bannerReady: weeklyBannerReady,
                ),
              ],
              const SizedBox(height: 24),
              EntranceFadeSlide(
                delay: const Duration(milliseconds: 140),
                child: _buildWeeklyMissionsSection(),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Premium section header (matches dashboard section-header style) ──
  Widget _premiumSectionHeader({
    required IconData icon,
    required Color accent,
    required String title,
    required String countText,
    String? resetText,
    List<Widget> actions = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Text(
                countText,
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            const Spacer(),
            ...actions,
          ],
        ),
        if (resetText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 12, color: HunterTheme.textTertiary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  resetText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Discipline-mode pill (unchanged behaviour: opens showDisciplineModeDialog).
  Widget _modeButton() {
    return StreamBuilder<HunterData?>(
      stream: HunterRepository.instance.watch(),
      initialData: HunterRepository.instance.getCached(),
      builder: (context, snapshot) {
        String mode = "MODE";
        final hunter = snapshot.data;
        if (hunter != null && hunter.disciplineMode != null) {
          mode = hunter.disciplineMode!.toUpperCase();
        }
        return GestureDetector(
          onTap: showDisciplineModeDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: HunterTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HunterTheme.primary.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield_rounded, size: 14, color: _blue),
              const SizedBox(width: 5),
              Text(mode, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    );
  }

  // Add-custom-mission button (unchanged behaviour: opens _showAddQuestDialog).
  Widget _addButton() {
    return GestureDetector(
      onTap: () => _showAddQuestDialog(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [HunterTheme.primary, HunterTheme.primary.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: HunterTheme.primary.withOpacity(0.35), blurRadius: 8)],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 20),
      ),
    );
  }

  // Premium empty-state card.
  Widget _buildEmptyState({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.08), HunterTheme.cardColor],
        ),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.14),
              border: Border.all(color: accent.withOpacity(0.4), width: 1.4),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.2), blurRadius: 16)],
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }


  // ── Quests Section ───────────────────────────────────────
  Widget _buildQuestsSection() {
    return StreamBuilder<List<CustomQuest>>(
      stream: QuestRepository.instance.watch(),
      initialData: QuestRepository.instance.getCached(),
      builder: (context, customSnapshot) {
        final customQuests = customSnapshot.data ?? [];
        final totalQuests = generatedQuests.length + customQuests.length;
        final completedCount = completedQuests.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _premiumSectionHeader(
              icon: Icons.auto_awesome_rounded,
              accent: HunterTheme.primary,
              title: 'DAILY MISSIONS (AI)',
              countText: '$completedCount/$totalQuests',
              resetText: 'Resets in ${timeUntilReset.inHours}h ${timeUntilReset.inMinutes.remainder(60)}m',
              actions: [
                _modeButton(),
                const SizedBox(width: 8),
                _addButton(),
              ],
            ),
            const SizedBox(height: 14),

            if (totalQuests == 0)
              _buildEmptyState(
                icon: Icons.auto_awesome_rounded,
                accent: HunterTheme.primary,
                title: 'No missions yet',
                subtitle: 'Tap + to create your first custom mission.',
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
            ...customQuests.map((quest) {
              return _buildQuestTile(
                name: quest.name,
                xp: quest.xp,
                icon: Icons.edit_note_rounded,
                isCompleted: completedQuests.contains(quest.name),
                isCustom: true,
                onTap: () => startQuest(quest.name, quest.xp),
                onDelete: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete Mission?"),
                    content: Text(quest.name),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
                      ElevatedButton(onPressed: () async {
                        await FirebaseFirestore.instance.collection('custom_quests').doc(quest.id).delete();
                        if (mounted) Navigator.pop(context);
                      }, child: const Text("DELETE")),
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


  // Premium mission tile. [xp] is retained for API compatibility but is not
  // rendered as a number, because the actual awarded reward is decided by the
  // time chosen when the mission starts (see _startQuestWithTimer /
  // _startWeeklyQuestWithTimer) — the real reward is shown on the active card.
  Widget _buildQuestTile({
    required String name,
    required int xp,
    required IconData icon,
    required bool isCompleted,
    required bool isCustom,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    final Color accent = isCompleted
        ? HunterTheme.success
        : (isCustom ? HunterTheme.gold : HunterTheme.primary);

    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withOpacity(isCompleted ? 0.16 : 0.10), HunterTheme.cardColor],
          ),
          border: Border.all(color: accent.withOpacity(isCompleted ? 0.5 : 0.3), width: 1.2),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.15),
              border: Border.all(color: accent.withOpacity(0.5), width: 1.2),
            ),
            child: Icon(isCompleted ? Icons.check_rounded : icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCompleted ? HunterTheme.textTertiary : HunterTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isCompleted
                      ? 'Completed'
                      : (isCustom ? 'Custom mission \u2022 Earn XP' : 'Timed mission \u2022 Earn XP'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCompleted ? HunterTheme.success : HunterTheme.textTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isCompleted)
            Icon(Icons.verified_rounded, color: HunterTheme.success, size: 24)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8)],
              ),
              child: const Text('START', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded, color: HunterTheme.danger, size: 20),
            ),
          ],
        ]),
      ),
    );
  }


  Widget _buildWeeklyMissionsSection() {
    final completedCount = weeklyMissions.where((m) => m['completed'] == true).length;
    final total = weeklyMissions.isEmpty ? 3 : weeklyMissions.length;
    final reset = untilNextMonday();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _premiumSectionHeader(
          icon: Icons.local_fire_department_rounded,
          accent: HunterTheme.gold,
          title: 'WEEKLY MISSIONS (AI)',
          countText: '$completedCount/$total',
          resetText: 'Resets in ${reset.inDays}d ${reset.inHours.remainder(24)}h ${reset.inMinutes.remainder(60)}m',
        ),
        const SizedBox(height: 14),
        if (_weeklyLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator(color: HunterTheme.primary)),
          )
        else if (weeklyMissions.isEmpty)
          _buildEmptyState(
            icon: Icons.local_fire_department_rounded,
            accent: HunterTheme.gold,
            title: 'No weekly missions yet',
            subtitle: 'New weekly missions are generated automatically.',
          )
        else
          ...weeklyMissions.map((m) => _buildQuestTile(
            name: (m['title'] ?? '').toString(),
            xp: ((m['xpReward'] ?? 0) as num).toInt(),
            icon: Icons.local_fire_department_rounded,
            isCompleted: m['completed'] == true,
            isCustom: false,
            onTap: () => startWeeklyQuest((m['title'] ?? '').toString()),
          )),
      ],
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



/// Premium introductory hero for the Missions screen.
///
/// Presentation-only. Uses a single lightweight glow controller; the content
/// is passed as [AnimatedBuilder.child] so only the decoration repaints per
/// frame (the content subtree is not rebuilt).
class _MissionHero extends StatefulWidget {
  const _MissionHero();

  @override
  State<_MissionHero> createState() => _MissionHeroState();
}

class _MissionHeroState extends State<_MissionHero> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.primary;

    final content = Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withOpacity(0.7)],
            ),
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MISSION BOARD',
                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 5),
              Text(
                "Today's Missions",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                'Complete missions to earn XP and rise, Hunter.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _glow,
      child: content,
      builder: (context, child) {
        final g = _glow.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withOpacity(0.22), accent.withOpacity(0.06), HunterTheme.cardColor],
            ),
            border: Border.all(color: accent.withOpacity(0.32 + g * 0.22), width: 1.4),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.10 + g * 0.14), blurRadius: 24, spreadRadius: 1)],
          ),
          child: child,
        );
      },
    );
  }
}

/// Premium active-mission card shared by the daily and weekly flows.
///
/// Presentation-only wrapper around the EXACT existing behaviour:
/// - When the timer is not finished it shows the same "timer not finished"
///   snackbar.
/// - When ready it shows the same Hunter Verification dialog and, on confirm,
///   invokes [onComplete] (completeQuest / completeWeeklyQuest).
/// - [onCancel] runs the same cancel logic.
/// The glow controller only repaints the decoration (content, including the
/// AdWidget, is passed as [AnimatedBuilder.child] and is not rebuilt per frame).
class _ActiveMissionCard extends StatefulWidget {
  final Duration remaining;
  final String title;
  final int reward;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final BannerAd? banner;
  final bool bannerReady;

  const _ActiveMissionCard({
    required this.remaining,
    required this.title,
    required this.reward,
    required this.onComplete,
    required this.onCancel,
    required this.banner,
    required this.bannerReady,
  });

  @override
  State<_ActiveMissionCard> createState() => _ActiveMissionCardState();
}

class _ActiveMissionCardState extends State<_ActiveMissionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  void _onNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("\u26a0\ufe0f Timer not finished yet \u2014 mission cannot be completed.")),
    );
  }

  void _onCompletePressed() {
    showDialog(
      context: context,
      builder: (_) {
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
          content: Text(
            "Are you sure you completed this mission honestly?\n\nOnly you know the truth.\n\n${messages.first}",
            style: TextStyle(color: HunterTheme.textPrimary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CONTINUE MISSION")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onComplete();
              },
              child: const Text("COMPLETE"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = widget.remaining == Duration.zero;
    final Color c = ready ? HunterTheme.success : HunterTheme.primary;

    final content = Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bolt_rounded, color: c, size: 16),
          const SizedBox(width: 6),
          Text('ACTIVE MISSION', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(width: 6),
          Icon(Icons.bolt_rounded, color: c, size: 16),
        ]),
        const SizedBox(height: 10),
        Text(
          ready ? 'Ready to Complete' : 'In Progress',
          style: TextStyle(color: ready ? HunterTheme.success : Colors.orangeAccent, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: HunterTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w800, height: 1.2),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [HunterTheme.gold.withOpacity(0.28), HunterTheme.gold.withOpacity(0.12)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HunterTheme.gold.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bolt_rounded, color: HunterTheme.gold, size: 16),
            const SizedBox(width: 6),
            Text('Reward  +${widget.reward} XP', style: TextStyle(color: HunterTheme.gold, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withOpacity(0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ready ? Icons.check_circle_rounded : Icons.timer_rounded, color: c, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                ready ? "TIME'S UP!" : formatMinutesSeconds(widget.remaining),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ready ? HunterTheme.success : HunterTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ready ? HunterTheme.success : HunterTheme.border,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: ready ? _onCompletePressed : _onNotReady,
            child: Text(
              'COMPLETE MISSION',
              style: TextStyle(
                color: ready ? Colors.black : HunterTheme.textTertiary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.onCancel,
          child: Text('Cancel mission', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, decoration: TextDecoration.underline)),
        ),
        if (widget.bannerReady && widget.banner != null) ...[
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: widget.banner!.size.width.toDouble(),
              height: widget.banner!.size.height.toDouble(),
              child: AdWidget(ad: widget.banner!),
            ),
          ),
        ],
      ],
    );

    return AnimatedBuilder(
      animation: _glow,
      child: content,
      builder: (context, child) {
        final g = _glow.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.withOpacity(0.14), HunterTheme.cardColor],
            ),
            border: Border.all(color: c.withOpacity(0.5 + g * 0.3), width: 1.6),
            boxShadow: [BoxShadow(color: c.withOpacity(0.14 + g * 0.18), blurRadius: 24, spreadRadius: 1)],
          ),
          child: child,
        );
      },
    );
  }
}
