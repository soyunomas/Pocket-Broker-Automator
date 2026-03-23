// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConnectionProfileAdapter extends TypeAdapter<ConnectionProfile> {
  @override
  final int typeId = 0;

  @override
  ConnectionProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConnectionProfile(
      id: fields[0] as String?,
      alias: fields[1] as String,
      host: fields[2] as String,
      port: fields[3] as int,
      username: fields[4] as String,
      password: fields[5] as String,
      clientId: fields[6] as String?,
      ssl: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ConnectionProfile obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.alias)
      ..writeByte(2)
      ..write(obj.host)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.clientId)
      ..writeByte(7)
      ..write(obj.ssl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
