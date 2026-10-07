package com.everif.everif_face_sdk

import android.content.Context
import org.tensorflow.lite.Interpreter
import java.io.File

internal class ModelStore(context: Context) {
    private val root = File(context.noBackupFilesDir, "everif_face_sdk/model_packs")
    private val names = setOf(
        "mobileFaceNetARCNET.tflite",
        "minifas_v2_2.7_80.tflite",
        "minifas_v1se_4.0_80.tflite",
    )

    fun has(version: String): Boolean = safeVersion(version) && names.all { File(root, "$version/$it").isFile }

    fun paths(version: String): Map<String, File> {
        if (!has(version)) error("modelUnavailable")
        return names.associateWith { File(root, "$version/$it") }
    }

    fun install(version: String, models: Map<*, *>) {
        if (!safeVersion(version) || models.keys.toSet() != names) error("modelUnavailable")
        val stage = File(root, ".stage-$version-${System.nanoTime()}")
        if (!stage.mkdirs()) error("modelUnavailable")
        try {
            names.forEach { name ->
                val bytes = models[name] as? ByteArray ?: error("modelUnavailable")
                if (bytes.isEmpty()) error("modelUnavailable")
                File(stage, name).writeBytes(bytes)
            }
            validate(stage)
            val target = File(root, version)
            if (target.exists() && !target.deleteRecursively()) error("modelUnavailable")
            if (!stage.renameTo(target)) error("modelUnavailable")
        } finally {
            if (stage.exists()) stage.deleteRecursively()
        }
    }

    private fun validate(directory: File) {
        fun open(name: String) = Interpreter(File(directory, name), Interpreter.Options().setNumThreads(1))
        open("mobileFaceNetARCNET.tflite").use { model ->
            require(model.getInputTensor(0).shape().contentEquals(intArrayOf(1, 112, 112, 3))) { "modelUnavailable" }
            require(model.getOutputTensor(0).shape().last() > 0) { "modelUnavailable" }
        }
        listOf("minifas_v2_2.7_80.tflite", "minifas_v1se_4.0_80.tflite").forEach { name ->
            open(name).use { model ->
                require(model.getInputTensor(0).shape().contentEquals(intArrayOf(1, 80, 80, 3))) { "modelUnavailable" }
                require(model.getOutputTensor(0).shape().contentEquals(intArrayOf(1, 3))) { "modelUnavailable" }
            }
        }
    }

    private fun safeVersion(version: String) = version.matches(Regex("[0-9]{1,8}"))
}
