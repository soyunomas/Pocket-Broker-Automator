# Changelog — PocketBroker Automator

## [0.5.0] - 2026-03-25 — Broker MQTT Local Embebido

### ✅ Implementado

#### Broker MQTT Local (Moquette vía MethodChannel)
- Integración de **Moquette 0.17** (broker MQTT en Java) como dependencia nativa Android
- `MqttBrokerPlugin.kt` expone el broker vía `MethodChannel` (`com.pocketbroker/mqtt_broker`)
- Métodos: `startBroker`, `stopBroker`, `isBrokerRunning`
- Store de Moquette en directorio privado de la app (`filesDir/moquette/`) para evitar errores de permisos
- Al iniciar, devuelve las IPs IPv4 del dispositivo para que los clientes sepan dónde conectarse

#### Start/Stop dinámico del broker
- Arranque y parada desde la UI sin reiniciar la app
- Estado persistido en Hive (`BrokerConfig`)
- Feedback visual con indicador de carga durante start/stop

#### Puerto configurable
- Campo editable en la pantalla de configuración (1–65535)
- Deshabilitado mientras el broker está en ejecución
- Valor por defecto: 1883

#### Autenticación básica en broker
- Switch para activar/desactivar autenticación
- Campos de usuario y contraseña (con toggle de visibilidad)
- `SimpleAuthenticator` valida credenciales contra los valores configurados
- Deshabilitado mientras el broker está en ejecución

#### UI de control en `BrokerScreen`
- **Card de estado** — Icono, texto de estado (Activo/Detenido), puerto, IPs del dispositivo en verde monospace
- **Card de configuración** — Puerto, switch de autenticación, campos de credenciales
- **Card informativa** — Descripción del broker local

#### Nuevos archivos
- `android/.../MqttBrokerPlugin.kt` — Plugin nativo con Moquette
- `lib/services/broker_service.dart` — Wrapper del MethodChannel
- `lib/providers/broker_provider.dart` — State management del broker

#### APK descargable
- El APK release compilado está disponible en la carpeta [`app/`](app/) del repositorio

---

## [0.4.0] - 2026-03-22 — Fix: Estabilidad de conexión y URLs

### 🐛 Corregido

#### Conexión/desconexión en bucle ("metralleta")
- **Causa:** Múltiples fuentes competían por reconectar: el callback `_onDisconnected`, el backoff de `_scheduleReconnect()`, el timer keep-alive de 30s en el background service, y el callback `_onConnected` que duplicaba el cambio de estado
- **Fix:**
  - Añadido flag `_isConnecting` para prevenir intentos concurrentes de conexión
  - Eliminado callback `_onConnected` (duplicaba el set de estado `connected` con `_attemptConnect`)
  - `_onDisconnected` ahora ignora desconexiones durante un intento activo
  - Timer keep-alive ya NO llama a `mqtt.connect()` (eso reseteaba `_reconnectAttempt = 0` y reiniciaba el bucle). Solo loguea estado; la reconexión la maneja `MqttClientService` con backoff exponencial

#### Conexión persiste tras borrar perfil
- **Causa:** `deleteProfile()` no desconectaba el servicio background. `MqttClientService` seguía con `_activeProfile` seteado y el keep-alive seguía intentando reconectar
- **Fix:** `deleteProfile()` ahora llama a `disconnect()` si el perfil borrado es la conexión activa, lo que para el servicio y limpia `_activeProfile`

#### URLs/Intents no se abren (background isolate)
- **Causa:** `launchUrl()` se ejecutaba en el isolate de background, que no tiene acceso a la Activity/UI de Android. `url_launcher` necesita el contexto de una Activity para abrir URLs
- **Fix:**
  - `AutomationEngine` ahora tiene un callback `onIntentAction` para delegar la apertura de URLs
  - En background service, el callback envía un evento IPC `launchUrl` al isolate principal
  - `ConnectionProvider` (UI) escucha ese evento y ejecuta `launchUrl()` con acceso a la Activity

---

## [0.3.1] - 2026-03-21 — Fix: Sonido y Webhooks/URLs

### 🐛 Corregido

#### Sonido deja de funcionar después de la primera regla
- **Causa:** Se reutilizaba una única instancia de `AudioPlayer` que quedaba en estado "completado" tras la primera reproducción
- **Fix:** Ahora se crea un `AudioPlayer` nuevo por cada reproducción y se libera automáticamente al terminar (`onPlayerComplete → dispose`)

#### Webhooks no ejecutaban las peticiones HTTP
- **Causa:** Faltaba manejo de errores específico y timeout; las excepciones se perdían silenciosamente
- **Fix:** Agregado `timeout(15s)`, try/catch interno con logging del statusCode o error, y validación de body vacío

#### URLs/Intents no se abrían
- **Causa:** En Android 11+ faltaban las `<queries>` de `VIEW` intent en el AndroidManifest, lo que hacía que `canLaunchUrl` siempre devolviera `false`
- **Fix:** Agregadas queries para `https` y `http` schemes. Eliminada la comprobación `canLaunchUrl` (no es necesaria con las queries declaradas) y se usa `launchUrl` directamente con try/catch

---

## [0.3.0] - 2026-03-21 — Reconexión Robusta

### ✅ Implementado

#### Retry con backoff exponencial (`mqtt_client_service.dart`)
- Reconexión automática con delay exponencial: 2s → 4s → 8s → 16s → … → 60s máximo
- Reset del contador al reconectar exitosamente
- Distinción entre desconexión intencional (usuario) y pérdida de conexión (red/broker)
- `connectTimeoutPeriod` de 10s para no bloquear en conexiones lentas
- Método `_scheduleReconnect()` con opción `immediate` para reconexión instantánea tras recuperar red

#### Network listener (`connectivity_plus`)
- Monitoreo de conectividad en tiempo real vía `Connectivity.onConnectivityChanged`
- Reconexión inmediata al detectar que la red vuelve (WiFi/Mobile) si había un perfil activo
- Solo reconecta si la desconexión no fue intencional

#### Manejo de Doze Mode (`battery_optimizer.dart`)
- Utilidad `BatteryOptimizer` con `permission_handler` para consultar y solicitar exclusión de battery optimization
- Diálogo UX al activar el background service: pregunta al usuario si desea desactivar la optimización
- Permiso `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` ya presente en AndroidManifest

#### Notificación en tiempo real
- `ConnectionProvider` actualiza la notificación del foreground service en cada cambio de estado:
  - `Conectado a [alias]`
  - `Reconectando a [alias]…`
  - `Desconectado de [alias]`
- Feedback instantáneo en el área de notificaciones de Android

---

## [0.2.0] - 2026-03-20 — Background Service + Fixes UI

### ✅ Implementado

#### Background Service (`background_service.dart`)
- Foreground service Android con `flutter_background_service`
- Notificación persistente configurable
- Start/Stop desde el AppBar (icono de sincronización)
- Canal de notificación dedicado (`pocket_broker_foreground`)
- Permiso `FOREGROUND_SERVICE_DATA_SYNC` añadido al manifest

#### Fixes UI
- **Logs:** Corregido overflow de 33px en vertical — filter chips ahora en `SingleChildScrollView` horizontal
- **Panel (ex-Dashboard):** Renombrado "Dashboard" → "Panel" en navegación y títulos
- **Panel:** Contenido de botones ajustado — fuentes reducidas, padding interno, `Flexible` + `maxLines` para evitar desbordamiento
- **Panel:** Iconos más compactos (24px), espaciado optimizado

#### Sonido con file picker
- Agregada dependencia `file_picker` para selección de archivos de audio
- Diálogo de acción "Sonido" ahora muestra botón "Elegir" con `FilePicker.platform.pickFiles(type: FileType.audio)`
- `AutomationEngine` reproduce desde ruta absoluta del dispositivo (`DeviceFileSource`) en vez de assets

#### Logs automáticos
- `ConnectionProvider` ahora escucha `messageStream` y registra automáticamente cada mensaje MQTT recibido en logs

#### Barrel exports
- Creado `services/services.dart` con exports de todos los servicios

---

## [0.1.0] - 2026-03-20 — MVP Inicial

### ✅ Implementado

#### Estructura del proyecto
- Proyecto Flutter creado con `com.pocketbroker` como org
- Arquitectura por capas: `models/`, `services/`, `providers/`, `screens/`
- Dependencias configuradas: `mqtt_client`, `hive`, `provider`, `audioplayers`, `http`, `url_launcher`, `flutter_secure_storage`, `permission_handler`
- Android: permisos de red, foreground service, wake lock, battery optimization
- `minSdk` fijado en 21

#### Modelos de datos (Hive + TypeAdapters generados)
- `ConnectionProfile` — perfil de conexión MQTT (host, port, SSL, auth, clientId)
- `DashboardButton` — botón del dashboard (label, color, topic, payload, QoS, retain)
- `AutomationRule` — regla de automatización con `RuleCondition` y `RuleAction`
- `LogEntry` — entrada de log (timestamp, tipo, mensaje)
- `BrokerConfig` — configuración del broker local (puerto, auth)

#### MQTT Client Service (`mqtt_client_service.dart`)
- Conexión/desconexión a brokers MQTT
- Múltiples perfiles de conexión guardados
- Reconexión automática (autoReconnect del cliente)
- Soporte TCP y SSL/TLS
- Publicación con QoS configurable y retain
- Suscripciones múltiples con re-suscripción tras reconexión
- Stream de estado de conexión (`connected`, `connecting`, `disconnected`)
- Stream de mensajes recibidos

#### Motor de Automatización (`automation_engine.dart`)
- Evaluación en tiempo real de reglas contra mensajes MQTT
- Soporte de wildcards MQTT (`+` y `#`)
- Condiciones: `equals`, `contains`, `regex`, `any`
- Acciones implementadas:
  - `sound` — reproducir audio desde archivo del dispositivo
  - `webhook` — GET/POST con body JSON
  - `intent` — abrir URL/app externa
  - `publish` — publicar mensaje MQTT como reacción

#### Sistema de Logs (`log_service.dart`)
- Persistencia en Hive
- Tipos: `sent`, `received`, `error`, `action`, `system`
- Rotación automática (máx. 1000 entradas)
- Stream broadcast para actualizaciones en tiempo real
- Registro automático de mensajes MQTT recibidos

#### State Management (Provider + ChangeNotifier)
- `ConnectionProvider` — CRUD de perfiles, connect/disconnect, log automático de mensajes
- `DashboardProvider` — CRUD de botones, acción de publish
- `AutomationProvider` — CRUD de reglas, toggle enable/disable
- `LogProvider` — lectura con filtro por tipo, limpieza

#### UI (Material 3 — Dark Theme obligatorio)
- `HomeScreen` — NavigationBar con 5 tabs + indicador estado + toggle background service
- `ConnectionsScreen` — lista de perfiles, crear/editar/eliminar, botón conectar/desconectar
- `DashboardScreen` (Panel) — grid 2 columnas de botones configurables, long press para editar
- `AutomationsScreen` — lista de reglas, crear/editar/eliminar, switch enable/disable, file picker para sonidos
- `LogsScreen` — lista con filtro por chips (scroll horizontal), timestamp, iconos por tipo, botón limpiar
- `BrokerScreen` — placeholder informativo

---

## Pendiente

### ✅ Completado (Prioridad Alta)

#### Reconexión robusta
- [x] Retry con backoff exponencial ante fallos de conexión
- [x] Reconexión automática al recuperar red (connectivity_plus listener)
- [x] Manejo de Doze Mode (solicitud exclusión battery optimization)
- [x] Actualizar notificación del foreground service con estado de conexión en tiempo real

### 🟡 Prioridad Media

#### ✅ Broker MQTT Local (Completado en 0.5.0)
- [x] Integrar Moquette (Java) vía MethodChannel
- [x] Start/Stop dinámico del broker
- [x] Puerto configurable
- [x] Autenticación básica en broker
- [x] UI de control en `BrokerScreen`

#### Dashboard mejoras
- [ ] Iconos seleccionables visualmente (icon picker)
- [ ] Grid con número de columnas configurable
- [ ] Reordenar botones (drag & drop)
- [ ] Feedback visual al presionar (animación/vibración)

#### Logs mejoras
- [ ] Exportar logs a archivo
- [ ] Búsqueda por texto en logs

#### Seguridad
- [ ] Cifrar credenciales con `flutter_secure_storage` (actualmente en Hive plano)
- [ ] Validación de inputs en formularios

### 🟢 Prioridad Baja (Roadmap futuro)

- [ ] Scripting (JS/Lua) para acciones avanzadas
- [ ] Import/export de configuración completa (JSON)
- [ ] Sincronización entre dispositivos
- [ ] UI tipo Node-RED para reglas visuales
- [ ] Widgets Android (home screen)
- [ ] Integración con Home Assistant
- [ ] Isolates para procesamiento MQTT pesado
- [ ] Monitor de topics en tiempo real (vista de sniffer)
- [ ] Soporte MQTT 5.0
- [ ] Tests unitarios y de integración
