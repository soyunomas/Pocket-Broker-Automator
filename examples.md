# 📘 Guía de Inicio y Ejemplos — PocketBroker Automator

Esta guía te enseñará paso a paso cómo probar la aplicación desde cero. 
Lo principal que debes entender es que PocketBroker funciona mediante mensajes **MQTT**: nos conectamos a un servidor (Broker), enviamos mensajes (mediante Paneles/Botones) y reaccionamos a mensajes (mediante Automatizaciones).

---

## 1️⃣ Primer Paso: Conectarse a un Broker MQTT

Para poder enviar o recibir información, necesitas conectarte a un "Broker". Este actúa como el intermediario central que reparte los mensajes.

**Ejemplo de conexión con un broker público gratuito:**
1. Ve a la pestaña **Ajustes de Conexión** o la pantalla principal donde visualices tus conexiones.
2. Pulsa en el botón **`+`** para añadir un nuevo broker remoto.
3. Rellena los datos así:
   - **Nombre:** `Broker de Prueba`
   - **Host / IP:** `mqtt.tyckr.io` (o también puedes probar `broker.hivemq.com` / `test.mosquitto.org`)
   - **Puerto:** `1883`
   - **Cliente ID:** Déjalo por defecto o inventa un número al azar.
   - *Nota: No hace falta ni usuario ni contraseña para estos brokers de prueba públicos.*
4. Guarda y activa la conexión. Sabrás que estás correctamente operativo cuando el indicador esté vinculado y en verde.

*(Alternativa: También puedes ir a la pestaña **Broker Local** e iniciar tu broker interno dentro del propio móvil si prefieres que nada salga a internet).*

---

## 2️⃣ Pruebas de Paneles y Botones (Dashboard)

El Panel te permite crear botones de control que envían (Publican) un comando a un `Topic` específico en el momento en que los pulsas.

Ve a la pestaña **Panel (Dashboard)**, pulsa en el botón `+` y vamos a crear algunos botones de prueba:

### Ejemplo A: Botón de Encender una Luz
- **Label (Nombre):** Encender Luz
- **Topic:** `prueba/casa/luz/salon/estado`
- **Payload (Mensaje):** `ON`
- **Color:** Amarillo `#FFEB3B`
*(La acción de este botón enviará la palabra `ON` textualmente al servidor bajo el canal de la luz).*

### Ejemplo B: Botón de Apagar una Luz
- **Label (Nombre):** Apagar Luz
- **Topic:** `prueba/casa/luz/salon/estado`
- **Payload (Mensaje):** `OFF`
- **Color:** Gris `#9E9E9E`

### Ejemplo C: Forzar una alerta de sensor
- **Label (Nombre):** Simular Temperatura Crítica
- **Topic:** `prueba/invernadero/temp`
- **Payload (Mensaje):** `45`
- **Color:** Rojo `#F44336`

> 💡 **Cómo probar que los botones envían bien:** 
> Vete a la pantalla de **Monitor (Consola)** y añade el filtro de topic `prueba/#`. Al hacer esto, todo lo que empiece por prueba te aparecerá en un log en vivo. Vuelve a tus botones, tócalos y mira cómo en el Monitor aparece al instante todo lo que envías.

---

## 3️⃣ Pruebas de Automatizaciones (Acciones)

Las reglas de **Automatización** funcionan quedándose calladas, "escuchando" silenciosamente. Si ven un mensaje que cumpla su fórmula, ejecutarán una acción en el móvil.
Usemos los botones de arriba para hacer las pruebas. Revisa la pestaña de **Automatizaciones** y pulsa en el `+` para crearlas:

### Ejemplo A: Hacer sonar una alarma al apagar
Queremos que tu móvil suene repentinamente si detecta que la luz se apagó.
- **Nombre:** Alarma de Apagado
- **Topic:** `prueba/casa/luz/salon/estado`
- **Condición:** Tipo `Igual a`, Valor `OFF`
- **Acciones:**
  - Añade la acción y selecciona **Tipo:** `Sonido`
  - Selecciona un archivo `.mp3` o `.wav` de las descargas o grabaciones de tu móvil.

**Prueba:** Vete a tu Panel Principal y toca el botón gris de "Apagar Luz". En milisegundos saltará el evento y oirás el sonido.

### Ejemplo B: Abrir una URL o invocar una App Externa (Intent)
Queremos que el móvil se prepare para iniciar una ruta de conducción hacia tu casa cuando alguien mande 'ON'.
- **Nombre:** Modo Conducción Inteligente
- **Topic:** `prueba/casa/luz/salon/estado`
- **Condición:** Tipo `Igual a`, Valor `ON`
- **Acciones:**
  - Añade la acción y selecciona **Tipo:** `Abrir URL/App`
  - **URL:** `https://maps.google.com/?q=40.4168,-3.7038` *(Ejemplo de España)*

**Prueba:** Al usar el botón "Encender Luz" con su payload "ON", la app llamará al sistema de Android para que cargue la ruta en Google Maps de inmediato. 

*(Recordatorio importante: A veces, si estás fuera de la app o con el modo depuración de Android estricto, en vez de interrumpirte bruscamente el sistema te lanzará una notificación interactiva diciendo que una automatización requiere tocar para ejecutarse y abrir la ventana).*

### Ejemplo C: Disparar un Webhook HTTP al exterior
Si el invernadero llega a temperaturas altísimas, mandaremos los datos a un servicio web o a una API privada tuya para que analice el error.
- **Nombre:** Escalada a Web del Sistema
- **Topic:** `prueba/invernadero/temp`
- **Condición:** Tipo `Contiene`, Valor `4` *(Saltará porque enviaremos el número 45, que contiene un 4).*
- **Acciones:**
  - Selecciona **Tipo:** `Webhook`
  - **Método HTTP:** `POST` *(La opción que acabamos de agregar).*
  - **URL:** `https://httpbin.org/post`
  - **Body JSON:** `{"alerta_enviada": true, "sistema": "invernadero"}`

**Prueba:** Toca tu botón rojo gigante (Ejemplo C). Acto seguido vete a la pantalla Configuración -> **Logs del Sistema**. Encontrarás un registro detallando que se activó la regla y se envió un "Webhook POST" hacia httpbin de manera invisible obteniendo la respuesta de que todo está conforme.

---

## 🔗 Otros Servicios de Webhook Avanzados e Intents Populares

Puedes expandir masivamente lo que puede hacer PocketBroker interactuando con servidores reales de terceros usando el **Ejemplo C (Webhook)**:

| Servicio / Destino | Método | Ejemplo de URL y Body a Completar |
|--------------------|:------:|-----------------------------------|
| **Home Assistant** | POST | **URL:** `http://TU_IP:8123/api/webhook/ID_WEBHOOK` <br> **Body JSON:** `{"action": "turn_on"}` |
| **Ntfy.sh** (Push) | POST | **URL:** `https://ntfy.sh/mi-topic-secreto` <br> **Body JSON:** `Alarma activada en casa` |
| **Telegram Bot** | POST | **URL:** `https://api.telegram.org/bot[TOKEN_DEL_BOT]/sendMessage` <br> **Body JSON:** `{"chat_id":"ID_TU_USUARIO","text":"🔥 ALARMA INVERNADERO"}` |
| **Twilio SMS** | POST | *(Usa SMS Directamente sin Interacción del usuario. Necesitarás colocar las credenciales en la propia URL en formato Basic Auth o buscar la API Documentada)*. |

**Atajos para móviles (para la acción de Abrir URL/App):**
Si quieres que Android interprete acciones nativas, puedes configurarle cosas como:
- **Hablar en Whatsapp a un número:** `https://wa.me/34612345678?text=Hola,%20detecté%20el%20sensor!`
- **Llamar por Teléfono:** `tel:+34612345678`
- **Cargar Spotify:** `spotify:track:4cOdK2wGLETKBW3PvgPWqT`
- **Cargar YouTube:** `https://youtube.com/watch?v=dQw4w9WgXcQ`
- **Rellenar un SMS nativo:** `sms:+34612345678?body=Ayuda` *(Te forzará a dar a enviar con el dedo por seguridad de Android, no se manda mágico).*
