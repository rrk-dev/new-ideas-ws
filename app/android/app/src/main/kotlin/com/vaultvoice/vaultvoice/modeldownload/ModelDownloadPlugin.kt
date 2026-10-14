package com.vaultvoice.vaultvoice.modeldownload

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.PowerManager
import android.os.StatFs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * MDL-02 model downloads (Android). The bytes are fetched by the Dart
 * `NetworkGateway` (redirects validated hop by hop); this plugin only
 * supplies device facts and keeps the process alive with a `dataSync`
 * foreground service ([ModelDownloadService]) while a download runs.
 * No network API is used here.
 *
 * Channel `vaultvoice/model_download` (same contract as iOS):
 * - `freeBytes {path}` → Long? (StatFs.availableBytes of the nearest
 *   existing ancestor)
 * - `networkStatus` → {connected, unmetered, lowPowerMode}
 * - `excludeFromBackup {path}` → true (all app data is excluded by
 *   `allowBackup=false` + `dataExtractionRules` + `fullBackupContent`)
 * - `keepAliveStart {title}`, `keepAliveUpdate {received,total}`,
 *   `keepAliveStop`
 *
 * Verified against the Android API reference for compileSdk 36.
 */
class ModelDownloadPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("detached", "no context", null)
        when (call.method) {
            "freeBytes" -> result.success(freeBytes(call.argument<String>("path")))
            "networkStatus" -> result.success(networkStatus(ctx))
            "excludeFromBackup" -> result.success(true)
            "keepAliveStart" -> {
                ModelDownloadService.start(ctx, call.argument<String>("title") ?: "")
                result.success(null)
            }
            "keepAliveUpdate" -> {
                val received = call.argument<Number>("received")?.toLong() ?: 0L
                val total = call.argument<Number>("total")?.toLong() ?: 0L
                ModelDownloadService.update(ctx, received, total)
                result.success(null)
            }
            "keepAliveStop" -> {
                ModelDownloadService.stop(ctx)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun freeBytes(path: String?): Long? {
        var dir: File? = File(path ?: return null)
        while (dir != null && !dir.exists()) dir = dir.parentFile
        return dir?.let {
            try {
                StatFs(it.path).availableBytes
            } catch (e: IllegalArgumentException) {
                null
            }
        }
    }

    private fun networkStatus(ctx: Context): Map<String, Boolean> {
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
        val connected = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        val unmetered = connected &&
            caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == true
        val power = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf(
            "connected" to connected,
            "unmetered" to unmetered,
            "lowPowerMode" to power.isPowerSaveMode,
        )
    }

    companion object {
        const val CHANNEL = "vaultvoice/model_download"
    }
}
