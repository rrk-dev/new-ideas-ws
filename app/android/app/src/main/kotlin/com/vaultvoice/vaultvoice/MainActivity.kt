package com.vaultvoice.vaultvoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // SEC-09: call detection without phone-state permissions.
        flutterEngine.plugins.add(CallGuardPlugin())
    }
}
