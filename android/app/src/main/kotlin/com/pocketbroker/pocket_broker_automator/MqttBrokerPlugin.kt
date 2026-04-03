package com.pocketbroker.pocket_broker_automator

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.moquette.broker.Server
import io.moquette.broker.config.MemoryConfig
import io.moquette.broker.security.IAuthenticator
import java.io.File
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Properties

class MqttBrokerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var server: Server? = null
    private val TAG = "MqttBrokerPlugin"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.pocketbroker/mqtt_broker")
        channel.setMethodCallHandler(this)
        appContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopServer()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startBroker" -> {
                val port = call.argument<Int>("port") ?: 1883
                val authEnabled = call.argument<Boolean>("authEnabled") ?: false
                val username = call.argument<String>("username") ?: ""
                val pwd = call.argument<String>("password") ?: ""
                val wsEnabled = call.argument<Boolean>("wsEnabled") ?: false
                val wsPort = call.argument<Int>("wsPort") ?: 8083
                startServer(port, authEnabled, username, pwd, wsEnabled, wsPort, result)
            }
            "stopBroker" -> {
                stopServer()
                result.success(mapOf("success" to true))
            }
            "isBrokerRunning" -> {
                result.success(mapOf("running" to (server != null)))
            }
            else -> result.notImplemented()
        }
    }

    private fun startServer(
        port: Int,
        authEnabled: Boolean,
        username: String,
        pwd: String,
        wsEnabled: Boolean,
        wsPort: Int,
        result: MethodChannel.Result
    ) {
        try {
            stopServer()

            // Usamos almacenamiento privado para el entorno Moquette y H2
            val dataDir = File(appContext.filesDir, "moquette")
            if (dataDir.exists()) dataDir.deleteRecursively()
            dataDir.mkdirs()
            
            val storePath = File(dataDir, "moquette_store.h2").absolutePath

            // FIX PARA ANDROID:
            // Forzamos a H2 y a Moquette a utilizar nuestros directorios seguros de Android
            // reescribiendo las variables del sistema en las que se basan por defecto.
            System.setProperty("java.io.tmpdir", appContext.cacheDir.absolutePath)
            System.setProperty("user.dir", dataDir.absolutePath)
            System.setProperty("moquette.path", dataDir.absolutePath)

            val props = Properties()
            props.setProperty("port", port.toString())
            props.setProperty("host", "0.0.0.0")
            props.setProperty("allow_anonymous", (!authEnabled).toString())
            props.setProperty("allow_zero_byte_client_id", "true")
            
            // Rutas absolutas explícitas
            props.setProperty("data_path", dataDir.absolutePath)
            props.setProperty("persistent_store", storePath)
            
            // Evitamos que intente leer configuraciones predeterminadas (ej: "conf/password_file.conf")
            // que al resolverse tratarían de acceder a la raíz "/" del sistema Android.
            props.setProperty("password_file", "")
            props.setProperty("acl_file", "")

            if (wsEnabled) {
                props.setProperty("websocket_port", wsPort.toString())
                props.setProperty("websocket_path", "/mqtt")
            }

            val config = MemoryConfig(props)
            server = Server()

            if (authEnabled && username.isNotEmpty()) {
                val authenticator = SimpleAuthenticator(username, pwd)
                // Se pasan nulls a los handlers extra que no necesitamos
                server!!.startServer(config, null, null, authenticator, null)
            } else {
                server!!.startServer(config)
            }

            val ips = getDeviceIps()
            val wsInfo = if (wsEnabled) " + WS:$wsPort" else ""
            Log.i(TAG, "Broker started on port $port$wsInfo (auth=$authEnabled) IPs=$ips")
            result.success(mapOf("success" to true, "ips" to ips))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start broker: ${e.message}", e)
            server = null
            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
        }
    }

    private fun getDeviceIps(): List<String> {
        val ips = mutableListOf<String>()
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                if (iface.isLoopback || !iface.isUp) continue
                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement()
                    if (addr is Inet4Address) {
                        ips.add(addr.hostAddress ?: continue)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting IPs: ${e.message}")
        }
        return ips
    }

    private fun stopServer() {
        try {
            server?.stopServer()
            Log.i(TAG, "Broker stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping broker: ${e.message}", e)
        }
        server = null
    }

    private class SimpleAuthenticator(
        private val validUsername: String,
        private val validPwd: String
    ) : IAuthenticator {
        override fun checkValid(clientId: String?, username: String?, password: ByteArray?): Boolean {
            val passStr = password?.let { String(it) } ?: ""
            return username == validUsername && passStr == validPwd
        }
    }
}
