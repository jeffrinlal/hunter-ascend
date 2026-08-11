import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'hunter_data.g.dart';

/// Domain model representing the hunter's profile data cached locally.
///
/// Organized into logical sections:
/// - Core identity (name, XP, level, rank, streak)
/// - Physical stats (height, weight, BMI inputs)
/// - Water tracking
/// - Step tracking
/// - Discipline & streak state
/// - Notification preferences
/// - Membership
/// - Duel & quest statistics
/// - Feature fields: quest state (loaded for Missions screen)
///
/// The repository converts between Firestore documents and this model —
/// screens never handle raw Map<String, dynamic>.
@HiveType(typeId: 0)
class HunterData {
  const HunterData({
    // ── Core identity ──
    this.hunterName = 'Hunter',
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.profilePicture,
    // ── Physical stats ──
    this.height = 0,
    this.weight = 0,
    this.startingWeight = 0,
    this.targetWeight,
    // ── Water tracking ──
    this.waterIntakeMl = 0,
    this.waterIntakeDate = '',
    this.selectedCupSize = 250,
    this.waterGoalMl = 2000,
    // ── Step tracking ──
    this.stepOffset = 0,
    this.stepOffsetDate = '',
    this.lastStepRewardDate,
    // ── Discipline & streak state ──
    this.disciplineMode,
    this.disciplineModeChangedAt,
    this.lastQuestDate,
    this.previousStreak = 0,
    this.lastQuestResetDate,
    this.yesterdayCompletedCount = 0,
    this.yesterdayTotalQuests = 0,
    this.disciplineStartDate,
    this.lastPunishmentDate,
    this.lastRecoveryDate,
    // ── Notification preferences ──
    this.notificationTime,
    // ── Membership ──
    this.membershipType,
    this.subscriptionActive = false,
    this.reviewRequested = false,
    this.membershipExpiry,
    // ── Duel & quest statistics ──
    this.duelWins = 0,
    this.duelLosses = 0,
    this.questsDone = 0,
    // ── Feature fields: quest state (Missions screen) ──
    this.completedQuests = const [],
    this.aiQuests = const [],
    this.aiQuestDate,
    this.weeklyMissions = const [],
    this.weeklyMissionsDate,
    this.weeklyMissionsGenerated = false,
    this.activeDashboardQuestName,
    this.activeDashboardQuestXp,
    this.activeDashboardQuestEndTime,
    this.activeWeeklyMissionTitle,
    this.activeWeeklyMissionXp,
    this.activeWeeklyMissionEndTime,
    // ── Feature fields: quest path preferences ──
    this.fatLoss = false,
    this.discipline = false,
    this.muscleGain = false,
    this.selfImprovement = false,
    // ── Leaderboard XP ──
    this.weeklyXp = 0,
    this.dailyXp = 0,
    this.weeklyResetEpoch = 0,
    this.dailyResetEpoch = 0,
    // ── Achievement tracking: social ──
    this.hasSharedApp = false,
    this.hasSharedProfile = false,
    this.hasSharedReport = false,
    this.hasSharedActivity = false,
    this.hasComparedHunter = false,
    // ── Achievement tracking: walking / explorer ──
    this.totalStepsAllTime = 0,
    this.stepsAccumulatedToday = 0,
    this.totalRunsCompleted = 0,
    this.totalRunDistanceKm = 0,
    this.longestRunKm = 0,
    // ── Achievement tracking: nutrition ──
    this.mealsLoggedCount = 0,
    this.proteinGoalHitDays = 0,
    this.balancedMacroDays = 0,
    this.lastProteinGoalHitDate,
    this.lastBalancedMacroDate,
    // ── Achievement tracking: hydration ──
    this.waterLogCount = 0,
    this.waterGoalStreak = 0,
    this.lastWaterGoalHitDate,
    // ── Achievement tracking: hidden/secret time-of-day actions ──
    this.hitMidnightAction = false,
    this.hitEarlyBirdAction = false,
    this.hitNightOwlAction = false,
    // ── Publicly-equipped badge ──
    this.equippedBadgeId,
    // ── Feature unlocks ──
    this.nutritionUnlockExpiry,
    this.mapUnlockExpiry,
    // ── Dungeon lifetime counters ──
    this.monstersDefeated = 0,
    this.bossesDefeated = 0,
    this.dungeonsCompleted = 0,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CORE IDENTITY
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(0) final String hunterName;
  @HiveField(1) final int xp;
  @HiveField(2) final int level;
  @HiveField(3) final int streak;
  @HiveField(4) final String? profilePicture;

  // ═══════════════════════════════════════════════════════════════════════════
  // PHYSICAL STATS
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(26) final double height;
  @HiveField(27) final double weight;
  @HiveField(28) final double startingWeight;
  @HiveField(53) final double? targetWeight;

  // ═══════════════════════════════════════════════════════════════════════════
  // WATER TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(5) final int waterIntakeMl;
  @HiveField(6) final String waterIntakeDate;
  @HiveField(7) final int selectedCupSize;
  @HiveField(8) final int waterGoalMl;

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(9) final int stepOffset;
  @HiveField(10) final String stepOffsetDate;
  @HiveField(11) final String? lastStepRewardDate;

  // ═══════════════════════════════════════════════════════════════════════════
  // DISCIPLINE & STREAK STATE
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(13) final String? disciplineMode;
  @HiveField(14) final String? disciplineModeChangedAt;
  @HiveField(15) final String? lastQuestDate;
  @HiveField(16) final int previousStreak;
  @HiveField(17) final String? lastQuestResetDate;
  @HiveField(18) final int yesterdayCompletedCount;
  @HiveField(19) final int yesterdayTotalQuests;
  @HiveField(20) final String? disciplineStartDate;
  @HiveField(21) final String? lastPunishmentDate;
  @HiveField(22) final String? lastRecoveryDate;

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION PREFERENCES
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(12) final String? notificationTime;

  // ═══════════════════════════════════════════════════════════════════════════
  // MEMBERSHIP
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(24) final String? membershipType;
  @HiveField(25) final bool subscriptionActive;
  @HiveField(23) final bool reviewRequested;
  @HiveField(48) final String? membershipExpiry;

  // ═══════════════════════════════════════════════════════════════════════════
  // DUEL & QUEST STATISTICS
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(29) final int duelWins;
  @HiveField(30) final int duelLosses;
  @HiveField(31) final int questsDone;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE FIELDS: QUEST STATE (Missions screen)
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(32) final List<String> completedQuests;
  @HiveField(33) final List<Map<String, dynamic>> aiQuests;
  @HiveField(34) final String? aiQuestDate;
  @HiveField(35) final List<Map<String, dynamic>> weeklyMissions;
  @HiveField(36) final String? weeklyMissionsDate;
  @HiveField(37) final bool weeklyMissionsGenerated;
  @HiveField(38) final String? activeDashboardQuestName;
  @HiveField(39) final int? activeDashboardQuestXp;
  @HiveField(40) final String? activeDashboardQuestEndTime;
  @HiveField(41) final String? activeWeeklyMissionTitle;
  @HiveField(42) final int? activeWeeklyMissionXp;
  @HiveField(43) final String? activeWeeklyMissionEndTime;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE FIELDS: QUEST PATH PREFERENCES
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(44) final bool fatLoss;
  @HiveField(45) final bool discipline;
  @HiveField(46) final bool muscleGain;
  @HiveField(47) final bool selfImprovement;

  // ═══════════════════════════════════════════════════════════════════════════
  // LEADERBOARD XP (daily/weekly with lazy epoch-based reset)
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(49) final int weeklyXp;
  @HiveField(50) final int dailyXp;
  @HiveField(51) final int weeklyResetEpoch;
  @HiveField(52) final int dailyResetEpoch;

  // ═══════════════════════════════════════════════════════════════════════════
  // ACHIEVEMENT TRACKING (added to make every achievement trigger real data,
  // no cumulative predicate here is a placeholder — every field below is
  // written by a real user action; see the corresponding trigger sites).
  // ═══════════════════════════════════════════════════════════════════════════

  @HiveField(54) final bool hasSharedApp;
  @HiveField(55) final bool hasSharedProfile;
  @HiveField(56) final bool hasSharedReport;
  @HiveField(57) final bool hasSharedActivity;
  @HiveField(58) final bool hasComparedHunter;

  @HiveField(59) final int totalStepsAllTime;
  @HiveField(74) final int stepsAccumulatedToday;
  @HiveField(60) final int totalRunsCompleted;
  @HiveField(61) final double totalRunDistanceKm;
  @HiveField(62) final double longestRunKm;

  @HiveField(63) final int mealsLoggedCount;
  @HiveField(64) final int proteinGoalHitDays;
  @HiveField(65) final int balancedMacroDays;
  @HiveField(72) final String? lastProteinGoalHitDate;
  @HiveField(73) final String? lastBalancedMacroDate;

  @HiveField(66) final int waterLogCount;
  @HiveField(67) final int waterGoalStreak;
  @HiveField(68) final String? lastWaterGoalHitDate;

  @HiveField(69) final bool hitMidnightAction;
  @HiveField(70) final bool hitEarlyBirdAction;
  @HiveField(71) final bool hitNightOwlAction;

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLICLY-EQUIPPED BADGE
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Unlike the other six Hunter Rank reward types (title, border, aura,
  // dashboardTheme, reportStyle, profileEffect) — which stay private in
  // `hunters/{uid}/equippedRewards/current` — the equipped BADGE is
  // deliberately denormalized directly onto this document so every screen
  // that already reads a hunter document (Profile, Dashboard, Global
  // Rankings, Compare Hunters, Public Hunter Profile) can display it with
  // zero additional Firestore reads. Only one badge can ever be equipped at
  // a time because this is a single scalar field, not a per-type map.
  @HiveField(75) final String? equippedBadgeId;

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE UNLOCKS (30-day rewarded ad unlocks for Basic users)
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Basic users can watch a rewarded ad to unlock Nutrition or Map for 30 days.
  // Pro and Max users always have access (no expiry needed).
  // Stored as ISO 8601 date strings; null means locked (or never unlocked).
  @HiveField(76) final String? nutritionUnlockExpiry;
  @HiveField(77) final String? mapUnlockExpiry;

  // ═══════════════════════════════════════════════════════════════════════════
  // DUNGEON LIFETIME COUNTERS (achievement progress)
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // All-time cumulative dungeon totals, used ONLY to drive the Dungeon
  // achievements in `kAchievements` (achievements read hunter stats, so a
  // counter has to live here to be visible to `Achievement.isDone`).
  //
  // These never reset. They are incremented exclusively inside the existing
  // `XpService.awardXp` transaction fired by a claimed DUNGEON CLEARED
  // (`DungeonSessionManager.claimClearReward`), so they add ZERO extra
  // Firestore reads or writes and automatically inherit that claim's
  // exactly-once gate and its rollback-on-failure behaviour.
  //
  // Because a clear requires every monster to be defeated AND the boss to be
  // beaten, one claim contributes: monsters += monsters in the run,
  // bosses += 1, dungeons += 1. `bossesDefeated` and `dungeonsCompleted`
  // therefore move together in the current design (boss defeat IS the clear
  // condition); they are kept as separate fields so boss achievements stay
  // semantically independent if that ever changes.
  @HiveField(78) final int monstersDefeated;
  @HiveField(79) final int bossesDefeated;
  @HiveField(80) final int dungeonsCompleted;

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY: Firestore → Domain
  // ═══════════════════════════════════════════════════════════════════════════

  factory HunterData.fromFirestore(Map<String, dynamic> data) {
    return HunterData(
      // Core identity
      hunterName: (data['hunterName'] ?? 'Hunter').toString(),
      xp: (data['xp'] ?? 0) as int,
      level: (data['level'] ?? 1) as int,
      streak: (data['streak'] ?? 0) as int,
      profilePicture: data['profilePicture'] as String?,
      // Physical stats
      height: ((data['height'] ?? 0) as num).toDouble(),
      weight: ((data['weight'] ?? 0) as num).toDouble(),
      startingWeight: ((data['startingWeight'] ?? data['weight'] ?? 0) as num).toDouble(),
      targetWeight: data['targetWeight'] != null ? (data['targetWeight'] as num).toDouble() : null,
      // Water tracking
      waterIntakeMl: ((data['waterIntakeMl'] ?? 0) as num).toInt(),
      waterIntakeDate: (data['waterIntakeDate'] ?? '').toString(),
      selectedCupSize: ((data['selectedCupSize'] ?? 250) as num).toInt(),
      waterGoalMl: ((data['waterGoalMl'] ?? 2000) as num).toInt(),
      // Step tracking
      stepOffset: (data['stepOffset'] ?? 0) as int,
      stepOffsetDate: (data['stepOffsetDate'] ?? '').toString(),
      lastStepRewardDate: data['lastStepRewardDate']?.toString(),
      // Discipline & streak
      disciplineMode: data['disciplineMode']?.toString(),
      disciplineModeChangedAt: _timestampToString(data['disciplineModeChangedAt']),
      lastQuestDate: data['lastQuestDate']?.toString(),
      previousStreak: (data['previousStreak'] ?? 0) as int,
      lastQuestResetDate: data['lastQuestResetDate']?.toString(),
      yesterdayCompletedCount: (data['yesterdayCompletedCount'] ?? 0) as int,
      yesterdayTotalQuests: (data['yesterdayTotalQuests'] ?? 0) as int,
      disciplineStartDate: data['disciplineStartDate']?.toString(),
      lastPunishmentDate: data['lastPunishmentDate']?.toString(),
      lastRecoveryDate: _timestampToString(data['lastRecoveryDate']),
      // Notifications
      notificationTime: data['notificationTime']?.toString(),
      // Membership
      membershipType: data['membershipType']?.toString() ?? data['membership']?.toString(),
      subscriptionActive: data['subscriptionActive'] == true,
      reviewRequested: data['reviewRequested'] == true,
      membershipExpiry: _timestampToString(data['membershipExpiry']),
      // Duel & quest statistics
      duelWins: (data['duelWins'] ?? 0) as int,
      duelLosses: (data['duelLosses'] ?? 0) as int,
      questsDone: (data['questsDone'] ?? 0) as int,
      // Quest state
      completedQuests: List<String>.from(data['completedQuests'] ?? []),
      aiQuests: List<Map<String, dynamic>>.from(data['aiQuests'] ?? []),
      aiQuestDate: data['aiQuestDate']?.toString(),
      weeklyMissions: List<Map<String, dynamic>>.from(data['weeklyMissions'] ?? []),
      weeklyMissionsDate: data['weeklyMissionsDate']?.toString(),
      weeklyMissionsGenerated: data['weeklyMissionsGenerated'] == true,
      activeDashboardQuestName: data['activeDashboardQuestName']?.toString(),
      activeDashboardQuestXp: (data['activeDashboardQuestXp'] as num?)?.toInt(),
      activeDashboardQuestEndTime: _timestampToString(data['activeDashboardQuestEndTime']),
      activeWeeklyMissionTitle: data['activeWeeklyMissionTitle']?.toString(),
      activeWeeklyMissionXp: (data['activeWeeklyMissionXp'] as num?)?.toInt(),
      activeWeeklyMissionEndTime: _timestampToString(data['activeWeeklyMissionEndTime']),
      // Quest path preferences
      fatLoss: data['fatLoss'] == true,
      discipline: data['discipline'] == true,
      muscleGain: data['muscleGain'] == true,
      selfImprovement: data['selfImprovement'] == true,
      // Leaderboard XP
      weeklyXp: (data['weeklyXp'] ?? 0) as int,
      dailyXp: (data['dailyXp'] ?? 0) as int,
      weeklyResetEpoch: (data['weeklyResetEpoch'] ?? 0) as int,
      dailyResetEpoch: (data['dailyResetEpoch'] ?? 0) as int,
      // Achievement tracking: social
      hasSharedApp: data['hasSharedApp'] == true,
      hasSharedProfile: data['hasSharedProfile'] == true,
      hasSharedReport: data['hasSharedReport'] == true,
      hasSharedActivity: data['hasSharedActivity'] == true,
      hasComparedHunter: data['hasComparedHunter'] == true,
      // Achievement tracking: walking / explorer
      totalStepsAllTime: ((data['totalStepsAllTime'] ?? 0) as num).toInt(),
      stepsAccumulatedToday: ((data['stepsAccumulatedToday'] ?? 0) as num).toInt(),
      totalRunsCompleted: ((data['totalRunsCompleted'] ?? 0) as num).toInt(),
      totalRunDistanceKm: ((data['totalRunDistanceKm'] ?? 0) as num).toDouble(),
      longestRunKm: ((data['longestRunKm'] ?? 0) as num).toDouble(),
      // Achievement tracking: nutrition
      mealsLoggedCount: ((data['mealsLoggedCount'] ?? 0) as num).toInt(),
      proteinGoalHitDays: ((data['proteinGoalHitDays'] ?? 0) as num).toInt(),
      balancedMacroDays: ((data['balancedMacroDays'] ?? 0) as num).toInt(),
      lastProteinGoalHitDate: data['lastProteinGoalHitDate']?.toString(),
      lastBalancedMacroDate: data['lastBalancedMacroDate']?.toString(),
      // Achievement tracking: hydration
      waterLogCount: ((data['waterLogCount'] ?? 0) as num).toInt(),
      waterGoalStreak: ((data['waterGoalStreak'] ?? 0) as num).toInt(),
      lastWaterGoalHitDate: data['lastWaterGoalHitDate']?.toString(),
      // Achievement tracking: hidden/secret time-of-day actions
      hitMidnightAction: data['hitMidnightAction'] == true,
      hitEarlyBirdAction: data['hitEarlyBirdAction'] == true,
      hitNightOwlAction: data['hitNightOwlAction'] == true,
      // Publicly-equipped badge
      equippedBadgeId: data['equippedBadgeId']?.toString(),
      // Feature unlocks
      nutritionUnlockExpiry: data['nutritionUnlockExpiry']?.toString(),
      mapUnlockExpiry: data['mapUnlockExpiry']?.toString(),
      // Dungeon lifetime counters (achievement progress)
      monstersDefeated: ((data['monstersDefeated'] ?? 0) as num).toInt(),
      bossesDefeated: ((data['bossesDefeated'] ?? 0) as num).toInt(),
      dungeonsCompleted: ((data['dungeonsCompleted'] ?? 0) as num).toInt(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERIALIZATION: Domain → Firestore
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toFirestore() {
    return {
      'hunterName': hunterName,
      'xp': xp,
      'level': level,
      'streak': streak,
      if (profilePicture != null) 'profilePicture': profilePicture,
      'height': height,
      'weight': weight,
      'startingWeight': startingWeight,
      if (targetWeight != null) 'targetWeight': targetWeight,
      'waterIntakeMl': waterIntakeMl,
      'waterIntakeDate': waterIntakeDate,
      'selectedCupSize': selectedCupSize,
      'waterGoalMl': waterGoalMl,
      'stepOffset': stepOffset,
      'stepOffsetDate': stepOffsetDate,
      if (lastStepRewardDate != null) 'lastStepRewardDate': lastStepRewardDate,
      if (disciplineMode != null) 'disciplineMode': disciplineMode,
      if (lastQuestDate != null) 'lastQuestDate': lastQuestDate,
      'previousStreak': previousStreak,
      if (lastQuestResetDate != null) 'lastQuestResetDate': lastQuestResetDate,
      'yesterdayCompletedCount': yesterdayCompletedCount,
      'yesterdayTotalQuests': yesterdayTotalQuests,
      if (disciplineStartDate != null) 'disciplineStartDate': disciplineStartDate,
      if (lastPunishmentDate != null) 'lastPunishmentDate': lastPunishmentDate,
      if (notificationTime != null) 'notificationTime': notificationTime,
      if (membershipType != null) 'membershipType': membershipType,
      if (membershipExpiry != null) 'membershipExpiry': membershipExpiry,
      'subscriptionActive': subscriptionActive,
      'reviewRequested': reviewRequested,
      'duelWins': duelWins,
      'duelLosses': duelLosses,
      'questsDone': questsDone,
      'completedQuests': completedQuests,
      'aiQuests': aiQuests,
      if (aiQuestDate != null) 'aiQuestDate': aiQuestDate,
      'weeklyMissions': weeklyMissions,
      if (weeklyMissionsDate != null) 'weeklyMissionsDate': weeklyMissionsDate,
      'weeklyMissionsGenerated': weeklyMissionsGenerated,
      'fatLoss': fatLoss,
      'discipline': discipline,
      'muscleGain': muscleGain,
      'selfImprovement': selfImprovement,
      'weeklyXp': weeklyXp,
      'dailyXp': dailyXp,
      'weeklyResetEpoch': weeklyResetEpoch,
      'dailyResetEpoch': dailyResetEpoch,
      'hasSharedApp': hasSharedApp,
      'hasSharedProfile': hasSharedProfile,
      'hasSharedReport': hasSharedReport,
      'hasSharedActivity': hasSharedActivity,
      'hasComparedHunter': hasComparedHunter,
      'totalStepsAllTime': totalStepsAllTime,
      'stepsAccumulatedToday': stepsAccumulatedToday,
      'totalRunsCompleted': totalRunsCompleted,
      'totalRunDistanceKm': totalRunDistanceKm,
      'longestRunKm': longestRunKm,
      // mealsLoggedCount / proteinGoalHitDays / balancedMacroDays /
      // lastProteinGoalHitDate / lastBalancedMacroDate are intentionally
      // NOT written here — they're local-only nutrition achievement
      // counters (see HunterRepository.updateNutritionAchievementLocal).
      // Nothing else reads them from Firestore, so keeping them local
      // avoids an extra write on every meal save.
      'waterLogCount': waterLogCount,
      'waterGoalStreak': waterGoalStreak,
      if (lastWaterGoalHitDate != null) 'lastWaterGoalHitDate': lastWaterGoalHitDate,
      'hitMidnightAction': hitMidnightAction,
      'hitEarlyBirdAction': hitEarlyBirdAction,
      'hitNightOwlAction': hitNightOwlAction,
      if (equippedBadgeId != null) 'equippedBadgeId': equippedBadgeId,
      if (nutritionUnlockExpiry != null) 'nutritionUnlockExpiry': nutritionUnlockExpiry,
      if (mapUnlockExpiry != null) 'mapUnlockExpiry': mapUnlockExpiry,
      // NOTE: monstersDefeated / bossesDefeated / dungeonsCompleted are
      // deliberately NOT serialized here — exactly like `dungeonScore`.
      // They are only ever mutated server-side via `FieldValue.increment`
      // inside the dungeon-clear XP transaction, so echoing a locally-cached
      // absolute value back into the document could clobber an increment
      // (last-write-wins). They are read-only on the client: `fromFirestore`
      // in, never out.
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // copyWith
  // ═══════════════════════════════════════════════════════════════════════════

  HunterData copyWith({
    String? hunterName,
    int? xp,
    int? level,
    int? streak,
    String? profilePicture,
    double? height,
    double? weight,
    double? startingWeight,
    double? targetWeight,
    int? waterIntakeMl,
    String? waterIntakeDate,
    int? selectedCupSize,
    int? waterGoalMl,
    int? stepOffset,
    String? stepOffsetDate,
    String? lastStepRewardDate,
    String? disciplineMode,
    String? disciplineModeChangedAt,
    String? lastQuestDate,
    int? previousStreak,
    String? lastQuestResetDate,
    int? yesterdayCompletedCount,
    int? yesterdayTotalQuests,
    String? disciplineStartDate,
    String? lastPunishmentDate,
    String? lastRecoveryDate,
    String? notificationTime,
    String? membershipType,
    bool? subscriptionActive,
    bool? reviewRequested,
    String? membershipExpiry,
    int? duelWins,
    int? duelLosses,
    int? questsDone,
    List<String>? completedQuests,
    List<Map<String, dynamic>>? aiQuests,
    String? aiQuestDate,
    List<Map<String, dynamic>>? weeklyMissions,
    String? weeklyMissionsDate,
    bool? weeklyMissionsGenerated,
    String? activeDashboardQuestName,
    int? activeDashboardQuestXp,
    String? activeDashboardQuestEndTime,
    String? activeWeeklyMissionTitle,
    int? activeWeeklyMissionXp,
    String? activeWeeklyMissionEndTime,
    bool? fatLoss,
    bool? discipline,
    bool? muscleGain,
    bool? selfImprovement,
    int? weeklyXp,
    int? dailyXp,
    int? weeklyResetEpoch,
    int? dailyResetEpoch,
    bool? hasSharedApp,
    bool? hasSharedProfile,
    bool? hasSharedReport,
    bool? hasSharedActivity,
    bool? hasComparedHunter,
    int? totalStepsAllTime,
    int? stepsAccumulatedToday,
    int? totalRunsCompleted,
    double? totalRunDistanceKm,
    double? longestRunKm,
    int? mealsLoggedCount,
    int? proteinGoalHitDays,
    int? balancedMacroDays,
    String? lastProteinGoalHitDate,
    String? lastBalancedMacroDate,
    int? waterLogCount,
    int? waterGoalStreak,
    String? lastWaterGoalHitDate,
    bool? hitMidnightAction,
    bool? hitEarlyBirdAction,
    bool? hitNightOwlAction,
    String? equippedBadgeId,
    String? nutritionUnlockExpiry,
    String? mapUnlockExpiry,
    int? monstersDefeated,
    int? bossesDefeated,
    int? dungeonsCompleted,
  }) {
    return HunterData(
      hunterName: hunterName ?? this.hunterName,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      profilePicture: profilePicture ?? this.profilePicture,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      startingWeight: startingWeight ?? this.startingWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      waterIntakeDate: waterIntakeDate ?? this.waterIntakeDate,
      selectedCupSize: selectedCupSize ?? this.selectedCupSize,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      stepOffset: stepOffset ?? this.stepOffset,
      stepOffsetDate: stepOffsetDate ?? this.stepOffsetDate,
      lastStepRewardDate: lastStepRewardDate ?? this.lastStepRewardDate,
      disciplineMode: disciplineMode ?? this.disciplineMode,
      disciplineModeChangedAt: disciplineModeChangedAt ?? this.disciplineModeChangedAt,
      lastQuestDate: lastQuestDate ?? this.lastQuestDate,
      previousStreak: previousStreak ?? this.previousStreak,
      lastQuestResetDate: lastQuestResetDate ?? this.lastQuestResetDate,
      yesterdayCompletedCount: yesterdayCompletedCount ?? this.yesterdayCompletedCount,
      yesterdayTotalQuests: yesterdayTotalQuests ?? this.yesterdayTotalQuests,
      disciplineStartDate: disciplineStartDate ?? this.disciplineStartDate,
      lastPunishmentDate: lastPunishmentDate ?? this.lastPunishmentDate,
      lastRecoveryDate: lastRecoveryDate ?? this.lastRecoveryDate,
      notificationTime: notificationTime ?? this.notificationTime,
      membershipType: membershipType ?? this.membershipType,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      reviewRequested: reviewRequested ?? this.reviewRequested,
      membershipExpiry: membershipExpiry ?? this.membershipExpiry,
      duelWins: duelWins ?? this.duelWins,
      duelLosses: duelLosses ?? this.duelLosses,
      questsDone: questsDone ?? this.questsDone,
      completedQuests: completedQuests ?? this.completedQuests,
      aiQuests: aiQuests ?? this.aiQuests,
      aiQuestDate: aiQuestDate ?? this.aiQuestDate,
      weeklyMissions: weeklyMissions ?? this.weeklyMissions,
      weeklyMissionsDate: weeklyMissionsDate ?? this.weeklyMissionsDate,
      weeklyMissionsGenerated: weeklyMissionsGenerated ?? this.weeklyMissionsGenerated,
      activeDashboardQuestName: activeDashboardQuestName ?? this.activeDashboardQuestName,
      activeDashboardQuestXp: activeDashboardQuestXp ?? this.activeDashboardQuestXp,
      activeDashboardQuestEndTime: activeDashboardQuestEndTime ?? this.activeDashboardQuestEndTime,
      activeWeeklyMissionTitle: activeWeeklyMissionTitle ?? this.activeWeeklyMissionTitle,
      activeWeeklyMissionXp: activeWeeklyMissionXp ?? this.activeWeeklyMissionXp,
      activeWeeklyMissionEndTime: activeWeeklyMissionEndTime ?? this.activeWeeklyMissionEndTime,
      fatLoss: fatLoss ?? this.fatLoss,
      discipline: discipline ?? this.discipline,
      muscleGain: muscleGain ?? this.muscleGain,
      selfImprovement: selfImprovement ?? this.selfImprovement,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      dailyXp: dailyXp ?? this.dailyXp,
      weeklyResetEpoch: weeklyResetEpoch ?? this.weeklyResetEpoch,
      dailyResetEpoch: dailyResetEpoch ?? this.dailyResetEpoch,
      hasSharedApp: hasSharedApp ?? this.hasSharedApp,
      hasSharedProfile: hasSharedProfile ?? this.hasSharedProfile,
      hasSharedReport: hasSharedReport ?? this.hasSharedReport,
      hasSharedActivity: hasSharedActivity ?? this.hasSharedActivity,
      hasComparedHunter: hasComparedHunter ?? this.hasComparedHunter,
      totalStepsAllTime: totalStepsAllTime ?? this.totalStepsAllTime,
      stepsAccumulatedToday: stepsAccumulatedToday ?? this.stepsAccumulatedToday,
      totalRunsCompleted: totalRunsCompleted ?? this.totalRunsCompleted,
      totalRunDistanceKm: totalRunDistanceKm ?? this.totalRunDistanceKm,
      longestRunKm: longestRunKm ?? this.longestRunKm,
      mealsLoggedCount: mealsLoggedCount ?? this.mealsLoggedCount,
      proteinGoalHitDays: proteinGoalHitDays ?? this.proteinGoalHitDays,
      balancedMacroDays: balancedMacroDays ?? this.balancedMacroDays,
      lastProteinGoalHitDate: lastProteinGoalHitDate ?? this.lastProteinGoalHitDate,
      lastBalancedMacroDate: lastBalancedMacroDate ?? this.lastBalancedMacroDate,
      waterLogCount: waterLogCount ?? this.waterLogCount,
      waterGoalStreak: waterGoalStreak ?? this.waterGoalStreak,
      lastWaterGoalHitDate: lastWaterGoalHitDate ?? this.lastWaterGoalHitDate,
      hitMidnightAction: hitMidnightAction ?? this.hitMidnightAction,
      hitEarlyBirdAction: hitEarlyBirdAction ?? this.hitEarlyBirdAction,
      hitNightOwlAction: hitNightOwlAction ?? this.hitNightOwlAction,
      equippedBadgeId: equippedBadgeId ?? this.equippedBadgeId,
      nutritionUnlockExpiry: nutritionUnlockExpiry ?? this.nutritionUnlockExpiry,
      mapUnlockExpiry: mapUnlockExpiry ?? this.mapUnlockExpiry,
      monstersDefeated: monstersDefeated ?? this.monstersDefeated,
      bossesDefeated: bossesDefeated ?? this.bossesDefeated,
      dungeonsCompleted: dungeonsCompleted ?? this.dungeonsCompleted,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static String? _timestampToString(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is String) return value;
    return value.toString();
  }
}
