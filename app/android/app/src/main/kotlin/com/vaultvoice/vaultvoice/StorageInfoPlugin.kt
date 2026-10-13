package com.vaultvoice.vaultvoice

import android.os.StatFs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * AUD-01 recording storage policy: free bytes on the volume holding the
 * app-private recording directory (`StatFs.getAvailableBytes`, API 18+).
 *
 * Method channel `vaultvoice/storage_info`: `freeBytes({path})` -> Long.
 */
class StorageInfoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var filesDir: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        filesDir = binding.applicationContext.filesDir.path
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "freeBytes" -> {
                // The directory may not exist yet: fall back to filesDir (same volume).
                val requested = call.argument<String>("path")
                val path = requested?.takeIf { File(it).exists() } ?: filesDir
                if (path == null) {
                    result.error("unavailable", "no storage path", null)
                    return
                }
                try {
                    result.success(StatFs(path).availableBytes)
                } catch (e: IllegalArgumentException) {
                    result.error("unavailable", "statfs failed", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "vaultvoice/storage_info"
    }
}
