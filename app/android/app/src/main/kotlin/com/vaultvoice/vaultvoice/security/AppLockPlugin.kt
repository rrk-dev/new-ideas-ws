package com.vaultvoice.vaultvoice.security

import android.annotation.TargetApi
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * SEC-03 (ADR-SEC-03-app-lock): device authentication + privacy screen
 * without `local_auth` (which requires a FragmentActivity; ours is a
 * FlutterActivity with the AUD-05 retained engine).
 *
 * Channel `vaultvoice/device_auth`: `authenticate({reason})` ->
 * `"success" | "failed" | "unavailable"`.
 * - API 30+: platform `BiometricPrompt` with
 *   `BIOMETRIC_WEAK or DEVICE_CREDENTIAL` (fingerprint/face or PIN/pattern).
 * - API 28-29: `BiometricPrompt` + `setDeviceCredentialAllowed(true)`.
 * - API 26-27: `KeyguardManager.createConfirmDeviceCredentialIntent`.
 * `"unavailable"` = no secure lock screen (`KeyguardManager.isDeviceSecure`).
 *
 * Channel `vaultvoice/privacy_screen`: `setEnabled({enabled})` toggles
 * `FLAG_SECURE`: blank recents thumbnail, no screenshots while the lock is on.
 */
class AppLockPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private var authChannel: MethodChannel? = null
    private var privacyChannel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var cancel: CancellationSignal? = null

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        authChannel = MethodChannel(b.binaryMessenger, AUTH_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        privacyChannel = MethodChannel(b.binaryMessenger, PRIVACY_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        authChannel?.setMethodCallHandler(null)
        privacyChannel?.setMethodCallHandler(null)
        authChannel = null
        privacyChannel = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b
        b.addActivityResultListener(this)
        applySecureFlag()
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) =
        onAttachedToActivity(b)

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        cancel?.cancel()
        cancel = null
        finish("failed")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setEnabled" -> {
                secure = call.argument<Boolean>("enabled") == true
                applySecureFlag()
                result.success(null)
            }
            "authenticate" -> authenticate(call.argument<String>("reason") ?: "", result)
            else -> result.notImplemented()
        }
    }

    private fun applySecureFlag() {
        val window = binding?.activity?.window ?: return
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun authenticate(reason: String, result: MethodChannel.Result) {
        val activity = binding?.activity
            ?: return result.error("no_activity", "no activity", null)
        if (pending != null) return result.error("in_progress", "already authenticating", null)
        val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguard.isDeviceSecure) return result.success("unavailable")
        pending = result
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> prompt(activity, reason)
            else -> confirmCredential(activity, keyguard, reason)
        }
    }

    @TargetApi(Build.VERSION_CODES.Q)
    private fun prompt(activity: Activity, reason: String) {
        val builder = BiometricPrompt.Builder(activity).setTitle(reason)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL,
            )
        } else {
            // API 29 only: setDeviceCredentialAllowed does not exist on API 28.
            @Suppress("DEPRECATION")
            builder.setDeviceCredentialAllowed(true)
        }
        val signal = CancellationSignal().also { cancel = it }
        builder.build().authenticate(
            signal,
            activity.mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult?) {
                    finish("success")
                }

                override fun onAuthenticationError(code: Int, message: CharSequence?) {
                    finish(
                        if (code == BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT ||
                            code == BiometricPrompt.BIOMETRIC_ERROR_NO_DEVICE_CREDENTIAL
                        ) {
                            "unavailable"
                        } else {
                            "failed"
                        },
                    )
                }
                // onAuthenticationFailed: one bad attempt; the prompt stays open.
            },
        )
    }

    @Suppress("DEPRECATION")
    private fun confirmCredential(activity: Activity, keyguard: KeyguardManager, reason: String) {
        val intent: Intent? = keyguard.createConfirmDeviceCredentialIntent(reason, null)
        if (intent == null) {
            finish("unavailable")
            return
        }
        activity.startActivityForResult(intent, REQUEST_CONFIRM)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CONFIRM) return false
        finish(if (resultCode == Activity.RESULT_OK) "success" else "failed")
        return true
    }

    private fun finish(outcome: String) {
        cancel = null
        val r = pending ?: return
        pending = null
        r.success(outcome)
    }

    companion object {
        const val AUTH_CHANNEL = "vaultvoice/device_auth"
        const val PRIVACY_CHANNEL = "vaultvoice/privacy_screen"
        private const val REQUEST_CONFIRM = 0x5EC3

        // Process-wide so a re-created activity (or the retained engine's next
        // activity, AUD-05) gets the flag before Dart re-sends it.
        @Volatile
        private var secure = false
    }
}
