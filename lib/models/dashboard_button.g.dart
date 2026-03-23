// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_button.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DashboardButtonAdapter extends TypeAdapter<DashboardButton> {
  @override
  final int typeId = 1;

  @override
  DashboardButton read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DashboardButton(
      id: fields[0] as String?,
      label: fields[1] as String,
      color: fields[2] as String,
      topic: fields[3] as String,
      payload: fields[4] as String,
      qos: fields[5] as int,
      retain: fields[6] as bool,
      icon: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DashboardButton obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.color)
      ..writeByte(3)
      ..write(obj.topic)
      ..writeByte(4)
      ..write(obj.payload)
      ..writeByte(5)
      ..write(obj.qos)
      ..writeByte(6)
      ..write(obj.retain)
      ..writeByte(7)
      ..write(obj.icon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardButtonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
