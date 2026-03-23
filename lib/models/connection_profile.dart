import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'connection_profile.g.dart';

@HiveType(typeId: 0)
class ConnectionProfile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String alias;

  @HiveField(2)
  String host;

  @HiveField(3)
  int port;

  @HiveField(4)
  String username;

  @HiveField(5)
  String password;

  @HiveField(6)
  String clientId;

  @HiveField(7)
  bool ssl;

  ConnectionProfile({
    String? id,
    required this.alias,
    required this.host,
    this.port = 1883,
    this.username = '',
    this.password = '',
    String? clientId,
    this.ssl = false,
  })  : id = id ?? const Uuid().v4(),
        clientId = clientId ?? 'pb_${const Uuid().v4().substring(0, 8)}';
}
