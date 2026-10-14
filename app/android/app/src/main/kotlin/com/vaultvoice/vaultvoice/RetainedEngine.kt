package com.vaultvoice.vaultvoice

import io.flutter.embedding.engine.FlutterEngine

/**
 * AUD-05: the Flutter engine kept alive while [RecordingService] runs and the
 * activity is gone (see [MainActivity.shouldDestroyEngineWithHost]). Cleared
 * when an activity that owns it is destroyed without a running recording.
 */
object RetainedEngine {
    @Volatile
    var engine: FlutterEngine? = null
}
