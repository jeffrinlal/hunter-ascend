import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'hunter_data.g.dart';

/// Domain model representing the hunter's profile data cached locally.
///
/// This is the strongly-typed representation of `hunters/{uid}` fields
/// relevant to the Dashboard. The repository converts between Firestore
/// documents and this model — screens never handle raw Map<String, dynamic>.
@HiveType(typeId: 0)
class HunterData {
  const HunterData({
    this.hunterName = 'Hunter',
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.profilePicture,
    this.waterIntakeMl = 0,
    this.waterIntakeDate = '',
    this.selectedCupSize = 250,
    this.waterGoalMl = 2000,
    this.stepOffset = 0,
    this.stepOffsetDate = '',
    this.lastStepRewardDate,
    this.notificationTime,
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
    this.reviewRequested = false,
    this.membershipType,
    this.subscriptionActive = false,
  });

  @HiveField(0) final String hunterName;
  @HiveField(1) final int xp;
  @HiveField(2) final int level;
  @HiveField(3) final int streak;
  @HiveField(4) final String? profilePicture;
  @HiveField(5) final int waterIntakeMl;
  @HiveField(6) final String waterIntakeDate;
  @HiveField(7) final int selectedCupSize;
  @HiveField(8) final int waterGoalMl;
  @HiveField(9) final int stepOffset;
  @HiveField(10) final String stepOffsetDate;
  @HiveField(11) final String? lastStepRewardDate;
  @HiveField(12) final String? notificationTime;
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
  @HiveField(23) final bool reviewRequested;
  @HiveField(24) final String? membershipType;
  @HiveField(25) final bool subscriptionActive;

  // ── Factory: Firestore → Domain ────────────────────────────────────────

  /// Creates a [HunterData] from a Firestore document snapshot's data map.
  factory HunterData.fromFirestore(Map<String, dynamic> data) {
    return HunterData(
      hunterName: (data['hunterName'] ?? 'Hunter').toString(),
      xp: (data['xp'] ?? 0) as int,
      level: (data['level'] ?? 1) as int,
      streak: (data['streak'] ?? 0) as int,
      profilePicture: data['profilePicture'] as String?,
      waterIntakeMl: ((data['waterIntakeMl'] ?? 0) as num).toInt(),
      waterIntakeDate: (data['waterIntakeDate'] ?? '').toString(),
      selectedCupSize: ((data['selectedCupSize'] ?? 250) as num).toInt(),
      waterGoalMl: ((data['waterGoalMl'] ?? 2000) as num).toInt(),
      stepOffset: (data['stepOffset'] ?? 0) as int,
      stepOffsetDate: (data['stepOffsetDate'] ?? '').toString(),
      lastStepRewardDate: data['lastStepRewardDate']?.toString(),
      notificationTime: data['notificationTime']?.toString(),
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
      reviewRequested: data['reviewRequested'] == true,
      membershipType: data['membershipType']?.toString() ?? data['membership']?.toString(),
      subscriptionActive: data['subscriptionActive'] == true,
    );
  }

  // ── Serialization: Domain → Firestore ──────────────────────────────────

  /// Converts this model to a Firestore-compatible map.
  /// Used only for debugging/testing — writes go through specific field
  /// updates, not full-document overwrites.
  Map<String, dynamic> toFirestore() {
    return {
      'hunterName': hunterName,
      'xp': xp,
      'level': level,
      'streak': streak,
      if (profilePicture != null) 'profilePicture': profilePicture,
      'waterIntakeMl': waterIntakeMl,
      'waterIntakeDate': waterIntakeDate,
      'selectedCupSize': selectedCupSize,
      'waterGoalMl': waterGoalMl,
      'stepOffset': stepOffset,
      'stepOffsetDate': stepOffsetDate,
      if (lastStepRewardDate != null) 'lastStepRewardDate': lastStepRewardDate,
      if (notificationTime != null) 'notificationTime': notificationTime,
      if (disciplineMode != null) 'disciplineMode': disciplineMode,
      if (lastQuestDate != null) 'lastQuestDate': lastQuestDate,
      'previousStreak': previousStreak,
      if (lastQuestResetDate != null) 'lastQuestResetDate': lastQuestResetDate,
      'yesterdayCompletedCount': yesterdayCompletedCount,
      'yesterdayTotalQuests': yesterdayTotalQuests,
      if (disciplineStartDate != null) 'disciplineStartDate': disciplineStartDate,
      if (lastPunishmentDate != null) 'lastPunishmentDate': lastPunishmentDate,
      'reviewRequested': reviewRequested,
      if (membershipType != null) 'membershipType': membershipType,
      'subscriptionActive': subscriptionActive,
    };
  }

  // ── copyWith ───────────────────────────────────────────────────────────

  HunterData copyWith({
    String? hunterName,
    int? xp,
    int? level,
    int? streak,
    String? profilePicture,
    int? waterIntakeMl,
    String? waterIntakeDate,
    int? selectedCupSize,
    int? waterGoalMl,
    int? stepOffset,
    String? stepOffsetDate,
    String? lastStepRewardDate,
    String? notificationTime,
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
    bool? reviewRequested,
    String? membershipType,
    bool? subscriptionActive,
  }) {
    return HunterData(
      hunterName: hunterName ?? this.hunterName,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      profilePicture: profilePicture ?? this.profilePicture,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      waterIntakeDate: waterIntakeDate ?? this.waterIntakeDate,
      selectedCupSize: selectedCupSize ?? this.selectedCupSize,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      stepOffset: stepOffset ?? this.stepOffset,
      stepOffsetDate: stepOffsetDate ?? this.stepOffsetDate,
      lastStepRewardDate: lastStepRewardDate ?? this.lastStepRewardDate,
      notificationTime: notificationTime ?? this.notificationTime,
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
      reviewRequested: reviewRequested ?? this.reviewRequested,
      membershipType: membershipType ?? this.membershipType,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static String? _timestampToString(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is String) return value;
    return value.toString();
  }
}
