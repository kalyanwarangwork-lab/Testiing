package com.kalyan.flashlight

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Talks to the phone's camera flash through Android's CameraManager.
 * setTorchMode needs no CAMERA permission, so the app asks for none.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "flashlight/torch"
    private var torchCameraId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(findTorchCamera() != null)
                    "setTorch" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        try {
                            setTorch(on)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("TORCH_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun cameraManager(): CameraManager =
        getSystemService(Context.CAMERA_SERVICE) as CameraManager

    private fun findTorchCamera(): String? {
        if (torchCameraId != null) return torchCameraId
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) return null
        val manager = cameraManager()
        torchCameraId = manager.cameraIdList.firstOrNull { id ->
            val c = manager.getCameraCharacteristics(id)
            c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                c.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        } ?: manager.cameraIdList.firstOrNull { id ->
            manager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
        return torchCameraId
    }

    private fun setTorch(on: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw IllegalStateException("Torch control needs Android 6.0 or newer")
        }
        val id = findTorchCamera() ?: throw IllegalStateException("No flash on this device")
        cameraManager().setTorchMode(id, on)
    }

    override fun onDestroy() {
        // Make sure the light never stays on after the app is closed.
        try { if (findTorchCamera() != null) setTorch(false) } catch (_: Exception) {}
        super.onDestroy()
    }
}
