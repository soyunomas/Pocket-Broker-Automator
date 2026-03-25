import 'package:hive/hive.dart';

part 'broker_config.g.dart';

@HiveType(typeId: 6)
class BrokerConfig extends HiveObject {
  @HiveField(0)
  bool enabled;

  @HiveField(1)
  int port;

  @HiveField(2)
  bool authEnabled;

  @HiveField(3)
  String username;

  @HiveField(4)
  String password;

  @HiveField(5)
  bool wsEnabled;

  @HiveField(6)
  int wsPort;

  BrokerConfig({
    this.enabled = false,
    this.port = 1883,
    this.authEnabled = false,
    this.username = '',
    this.password = '',
    this.wsEnabled = false,
    this.wsPort = 8083,
  });
}
