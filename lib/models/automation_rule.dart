import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'automation_rule.g.dart';

@HiveType(typeId: 2)
class RuleCondition {
  @HiveField(0)
  String type; // 'equals', 'contains', 'regex', 'any'

  @HiveField(1)
  String value;

  RuleCondition({
    required this.type,
    this.value = '',
  });

  factory RuleCondition.fromMap(Map<String, dynamic> map) {
    return RuleCondition(
      type: map['type'] as String? ?? 'equals',
      value: map['value'] as String? ?? '',
    );
  }
}

@HiveType(typeId: 3)
class RuleAction {
  @HiveField(0)
  String type; // 'sound', 'webhook', 'intent', 'publish'

  @HiveField(1)
  Map<String, String> params;

  RuleAction({
    required this.type,
    required this.params,
  });

  factory RuleAction.fromMap(Map<String, dynamic> map) {
    return RuleAction(
      type: map['type'] as String? ?? '',
      params: Map<String, String>.from(map['params'] ?? {}),
    );
  }
}

@HiveType(typeId: 4)
class AutomationRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String topic;

  @HiveField(3)
  RuleCondition condition;

  @HiveField(4)
  List<RuleAction> actions;

  @HiveField(5)
  bool enabled;

  AutomationRule({
    String? id,
    required this.name,
    required this.topic,
    required this.condition,
    required this.actions,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'topic': topic,
        'enabled': enabled,
        'condition': {'type': condition.type, 'value': condition.value},
        'actions': actions
            .map((a) => {'type': a.type, 'params': a.params})
            .toList(),
      };

  factory AutomationRule.fromMap(Map<String, dynamic> map) {
    return AutomationRule(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      condition: RuleCondition.fromMap(
          Map<String, dynamic>.from(map['condition'] ?? {})),
      actions: (map['actions'] as List<dynamic>?)
              ?.map((a) => RuleAction.fromMap(Map<String, dynamic>.from(a)))
              .toList() ??
          [],
    );
  }
}
