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
      hunterName: fields[0] as String? ?? 'Hunter',
      xp: fields[1] as int? ?? 0,
      level: fields[2] as int? ?? 1,
      streak: fields[3] as int? ?? 0,
      profilePicture: fields[4] as String?,
      waterIntakeMl: fields[5] as int? ?? 0,
      waterIntakeDate: fields[6] as String? ?? '',
      selectedCupSize: fields[7] as int? ?? 250,
      waterGoalMl: fields[8] as int? ?? 2000,
      stepOffset: fields[9] as int? ?? 0,
      stepOffsetDate: fields[10] as String? ?? '',
      lastStepRewardDate: fields[11] as String?,
      notificationTime: fields[12] as String?,
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
      reviewRequested: fields[23] as bool? ?? false,
      membershipType: fields[24] as String?,
      subscriptionActive: fields[25] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, HunterData obj) {
    writer
      ..writeByte(26) // number of fields
      ..writeByte(0)..write(obj.hunterName)
      ..writeByte(1)..write(obj.xp)
      ..writeByte(2)..write(obj.level)
      ..writeByte(3)..write(obj.streak)
      ..writeByte(4)..write(obj.profilePicture)
      ..writeByte(5)..write(obj.waterIntakeMl)
      ..writeByte(6)..write(obj.waterIntakeDate)
      ..writeByte(7)..write(obj.selectedCupSize)
      ..writeByte(8)..write(obj.waterGoalMl)
      ..writeByte(9)..write(obj.stepOffset)
      ..writeByte(10)..write(obj.stepOffsetDate)
      ..writeByte(11)..write(obj.lastStepRewardDate)
      ..writeByte(12)..write(obj.notificationTime)
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
      ..writeByte(23)..write(obj.reviewRequested)
      ..writeByte(24)..write(obj.membershipType)
      ..writeByte(25)..write(obj.subscriptionActive);
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
