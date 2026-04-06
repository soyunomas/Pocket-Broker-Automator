# Changelog — PocketBroker Automator

## [1.2.0] - 2026-04-06 — Motor v2, Export/Import, Interpolación y Estabilidad

Esta versión unifica una gran reescritura del motor de automatización (v2) junto con herramientas cruciales de respaldo y mejoras profundas en la estabilidad del servicio en segundo plano.

### 🚀 Novedades Principales

#### Motor de Automatización v2: Interpolación de Variables (Templates `{{clave}}`)
- Nuevo método `_interpolate(template, rawPayload)` que reemplaza variables dinámicas en los parámetros de las acciones sin necesidad de programar.
- `{{payload}}` se sustituye por el payload MQTT completo (texto).
- Si el payload es JSON válido, cada `{{clave}}` se sustituye por el valor correspondiente (ej. `{{temperatura}}` → `24.5`).
- **Soportado en:** URL de webhooks, body HTTP, URL de intents, topic de publish, payload de publish y ruta de sonidos.
- Log automático cuando se detecta interpolación y *Warning* en logs si el payload no es JSON válido pero la plantilla usa `{{clave}}`.

#### Export/Import de configuración (JSON)
- Nuevo menú ⋮ en el AppBar con opciones de **Exportar** e **Importar** configuración.
- Diálogo de selección con checkboxes para elegir qué secciones exportar: Conexiones, Reglas, Controles y Monitores.
- El archivo JSON incluye todos los datos serializados de cada sección seleccionada.
- Al importar, el sistema detecta automáticamente qué contiene el archivo y muestra un resumen antes de confirmar.

#### Ejecución concurrente y aislada (Fire-and-forget)
- Las acciones de cada regla se ejecutan en secuencia dentro de la misma regla (evitando conflictos como dos sonidos pisándose), pero **sin bloquear** la evaluación de nuevos mensajes MQTT entrantes.
- Nuevo método `_executeActionsSequentially` con aislamiento de errores: el fallo de una acción (ej. timeout de webhook) ya no detiene las demás acciones de la regla.
- Cada acción genera logs detallados del proceso: inicio (`↳ Ejecutando...`), resultado (`✓ completada` / `✗ falló`), y resumen final.

#### Mecanismo de Cooldown (Anti-spam)
- Protección contra ráfagas de mensajes MQTT repetidos que colapsaban el motor.
- Mapa `_lastTriggered` controla la última ejecución de cada regla.
- **Cooldown de 1 segundo:** si una misma regla se dispara en menos de 1s, se ignora la ejecución y se deja constancia visual en los logs (`Regla "X" bloqueada por cooldown`).

#### Logs del motor sincronizados en la UI
- **Rediseño arquitectónico:** El `AutomationEngine` (isolate de fondo) ahora se comunica con la UI en tiempo real.
- Creado un nuevo canal IPC `logEntry` — el background service reenvía cada log al UI vía `service.invoke('logEntry', ...)`, y el `ConnectionProvider` lo replica en el `LogService` local.
- Se excluyen logs tipo `received` del reenvío para evitar duplicados en la UI.
- Todos los `_logService.log()` en métodos async ahora usan `await` para garantizar la persistencia ordenada en base de datos.

#### BatteryOptimizer activado
- La clase `BatteryOptimizer` ahora solicita la exclusión de optimización de batería automáticamente al conectar al broker por primera vez.
- **Crítico** para dispositivos Xiaomi/Samsung/Huawei que destruyen los *foreground services* si no cuentan con esta exclusión.

### 🔧 Mejoras de UI y UX

#### Límite de lecturas del monitor ampliado
- Capacidad de Caché en memoria aumentada drásticamente: de 200 a **10.000** lecturas por topic.
- Almacenamiento persistente (Hive) aumentado: de 5.000 a **50.000** lecturas totales (suficiente para ~7 días con mensajes cada 12 segundos).

#### Optimizaciones de interacción
- **Indicador interactivo:** El estado de conexión (🟢 / 🟡 / 🔴) en el AppBar ahora es pulsable y navega directamente a la pantalla de Conexiones.
- **Valores copiables:** Cada fila del historial en los paneles de monitoreo es pulsable para copiar el valor al portapapeles (se ha añadido un icono de copia sutil como indicador visual).
- **Botón de limpieza en Debug Trace:** Añadido icono de papelera (🗑️) en la pantalla de traza de debug que envía el comando `clearDebugTrace` al isolate para limpiar el *ring buffer*. Incluye protección si el servicio no está activo.

#### Sanitización visual y de datos
- **Trim automático:** Todos los campos de topic, payload y valor se recortan automáticamente (`.trim()`) al guardar (en dashboard, monitores, reglas y acciones). Evita errores por espacios invisibles añadidos por el teclado del móvil.
- **Alias del broker:** El texto en el AppBar ahora tiene un ancho máximo de 120px con *overflow ellipsis* para evitar que nombres largos rompan la interfaz.

### 🐛 Corregido

- **Fix Crítico (Logs ausentes):** Resuelto el problema donde los logs de ejecución de reglas y acciones no aparecían en la pantalla de la app por estar atrapados en el *isolate* secundario (solucionado vía IPC `logEntry`).
- **Export 0 bytes / crash en Android:** `FilePicker.saveFile()` en Android devuelve un *content URI*, no un *path* escribible. Ahora se pasan los `bytes` directamente al plugin, evitando que la app crashee al exportar.
- **Triple pantalla de debug:** Se bloqueó la creación de múltiples pantallas fantasma con *timeout* si el usuario pulsaba repetidamente el botón de traza sin tener el servicio activo.

## [1.1.0] - 2026-04-03 — Monitoreo Avanzado y Sync de Subscripciones

### ✅ Implementado

#### Panel de Monitoreo Sensorial
- Monitorización visual en tiempo real de topics MQTT usando widgets configurables.
- 5 Tipos de visualización:
  - **Gauge:** Mostrador de valor límite con min/max.
  - **Gráfica de Líneas:** Tendencias en tiempo real de valores numéricos (última 1h).
  - **Barras por hora:** Estadísticas y eventos agrupados por hora del día.
  - **Contador:** Histórico numérico absoluto y ventanas de tiempo (Hoy, 1h).
  - **Histórico (Log):** Ventana de los últimos payloads de texto recibidos.
- Selección por Color y Unidad personalizada (ej: °C, lux, W).
- Vista en profundidad inferior re-ajustable con histórico de 50 registros por variable.

### 🐛 Corregido

#### Sincronización Dinámica de Subscripciones IPC
- Eliminación correcta de subscripciones MQTT huérfanas o "estancadas" (stale subscriptions) cuando se desactiva una regla o widget.
- Los topics del Panel de Monitoreo se "protegen" automáticamente para que no se desuscriban accidentalmente en la evaluación general.
- Comando explícito de sincronización (`syncSubscriptions`) entre el background _isolate_ y la UI.
- Reconexión mucho más fiable que inyecta todos los payloads MQTT en cache instantáneamente a recuperar red.

---

## [1.0.0] - 2026-03-25 — Lanzamiento V1 (previamente 0.5.0)

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
