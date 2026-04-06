# TO-DO — Persistencia en segundo plano

## Auditoría de persistencia en segundo plano

### ✅ Lo que está bien

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| **Foreground Service** | ✅ | `isForegroundMode: true` + notificación persistente → Android no mata el proceso |
| **Tipo de servicio** | ✅ | `foregroundServiceType="dataSync"` declarado en Manifest y en configure() |
| **Permisos** | ✅ | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`, `INTERNET` |
| **Reconnect con backoff** | ✅ | Exponencial 2/4/8/16/32/60s con tope |
| **Reconnect por red** | ✅ | `connectivity_plus` detecta cambio de red → reconexión inmediata |
| **Keep-alive MQTT** | ✅ | `keepAlivePeriod = 30s` — el broker detecta desconexión rápido |
| **Keep-alive timer** | ✅ | Timer 60s como safety net para logging de estado |
| **Resubscripción** | ✅ | `_resubscribeAll()` al reconectar + Engine re-suscribe sus topics |
| **Proguard** | ✅ | Reglas correctas para Moquette/Netty/Flutter |
| **BatteryOptimizer** | ✅ | Se solicita exclusión de batería al conectar (v1.3.0) |

### ⚠️ Riesgos y debilidades

| # | Problema | Severidad | Detalle |
|---|----------|-----------|---------|
| 1 | ~~**`BatteryOptimizer` nunca se usa**~~ | ✅ Resuelto | Integrado en `ConnectionProvider.connect()` — se solicita exclusión antes de arrancar el servicio (v1.3.0) |
| 2 | **`autoStart: false`** | 🟡 Media | Si el dispositivo reinicia, el servicio NO arranca automáticamente. Tienes `RECEIVE_BOOT_COMPLETED` en el Manifest pero `autoStart: false` en la config. |
| 3 | **`disconnect()` mata el servicio** | 🟡 Media | `ConnectionProvider.disconnect()` llama `BackgroundServiceController.stop()` → `service.stopSelf()`. Si el usuario desconecta y luego cierra la app, el servicio desaparece. Al volver no hay servicio corriendo. |
| 4 | **`startClean()` en MQTT** | 🟡 Media | Cada reconexión usa `startClean()` → el broker descarta sesión anterior. Mensajes QoS 1/2 recibidos mientras estaba desconectado se pierden. |
| 5 | **No hay WAKE_LOCK activo** | 🟡 Media | El permiso existe pero nunca se adquiere un `WakeLock`. En Doze mode, el CPU puede dormirse y los Timers/Streams dejan de ejecutarse. El foreground service ayuda pero no garantiza CPU en todos los fabricantes. |
| 6 | **`_listenMessages()` acumula listeners** | 🟠 Baja | Cada `_attemptConnect()` exitoso llama `_listenMessages()` que hace `_client?.updates?.listen(...)` sin cancelar el anterior. El client anterior está disconnected así que el stream muere solo, pero es un leak menor. |
| 7 | **Timer keep-alive no se cancela** | 🟠 Baja | `Timer.periodic(60s)` en `_onStart` nunca se cancela en `stop`. Menor porque `stopSelf()` mata el isolate. |

### Escenarios de supervivencia

| Escenario | Resultado | Motivo |
|-----------|-----------|--------|
| Usuario minimiza app | ✅ Sobrevive | Foreground Service con notificación |
| Pantalla apagada 5+ min | ✅ Sobrevive | Foreground Service con notificación |
| Doze mode (30+ min) | ⚠️ Riesgo | CPU puede dormirse, Timers pausados, no hay WakeLock activo |
| Fabricante agresivo (Xiaomi/Samsung/Huawei) | ✅ Sobrevive | `BatteryOptimizer` solicita exclusión al usuario (v1.3.0) |
| Reinicio del dispositivo | 🔴 No arranca | `autoStart: false`, no hay BootReceiver configurado |
| Swipe-to-kill del usuario | ⚠️ Riesgo | Android puede matar el foreground service sin exclusión de batería |

### Archivos implicados

- `lib/utils/battery_optimizer.dart` — Invocado en `ConnectionProvider.connect()` (v1.3.0)
- `lib/services/background_service.dart` — `autoStart: false` (línea 55)
- `lib/providers/connection_provider.dart` — `disconnect()` llama `stop()`, `connect()` solicita exclusión de batería
- `lib/services/mqtt_client_service.dart` — `startClean()` (línea 114), `_listenMessages()` sin cancelar anterior (línea 127)
- `android/app/src/main/AndroidManifest.xml` — `RECEIVE_BOOT_COMPLETED` declarado pero no utilizado
