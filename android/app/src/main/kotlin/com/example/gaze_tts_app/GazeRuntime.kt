package com.example.gaze_tts_app

import android.annotation.SuppressLint
import android.content.Context
import android.util.Size
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.camera.view.PreviewView
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class GazeRuntime(private val context: Context) {
    private var sink: EventChannel.EventSink? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var executor: ExecutorService? = null
    private var detector: FaceDetector? = null
    private var owner: LifecycleOwner? = null
    private var previewView: PreviewView? = null
    private var preview: Preview? = null

    fun setSink(s: EventChannel.EventSink) { sink = s }
    fun clearSink() { sink = null }
    fun getPreviewView(): PreviewView {
        if (previewView == null) {
            previewView = PreviewView(context)
        }
        return previewView as PreviewView
    }

    fun start(owner: LifecycleOwner, cb: (Boolean) -> Unit) {
        this.owner = owner
        executor = Executors.newSingleThreadExecutor()
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                cameraProvider = providerFuture.get()
                bindCameraUseCases(cb)
            } catch (e: Exception) {
                cb(false)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun stop(ctx: Context) {
        try {
            cameraProvider?.unbindAll()
            detector?.close()
            executor?.shutdown()
        } catch (_: Exception) {}
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases(cb: (Boolean) -> Unit) {
        val provider = cameraProvider ?: return cb(false)
        val selector = CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_FRONT).build()
        analysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetResolution(Size(1280, 720))
            .build()

        val opts = FaceDetectorOptions.Builder()
            .enableTracking()
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .build()
        detector = FaceDetection.getClient(opts)

        analysis?.setAnalyzer(executor!!, ImageAnalysis.Analyzer { imageProxy ->
            processFrame(imageProxy)
        })

        // Preview use case
        if (previewView == null) previewView = PreviewView(context)
        preview = Preview.Builder()
            .setTargetResolution(Size(1280, 720))
            .build().also { p ->
                p.setSurfaceProvider(previewView!!.surfaceProvider)
            }

        try {
            provider.unbindAll()
            val lifecycleOwner = owner ?: return cb(false)
            provider.bindToLifecycle(lifecycleOwner, selector, analysis, preview)
            cb(true)
        } catch (e: Exception) {
            cb(false)
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun processFrame(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) { imageProxy.close(); return }
        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
        val inputImage = InputImage.fromMediaImage(mediaImage, rotationDegrees)
        detector?.process(inputImage)
            ?.addOnSuccessListener { faces ->
                if (faces.isNotEmpty()) {
                    val f = faces.first()
                    val le = f.getLandmark(com.google.mlkit.vision.face.FaceLandmark.LEFT_EYE)?.position
                    val re = f.getLandmark(com.google.mlkit.vision.face.FaceLandmark.RIGHT_EYE)?.position
                    val bb = f.boundingBox
                    val w = inputImage.width.toFloat()
                    val h = inputImage.height.toFloat()
                    var nx = 0.5f
                    var ny = 0.5f
                    if (le != null && re != null) {
                        nx = ((le.x + re.x) / 2f) / w
                        ny = ((le.y + re.y) / 2f) / h
                    } else {
                        nx = (bb.centerX() / w)
                        ny = (bb.centerY() / h)
                    }
                    // 좌우 반전(전면 카메라 미러링 보정)
                    nx = 1f - nx
                    val payload = mapOf(
                        "x" to nx.toDouble().coerceIn(0.0, 1.0),
                        "y" to ny.toDouble().coerceIn(0.0, 1.0),
                        "valid" to true,
                        "ts" to System.currentTimeMillis()
                    )
                    sink?.success(payload)
                }
            }
            ?.addOnCompleteListener { imageProxy.close() }
            ?.addOnFailureListener { imageProxy.close() }
    }
}
