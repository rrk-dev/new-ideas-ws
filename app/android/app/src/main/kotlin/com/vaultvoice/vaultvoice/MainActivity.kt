package com.vaultvoice.vaultvoice

import com.vaultvoice.vaultvoice.billing.PurchasePlugin
import android.content.Context
import android.content.Intent
import com.vaultvoice.vaultvoice.audioimport.AudioImportFlutterApi
import com.vaultvoice.vaultvoice.audioimport.AudioImportHostApi
import com.vaultvoice.vaultvoice.audioimport.AudioImportHostApiImpl
import com.vaultvoice.vaultvoice.modeldownload.ModelDownloadPlugin
import com.vaultvoice.vaultvoice.saf.SafHostApi
import com.vaultvoice.vaultvoice.saf.SafHostApiImpl
import com.vaultvoice.vaultvoice.security.AppLockPlugin
import com.vaultvoice.vaultvoice.security.SecureStoragePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // Storage Access Framework vault folders (EXP-03).
    private var safApi: SafHostApiImpl? = null

    // AUD-06: audio import (platform decoders + share-sheet intents).
    private var importApi: AudioImportHostApiImpl? = null
    private var launchIntentHandled = false

    // AUD-05: while the recording foreground service runs, the Flutter engine
    // (and with it the Dart capture code) must outlive this activity — e.g.
    // when the user swipes the app away. The retained engine is handed to the
    // next activity instead of starting a second one.
    override fun provideFlutterEngine(context: Context): FlutterEngine? = RetainedEngine.engine

    override fun shouldDestroyEngineWithHost(): Boolean {
        // FND-08: likewise while the processing service runs the pipeline.
        if (RecordingService.isRunning || ProcessingService.isRunning) {
            RetainedEngine.engine = flutterEngine
            return false
        }
        RetainedEngine.engine = null
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(PurchasePlugin::class.java)) flutterEngine.plugins.add(PurchasePlugin())
        // SEC-09: call detection without phone-state permissions.
        flutterEngine.plugins.add(CallGuardPlugin())
        // MDL-02: device facts + dataSync keep-alive for model downloads.
        flutterEngine.plugins.add(ModelDownloadPlugin())
        // AUD-01: free-space checks for the recording storage policy.
        flutterEngine.plugins.add(StorageInfoPlugin())
        // FND-08: processing foreground service, power/thermal conditions.
        if (!flutterEngine.plugins.has(ProcessingPlugin::class.java)) {
            flutterEngine.plugins.add(ProcessingPlugin())
        }
        // APP-01: "Open settings" recovery after a denied permission.
        flutterEngine.plugins.add(AppSettingsPlugin())
        // SEC-01: Keystore-wrapped data keys (sqlite3mc database key).
        flutterEngine.plugins.add(SecureStoragePlugin())
        // SEC-03: device authentication + FLAG_SECURE privacy screen.
        flutterEngine.plugins.add(AppLockPlugin())
        // AUD-05: microphone foreground service + ongoing notification.
        if (!flutterEngine.plugins.has(RecordingIndicatorPlugin::class.java)) {
            flutterEngine.plugins.add(RecordingIndicatorPlugin())
        }
        val api = SafHostApiImpl(this)
        safApi = api
        SafHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, api)
        val imports = AudioImportHostApiImpl(applicationContext)
        imports.flutterApi = AudioImportFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        importApi = imports
        AudioImportHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, imports)
        if (!launchIntentHandled) {
            launchIntentHandled = true
            imports.handleIntent(intent)
        }
    }

    // AUD-06: a file shared while the app is already open (singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        importApi?.handleIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SafHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        AudioImportHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        importApi?.dispose()
        importApi = null
        safApi?.dispose()
        safApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (safApi?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
