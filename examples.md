# 📘 Ejemplos de Automatización — PocketBroker Automator

## 🔗 Webhooks

### Servicios de prueba (no requieren registro)

| Servicio | URL | Descripción |
|----------|-----|-------------|
| [httpbin.org](https://httpbin.org) | `https://httpbin.org/get` | Devuelve los datos de tu petición como JSON |
| [webhook.site](https://webhook.site) | Genera una URL única | Inspecciona peticiones en tiempo real |
| [httpstat.us](https://httpstat.us) | `https://httpstat.us/200` | Devuelve el código HTTP que pidas |

#### Ejemplo 1: Webhook GET simple
- **URL:** `https://httpbin.org/get`
- **Method:** GET
- En los logs verás `Webhook GET → 200`

#### Ejemplo 2: Webhook POST con body
- **URL:** `https://httpbin.org/post`
- **Method:** POST
- **Body:** `{"sensor": "temperatura", "valor": 22.5}`
- httpbin te devuelve un JSON con lo que enviaste

#### Ejemplo 3: webhook.site (ver peticiones en tiempo real)
1. Entra en https://webhook.site desde el navegador
2. Copia la URL única que te genera (ej: `https://webhook.site/abc-123-...`)
3. Usa esa URL en la acción webhook
4. Cada vez que se dispare la regla, verás la petición en la web

### Servicios reales (requieren cuenta)

#### IFTTT (If This Then That)
1. Crea un applet con trigger "Webhooks"
2. Tu URL será: `https://maker.ifttt.com/trigger/{evento}/with/key/{tu_key}`
3. Puedes encadenar con cualquier acción IFTTT (email, smart home, etc.)
- **Method:** POST
- **Body:** `{"value1": "sensor1", "value2": "25°C"}`

#### Home Assistant
- **URL:** `http://TU_IP:8123/api/webhook/{webhook_id}`
- **Method:** POST
- **Body:** `{"action": "turn_on", "entity": "light.salon"}`

#### Ntfy.sh (notificaciones push gratuitas)
- **URL:** `https://ntfy.sh/mi-topic-secreto`
- **Method:** POST
- **Body:** `Alerta: sensor activado`
- Instala la app [ntfy](https://ntfy.sh) en otro móvil para recibir las notificaciones

#### Pushover
- **URL:** `https://api.pushover.net/1/messages.json`
- **Method:** POST
- **Body:** `{"token":"APP_TOKEN","user":"USER_KEY","message":"Sensor activado"}`

---

## 📱 URL / Abrir App (Intent)

**Sí, se pueden abrir apps del teléfono** usando URL schemes y deep links.
Android asocia esquemas de URL con apps instaladas. Si la app está instalada, se abre directamente.

### Apps comunes

| App | URL | Qué hace |
|-----|-----|----------|
| **Navegador** | `https://google.com` | Abre una web |
| **Teléfono** | `tel:+34612345678` | Abre el marcador con el número |
| **SMS** | `sms:+34612345678?body=Hola` | Abre SMS con texto prellenado |
| **Email** | `mailto:test@example.com?subject=Alerta&body=Sensor%20activado` | Abre cliente de correo |
| **WhatsApp** | `https://wa.me/34612345678?text=Alerta%20sensor` | Abre chat de WhatsApp |
| **Telegram** | `tg://msg?to=username&text=Hola` | Abre chat de Telegram |
| **Google Maps** | `geo:40.4168,-3.7038?q=Madrid` | Abre Maps en coordenadas |
| **Google Maps** | `https://maps.google.com/?q=40.4168,-3.7038` | Navegación a punto |
| **YouTube** | `https://youtube.com/watch?v=dQw4w9WgXcQ` | Abre vídeo en app YouTube |
| **Spotify** | `spotify:track:4cOdK2wGLETKBW3PvgPWqT` | Abre canción en Spotify |
| **Spotify** | `spotify:playlist:37i9dQZF1DXcBWIGoYBM5M` | Abre playlist |
| **Instagram** | `https://instagram.com/_u/username` | Abre perfil en Instagram |
| **Twitter/X** | `https://twitter.com/username` | Abre perfil en X |
| **Google Home** | `googlehome://` | Abre Google Home |
| **Ajustes WiFi** | `App-Prefs:WIFI` (iOS) | *(Solo iOS)* |

### Ejemplos prácticos de automatización

#### 🚨 Alarma: llamar a un número
```
Topic:   casa/alarma/estado
Valor:   intrusion
Acción:  intent → tel:+34612345678
```
Al detectar intrusión, abre el marcador listo para llamar.

#### 💬 Notificar por WhatsApp
```
Topic:   jardin/riego/estado
Valor:   completado
Acción:  intent → https://wa.me/34612345678?text=Riego%20completado
```

#### 🎵 Ambiente: reproducir playlist
```
Topic:   casa/modo
Valor:   fiesta
Acción:  intent → spotify:playlist:37i9dQZF1DXcBWIGoYBM5M
```

#### 📍 Localización: abrir mapa
```
Topic:   vehiculo/gps
Valor:   any
Acción:  intent → https://maps.google.com/?q=40.4168,-3.7038
```
*(En una versión futura se podría usar el payload como coordenadas)*

#### 📧 Email de alerta
```
Topic:   servidor/estado
Valor:   critical
Acción:  intent → mailto:admin@empresa.com?subject=ALERTA&body=Servidor%20caído
```

---

## 🔁 Combinaciones (múltiples acciones por regla)

Una sola regla puede tener varias acciones simultáneas:

#### Sensor de temperatura alta
```
Topic:     invernadero/temp
Condición: > 40 (usar "contains" con "4" como workaround)
Acciones:
  1. sound    → alarma.mp3
  2. webhook  → POST https://ntfy.sh/mi-invernadero  body: "Temp crítica!"
  3. publish  → invernadero/ventilador → ON
  4. intent   → https://wa.me/34612345678?text=Temperatura%20crítica
```

#### Timbre de puerta inteligente
```
Topic:     casa/timbre
Condición: equals → pressed
Acciones:
  1. sound    → doorbell.mp3
  2. webhook  → GET https://mi-camara/snapshot
  3. intent   → https://mi-camara.local/live
```

---

## ⚠️ Limitaciones de URL schemes

### SMS (`sms:`) — NO envía automáticamente
El scheme `sms:` solo **abre la app de mensajes** con el texto prellenado, pero requiere que el usuario pulse "Enviar". Es una restricción de seguridad de Android — ningún truco (retorno de carro, caracteres especiales, etc.) puede saltársela.

### Alternativas para enviar SMS sin interacción

#### Opción 1: Webhook a API de SMS (recomendada)
Usa la acción **webhook** en lugar de **intent**:

**Twilio** (tiene capa gratuita):
```
Acción:  webhook
URL:     https://api.twilio.com/2010-04-01/Accounts/{SID}/Messages.json
Method:  POST
Body:    To=+34612345678&From=+1234567890&Body=Alerta%20sensor
```
*(Requiere autenticación HTTP Basic con SID:AuthToken en la URL)*

**CallMeBot** (gratis, sin registro para WhatsApp):
```
Acción:  webhook
URL:     https://api.callmebot.com/whatsapp.php?phone=+34612345678&text=Alerta+sensor&apikey=TU_KEY
Method:  GET
```

**Ntfy.sh → SMS** (gratis):
Ntfy puede enviar notificaciones push que llegan como si fueran SMS si configuras la app ntfy en el móvil destino.

#### Opción 2: Telegram Bot (gratis, ilimitado)
Crea un bot con @BotFather y envía mensajes vía webhook:
```
Acción:  webhook
URL:     https://api.telegram.org/bot{TOKEN}/sendMessage
Method:  POST
Body:    {"chat_id": "TU_CHAT_ID", "text": "🚨 Alerta: sensor activado"}
```
Esto **sí envía el mensaje automáticamente**, sin interacción.

#### Opción 3: Email como alternativa
Servicios como **Mailgun** o **SendGrid** permiten enviar emails vía webhook:
```
Acción:  webhook
URL:     https://api.mailgun.net/v3/TU_DOMINIO/messages
Method:  POST
Body:    from=alerta@tudominio.com&to=tu@email.com&subject=Alerta&text=Sensor+activado
```

### Resumen: ¿qué se puede hacer automáticamente?

| Método | ¿Automático? | Coste |
|--------|:------------:|-------|
| `sms:` (intent) | ❌ Requiere pulsar enviar | Gratis |
| Twilio webhook | ✅ Envío directo | ~0.01€/SMS |
| Telegram Bot webhook | ✅ Envío directo | Gratis |
| CallMeBot WhatsApp | ✅ Envío directo | Gratis |
| Ntfy.sh push | ✅ Notificación directa | Gratis |
| `mailto:` (intent) | ❌ Requiere pulsar enviar | Gratis |
| Mailgun/SendGrid webhook | ✅ Envío directo | Capa gratuita |
| `tel:` (intent) | ❌ Requiere pulsar llamar | Gratis |

> **Regla general**: Los **intents** (`sms:`, `mailto:`, `tel:`) abren la app pero necesitan confirmación del usuario. Los **webhooks** a APIs externas envían sin interacción.

---

## 💡 Tips

- **webhook.site** es la forma más rápida de verificar que tus webhooks funcionan
- Los URL schemes (`tel:`, `sms:`, `mailto:`) funcionan sin instalar nada extra
- Si una app no se abre con un deep link, prueba con su URL web normal (ej: `https://wa.me/...`)
- Las acciones de tipo **intent** abren la URL en el navegador o app asociada
- Si la app está en **background**, recibirás una **notificación tocable** que abrirá la URL
- Usa **publish** como acción para encadenar reglas (una regla dispara otra)
