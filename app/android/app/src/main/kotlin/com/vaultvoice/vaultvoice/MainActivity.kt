package com.vaultvoice.vaultvoice

import android.content.Context
import android.content.Intent
import com.vaultvoice.vaultvoice.modeldownload.ModelDownloadPlugin
import com.vaultvoice.vaultvoice.saf.SafHostApi
import com.vaultvoice.vaultvoice.saf.SafHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // Storage Access Framework vault folders (EXP-03).
    private var safApi: SafHostApiImpl? = null

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
        // AUD-05: microphone foreground service + ongoing notification.
        if (!flutterEngine.plugins.has(RecordingIndicatorPlugin::class.java)) {
            flutterEngine.plugins.add(RecordingIndicatorPlugin())
        }
        val api = SafHostApiImpl(this)
        safApi = api
        SafHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, api)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SafHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        safApi?.dispose()
        safApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (safApi?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
