package com.vaultvoice.vaultvoice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * FND-08 bridge for Dart's `MethodChannelBackgroundProcessing`.
 *
 * Methods on `vaultvoice/processing`:
 * - `conditions()` → `{charging, lowPower, thermal}` (BatteryManager,
 *   PowerManager.isPowerSaveMode, PowerManager.currentThermalStatus);
 * - `begin({title, text})` / `progress({percent})` / `end()` — the
 *   [ProcessingService] foreground service (start refused from background ⇒
 *   `fgs_refused`; Dart keeps running on checkpoints);
 * - `scheduleDeferred()` / `completeDeferred()` — no-ops on Android: deferred
 *   jobs resume when the app is next opened (WorkManager scheduling is a
 *   follow-up, see FND-08 notes).
 * Events on `vaultvoice/processing/events`: `{kind: conditions, …}` on
 * charger / battery-saver / thermal changes, `{kind: expiring}` on the FGS
 * `onTimeout`.
 *
 * Thermal mapping (PowerManager.THERMAL_STATUS_*): NONE/LIGHT → nominal/fair,
 * MODERATE → serious, SEVERE and worse → critical.
 */
class ProcessingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopWatching()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        context = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val ctx = context ?: return
        ProcessingService.onTimeoutListener = {
            mainHandler.post { sink?.success(mapOf("kind" to "expiring")) }
        }
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) = emitConditions()
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(r, filter)
        }
        receiver = r
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
            val l = PowerManager.OnThermalStatusChangedListener { emitConditions() }
            pm.addThermalStatusListener(ctx.mainExecutor, l)
            thermalListener = l
        }
    }

    override fun onCancel(arguments: Any?) {
        stopWatching()
        sink = null
    }

    private fun stopWatching() {
        val ctx = context
        ProcessingService.onTimeoutListener = null
        receiver?.let { r -> ctx?.let { runCatching { it.unregisterReceiver(r) } } }
        receiver = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            thermalListener?.let { l ->
                (ctx?.getSystemService(Context.POWER_SERVICE) as? PowerManager)?.removeThermalStatusListener(l)
            }
        }
        thermalListener = null
    }

    private fun emitConditions() {
        val ctx = context ?: return
        val map = conditionsOf(ctx) + ("kind" to "conditions")
        mainHandler.post { sink?.success(map) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("unavailable", "not attached", null)
            return
        }
        when (call.method) {
            "conditions" -> result.success(conditionsOf(ctx))
            "begin" -> {
                try {
                    ProcessingService.start(
                        ctx,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text") ?: "",
                    )
                    result.success(null)
                } catch (e: RuntimeException) {
                    // ForegroundServiceStartNotAllowedException (app not visible)
                    // or SecurityException: processing continues on checkpoints.
                    result.error("fgs_refused", e.javaClass.simpleName, null)
                }
            }
            "progress" -> {
                ProcessingService.update(ctx, call.argument<Int>("percent") ?: 0)
                result.success(null)
            }
            "end" -> {
                ProcessingService.stop(ctx)
                result.success(null)
            }
            "scheduleDeferred", "completeDeferred" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun conditionsOf(ctx: Context): Map<String, Any> {
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        // Sticky ACTION_BATTERY_CHANGED read (null receiver = no registration).
        val sticky = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val battery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(null, sticky, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(null, sticky)
        }
        val status = battery?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            when (pm.currentThermalStatus) {
                PowerManager.THERMAL_STATUS_NONE -> "nominal"
                PowerManager.THERMAL_STATUS_LIGHT -> "fair"
                PowerManager.THERMAL_STATUS_MODERATE -> "serious"
                else -> "critical"
            }
        } else {
            "unknown"
        }
        return mapOf("charging" to charging, "lowPower" to pm.isPowerSaveMode, "thermal" to thermal)
    }

    companion object {
        const val METHOD_CHANNEL = "vaultvoice/processing"
        const val EVENT_CHANNEL = "vaultvoice/processing/events"
    }
}
