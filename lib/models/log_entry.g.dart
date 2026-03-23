// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LogEntryAdapter extends TypeAdapter<LogEntry> {
  @override
  final int typeId = 5;

  @override
  LogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LogEntry(
      timestamp: fields[0] as int?,
      type: fields[1] as String,
      message: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LogEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.message);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
