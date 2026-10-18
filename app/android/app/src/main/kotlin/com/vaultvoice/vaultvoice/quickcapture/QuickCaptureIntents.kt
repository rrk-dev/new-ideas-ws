package com.vaultvoice.vaultvoice.quickcapture

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.vaultvoice.vaultvoice.MainActivity

/**
 * Explicit intents into [MainActivity] used by the widget, tile and shortcut.
 * They carry one static extra (which surface was tapped) and open the app;
 * the app then shows the Record screen. They never start a recording.
 */
object QuickCaptureIntents {
    const val ACTION = "com.vaultvoice.vaultvoice.action.QUICK_CAPTURE"
    const val EXTRA_ENTRY = "quick_capture_entry"

    fun intent(context: Context, entry: QuickCaptureStore.Entry): Intent =
        Intent(context, MainActivity::class.java)
            .setAction(ACTION)
            .putExtra(EXTRA_ENTRY, entry.wire)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    // The request code differs per entry: PendingIntent identity ignores extras.
    fun pendingIntent(context: Context, entry: QuickCaptureStore.Entry): PendingIntent =
        PendingIntent.getActivity(
            context,
            entry.ordinal + 1,
            intent(context, entry),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    /**
     * Records the tap carried by [intent] (if any) and strips it, so the same
     * Intent cannot be consumed twice. Ignores intents restored from the
     * recents list. Returns true when a request was stored.
     */
    fun submitFrom(intent: Intent?): Boolean {
        if (intent == null || intent.action != ACTION) return false
        val entry = QuickCaptureStore.Entry.fromWire(intent.getStringExtra(EXTRA_ENTRY))
        intent.removeExtra(EXTRA_ENTRY)
        intent.action = null
        if (entry == null) return false
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return false
        QuickCaptureStore.submit(entry)
        return true
    }
}
