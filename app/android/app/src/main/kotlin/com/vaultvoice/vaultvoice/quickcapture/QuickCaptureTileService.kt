package com.vaultvoice.vaultvoice.quickcapture

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Quick Settings tile: always inactive, never toggles. A tap opens the app on
 * the Record screen. API 34+ must use the PendingIntent overload (the Intent
 * overload throws UnsupportedOperationException there).
 */
class QuickCaptureTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let {
            it.state = Tile.STATE_INACTIVE
            it.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val entry = QuickCaptureStore.Entry.ANDROID_TILE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(QuickCaptureIntents.pendingIntent(this, entry))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(QuickCaptureIntents.intent(this, entry))
        }
    }
}
