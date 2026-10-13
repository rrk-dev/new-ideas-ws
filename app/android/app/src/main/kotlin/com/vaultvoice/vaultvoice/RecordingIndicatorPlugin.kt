package com.vaultvoice.vaultvoice

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * AUD-05 bridge between Dart's `MethodChannelRecordingIndicator` and
 * [RecordingService] (docs/adr/ADR-AUD-05-android-background-recording.md).
 *
 * Methods on `vaultvoice/recording_indicator`:
 * - `show({recording, title, text, chronometerBaseMs?, actions})` — starts the
 *   microphone foreground service on the first call, updates it afterwards.
 *   On Android 13+ asks for POST_NOTIFICATIONS once (the FGS runs either way;
 *   the OS microphone indicator stays visible).
 * - `hide()`, `remind({text})`, `batteryStatus()`, `openBatterySettings()`.
 * Events on `vaultvoice/recording_indicator/actions`: "pause" | "resume" | "stop".
 */
class RecordingIndicatorPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var context: Context? = null
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var askedForNotifications = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        sink = null
        RecordingService.onAction = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        RecordingService.onAction = { action -> mainHandler.post { sink?.success(action) } }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        RecordingService.onAction = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("unavailable", "not attached", null)
            return
        }
        when (call.method) {
            "show" -> {
                maybeAskForNotifications()
                try {
                    RecordingService.show(ctx, specOf(call))
                    result.success(null)
                } catch (e: RuntimeException) {
                    // ForegroundServiceStartNotAllowedException / IllegalStateException
                    // (app not visible) or SecurityException.
                    result.error("fgs_refused", e.javaClass.simpleName, null)
                }
            }
            "hide" -> {
                RecordingService.hide()
                result.success(null)
            }
            "remind" -> {
                RecordingService.instance?.remind(call.argument<String>("text") ?: "")
                result.success(null)
            }
            "batteryStatus" -> {
                val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "ignoringOptimizations" to pm.isIgnoringBatteryOptimizations(ctx.packageName),
                    ),
                )
            }
            "openBatterySettings" -> {
                openBatterySettings(ctx)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun specOf(call: MethodCall): Bundle = Bundle().apply {
        putBoolean("recording", call.argument<Boolean>("recording") ?: false)
        putString("title", call.argument<String>("title"))
        putString("text", call.argument<String>("text"))
        call.argument<Number>("chronometerBaseMs")?.let { putLong("chronometerBaseMs", it.toLong()) }
        putStringArrayList("actions", ArrayList(call.argument<List<String>>("actions").orEmpty()))
    }

    private fun maybeAskForNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || askedForNotifications) return
        val act = activity ?: return
        if (act.checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        askedForNotifications = true
        act.requestPermissions(arrayOf(POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
    }

    /**
     * The battery-optimization list (no special permission). We never use
     * ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (Play policy).
     */
    private fun openBatterySettings(ctx: Context) {
        val list = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            ctx.startActivity(list)
        } catch (e: RuntimeException) {
            val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(details)
        }
    }

    companion object {
        const val METHOD_CHANNEL = "vaultvoice/recording_indicator"
        const val EVENT_CHANNEL = "vaultvoice/recording_indicator/actions"
        private const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4103
    }
}
