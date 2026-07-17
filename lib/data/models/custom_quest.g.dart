// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_quest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomQuestAdapter extends TypeAdapter<CustomQuest> {
  @override
  final int typeId = 2;

  @override
  CustomQuest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomQuest(
      id: fields[0] as String? ?? '',
      uid: fields[1] as String? ?? '',
      name: fields[2] as String? ?? '',
      xp: fields[3] as int? ?? 0,
      createdAt: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomQuest obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.uid)
      ..writeByte(2)..write(obj.name)
      ..writeByte(3)..write(obj.xp)
      ..writeByte(4)..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomQuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
