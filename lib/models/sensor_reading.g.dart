// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sensor_reading.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SensorReadingAdapter extends TypeAdapter<SensorReading> {
  @override
  final int typeId = 8;

  @override
  SensorReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SensorReading(
      topic: fields[0] as String,
      value: fields[1] as String,
      timestamp: fields[2] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SensorReading obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.topic)
      ..writeByte(1)
      ..write(obj.value)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
