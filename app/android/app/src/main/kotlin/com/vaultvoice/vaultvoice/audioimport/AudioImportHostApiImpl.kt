package com.vaultvoice.vaultvoice.audioimport

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * AUD-06 audio import: platform decoders only (no ffmpeg) and files handed
 * over by the share sheet.
 *
 * - `decodeToPcm`: `MediaExtractor` (first `audio/` track) + `MediaCodec`
 *   decoder → raw interleaved PCM16 LE at the codec's output rate/channels.
 *   Dart resamples / down-mixes to the 16 kHz mono contract (`PcmConverter`).
 *   MediaCodec decodes AAC/m4a, mp3, wav, flac, ogg/vorbis and opus on
 *   API 26+ (developer.android.com/guide/topics/media/platform/supported-formats).
 *   Float PCM output (`KEY_PCM_ENCODING`, API 24+) is converted to 16-bit.
 * - Shares: `ACTION_SEND` / `ACTION_SEND_MULTIPLE` / `ACTION_VIEW` with
 *   `audio/` content are copied **immediately** into `cacheDir/shared_audio`
 *   (URI grants are temporary), then Dart is told via `sharesAvailable`.
 *   Nothing is processed before the user's rights/consent attestation in Dart.
 * - Never logs file names, paths or URIs (content-free logging).
 */
class AudioImportHostApiImpl(private val context: Context) : AudioImportHostApi {
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<SharedAudioFile>()

    /** Set once the Dart side is attached. */
    var flutterApi: AudioImportFlutterApi? = null

    override fun decodeToPcm(
        srcPath: String,
        dstPath: String,
        callback: (Result<DecodedAudio>) -> Unit,
    ) {
        io.execute {
            val result = try {
                Result.success(decode(srcPath, dstPath))
            } catch (e: AudioImportFlutterError) {
                Result.failure(e)
            } catch (e: Exception) {
                Log.w(TAG, "decode failed: ${e.javaClass.simpleName}")
                Result.failure(AudioImportFlutterError("failed", e.javaClass.simpleName, null))
            }
            main.post { callback(result) }
        }
    }

    override fun takePendingShares(): List<SharedAudioFile> = synchronized(pending) {
        val out = pending.toList()
        pending.clear()
        out
    }

    /** Copies the audio of a share/view intent; returns true if it had any. */
    fun handleIntent(intent: Intent?): Boolean {
        val uris = sharedAudioUris(intent ?: return false)
        if (uris.isEmpty()) return false
        io.execute {
            var added = 0
            for (uri in uris) {
                val copy = copyIn(uri) ?: continue
                synchronized(pending) { pending.add(copy) }
                added++
            }
            if (added > 0) main.post { flutterApi?.sharesAvailable { } }
        }
        return true
    }

    fun dispose() {
        io.shutdown()
    }

    // --- shares ---------------------------------------------------------------

    private fun sharedAudioUris(intent: Intent): List<Uri> {
        val type = intent.type
        val isAudio = type == null || type.startsWith("audio/") || type == "application/ogg"
        if (!isAudio) return emptyList()
        return when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(streamExtra(intent))
            Intent.ACTION_SEND_MULTIPLE -> streamListExtra(intent)
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            else -> emptyList()
        }.filter { it.scheme == "content" || it.scheme == "file" }
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
        }

    private fun copyIn(uri: Uri): SharedAudioFile? {
        val resolver = context.contentResolver
        val ext = extensionOf(uri)
        val dir = File(context.cacheDir, "shared_audio").apply { mkdirs() }
        val dst = File(dir, UUID.randomUUID().toString() + (ext?.let { ".$it" } ?: ""))
        return try {
            val input = resolver.openInputStream(uri) ?: return null
            input.use { inp -> FileOutputStream(dst).use { inp.copyTo(it, 1 shl 16) } }
            SharedAudioFile(dst.path, ext, lastModifiedOf(uri))
        } catch (e: Exception) {
            Log.w(TAG, "share copy failed: ${e.javaClass.simpleName}")
            dst.delete()
            null
        }
    }

    private fun extensionOf(uri: Uri): String? {
        val resolver = context.contentResolver
        val queried: String? = try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
        val fromName = queried ?: uri.lastPathSegment
        val nameExt = fromName?.substringAfterLast('.', "")?.lowercase(Locale.ROOT)
        if (!nameExt.isNullOrEmpty() && nameExt.length <= 5) return nameExt
        val mime = resolver.getType(uri) ?: return null
        return MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
    }

    private fun lastModifiedOf(uri: Uri): Long? = try {
        context.contentResolver.query(
            uri,
            arrayOf(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getLong(0).takeIf { it > 0 } else null }
    } catch (e: Exception) {
        null
    }

    // --- decoding -------------------------------------------------------------

    private fun decode(srcPath: String, dstPath: String): DecodedAudio {
        val extractor = MediaExtractor()
        try {
            try {
                extractor.setDataSource(srcPath)
            } catch (e: IOException) {
                throw AudioImportFlutterError("unsupported", "container", null)
            }
            var track = -1
            for (i in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
                if (mime != null && mime.startsWith("audio/")) {
                    track = i
                    break
                }
            }
            if (track < 0) throw AudioImportFlutterError("no_audio", "no audio track", null)
            extractor.selectTrack(track)
            val inFormat = extractor.getTrackFormat(track)
            val mime = inFormat.getString(MediaFormat.KEY_MIME)!!
            val codec = try {
                MediaCodec.createDecoderByType(mime)
            } catch (e: Exception) {
                throw AudioImportFlutterError("unsupported", "codec", null)
            }
            try {
                codec.configure(inFormat, null, null, 0)
                codec.start()
                return drain(extractor, codec, inFormat, File(dstPath), creationDateOf(srcPath))
            } finally {
                try { codec.stop() } catch (e: Exception) { }
                codec.release()
            }
        } finally {
            extractor.release()
        }
    }

    private fun drain(
        extractor: MediaExtractor,
        codec: MediaCodec,
        inFormat: MediaFormat,
        dst: File,
        creationDateMs: Long?,
    ): DecodedAudio {
        var sampleRate = inFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = inFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var float = false
        var bytes = 0L
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        BufferedOutputStream(FileOutputStream(dst), 1 shl 16).use { out ->
            while (!outputDone) {
                if (!inputDone) {
                    val idx = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (idx >= 0) {
                        val buf = codec.getInputBuffer(idx)!!
                        val n = extractor.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(idx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(idx, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    o >= 0 -> {
                        if (info.size > 0) {
                            val buf = codec.getOutputBuffer(o)!!
                            buf.position(info.offset)
                            buf.limit(info.offset + info.size)
                            bytes += write(out, buf, float)
                        }
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                    o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val f = codec.outputFormat
                        val rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        val ch = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        if (bytes > 0 && (rate != sampleRate || ch != channels)) {
                            throw AudioImportFlutterError("failed", "format changed mid-stream", null)
                        }
                        sampleRate = rate
                        channels = ch
                        float = Build.VERSION.SDK_INT >= 24 &&
                            f.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            f.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                    }
                }
            }
        }
        val frames = bytes / (2L * channels)
        return DecodedAudio(sampleRate.toLong(), channels.toLong(), frames, creationDateMs)
    }

    /** Writes [buf] as PCM16 LE; returns the bytes written. */
    private fun write(out: BufferedOutputStream, buf: ByteBuffer, float: Boolean): Long {
        if (!float) {
            val arr = ByteArray(buf.remaining())
            buf.get(arr)
            out.write(arr)
            return arr.size.toLong()
        }
        val floats = buf.order(ByteOrder.nativeOrder()).asFloatBuffer()
        val arr = ByteArray(floats.remaining() * 2)
        var i = 0
        while (floats.hasRemaining()) {
            val v = (floats.get().coerceIn(-1f, 1f) * 32767f).toInt()
            arr[i++] = (v and 0xff).toByte()
            arr[i++] = ((v shr 8) and 0xff).toByte()
        }
        out.write(arr)
        return arr.size.toLong()
    }

    /** Recording date from the container metadata (`METADATA_KEY_DATE`). */
    private fun creationDateOf(path: String): Long? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val raw = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE) ?: return null
            parseMetadataDate(raw)
        } catch (e: Exception) {
            null
        } finally {
            try { r.release() } catch (e: Exception) { }
        }
    }

    companion object {
        private const val TAG = "VVAudioImport"
        private const val TIMEOUT_US = 10_000L

        /** `20230615T143000.000Z` (and the variant without millis). */
        fun parseMetadataDate(raw: String): Long? {
            for (pattern in listOf("yyyyMMdd'T'HHmmss.SSS'Z'", "yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd'T'HHmmss")) {
                try {
                    val f = SimpleDateFormat(pattern, Locale.US)
                    f.timeZone = TimeZone.getTimeZone("UTC")
                    f.isLenient = false
                    val d = f.parse(raw) ?: continue
                    // MediaMetadataRetriever reports 1904-01-01 for "unset" (MP4 epoch).
                    if (d.time > 0) return d.time
                } catch (e: Exception) {
                    // try the next pattern
                }
            }
            return null
        }
    }
}
