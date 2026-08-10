// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_entry.dart';

class LeaderboardEntryAdapter extends TypeAdapter<LeaderboardEntry> {
  @override
  final int typeId = 3;

  @override
  LeaderboardEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeaderboardEntry(
      uid: fields[0] as String? ?? '',
      hunterName: fields[1] as String? ?? 'Hunter',
      level: fields[2] as int? ?? 1,
      xp: fields[3] as int? ?? 0,
      weeklyXp: fields[4] as int? ?? 0,
      dailyXp: fields[5] as int? ?? 0,
      profilePicture: fields[6] as String?,
      membership: fields[7] as String?,
      membershipExpiry: fields[8] as String?,
      equippedBadgeId: fields[9] as String?,
      dungeonScore: fields[10] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, LeaderboardEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.hunterName)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.xp)
      ..writeByte(4)
      ..write(obj.weeklyXp)
      ..writeByte(5)
      ..write(obj.dailyXp)
      ..writeByte(6)
      ..write(obj.profilePicture)
      ..writeByte(7)
      ..write(obj.membership)
      ..writeByte(8)
      ..write(obj.membershipExpiry)
      ..writeByte(9)
      ..write(obj.equippedBadgeId)
      ..writeByte(10)
      ..write(obj.dungeonScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
