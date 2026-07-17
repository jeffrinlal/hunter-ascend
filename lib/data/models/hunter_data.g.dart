// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hunter_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HunterDataAdapter extends TypeAdapter<HunterData> {
  @override
  final int typeId = 0;

  @override
  HunterData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HunterData(
      // Core identity
      hunterName: fields[0] as String? ?? 'Hunter',
      xp: fields[1] as int? ?? 0,
      level: fields[2] as int? ?? 1,
      streak: fields[3] as int? ?? 0,
      profilePicture: fields[4] as String?,
      // Physical stats
      height: (fields[26] as num?)?.toDouble() ?? 0,
      weight: (fields[27] as num?)?.toDouble() ?? 0,
      startingWeight: (fields[28] as num?)?.toDouble() ?? 0,
      // Water tracking
      waterIntakeMl: fields[5] as int? ?? 0,
      waterIntakeDate: fields[6] as String? ?? '',
      selectedCupSize: fields[7] as int? ?? 250,
      waterGoalMl: fields[8] as int? ?? 2000,
      // Step tracking
      stepOffset: fields[9] as int? ?? 0,
      stepOffsetDate: fields[10] as String? ?? '',
      lastStepRewardDate: fields[11] as String?,
      // Discipline & streak
      disciplineMode: fields[13] as String?,
      disciplineModeChangedAt: fields[14] as String?,
      lastQuestDate: fields[15] as String?,
      previousStreak: fields[16] as int? ?? 0,
      lastQuestResetDate: fields[17] as String?,
      yesterdayCompletedCount: fields[18] as int? ?? 0,
      yesterdayTotalQuests: fields[19] as int? ?? 0,
      disciplineStartDate: fields[20] as String?,
      lastPunishmentDate: fields[21] as String?,
      lastRecoveryDate: fields[22] as String?,
      // Notifications
      notificationTime: fields[12] as String?,
      // Membership
      membershipType: fields[24] as String?,
      subscriptionActive: fields[25] as bool? ?? false,
      reviewRequested: fields[23] as bool? ?? false,
      membershipExpiry: fields[48] as String?,
      // Duel & quest statistics
      duelWins: fields[29] as int? ?? 0,
      duelLosses: fields[30] as int? ?? 0,
      questsDone: fields[31] as int? ?? 0,
      // Quest state
      completedQuests: (fields[32] as List?)?.cast<String>() ?? const [],
      aiQuests: (fields[33] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      aiQuestDate: fields[34] as String?,
      weeklyMissions: (fields[35] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      weeklyMissionsDate: fields[36] as String?,
      weeklyMissionsGenerated: fields[37] as bool? ?? false,
      activeDashboardQuestName: fields[38] as String?,
      activeDashboardQuestXp: fields[39] as int?,
      activeDashboardQuestEndTime: fields[40] as String?,
      activeWeeklyMissionTitle: fields[41] as String?,
      activeWeeklyMissionXp: fields[42] as int?,
      activeWeeklyMissionEndTime: fields[43] as String?,
      // Quest path preferences
      fatLoss: fields[44] as bool? ?? false,
      discipline: fields[45] as bool? ?? false,
      muscleGain: fields[46] as bool? ?? false,
      selfImprovement: fields[47] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, HunterData obj) {
    writer
      ..writeByte(49) // total number of fields
      // Core identity
      ..writeByte(0)..write(obj.hunterName)
      ..writeByte(1)..write(obj.xp)
      ..writeByte(2)..write(obj.level)
      ..writeByte(3)..write(obj.streak)
      ..writeByte(4)..write(obj.profilePicture)
      // Physical stats
      ..writeByte(26)..write(obj.height)
      ..writeByte(27)..write(obj.weight)
      ..writeByte(28)..write(obj.startingWeight)
      // Water tracking
      ..writeByte(5)..write(obj.waterIntakeMl)
      ..writeByte(6)..write(obj.waterIntakeDate)
      ..writeByte(7)..write(obj.selectedCupSize)
      ..writeByte(8)..write(obj.waterGoalMl)
      // Step tracking
      ..writeByte(9)..write(obj.stepOffset)
      ..writeByte(10)..write(obj.stepOffsetDate)
      ..writeByte(11)..write(obj.lastStepRewardDate)
      // Discipline & streak
      ..writeByte(13)..write(obj.disciplineMode)
      ..writeByte(14)..write(obj.disciplineModeChangedAt)
      ..writeByte(15)..write(obj.lastQuestDate)
      ..writeByte(16)..write(obj.previousStreak)
      ..writeByte(17)..write(obj.lastQuestResetDate)
      ..writeByte(18)..write(obj.yesterdayCompletedCount)
      ..writeByte(19)..write(obj.yesterdayTotalQuests)
      ..writeByte(20)..write(obj.disciplineStartDate)
      ..writeByte(21)..write(obj.lastPunishmentDate)
      ..writeByte(22)..write(obj.lastRecoveryDate)
      // Notifications
      ..writeByte(12)..write(obj.notificationTime)
      // Membership
      ..writeByte(24)..write(obj.membershipType)
      ..writeByte(25)..write(obj.subscriptionActive)
      ..writeByte(23)..write(obj.reviewRequested)
      ..writeByte(48)..write(obj.membershipExpiry)
      // Duel & quest statistics
      ..writeByte(29)..write(obj.duelWins)
      ..writeByte(30)..write(obj.duelLosses)
      ..writeByte(31)..write(obj.questsDone)
      // Quest state
      ..writeByte(32)..write(obj.completedQuests)
      ..writeByte(33)..write(obj.aiQuests)
      ..writeByte(34)..write(obj.aiQuestDate)
      ..writeByte(35)..write(obj.weeklyMissions)
      ..writeByte(36)..write(obj.weeklyMissionsDate)
      ..writeByte(37)..write(obj.weeklyMissionsGenerated)
      ..writeByte(38)..write(obj.activeDashboardQuestName)
      ..writeByte(39)..write(obj.activeDashboardQuestXp)
      ..writeByte(40)..write(obj.activeDashboardQuestEndTime)
      ..writeByte(41)..write(obj.activeWeeklyMissionTitle)
      ..writeByte(42)..write(obj.activeWeeklyMissionXp)
      ..writeByte(43)..write(obj.activeWeeklyMissionEndTime)
      // Quest path preferences
      ..writeByte(44)..write(obj.fatLoss)
      ..writeByte(45)..write(obj.discipline)
      ..writeByte(46)..write(obj.muscleGain)
      ..writeByte(47)..write(obj.selfImprovement);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HunterDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
