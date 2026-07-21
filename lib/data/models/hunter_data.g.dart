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
      targetWeight: (fields[53] as num?)?.toDouble(),
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
      // Leaderboard XP
      weeklyXp: fields[49] as int? ?? 0,
      dailyXp: fields[50] as int? ?? 0,
      weeklyResetEpoch: fields[51] as int? ?? 0,
      dailyResetEpoch: fields[52] as int? ?? 0,
      // Achievement tracking: social
      hasSharedApp: fields[54] as bool? ?? false,
      hasSharedProfile: fields[55] as bool? ?? false,
      hasSharedReport: fields[56] as bool? ?? false,
      hasSharedActivity: fields[57] as bool? ?? false,
      hasComparedHunter: fields[58] as bool? ?? false,
      // Achievement tracking: walking / explorer
      totalStepsAllTime: fields[59] as int? ?? 0,
      totalRunsCompleted: fields[60] as int? ?? 0,
      totalRunDistanceKm: (fields[61] as num?)?.toDouble() ?? 0,
      longestRunKm: (fields[62] as num?)?.toDouble() ?? 0,
      // Achievement tracking: nutrition
      mealsLoggedCount: fields[63] as int? ?? 0,
      proteinGoalHitDays: fields[64] as int? ?? 0,
      balancedMacroDays: fields[65] as int? ?? 0,
      // Achievement tracking: hydration
      waterLogCount: fields[66] as int? ?? 0,
      waterGoalStreak: fields[67] as int? ?? 0,
      lastWaterGoalHitDate: fields[68] as String?,
      // Achievement tracking: hidden/secret time-of-day actions
      hitMidnightAction: fields[69] as bool? ?? false,
      hitEarlyBirdAction: fields[70] as bool? ?? false,
      hitNightOwlAction: fields[71] as bool? ?? false,
      // Achievement tracking: nutrition (date guards)
      lastProteinGoalHitDate: fields[72] as String?,
      lastBalancedMacroDate: fields[73] as String?,
      stepsAccumulatedToday: fields[74] as int? ?? 0,
      // Publicly-equipped badge
      equippedBadgeId: fields[75] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HunterData obj) {
    writer
      ..writeByte(76) // total number of fields
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
      ..writeByte(53)..write(obj.targetWeight)
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
      ..writeByte(47)..write(obj.selfImprovement)
      // Leaderboard XP
      ..writeByte(49)..write(obj.weeklyXp)
      ..writeByte(50)..write(obj.dailyXp)
      ..writeByte(51)..write(obj.weeklyResetEpoch)
      ..writeByte(52)..write(obj.dailyResetEpoch)
      // Achievement tracking: social
      ..writeByte(54)..write(obj.hasSharedApp)
      ..writeByte(55)..write(obj.hasSharedProfile)
      ..writeByte(56)..write(obj.hasSharedReport)
      ..writeByte(57)..write(obj.hasSharedActivity)
      ..writeByte(58)..write(obj.hasComparedHunter)
      // Achievement tracking: walking / explorer
      ..writeByte(59)..write(obj.totalStepsAllTime)
      ..writeByte(60)..write(obj.totalRunsCompleted)
      ..writeByte(61)..write(obj.totalRunDistanceKm)
      ..writeByte(62)..write(obj.longestRunKm)
      // Achievement tracking: nutrition
      ..writeByte(63)..write(obj.mealsLoggedCount)
      ..writeByte(64)..write(obj.proteinGoalHitDays)
      ..writeByte(65)..write(obj.balancedMacroDays)
      // Achievement tracking: hydration
      ..writeByte(66)..write(obj.waterLogCount)
      ..writeByte(67)..write(obj.waterGoalStreak)
      ..writeByte(68)..write(obj.lastWaterGoalHitDate)
      // Achievement tracking: hidden/secret time-of-day actions
      ..writeByte(69)..write(obj.hitMidnightAction)
      ..writeByte(70)..write(obj.hitEarlyBirdAction)
      ..writeByte(71)..write(obj.hitNightOwlAction)
      // Achievement tracking: nutrition (date guards)
      ..writeByte(72)..write(obj.lastProteinGoalHitDate)
      ..writeByte(73)..write(obj.lastBalancedMacroDate)
      ..writeByte(74)..write(obj.stepsAccumulatedToday)
      // Publicly-equipped badge
      ..writeByte(75)..write(obj.equippedBadgeId);
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
