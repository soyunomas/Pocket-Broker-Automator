# PocketBroker Automator

<p align="center">
  <img src="github/screenshots/icon_placeholder.png" alt="PocketBroker Automator" width="120" />
</p>

**Aplicación Android para control y automatización IoT vía MQTT.**

PocketBroker Automator actúa como cliente MQTT avanzado, motor de automatización basado en eventos y panel de control interactivo — todo en un solo dispositivo, sin necesidad de cloud.

---

## ✨ Características

- 🔌 **Cliente MQTT** — Conexión a múltiples brokers con perfiles guardados (TCP/SSL)
- 🔄 **Reconexión robusta** — Backoff exponencial + detección de red + manejo de Doze Mode
- 🤖 **Motor de automatización** — Reglas trigger/acción sobre mensajes MQTT en tiempo real
- 🎛️ **Panel de control** — Botones configurables para publicar en topics MQTT
- 📋 **Logs** — Registro persistente de mensajes, acciones y errores con filtros
- 🔔 **Background Service** — Foreground service Android para operación 24/7
- 🌙 **Modo oscuro** — Material 3 dark theme

### Acciones de automatización

| Tipo | Descripción |
|------|-------------|
| 🔊 Sonido | Reproducir archivo de audio del dispositivo |
| 🌐 Webhook | Petición HTTP GET/POST con body JSON |
| 🔗 Intent/URL | Abrir URL o app externa |
| 📤 Publish | Publicar mensaje MQTT como reacción |

### Condiciones de trigger

- `equals` — payload exacto
- `contains` — contiene texto
- `regex` — expresión regular
- `any` — cualquier mensaje en el topic

---

## 📱 Requisitos

- Android 5.0+ (API 21)
- Flutter SDK 3.4.3+
- Dart SDK 3.4.3+

---

## 🛠️ Compilación

### Prerrequisitos

1. **Flutter SDK** instalado y en el PATH ([instrucciones](https://docs.flutter.dev/get-started/install))
2. **Android SDK** con API level 35+ (se instala con Android Studio o `sdkmanager`)
3. **Java JDK 17** (requerido por Gradle)

Verifica tu entorno:

```bash
flutter doctor
```

### Clonar y compilar

```bash
# Clonar el repositorio
git clone https://github.com/soyunomas/pocket-broker-automator.git
cd pocket-broker-automator

# Instalar dependencias
flutter pub get

# Compilar APK debug
flutter build apk --debug

# El APK se genera en:
# build/app/outputs/flutter-apk/app-debug.apk
```

### Compilar APK release

```bash
# APK release (sin firmar)
flutter build apk --release

# APK release por arquitectura (más ligero)
flutter build apk --split-per-abi --release
```

### Instalar directamente en dispositivo

```bash
# Con dispositivo conectado por USB (debug mode activado)
flutter run

# O instalar el APK directamente
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## 📁 Estructura del proyecto

```
lib/
├── main.dart                 # Entry point + providers setup
├── models/                   # Modelos Hive (con TypeAdapters)
│   ├── connection_profile.dart
│   ├── dashboard_button.dart
│   ├── automation_rule.dart
│   ├── log_entry.dart
│   └── broker_config.dart
├── services/                 # Lógica de negocio
│   ├── mqtt_client_service.dart    # Cliente MQTT + reconexión
│   ├── background_service.dart     # Foreground service Android
│   ├── automation_engine.dart      # Motor de reglas
│   └── log_service.dart            # Persistencia de logs
├── providers/                # State management (ChangeNotifier)
│   ├── connection_provider.dart
│   ├── dashboard_provider.dart
│   ├── automation_provider.dart
│   └── log_provider.dart
├── screens/                  # Pantallas UI
│   ├── home_screen.dart
│   ├── connections_screen.dart
│   ├── dashboard_screen.dart
│   ├── automations_screen.dart
│   ├── logs_screen.dart
│   └── broker_screen.dart
└── utils/                    # Utilidades
```

---

## ⚙️ Arquitectura

```
[ UI Layer (Flutter / Material 3) ]
        ↓
[ Providers (ChangeNotifier + Provider) ]
        ↓
[ Services Layer ]
    ├── MqttClientService (conexión, pub/sub, reconexión)
    ├── AutomationEngine (evaluación de reglas)
    ├── BackgroundService (foreground service Android)
    └── LogService (persistencia Hive)
        ↓
[ Storage (Hive) ]
```

La comunicación entre el **foreground service** (isolate background) y la **UI** se realiza mediante IPC bidireccional de `flutter_background_service`:
- UI → Service: `connect`, `disconnect`, `publish`, `subscribe`, `updateRules`
- Service → UI: `connectionState`, `message`, `launchUrl`

---

## 📦 Dependencias principales

| Paquete | Uso |
|---------|-----|
| `mqtt_client` | Cliente MQTT (TCP/SSL) |
| `hive` / `hive_flutter` | Base de datos local NoSQL |
| `provider` | State management |
| `flutter_background_service` | Foreground service Android |
| `flutter_local_notifications` | Notificaciones persistentes |
| `connectivity_plus` | Detección de cambios de red |
| `audioplayers` | Reproducción de audio |
| `http` | Peticiones HTTP (webhooks) |
| `url_launcher` | Abrir URLs/apps externas |
| `permission_handler` | Gestión de permisos Android |
| `flutter_secure_storage` | Almacenamiento seguro (futuro) |

---

## 🔐 Permisos Android

| Permiso | Motivo |
|---------|--------|
| `INTERNET` | Conexión MQTT y webhooks |
| `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE` | Detección de red |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` | Servicio en background |
| `WAKE_LOCK` | Mantener conexión activa |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Evitar Doze Mode |
| `POST_NOTIFICATIONS` | Notificación del servicio (Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Reinicio automático (futuro) |

---

## 🗺️ Roadmap

- [ ] Broker MQTT local embebido (Moquette vía MethodChannel)
- [ ] Cifrado de credenciales con `flutter_secure_storage`
- [ ] Icon picker para botones del dashboard
- [ ] Export/Import de configuración (JSON)
- [ ] Monitor de topics en tiempo real (sniffer)
- [ ] Scripting (JS/Lua) para acciones avanzadas
- [ ] Widgets Android (home screen)
- [ ] Integración con Home Assistant
- [ ] Soporte MQTT 5.0

---

## 📄 Licencia

MIT License — ver [LICENSE](LICENSE)
