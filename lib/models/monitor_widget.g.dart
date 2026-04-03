// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_widget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MonitorWidgetAdapter extends TypeAdapter<MonitorWidget> {
  @override
  final int typeId = 7;

  @override
  MonitorWidget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonitorWidget(
      id: fields[0] as String?,
      label: fields[1] as String,
      topic: fields[2] as String,
      type: fields[3] as String,
      unit: fields[4] as String,
      icon: fields[5] as String?,
      minValue: fields[6] as double?,
      maxValue: fields[7] as double?,
      color: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MonitorWidget obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.topic)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.minValue)
      ..writeByte(7)
      ..write(obj.maxValue)
      ..writeByte(8)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonitorWidgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
