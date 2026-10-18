package com.vaultvoice.vaultvoice.quickcapture

/** Pigeon host API: Dart polls this at startup and on resume (never pushes). */
class QuickCaptureHostApiImpl : QuickCaptureHostApi {
    override fun consumeRequest(): QuickCaptureRequestMessage? {
        val request = QuickCaptureStore.consume() ?: return null
        return QuickCaptureRequestMessage(
            id = request.id,
            entry = request.entry.wire,
            mode = "navigate",
            remainingMs = request.remainingMs,
        )
    }
}
