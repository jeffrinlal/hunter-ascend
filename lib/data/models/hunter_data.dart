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
