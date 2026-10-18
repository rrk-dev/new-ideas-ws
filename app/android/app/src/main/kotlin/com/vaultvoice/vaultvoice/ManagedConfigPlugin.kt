package com.vaultvoice.vaultvoice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.RestrictionsManager
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * LIC-04 managed configuration (MDM). Method channel
 * `vaultvoice/managed_config`: `read` -> JSON string of the application
 * restrictions (null when none); native -> Dart `changed`.
 *
 * Reads `RestrictionsManager.getApplicationRestrictions()` (Android
 * "Managed configurations", schema in res/xml/app_restrictions.xml).
 * `ACTION_APPLICATION_RESTRICTIONS_CHANGED` is not delivered to
 * manifest-declared receivers, so the receiver is registered at runtime.
 * Nothing is written and nothing is logged.
 */
class ManagedConfigPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var receiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val ctx = binding.applicationContext
        context = ctx
        val ch = MethodChannel(binding.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler(this)
        channel = ch
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                ch.invokeMethod("changed", null)
            }
        }
        ctx.registerReceiver(r, IntentFilter(Intent.ACTION_APPLICATION_RESTRICTIONS_CHANGED))
        receiver = r
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        receiver?.let { context?.unregisterReceiver(it) }
        receiver = null
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> result.success(readJson())
            else -> result.notImplemented()
        }
    }

    private fun readJson(): String? {
        val ctx = context ?: return null
        val manager = ctx.getSystemService(Context.RESTRICTIONS_SERVICE) as? RestrictionsManager
            ?: return null
        val bundle = manager.applicationRestrictions
        if (bundle == null || bundle.isEmpty) return null
        return toJson(bundle).toString()
    }

    private fun toJson(bundle: Bundle): JSONObject {
        val out = JSONObject()
        for (key in bundle.keySet()) {
            @Suppress("DEPRECATION")
            out.put(key, convert(bundle.get(key)))
        }
        return out
    }

    private fun convert(value: Any?): Any? = when (value) {
        null -> JSONObject.NULL
        is Bundle -> toJson(value)
        is Array<*> -> JSONArray().also { a -> value.forEach { a.put(convert(it)) } }
        is Boolean, is Int, is Long, is Double, is String -> value
        else -> value.toString()
    }

    companion object {
        const val CHANNEL = "vaultvoice/managed_config"
    }
}
