import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/core/skins/skin_aware_surface.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hunter_ascend/services/ai_quest_service.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/achievements_service.dart';
import 'package:hunter_ascend/widgets/dashboard/sleep_card.dart';
import 'package:hunter_ascend/widgets/dashboard/sleep_ambience_picker.dart';
import 'package:hunter_ascend/widgets/dashboard/sleep_summary_dialog.dart';
import 'package:hunter_ascend/screens/dashboard/sleep_start_screen.dart';
import 'package:hunter_ascend/services/sleep_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/mission_engine.dart';
import 'package:hunter_ascend/services/xp_service.dart';
import 'package:hunter_ascend/services/rank_celebration_service.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/models/custom_quest.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/data/repositories/quest_repository.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:hunter_ascend/widgets/missions/active_mission_card.dart';
import 'package:hunter_ascend/widgets/missions/mission_duration_dialog.dart';


/// Missions screen: daily quests, weekly missions, AI quest generation,
/// custom quest dialog, banner ads. Execution (duration dialog, start flow,
/// countdown, completion detection, active-card UI, persistence/restore)
/// is delegated to the shared [MissionEngine] + [ActiveMissionCard] that
/// Dungeons reuse as well.
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

  /// Runs the daily rollover before discipline evaluates yesterday's counts.
  /// A transaction keeps simultaneous startup calls from resetting twice.
  ///
  /// ## Optimized reset (completed-only regeneration)
  /// Instead of clearing all `completedQuests` and regenerating all missions,
  /// this now:
  /// 1. Records yesterday's completion/total counts (unchanged).
  /// 2. Removes ONLY the names of completed missions from `completedQuests`.
  /// 3. Marks `lastQuestResetDate = today` to prevent re-triggering.
  ///
  /// The actual replacement of completed missions happens in `_loadAIQuests()`,
  /// which inspects each mission's completion state and age.
  static Future<bool> resetDailyQuestsIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    final today = DateTime.now().toString().substring(0, 10);
    final current = await ref.get();
    if (current.exists && (current.data()?['lastQuestResetDate'] ?? '') == today) {
      return false;
    }
    final customCount = await FirebaseFirestore.instance
        .collection('custom_quests')
        .where('uid', isEqualTo: user.uid)
        .get()
        .then((snapshot) => snapshot.docs.length);

    var reset = false;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      reset = false;
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if ((data['lastQuestResetDate'] ?? '') == today) return;

      final completed = List<String>.from(data['completedQuests'] ?? []);
      final aiQuests = List.from(data['aiQuests'] ?? []);
      txn.update(ref, {
        'yesterdayCompletedCount': completed.length,
        'yesterdayTotalQuests': aiQuests.length + customCount,
        // Only clear the names of missions that were completed yesterday.
        // Retained (incomplete) missions keep their name in completedQuests=[]
        // since they weren't completed — their absence from the list already
        // means "incomplete", so the cleared list is correct.
        'completedQuests': <String>[],
        'lastQuestResetDate': today,
      });
      reset = true;
    });
    return reset;
  }
}


class _MissionsScreenState extends State<MissionsScreen> {

  // ── Colors ──────────────────────────────────────────────
  // Membership-aware accent: app primary for Basic, gold for Pro, purple for Max.
  static Color get _blue => MembershipTheme.current.accent;

  // ── State ────────────────────────────────────────────────
  int xp = 0;
  int level = 1;

  bool _isCompletingQuest = false;
  bool _isCompletingWeeklyQuest = false;

  // ── Mission execution — delegated to the shared MissionEngine (start
  //    flow, countdown, completion detection, persistence, restore). The
  //    daily and weekly runs each own their own Firestore slot; Dungeons
  //    run the same engine from the dungeon play screen. ─────────────────
  final MissionEngine _dailyEngine = MissionEngine(
    titleField: 'activeDashboardQuestName',
    xpField: 'activeDashboardQuestXp',
    endTimeField: 'activeDashboardQuestEndTime',
  );
  final MissionEngine _weeklyEngine = MissionEngine(
    titleField: 'activeWeeklyMissionTitle',
    xpField: 'activeWeeklyMissionXp',
    endTimeField: 'activeWeeklyMissionEndTime',
    rewardMultiplier: 3, // weekly missions reward 3x daily
  );

  /// Banners shown on the active mission cards (shared lifecycle: single
  /// retry, membership-aware — see [MissionBannerAd]).
  late final MissionBannerAd _dailyBanner =
      MissionBannerAd(onChanged: _onBannerChanged);
  late final MissionBannerAd _weeklyBanner =
      MissionBannerAd(onChanged: _onBannerChanged);

  // ── Weekly missions ──────────────────────────────────────
  List<Map<String, dynamic>> weeklyMissions = [];
  bool _weeklyLoading = false;

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
      checkDailyReset().then((_) => _loadAIQuests());
    }
  }

  List<Map<String, dynamic>> generatedQuests = [];

  static const Duration _aiLockTimeout = Duration(minutes: 5);


  /// Maximum number of daily AI missions.
  static const int _dailyMissionCount = 5;

  /// Missions older than this are expired and replaced regardless of
  /// completion state.
  static const int _missionExpiryDays = 30;

  Future<void> _loadAIQuests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('hunters').doc(uid);
    final doc = await ref.get();

    if (!mounted) return;
    final data = doc.data() ?? {};

    final today = DateTime.now().toIso8601String().split('T').first;
    final savedDate = data['aiQuestDate'] ?? '';

    // If quests were already generated/refreshed TODAY, just load them.
    if (savedDate == today) {
      _applyQuestsFromFirestore(data);
      return;
    }

    // ── Determine which missions need replacement ──
    final existingQuests =
        List<Map<String, dynamic>>.from(data['aiQuests'] ?? []);
    final completedNames =
        List<String>.from(data['completedQuests'] ?? []);

    final retained = <Map<String, dynamic>>[];
    final retainedTitles = <String>[];

    for (final q in existingQuests) {
      final title = (q['title'] ?? '').toString();
      final isCompleted = completedNames.contains(title);
      final isExpired = _isMissionExpired(q, savedDate);

      if (!isCompleted && !isExpired) {
        retained.add(q);
        retainedTitles.add(title);
      }
    }

    // Cap retained missions at the target count (handles migration from 6→5).
    while (retained.length > _dailyMissionCount) {
      retained.removeLast();
      retainedTitles.removeLast();
    }

    final replacementCount = _dailyMissionCount - retained.length;

    // If nothing needs replacing, just stamp today's date and persist the
    // retained set (possibly trimmed from 6→5 on first post-update run).
    if (replacementCount <= 0) {
      final updatedQuests = retained.take(_dailyMissionCount).toList();
      await ref.update({
        'aiQuestDate': today,
        'aiQuests': updatedQuests,
      });
      if (!mounted) return;
      setState(() {
        generatedQuests = _questsToDisplayList(updatedQuests);
      });
      return;
    }

    // ── Acquire generation lock (prevents concurrent AI calls) ──
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
      // Another instance is generating. Wait briefly, then load whatever
      // it produces.
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final refreshed = await ref.get();
      if (!mounted) return;
      _applyQuestsFromFirestore(refreshed.data() ?? {});
      return;
    }

    // ── We hold the lock. Generate only the replacements. ──
    try {
      final hunter = data;

      List<String> goals = [];
      if (hunter['fatLoss'] == true) goals.add('Fat Loss');
      if (hunter['discipline'] == true) goals.add('Discipline');
      if (hunter['muscleGain'] == true) goals.add('Muscle Gain');
      if (hunter['selfImprovement'] == true) goals.add('Self Improvement');

      final goalString = goals.join(', ');

      final newQuests = await AIQuestService.generateQuests(
        level: hunter['level'] ?? 1,
        streak: hunter['streak'] ?? 0,
        weight: (hunter['weight'] ?? 85).toDouble(),
        height: (hunter['height'] ?? 167).toDouble(),
        goals: goalString,
        count: replacementCount,
        excludeTitles: retainedTitles,
      );

      if (!mounted) return;

      if (newQuests.isEmpty) {
        await ref.update({'aiQuestGeneratingAt': FieldValue.delete()});
        return;
      }

      // `generateQuests` already persisted the NEW quests to Firestore, but it
      // wrote them as the ENTIRE aiQuests array (which is just the new ones).
      // We need to merge retained + new and re-persist the combined set.
      final combined = <Map<String, dynamic>>[
        ...retained,
        ...newQuests.whereType<Map>().map((q) => Map<String, dynamic>.from(q)),
      ];

      // Trim to target count in case AI returned extras.
      final finalQuests = combined.take(_dailyMissionCount).toList();

      await ref.update({
        'aiQuestDate': today,
        'aiQuests': finalQuests,
        'aiQuestGeneratingAt': FieldValue.delete(),
      });

      if (!mounted) return;
      setState(() {
        generatedQuests = _questsToDisplayList(finalQuests);
      });

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

  /// Checks if a mission is older than [_missionExpiryDays].
  ///
  /// Uses the per-mission `createdAt` field if present; falls back to the
  /// batch-level `aiQuestDate` for missions created before this optimization
  /// was deployed (graceful migration — no data loss).
  static bool _isMissionExpired(Map<String, dynamic> quest, String batchDate) {
    final createdStr =
        (quest['createdAt'] ?? batchDate).toString();
    if (createdStr.isEmpty) return false;
    final created = DateTime.tryParse(createdStr);
    if (created == null) return false;
    return DateTime.now().difference(created).inDays >= _missionExpiryDays;
  }

  /// Converts raw Firestore quest maps to the display-format used by the UI.
  static List<Map<String, dynamic>> _questsToDisplayList(
    List<Map<String, dynamic>> quests,
  ) {
    return quests.map<Map<String, dynamic>>((q) {
      return {
        "name": q["title"],
        "xp": q["xp"],
        "icon": Icons.auto_awesome,
      };
    }).toList();
  }

  /// Applies already-persisted quests from a Firestore document to local state.
  void _applyQuestsFromFirestore(Map<String, dynamic> data) {
    final quests = List<Map<String, dynamic>>.from(data['aiQuests'] ?? []);
    setState(() {
      generatedQuests = _questsToDisplayList(quests);
    });
  }


  List<String> completedQuests = [];

  final TextEditingController customQuestController = TextEditingController();


  // ── Init ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    MembershipService.instance.tierNotifier.addListener(_onMembershipTierChanged);

    _dailyEngine.addListener(_onEngineChanged);
    _weeklyEngine.addListener(_onEngineChanged);

    updateQuestCountdown();
    countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => updateQuestCountdown(),
    );

    _dailyBanner.load();
    _weeklyBanner.load();

    loadHunterData().then((_) async {
      await checkDailyReset();
      await _loadAIQuests();
    });

    _restoreMissionEngines();
    _loadWeeklyMissions();

    // Initialize sleep mission state.
    SleepService.instance.initialize();
  }

  @override
  void dispose() {
    MembershipService.instance.tierNotifier.removeListener(_onMembershipTierChanged);
    _dailyEngine.removeListener(_onEngineChanged);
    _weeklyEngine.removeListener(_onEngineChanged);
    _dailyEngine.dispose();
    _weeklyEngine.dispose();
    _dailyBanner.dispose();
    _weeklyBanner.dispose();
    countdownTimer?.cancel();
    customQuestController.dispose();
    super.dispose();
  }


  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  void _onBannerChanged() {
    if (mounted) setState(() {});
  }

  void _onMembershipTierChanged() {
    // Banners manage their own load/dispose on tier changes — just rebuild.
    if (mounted) setState(() {});
  }


  // ── Quest logic ──────────────────────────────────────────
  void startQuest(String questName, int reward) {
    showMissionDurationDialog(
      context: context,
      title: questName,
      onSelected: (minutes) =>
          _dailyEngine.start(title: questName, minutes: minutes),
    );
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
    final completedQuestName = _dailyEngine.title ?? '';
    final int reward = _dailyEngine.reward;
    await _dailyEngine.clearRun();
    setState(() { completedQuests.add(completedQuestName); });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final oldLevel = level;
      final result = await XpService.instance.awardXp(amount: reward);
      if (result != null) {
        if (mounted) setState(() { xp = result.xp; level = result.level; });
        else { xp = result.xp; level = result.level; }
        leveledUp = result.leveledUp;
        if (leveledUp && mounted) {
          MilestoneService.celebrateLevelUps(context, oldLevel, result.level);
          // Presentation-only Rank-Up / Reward-Unlock celebrations, queued
          // right after the level-up dialog(s). Reads RankService/
          // RankRewardService — never modifies progression or grants.
          RankCelebrationService.instance.celebrateIfRankUp(
            context,
            uid: user.uid,
            oldLevel: oldLevel,
            newLevel: result.level,
          );
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

    // Immediately re-evaluate/celebrate any achievement this quest
    // completion just satisfied — quest-count ladder (q_1..q_1000), plus any
    // XP/level/streak-driven ones this same completion also crossed.
    await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);

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


  // Seeds the local xp / level / completedQuests display state. All three are
  // HunterData fields and this screen already renders the same document via
  // its StreamBuilder on HunterRepository.watch(), so the live-synced cache is
  // the same value this read would return. Quest completion, streak and reset
  // logic are untouched — they keep their own authoritative reads and
  // transactions. Falls back to a real read on a cold cache so first-run
  // behaviour is unchanged.
  Future<void> loadHunterData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cached = HunterRepository.instance.getCached();
    HunterData hunter;
    if (cached != null) {
      hunter = cached;
    } else {
      final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
      if (!doc.exists) return;
      hunter = HunterData.fromFirestore(doc.data()!);
    }

    if (!mounted) return;
    setState(() {
      xp = hunter.xp;
      level = hunter.level;
      completedQuests = List<String>.from(hunter.completedQuests);
    });
  }

  // Restores both mission engines from ONE shared read of the hunter
  // document. The daily and weekly engines occupy different field slots on
  // the SAME document, so they previously issued two identical reads per
  // Missions screen entry.
  //
  // This intentionally keeps a fresh authoritative read rather than using the
  // HunterRepository cache: engine restore rehydrates the reward (XP) amount
  // that is later awarded on completion. Only the number of fetches changes —
  // both engines see exactly the values they saw before. If the shared read
  // fails, each engine falls back to fetching for itself, preserving the
  // original behaviour.
  Future<void> _restoreMissionEngines() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      await _dailyEngine.restore(hunterDoc: data);
      await _weeklyEngine.restore(hunterDoc: data);
    } catch (e) {
      debugPrint('MissionsScreen._restoreMissionEngines: $e');
      await _dailyEngine.restore();
      await _weeklyEngine.restore();
    }
  }

  Future<void> checkDailyReset() async {
    await MissionsScreen.resetDailyQuestsIfNeeded();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();
    if (!mounted || !doc.exists) return;
    final data = doc.data()!;
    final today = DateTime.now().toString().substring(0, 10);
    if ((data['lastQuestResetDate'] ?? '') == today) {
      setState(() {
        completedQuests = List<String>.from(data['completedQuests'] ?? []);
      });
    }
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

  /// Maximum number of weekly missions.
  static const int _weeklyMissionCount = 1;

  Future<void> _generateWeeklyMissions(
      Map<String, dynamic> data, String currentWeek) async {
    if (mounted) setState(() => _weeklyLoading = true);

    // ── Determine which existing weekly missions to retain ──
    final existing = (data['weeklyMissions'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];

    final retained = <Map<String, dynamic>>[];
    final retainedTitles = <String>[];

    for (final m in existing) {
      final isCompleted = m['completed'] == true;
      final isExpired = _isWeeklyMissionExpired(m, data);
      if (!isCompleted && !isExpired) {
        retained.add(m);
        retainedTitles.add((m['title'] ?? '').toString());
      }
    }

    // Cap at target count (handles migration from 3→1).
    while (retained.length > _weeklyMissionCount) {
      retained.removeLast();
      retainedTitles.removeLast();
    }

    final replacementCount = _weeklyMissionCount - retained.length;

    // Nothing to replace — just update the week marker and keep existing.
    if (replacementCount <= 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .update({
          'weeklyMissions': retained.take(_weeklyMissionCount).toList(),
          'weeklyMissionsDate': currentWeek,
          'weeklyMissionsGenerated': true,
        });
      }
      if (mounted) {
        setState(() {
          weeklyMissions = retained.take(_weeklyMissionCount).toList();
          _weeklyLoading = false;
        });
      }
      return;
    }

    // ── Generate only the replacements ──
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

    final raw = await AIQuestService.generateWeeklyQuests(
      goals: goals,
      level: lvl,
      count: replacementCount,
      excludeTitles: retainedTitles,
    );

    final today = DateTime.now().toIso8601String().split('T').first;
    var newMissions = raw.take(replacementCount).map<Map<String, dynamic>>((q) {
      final m = q as Map;
      return {
        'title': (m['title'] ?? 'Weekly Mission').toString(),
        'completed': false,
        'xpReward': ((m['xp'] ?? 150) as num).toInt() * 3,
        'createdAt': (m['createdAt'] ?? today).toString(),
      };
    }).toList();

    if (newMissions.isEmpty) {
      newMissions = [
        {
          'title': 'Walk 25,000 steps this week',
          'completed': false,
          'xpReward': 450,
          'createdAt': today,
        },
      ];
    }

    final combined = <Map<String, dynamic>>[...retained, ...newMissions];
    final finalMissions = combined.take(_weeklyMissionCount).toList();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({
        'weeklyMissions': finalMissions,
        'weeklyMissionsDate': currentWeek,
        'weeklyMissionsGenerated': true,
      });
    }
    if (mounted) {
      setState(() {
        weeklyMissions = finalMissions;
        _weeklyLoading = false;
      });
    }
  }

  /// Checks if a weekly mission has been incomplete for >= 30 days.
  /// Falls back to `weeklyMissionsDate` batch identifier for missions without
  /// a per-mission `createdAt` (graceful migration).
  static bool _isWeeklyMissionExpired(
    Map<String, dynamic> mission,
    Map<String, dynamic> hunterData,
  ) {
    final createdStr = (mission['createdAt'] ??
            hunterData['weeklyMissionsDate'] ??
            '')
        .toString();
    if (createdStr.isEmpty) return false;
    // Weekly date may be in "YYYY-Www" format — parse only ISO dates.
    final created = DateTime.tryParse(createdStr);
    if (created == null) {
      // If it's a week-ID string (e.g. "2024-W29"), compute age from the
      // week number. For simplicity: if the week ID is from > 4 weeks ago,
      // treat as expired.
      final match = RegExp(r'(\d{4})-W(\d{2})').firstMatch(createdStr);
      if (match == null) return false;
      final year = int.tryParse(match.group(1)!) ?? 0;
      final week = int.tryParse(match.group(2)!) ?? 0;
      final missionDate =
          DateTime(year, 1, 1).add(Duration(days: (week - 1) * 7));
      return DateTime.now().difference(missionDate).inDays >= 30;
    }
    return DateTime.now().difference(created).inDays >= 30;
  }


  void startWeeklyQuest(String title) {
    showMissionDurationDialog(
      context: context,
      title: title,
      onSelected: (minutes) =>
          _weeklyEngine.start(title: title, minutes: minutes),
    );
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
    final completedTitle = _weeklyEngine.title ?? '';
    final int reward = _weeklyEngine.reward;
    await _weeklyEngine.clearRun();
    setState(() {
      for (final m in weeklyMissions) {
        if (m['title'] == completedTitle) m['completed'] = true;
      }
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final oldLevel = level;
      final result = await XpService.instance.awardXp(amount: reward);
      if (result != null) {
        if (mounted) setState(() { xp = result.xp; level = result.level; });
        else { xp = result.xp; level = result.level; }
        leveledUp = result.leveledUp;
        if (leveledUp && mounted) {
          MilestoneService.celebrateLevelUps(context, oldLevel, result.level);
          // Presentation-only Rank-Up / Reward-Unlock celebrations, queued
          // right after the level-up dialog(s). Reads RankService/
          // RankRewardService — never modifies progression or grants.
          RankCelebrationService.instance.celebrateIfRankUp(
            context,
            uid: user.uid,
            oldLevel: oldLevel,
            newLevel: result.level,
          );
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

    // Immediately re-evaluate/celebrate any achievement this weekly mission
    // completion just satisfied (quest-count ladder, XP/level, etc.).
    await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);

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
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
        SkinService.instance.activeSkinNotifier,
        SkinService.instance.skinAppearanceActiveNotifier,
      ]),
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
    return MembershipScaffold(
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
              if (_dailyEngine.isActive) ...[
                ActiveMissionCard(
                  remaining: _dailyEngine.remaining,
                  title: _dailyEngine.title ?? '',
                  reward: _dailyEngine.reward,
                  onComplete: completeQuest,
                  onCancel: () => _dailyEngine.clearRun(),
                  banner: _dailyBanner.ad,
                  bannerReady: _dailyBanner.ready,
                ),
                const SizedBox(height: 20),
              ],
              EntranceFadeSlide(
                delay: const Duration(milliseconds: 100),
                child: _buildQuestsSection(),
              ),
              if (_weeklyEngine.isActive) ...[
                const SizedBox(height: 20),
                ActiveMissionCard(
                  remaining: _weeklyEngine.remaining,
                  title: _weeklyEngine.title ?? '',
                  reward: _weeklyEngine.reward,
                  onComplete: completeWeeklyQuest,
                  onCancel: () => _weeklyEngine.clearRun(),
                  banner: _weeklyBanner.ad,
                  bannerReady: _weeklyBanner.ready,
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
              color: _blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blue.withOpacity(0.35)),
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
          gradient: LinearGradient(colors: MembershipTheme.current.gradient),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _blue.withOpacity(0.35), blurRadius: 8)],
        ),
        child: Icon(Icons.add_rounded,
            color: MembershipTheme.isMax ? Colors.white : Colors.black,
            size: 20),
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
              accent: MembershipTheme.current.accent,
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
                accent: MembershipTheme.current.accent,
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
        : (isCustom ? HunterTheme.gold : MembershipTheme.current.accent);

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
            child: Center(child: CircularProgressIndicator(color: MembershipTheme.current.accent)),
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
    final accent = MembershipTheme.current.accent;

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

    // Phase 3: wrapped in SkinAwareSurface, which is a no-op for
    // Classic/Premium-Theme users (see that widget's doc comment). This
    // wraps the OUTER animated card without touching the existing `_glow`
    // AnimationController or its own border/gradient logic at all.
    return SkinAwareSurface(
      child: AnimatedBuilder(
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
      ),
    );
  }
}
