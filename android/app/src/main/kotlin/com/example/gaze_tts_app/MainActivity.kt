// android/app/src/main/kotlin/com/example/gaze_tts_app/MainActivity.kt
package com.example.gaze_tts_app

import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

import android.util.Size
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {

    // Flutter와 통신할 채널 이름 (Dart와 동일해야 함)
    private val METHOD = "gaze/android"
    private val EVENT = "gaze/android/stream"

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private lateinit var cameraExecutor: ExecutorService
    private var started = false

    // MLKit 얼굴 감지기 설정
    private val faceDetector by lazy {
        val opts = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .enableTracking()
            .build()
        FaceDetection.getClient(opts)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cameraExecutor = Executors.newSingleThreadExecutor()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Flutter → Android MethodChannel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val args = call.arguments as? Map<*, *>
                        val headless = (args?.get("headless") as? Boolean) ?: true
                        startCamera(headless)
                        result.success(true)
                    }
                    "stop" -> {
                        stopCamera()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Android → Flutter EventChannel
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.i("GazeTTS", "EventChannel connected")
                }

                override fun onCancel(arguments: Any?) {
                    Log.i("GazeTTS", "EventChannel cancelled")
                    eventSink = null
                }
            })
        }
    }

    /** 카메라 시작 */
    private fun startCamera(headless: Boolean) {
        if (started) return
        started = true
        Log.i("GazeTTS", "Starting camera (headless=$headless)")

        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            cameraProvider = providerFuture.get()

            val camSelector = CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
                .build()

            // 분석 전용 (ImageAnalysis)
            analysis = ImageAnalysis.Builder()
                .setTargetResolution(Size(640, 480))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { ia ->
                    ia.setAnalyzer(cameraExecutor) { imageProxy ->
                        analyzeImage(imageProxy)
                    }
                }

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(this, camSelector, analysis)
                Log.i("GazeTTS", "Camera bound successfully")
            } catch (e: Exception) {
                Log.e("GazeTTS", "Failed to bind camera: ${e.message}")
                emitGaze(0.5, 0.5, false)
            }

        }, ContextCompat.getMainExecutor(this))
    }

    /** 카메라 중지 */
    private fun stopCamera() {
        Log.i("GazeTTS", "Stopping camera")
        started = false
        try {
            cameraProvider?.unbindAll()
            analysis?.clearAnalyzer()
        } catch (e: Exception) {
            Log.e("GazeTTS", "Error stopping camera: ${e.message}")
        }
    }

    /** MLKit 얼굴 분석 → 시선 좌표 추정 */
    private fun analyzeImage(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val rotation = imageProxy.imageInfo.rotationDegrees
        val inputImage = InputImage.fromMediaImage(mediaImage, rotation)

        faceDetector.process(inputImage)
            .addOnSuccessListener { faces ->
                val w = imageProxy.width.toFloat()
                val h = imageProxy.height.toFloat()

                // 가장 큰 얼굴 선택
                var bestFace: Face? = null
                var bestArea = 0f
                for (face in faces) {
                    val area = (face.boundingBox.width() * face.boundingBox.height()).toFloat()
                    if (area > bestArea) {
                        bestArea = area
                        bestFace = face
                    }
                }

                if (bestFace != null) {
                    val box = bestFace.boundingBox
                    val cx = box.centerX().toFloat().coerceIn(0f, w)
                    val cy = box.centerY().toFloat().coerceIn(0f, h)

                    // 전면 카메라 반전 보정
                    val nx = 1f - (cx / w)
                    val ny = cy / h

                    emitGaze(nx.toDouble(), ny.toDouble(), true)
                } else {
                    emitGaze(0.5, 0.5, false)
                }
            }
            .addOnFailureListener { e ->
                Log.e("GazeTTS", "Face detection failed: ${e.message}")
                emitGaze(0.5, 0.5, false)
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    }

    /** Flutter로 좌표 전송 */
    private fun emitGaze(x: Double, y: Double, valid: Boolean) {
        val payload = mapOf(
            "x" to clamp01(x),
            "y" to clamp01(y),
            "valid" to valid,
            "ts" to System.currentTimeMillis()
        )
        eventSink?.success(payload)
    }

    /** 안전한 0~1 클램프 */
    private fun clamp01(v: Double): Double = max(0.0, min(1.0, v))

    override fun onDestroy() {
        super.onDestroy()
        stopCamera()
        cameraExecutor.shutdown()
    }
}
