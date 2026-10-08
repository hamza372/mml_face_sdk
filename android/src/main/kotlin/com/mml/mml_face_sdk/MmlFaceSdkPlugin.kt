package com.mml.mml_face_sdk

import android.content.Context
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.Executors

class MmlFaceSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var engine: FaceEngine? = null
    private lateinit var modelStore: ModelStore
    private val executor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        modelStore = ModelStore(context)
        channel = MethodChannel(binding.binaryMessenger, "mml_face_sdk")
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
                val value = when (call.method) {
                    "hasModelPack" -> modelStore.has(call.argument<String>("version") ?: "")
                    "installModelPack" -> {
                        engine?.close(); engine = null
                        modelStore.install(
                            call.argument<String>("version") ?: error("modelUnavailable"),
                            call.argument<Map<*, *>>("models") ?: error("modelUnavailable"),
                        )
                        null
                    }
                    "createTemplate" -> faceEngine().createTemplate(call.argument<ByteArray>("image") ?: error("invalidImage"))
                    "createTemplateFrame" -> faceEngine().createTemplateFrame(
                        call.argument<ByteArray>("nv21") ?: error("invalidImage"),
                        call.argument<Int>("width") ?: error("invalidImage"),
                        call.argument<Int>("height") ?: error("invalidImage"),
                        call.argument<Int>("rotationDegrees") ?: error("invalidImage"),
                    )
                    "verify" -> faceEngine().verify(call.argument<ByteArray>("image") ?: error("invalidImage"), call.argument<List<Double>>("template") ?: error("templateIncompatible"), call.argument<Boolean>("liveness") ?: true)
                    "verifyFrame" -> faceEngine().verifyFrame(
                        call.argument<ByteArray>("nv21") ?: error("invalidImage"),
                        call.argument<Int>("width") ?: error("invalidImage"),
                        call.argument<Int>("height") ?: error("invalidImage"),
                        call.argument<Int>("rotationDegrees") ?: error("invalidImage"),
                        call.argument<List<Double>>("template") ?: error("templateIncompatible"),
                        call.argument<Boolean>("liveness") ?: true,
                    )
                    "resetLiveness" -> { engine?.reset(); null }
                    "dispose" -> { engine?.close(); engine = null; null }
                    else -> { main { result.notImplemented() }; return@execute }
                }
                main { result.success(value) }
            } catch (error: Throwable) {
                main { result.error(FaceEngine.publicError(error), "Face operation failed.", null) }
            }
        }
    }

    private fun faceEngine(): FaceEngine = engine ?: FaceEngine(modelStore.paths("1")).also { engine = it }

    private fun main(block: () -> Unit) = android.os.Handler(context.mainLooper).post(block)
    private fun sha256(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null); engine?.close(); executor.shutdownNow() }
}
