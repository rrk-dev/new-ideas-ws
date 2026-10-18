package com.vaultvoice.vaultvoice.quickcapture

import android.os.SystemClock

/**
 * QCP-03 quick-capture hand-off store (ADR-QCP-01 → "Single-use hand-off request").
 *
 * One in-memory request, never persisted. A widget, tile or shortcut tap
 * only asks the app to open the Record screen; nothing here can start a
 * recording. Static fields only: no recording-derived data.
 */
object QuickCaptureStore {
    /** A request lives this long after the activity received the tap. */
    const val TTL_MS = 10_000L

    /** Routing/labelling only; not a Dart `StartSource`. */
    enum class Entry(val wire: String) {
        ANDROID_WIDGET("androidWidget"),
        ANDROID_TILE("androidTile"),
        ANDROID_SHORTCUT("androidShortcut");

        companion object {
            fun fromWire(value: String?): Entry? = entries.firstOrNull { it.wire == value }
        }
    }

    class Request(val id: String, val entry: Entry, val remainingMs: Long)

    private class Pending(val id: String, val entry: Entry, val expiresAt: Long)

    // Device-wide monotonic clock (ADR: SystemClock.elapsedRealtime); injectable for tests.
    @Volatile
    var uptimeMs: () -> Long = { SystemClock.elapsedRealtime() }

    private var pending: Pending? = null

    /** Replaces any earlier request: only the latest tap counts. */
    @Synchronized
    fun submit(entry: Entry) {
        pending = Pending(
            id = java.util.UUID.randomUUID().toString(),
            entry = entry,
            expiresAt = uptimeMs() + TTL_MS,
        )
    }

    /** Returns the request and deletes it atomically; null if none or expired. */
    @Synchronized
    fun consume(): Request? {
        val p = pending ?: return null
        pending = null
        val remaining = p.expiresAt - uptimeMs()
        if (remaining <= 0) return null
        return Request(p.id, p.entry, remaining)
    }

    @Synchronized
    fun clear() {
        pending = null
    }
}
