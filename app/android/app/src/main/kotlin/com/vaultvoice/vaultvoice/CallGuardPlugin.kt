package com.vaultvoice.vaultvoice

import android.content.Context
import android.media.AudioManager
import android.media.AudioRecordingConfiguration
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

/**
 * SEC-09 CallGuard (Android), see docs/adr/ADR-SEC-09-recording-policy.md.
 *
 * Detects ringing/active cellular and VoIP calls **without any phone-state
 * permission**: `AudioManager.getMode()` in {RINGTONE, IN_CALL,
 * IN_COMMUNICATION, CALL_SCREENING, CALL_REDIRECT, COMMUNICATION_REDIRECT}
 * means "in call". Changes are observed with `addOnModeChangedListener`
 * (API 31+) or by polling every 500 ms (API 26-30) while Dart listens.
 * `AudioRecordingCallback` reports when our own capture is silenced
 * (`isClientSilenced`, API 29+).
 *
 * This class only *reads* the audio mode; it never changes it.
 * Verified against the Android API reference for compileSdk 36.
 *
 * Wire format (EventChannel): `{"signal": <CallGuardSignal name>, "atMs": epoch ms}`.
 */
class CallGuardPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var audioManager: AudioManager? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val mainExecutor = Executor { runnable -> mainHandler.post(runnable) }
    private var lastInCall: Boolean? = null
    private var lastSilenced = false
    private var polling = false
    // Typed Any? so the API 31 interface is only touched behind SDK checks.
    private var modeListener: Any? = null
    private var recordingCallback: AudioManager.AudioRecordingCallback? = null

    private val poll = object : Runnable {
        override fun run() {
            if (!polling) return
            evaluateMode()
            mainHandler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        audioManager = binding.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopObserving()
        sink = null
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        audioManager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isInCall" -> {
                val am = audioManager
                if (am == null) {
                    result.error("unavailable", "audio manager unavailable", null)
                } else {
                    result.success(isCallMode(am.mode))
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        lastInCall = null
        lastSilenced = false
        startObserving()
        evaluateMode()
    }

    override fun onCancel(arguments: Any?) {
        stopObserving()
        sink = null
    }

    private fun startObserving() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val listener = AudioManager.OnModeChangedListener { evaluateMode() }
            am.addOnModeChangedListener(mainExecutor, listener)
            modeListener = listener
        } else {
            polling = true
            mainHandler.postDelayed(poll, POLL_INTERVAL_MS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val callback = object : AudioManager.AudioRecordingCallback() {
                override fun onRecordingConfigChanged(configs: MutableList<AudioRecordingConfiguration>?) {
                    evaluateSilenced(configs)
                }
            }
            am.registerAudioRecordingCallback(callback, mainHandler)
            recordingCallback = callback
        }
    }

    private fun stopObserving() {
        val am = audioManager
        polling = false
        mainHandler.removeCallbacks(poll)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (modeListener as? AudioManager.OnModeChangedListener)?.let { am?.removeOnModeChangedListener(it) }
        }
        modeListener = null
        // AudioRecordingCallback exists since API 24 (minSdk is 26).
        recordingCallback?.let { am?.unregisterAudioRecordingCallback(it) }
        recordingCallback = null
    }

    private fun evaluateMode() {
        val am = audioManager ?: return
        val inCall = isCallMode(am.mode)
        if (inCall == lastInCall) return
        lastInCall = inCall
        emit(if (inCall) "callActive" else "callEnded")
    }

    private fun evaluateSilenced(configs: List<AudioRecordingConfiguration>?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        // Non-privileged apps only receive their own recording configurations.
        val silenced = configs.orEmpty().any { it.isClientSilenced }
        if (silenced == lastSilenced) return
        lastSilenced = silenced
        emit(if (silenced) "captureSilenced" else "captureUnsilenced")
    }

    private fun emit(signal: String) {
        val event = mapOf("signal" to signal, "atMs" to System.currentTimeMillis())
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sink?.success(event)
        } else {
            mainHandler.post { sink?.success(event) }
        }
    }

    companion object {
        const val METHOD_CHANNEL = "vaultvoice/call_guard"
        const val EVENT_CHANNEL = "vaultvoice/call_guard/events"
        private const val POLL_INTERVAL_MS = 500L

        /** Audio modes that mean a call is ringing or active (cellular or VoIP). */
        fun isCallMode(mode: Int): Boolean = when (mode) {
            AudioManager.MODE_RINGTONE,
            AudioManager.MODE_IN_CALL,
            AudioManager.MODE_IN_COMMUNICATION,
            AudioManager.MODE_CALL_SCREENING,
            AudioManager.MODE_CALL_REDIRECT,
            AudioManager.MODE_COMMUNICATION_REDIRECT -> true
            else -> false
        }
    }
}
