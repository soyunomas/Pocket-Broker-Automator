// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'automation_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RuleConditionAdapter extends TypeAdapter<RuleCondition> {
  @override
  final int typeId = 2;

  @override
  RuleCondition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RuleCondition(
      type: fields[0] as String,
      value: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RuleCondition obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleConditionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RuleActionAdapter extends TypeAdapter<RuleAction> {
  @override
  final int typeId = 3;

  @override
  RuleAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RuleAction(
      type: fields[0] as String,
      params: (fields[1] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, RuleAction obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.params);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AutomationRuleAdapter extends TypeAdapter<AutomationRule> {
  @override
  final int typeId = 4;

  @override
  AutomationRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AutomationRule(
      id: fields[0] as String?,
      name: fields[1] as String,
      topic: fields[2] as String,
      condition: fields[3] as RuleCondition,
      actions: (fields[4] as List).cast<RuleAction>(),
      enabled: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AutomationRule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.topic)
      ..writeByte(3)
      ..write(obj.condition)
      ..writeByte(4)
      ..write(obj.actions)
      ..writeByte(5)
      ..write(obj.enabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutomationRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
