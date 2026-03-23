// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broker_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrokerConfigAdapter extends TypeAdapter<BrokerConfig> {
  @override
  final int typeId = 6;

  @override
  BrokerConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrokerConfig(
      enabled: fields[0] as bool,
      port: fields[1] as int,
      authEnabled: fields[2] as bool,
      username: fields[3] as String,
      password: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BrokerConfig obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.enabled)
      ..writeByte(1)
      ..write(obj.port)
      ..writeByte(2)
      ..write(obj.authEnabled)
      ..writeByte(3)
      ..write(obj.username)
      ..writeByte(4)
      ..write(obj.password);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
