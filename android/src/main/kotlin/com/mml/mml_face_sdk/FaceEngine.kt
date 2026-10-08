package com.mml.mml_face_sdk

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import com.google.mlkit.vision.common.InputImage.IMAGE_FORMAT_NV21
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.io.File
import java.io.ByteArrayInputStream
import kotlin.math.*

internal class FaceEngine(models: Map<String, File>) : AutoCloseable {
    private val detector = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE).setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL).build())
    private val arc = load(models.getValue("mobileFaceNetARCNET.tflite"))
    private val fas27 = load(models.getValue("minifas_v2_2.7_80.tflite"))
    private val fas40 = load(models.getValue("minifas_v1se_4.0_80.tflite"))
    private val scores = ArrayDeque<Double>()
    private var lowRun = 0
    private var lowStarted = 0L
    private var spoofLatched = false

    fun createTemplate(bytes: ByteArray): Map<String, Any> {
        val (bitmap, face) = validatedFace(bytes)
        return try { quality(bitmap, face) + mapOf("embedding" to embedding(align(bitmap, face)).toList()) } finally { bitmap.recycle() }
    }

    fun createTemplateFrame(nv21: ByteArray, width: Int, height: Int, rotationDegrees: Int): Map<String, Any> {
        val (bitmap, face) = validatedFrame(nv21, width, height, rotationDegrees)
        return try { quality(bitmap, face) + mapOf("embedding" to embedding(align(bitmap, face)).toList()) } finally { bitmap.recycle() }
    }

    fun verify(bytes: ByteArray, template: List<Double>, liveness: Boolean): Map<String, Any?> {
        val (bitmap, face) = validatedFace(bytes)
        return verifyBitmap(bitmap, face, template, liveness)
    }

    fun verifyFrame(nv21: ByteArray, width: Int, height: Int, rotationDegrees: Int, template: List<Double>, liveness: Boolean): Map<String, Any?> {
        val (bitmap, face) = validatedFrame(nv21, width, height, rotationDegrees)
        return verifyBitmap(bitmap, face, template, liveness)
    }

    private fun verifyBitmap(bitmap: Bitmap, face: Face, template: List<Double>, liveness: Boolean): Map<String, Any?> {
        try {
            val result = quality(bitmap, face).toMutableMap<String, Any?>()
            if (liveness) {
                if ((result["faceRatio"] as Double) < .72) {
                    scores.clear(); lowRun = 0; lowStarted = 0
                    result["livenessPassed"] = false; result["spoofLatched"] = spoofLatched
                    return result
                }
                if (spoofLatched) return result + mapOf("livenessPassed" to false, "spoofLatched" to true)
                val score = (fasScore(fas27, bitmap, face, 2.7) + fasScore(fas40, bitmap, face, 4.0)) / 2.0
                scores.addLast(score); if (scores.size > 4) scores.removeFirst()
                val now = System.currentTimeMillis()
                if (score < .40) { if (lowRun == 0) lowStarted = now; lowRun++; if (lowRun >= 3 && now - lowStarted >= 600) spoofLatched = true } else { lowRun = 0; lowStarted = 0 }
                val sorted = scores.sorted(); val median = if (sorted.size % 2 == 0) (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2 else sorted[sorted.size / 2]
                result["livenessScore"] = median; result["spoofLatched"] = spoofLatched
                if (scores.size < 4 || median < .75 || spoofLatched) { result["livenessPassed"] = false; return result }
                result["livenessPassed"] = true
            }
            val current = embedding(align(bitmap, face)); require(template.size == current.size) { "templateIncompatible" }
            result["similarity"] = cosine(current, template)
            if (!liveness) result["livenessPassed"] = null
            return result
        } finally { bitmap.recycle() }
    }

    private fun validatedFace(bytes: ByteArray): Pair<Bitmap, Face> {
        val bitmap = decodeOriented(bytes)
        val faces = Tasks.await(detector.process(InputImage.fromBitmap(bitmap, 0)))
        return validateDetectedFace(bitmap, faces)
    }

    private fun validatedFrame(nv21: ByteArray, width: Int, height: Int, rotationDegrees: Int): Pair<Bitmap, Face> {
        require(width > 0 && height > 0 && rotationDegrees in listOf(0, 90, 180, 270)) { "invalidImage" }
        val faces = Tasks.await(detector.process(InputImage.fromByteArray(nv21, width, height, rotationDegrees, IMAGE_FORMAT_NV21)))
        val bitmap = rotateBitmap(nv21ToBitmap(nv21, width, height), rotationDegrees.toFloat())
        return validateDetectedFace(bitmap, faces)
    }

    private fun validateDetectedFace(bitmap: Bitmap, faces: List<Face>): Pair<Bitmap, Face> {
        if (faces.isEmpty()) { bitmap.recycle(); error("noFace") }
        if (faces.size != 1) { bitmap.recycle(); error("multipleFaces") }
        val face = faces.single(); val ratio = face.boundingBox.width().toDouble() / min(bitmap.width, bitmap.height)
        if (ratio < .20) { bitmap.recycle(); error("faceTooSmall") }
        if (abs(face.headEulerAngleY) > 20 || abs(face.headEulerAngleZ) > 20) { bitmap.recycle(); error("faceNotFrontal") }
        return bitmap to face
    }

    private fun rotateBitmap(source: Bitmap, degrees: Float): Bitmap {
        if (degrees == 0f) return source
        val matrix = Matrix().apply { postRotate(degrees) }
        val rotated = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        if (rotated !== source) source.recycle()
        return rotated
    }

    private fun nv21ToBitmap(nv21: ByteArray, width: Int, height: Int): Bitmap {
        require(nv21.size >= width * height * 3 / 2) { "invalidImage" }
        val output = IntArray(width * height)
        val frameSize = width * height
        var pixel = 0
        for (row in 0 until height) {
            var uv = frameSize + (row shr 1) * width
            var u = 0
            var v = 0
            for (column in 0 until width) {
                var y = (nv21[pixel].toInt() and 0xff) - 16
                if (y < 0) y = 0
                if ((column and 1) == 0) {
                    v = (nv21[uv++].toInt() and 0xff) - 128
                    u = (nv21[uv++].toInt() and 0xff) - 128
                }
                val y1192 = 1192 * y
                val r = (y1192 + 1634 * v).coerceIn(0, 262143)
                val g = (y1192 - 833 * v - 400 * u).coerceIn(0, 262143)
                val b = (y1192 + 2066 * u).coerceIn(0, 262143)
                val red = ((r shl 6) and 0xff0000)
                val green = ((g shr 2) and 0xff00)
                val blue = (b shr 10) and 0xff
                output[pixel++] = (0xff shl 24) or red or green or blue
            }
        }
        return Bitmap.createBitmap(output, width, height, Bitmap.Config.ARGB_8888)
    }

    private fun decodeOriented(bytes: ByteArray): Bitmap {
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: error("invalidImage")
        val exif = runCatching { ExifInterface(ByteArrayInputStream(bytes)) }.getOrNull() ?: return decoded
        val rotation = exif.rotationDegrees
        val flipped = exif.isFlipped
        if (rotation == 0 && !flipped) return decoded
        val matrix = Matrix()
        if (flipped) matrix.postScale(-1f, 1f)
        if (rotation != 0) matrix.postRotate(rotation.toFloat())
        val oriented = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (oriented !== decoded) decoded.recycle()
        return oriented
    }

    private fun quality(image: Bitmap, face: Face) = mapOf<String, Any>("faceRatio" to face.boundingBox.width().toDouble() / min(image.width, image.height), "yaw" to face.headEulerAngleY.toDouble(), "roll" to face.headEulerAngleZ.toDouble())

    private fun fasScore(model: Interpreter, image: Bitmap, face: Face, scale: Double): Double {
        val box = face.boundingBox; val w = (box.width() * scale).roundToInt().coerceAtMost(image.width); val h = (box.height() * scale).roundToInt().coerceAtMost(image.height)
        val left = (box.exactCenterX() - w / 2).roundToInt().coerceIn(0, image.width - w); val top = (box.exactCenterY() - h / 2).roundToInt().coerceIn(0, image.height - h)
        val crop = Bitmap.createBitmap(image, left, top, w, h); val small = Bitmap.createScaledBitmap(crop, 80, 80, true); if (crop !== small) crop.recycle()
        val pixels = IntArray(6400); small.getPixels(pixels, 0, 80, 0, 0, 80, 80); small.recycle()
        val input = ByteBuffer.allocateDirect(6400 * 12).order(ByteOrder.nativeOrder()); pixels.forEach { input.putFloat(Color.blue(it).toFloat()); input.putFloat(Color.green(it).toFloat()); input.putFloat(Color.red(it).toFloat()) }; input.rewind()
        val output = arrayOf(FloatArray(3)); model.run(input, output); val raw = output[0]; require(raw.all { it.isFinite() }) { "internal" }
        val sum = raw.sum(); if (raw.all { it in 0f..1f } && abs(sum - 1f) < .001) return raw[1].toDouble()
        val maximum = raw.max(); val exps = raw.map { exp((it - maximum).toDouble()) }; return exps[1] / exps.sum()
    }

    private fun align(image: Bitmap, face: Face): Bitmap {
        val points = intArrayOf(FaceLandmark.LEFT_EYE, FaceLandmark.RIGHT_EYE, FaceLandmark.NOSE_BASE, FaceLandmark.MOUTH_LEFT, FaceLandmark.MOUTH_RIGHT).map { face.getLandmark(it)?.position ?: error("landmarksMissing") }
        val eyes = points.take(2).sortedBy { it.x }; val mouths = points.takeLast(2).sortedBy { it.x }; val src = listOf(eyes[0], eyes[1], points[2], mouths[0], mouths[1])
        val tx = doubleArrayOf(38.2946,73.5318,56.0252,41.5493,70.7299); val ty = doubleArrayOf(51.6963,51.5014,71.7366,92.3655,92.2041)
        val sx=src.map{it.x.toDouble()}.average(); val sy=src.map{it.y.toDouble()}.average(); val dx=tx.average(); val dy=ty.average(); var den=0.0; var real=0.0; var imag=0.0
        for(i in 0..4){val x=src[i].x-sx;val y=src[i].y-sy;val u=tx[i]-dx;val v=ty[i]-dy;den+=x*x+y*y;real+=u*x+v*y;imag+=v*x-u*y}; require(den>0){"landmarksMissing"}
        val a=real/den;val b=imag/den;val ox=dx-a*sx+b*sy;val oy=dy-b*sx-a*sy;val det=a*a+b*b; val out=IntArray(112*112);val source=IntArray(image.width*image.height);image.getPixels(source,0,image.width,0,0,image.width,image.height)
        for(y in 0 until 112)for(x in 0 until 112){val u=x-ox;val v=y-oy;out[y*112+x]=bilinear(source,image.width,image.height,(a*u+b*v)/det,(-b*u+a*v)/det)}
        return Bitmap.createBitmap(out,112,112,Bitmap.Config.ARGB_8888)
    }

    private fun bilinear(p: IntArray, w: Int, h: Int, x: Double, y: Double): Int {
        if (x < 0 || y < 0 || x > w - 1 || y > h - 1) return Color.BLACK
        val x0 = x.toInt(); val y0 = y.toInt(); val x1 = min(x0 + 1, w - 1); val y1 = min(y0 + 1, h - 1)
        val dx = x - x0; val dy = y - y0
        fun channel(f: (Int) -> Int): Int {
            return (f(p[y0*w+x0])*(1-dx)*(1-dy) + f(p[y0*w+x1])*dx*(1-dy) + f(p[y1*w+x0])*(1-dx)*dy + f(p[y1*w+x1])*dx*dy).roundToInt().coerceIn(0,255)
        }
        return Color.rgb(channel(Color::red), channel(Color::green), channel(Color::blue))
    }
    private fun embedding(image: Bitmap): FloatArray { try { val pix=IntArray(12544);image.getPixels(pix,0,112,0,0,112,112);val input=ByteBuffer.allocateDirect(12544*12).order(ByteOrder.nativeOrder());pix.forEach{input.putFloat((Color.blue(it)-127.5f)/128f);input.putFloat((Color.green(it)-127.5f)/128f);input.putFloat((Color.red(it)-127.5f)/128f)};input.rewind();val n=arc.getOutputTensor(0).shape().last();val out=arrayOf(FloatArray(n));arc.run(input,out);val norm=sqrt(out[0].sumOf{it*it.toDouble()});require(norm>0&&norm.isFinite()){ "internal"};return FloatArray(n){(out[0][it]/norm).toFloat()} } finally { image.recycle() } }
    private fun cosine(a:FloatArray,b:List<Double>):Double{var d=0.0;var x=0.0;var y=0.0;for(i in a.indices){d+=a[i]*b[i];x+=a[i]*a[i];y+=b[i]*b[i]};return d/sqrt(x*y)}
    private fun load(file:File):Interpreter = Interpreter(file, Interpreter.Options().setNumThreads(2))
    fun reset(){scores.clear();lowRun=0;lowStarted=0;spoofLatched=false}
    override fun close(){reset();detector.close();arc.close();fas27.close();fas40.close()}
    companion object { fun publicError(error:Throwable):String { val text=generateSequence(error){it.cause}.joinToString(" "){it.message.orEmpty()};return listOf("invalidImage","noFace","multipleFaces","faceTooSmall","faceNotFrontal","landmarksMissing","templateIncompatible","modelUnavailable").firstOrNull{text.contains(it)}?:"internal" } }
}
