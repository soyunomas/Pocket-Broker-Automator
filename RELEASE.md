# 🚀 PocketBroker Automator v1.2.0

**Fecha:** 6 de abril de 2026

## 🔥 Novedades Principales

### 🔀 Templates Dinámicos (Interpolación de Variables)
Ahora tus automatizaciones son inteligentes. Puedes usar datos del mensaje MQTT entrante directamente en los campos de tus acciones sin necesidad de programar nada.

- `{{payload}}` → inserta el mensaje completo recibido.
- `{{clave}}` → si el payload es JSON, inserta el valor de esa clave (ej. `{{temperatura}}` → `24.5`).

**Funciona en:** URLs de webhooks, body HTTP, URLs de intents, topics/payloads de publish y rutas de sonidos.

*Ejemplos rápidos:*
| Campo | Template que escribes | Payload que llega | Resultado final que se ejecuta |
|-------|----------|-----------------|-----------|
| Webhook | `https://api.com/save?temp={{temperatura}}` | `{"temperatura": 24.5}` | `https://api.com/save?temp=24.5` |
| Body POST | `{"sensor": "{{device}}", "valor": "{{valor}}"}` | `{"device": "bomba", "valor": 100}` | `{"sensor": "bomba", "valor": "100"}` |
| Publish | `alertas/{{device}}` | `{"device": "bomba_agua"}` | `alertas/bomba_agua` |

### 💾 Exportación e Importación de Configuración
Ya no perderás tus reglas y paneles. Usa el nuevo menú (⋮) para **Exportar** e **Importar** tu entorno completo en formato JSON. 
Puedes elegir exactamente qué guardar: Conexiones, Reglas, Controles o Monitores.

### 🛡️ Motor de Automatización v2: Concurrencia y Anti-spam
- **Anti-spam (Cooldown):** Si un sensor se vuelve loco y publica rapidísimo, el motor ignorará las ejecuciones repetidas de una misma regla durante **1 segundo** para evitar el colapso del móvil.
- **Fire-and-forget:** Las acciones de una regla ahora se ejecutan en su propio hilo. Si un webhook falla o tarda mucho, no bloqueará la lectura de los siguientes mensajes MQTT entrantes.

### 🔋 Máxima Estabilidad en Segundo Plano
- **Battery Optimizer:** Crítico para usuarios de Xiaomi, Samsung y Huawei. La app ahora solicita automáticamente la exclusión de ahorro de batería al conectar para evitar que el sistema mate el servicio de monitoreo en segundo plano.
- **Sincronización de Logs (Fix):** Se ha reescrito la comunicación interna (nuevo canal IPC). Ahora todos los logs que genera el motor en segundo plano (errores de webhooks, sonidos ejecutados, etc.) aparecen en tiempo real en la pantalla de Logs de la app.

---

## 🔧 Mejoras de Interfaz y Uso

- **📈 Monitores con esteroides:** El límite de retención histórico ha subido de 5.000 a **50.000 lecturas** (aprox. 7 días de datos continuos).
- **📋 Valores copiables:** Toca cualquier fila en el historial de un monitor para copiar su valor al portapapeles.
- **✂️ Adiós a los espacios fantasma:** Todos los campos de texto ahora se limpian solos (`.trim()`) al guardarse, evitando errores por el autocompletado del teclado.
- **🔘 Conexión rápida:** El semáforo de estado de conexión (🟢/🔴) en la barra superior ahora es un botón que te lleva directo a tus brokers.
- **🗑️ Limpieza de Debug:** Nuevo botón en la pantalla de traza para vaciar la memoria temporal en tiempo real.

---

## 🐛 Bugs Corregidos

- Solucionado un crash crítico (`0 bytes`) al intentar exportar archivos en versiones recientes de Android debido a restricciones de URI.
- Bloqueada la creación de múltiples pantallas fantasma si se pulsaba repetidamente el botón de Debug Trace sin estar conectado.
- Nombres de broker demasiado largos ya no rompen el diseño de la barra superior.

---

## 📥 Instalación

1. Descarga el archivo `app-release.apk` desde la sección **Assets** de esta release.
2. Instálalo en tu dispositivo (requiere Android 5.0 o superior).
3. *Nota:* Si actualizas desde la versión 1.1.0, todos tus brokers, reglas y paneles se conservarán intactos.

---

## 📦 Compilación desde el código fuente

Si prefieres compilar la app tú mismo:

```bash
git clone https://github.com/soyunomas/pocket-broker-automator.git
cd pocket-broker-automator
flutter pub get
flutter build apk --release