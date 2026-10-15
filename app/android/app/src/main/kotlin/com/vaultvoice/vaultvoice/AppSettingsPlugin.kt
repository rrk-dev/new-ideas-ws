package com.vaultvoice.vaultvoice

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * APP-01 permission recovery: opens this app's page in the system Settings
 * (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`, API 9+) so the user can
 * grant a permission they denied earlier. Requests nothing itself.
 *
 * Method channel `vaultvoice/app_settings`: `open()` -> Boolean.
 */
class AppSettingsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

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
        when (call.method) {
            "open" -> {
                val ctx = context
                if (ctx == null) {
                    result.success(false)
                    return
                }
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", ctx.packageName, null),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    ctx.startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "vaultvoice/app_settings"
    }
}
