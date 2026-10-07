package com.everif.everif_face_sdk

import android.content.Context
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.Executors

class EverifFaceSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var engine: FaceEngine? = null
    private val executor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "everif_face_sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getDeviceBinding") {
            val id = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            result.success(mapOf("appId" to context.packageName, "deviceId" to sha256("android:$id:${context.packageName}"), "platform" to "android"))
            return
        }
        executor.execute {
            try {
                val faceEngine = engine ?: FaceEngine(context).also { engine = it }
                val value = when (call.method) {
                    "createTemplate" -> faceEngine.createTemplate(call.argument<ByteArray>("image") ?: error("invalidImage"))
                    "verify" -> faceEngine.verify(call.argument<ByteArray>("image") ?: error("invalidImage"), call.argument<List<Double>>("template") ?: error("templateIncompatible"), call.argument<Boolean>("liveness") ?: true)
                    "resetLiveness" -> { faceEngine.reset(); null }
                    "dispose" -> { faceEngine.close(); engine = null; null }
                    else -> { main { result.notImplemented() }; return@execute }
                }
                main { result.success(value) }
            } catch (error: Throwable) {
                main { result.error(FaceEngine.publicError(error), "Face operation failed.", null) }
            }
        }
    }

    private fun main(block: () -> Unit) = android.os.Handler(context.mainLooper).post(block)
    private fun sha256(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null); engine?.close(); executor.shutdownNow() }
}
