package com.vaultvoice.vaultvoice.saf

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.util.Log
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Storage Access Framework host API (EXP-03): folder picking with persisted
 * URI permissions and DocumentsContract-based create/overwrite/mkdir.
 *
 * - `DocumentFile.findFile` is avoided (it lists the directory on every call);
 *   children are queried once per path segment via
 *   `DocumentsContract.buildChildDocumentsUriUsingTree`.
 * - Existing files are overwritten with mode `"wt"` (truncate) — `"w"` may
 *   leave stale trailing bytes on some providers.
 * - Every call re-checks `persistedUriPermissions`, so a revoked grant
 *   surfaces as error code `revoked` and a removed SD card as `unavailable`.
 * - Never requests MANAGE_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE.
 * - IO runs on a single background thread; replies are posted to the main
 *   thread. Error messages are content-free (no file names or paths).
 *
 * Written against the Android API 26–36 `DocumentsContract` reference and the
 * Pigeon 29.0.8 generated `SafHostApi` interface. Error codes must match
 * `VaultErrorCodes` in `lib/features/export/data/vault_platform_errors.dart`.
 */
class SafHostApiImpl(private val activity: Activity) : SafHostApi {
    companion object {
        const val REQUEST_CODE_PICK_TREE = 0x5AF1
        private const val TAG = "VVSaf"
        private const val MIME_MARKDOWN = "text/markdown"
        private const val MIME_BINARY = "application/octet-stream"
        private const val TMP_SUFFIX = ".vvtmp"
        private const val RW_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

        private fun err(code: String, message: String) = SafFlutterError(code, message, null)
    }

    private val resolver: ContentResolver = activity.applicationContext.contentResolver
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPick: ((Result<SafTree?>) -> Unit)? = null

    private data class Child(val docId: String, val name: String, val isDir: Boolean)

    fun dispose() {
        pendingPick?.invoke(Result.failure(err("unavailable", "engine detached")))
        pendingPick = null
        io.shutdown()
    }

    // ---------------------------------------------------------------- picker

    override fun pickTree(initialTreeUri: String?, callback: (Result<SafTree?>) -> Unit) {
        if (pendingPick != null) {
            callback(Result.failure(err("busy", "picker already open")))
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                RW_FLAGS or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
            initialTreeUri?.let { raw ->
                runCatching { rootDocUri(parseTree(raw)) }.getOrNull()?.let {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, it)
                }
            }
        }
        pendingPick = callback
        try {
            activity.startActivityForResult(intent, REQUEST_CODE_PICK_TREE)
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            callback(Result.failure(err("unavailable", "no document picker")))
        }
    }

    /** Called from `MainActivity.onActivityResult`; true when consumed. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_TREE) return false
        val callback = pendingPick ?: return true
        pendingPick = null
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (data == null || uri == null) {
            callback(Result.success(null))
            return true
        }
        if ((data.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION) == 0) {
            callback(Result.failure(err("revoked", "write permission not granted")))
            return true
        }
        try {
            resolver.takePersistableUriPermission(uri, RW_FLAGS)
        } catch (e: SecurityException) {
            callback(Result.failure(err("revoked", "persistable grant refused")))
            return true
        }
        io.execute {
            val name = runCatching { queryName(rootDocUri(uri)) }.getOrNull()
            main.post { callback(Result.success(SafTree(uri.toString(), name))) }
        }
        return true
    }

    // ---------------------------------------------------------------- access

    override fun checkAccess(treeUri: String, callback: (Result<SafAccessStatus>) -> Unit) =
        runIo(callback) { accessOf(parseTree(treeUri)) }

    override fun persistedTrees(): List<String> =
        resolver.persistedUriPermissions
            .filter { it.isReadPermission && it.isWritePermission }
            .map { it.uri }
            .filter { DocumentsContract.isTreeUri(it) }
            .map { it.toString() }

    override fun releaseTree(treeUri: String) {
        val tree = Uri.parse(treeUri)
        try {
            resolver.releasePersistableUriPermission(tree, RW_FLAGS)
        } catch (e: Exception) {
            // Already gone (SecurityException) or malformed: nothing to release.
        }
    }

    override fun appLocalVaultPath(): String {
        // PRODUCT-DECISION: the Android fallback vault is app-private
        // (filesDir/vault, not visible to other apps) until the user picks a
        // folder; notes can still be shared (EXP-08). Conservative for privacy.
        val dir = File(activity.applicationContext.filesDir, "vault")
        dir.mkdirs()
        return dir.absolutePath
    }

    private fun accessOf(tree: Uri): SafAccessStatus {
        if (!hasWriteGrant(tree)) return SafAccessStatus.REVOKED
        return try {
            resolver.query(
                rootDocUri(tree),
                arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_FLAGS),
                null, null, null,
            )?.use { c ->
                if (!c.moveToFirst()) {
                    SafAccessStatus.UNAVAILABLE
                } else if ((c.getInt(1) and Document.FLAG_DIR_SUPPORTS_CREATE) == 0) {
                    // Read-only folder: permanent, the user must pick another one.
                    SafAccessStatus.REVOKED
                } else {
                    SafAccessStatus.OK
                }
            } ?: SafAccessStatus.UNAVAILABLE
        } catch (e: SecurityException) {
            SafAccessStatus.REVOKED
        } catch (e: Exception) {
            // Volume removed (SD card) or provider gone.
            SafAccessStatus.UNAVAILABLE
        }
    }

    private fun hasWriteGrant(tree: Uri): Boolean =
        resolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission && it.isWritePermission
        }

    private fun requireWritable(tree: Uri) {
        when (accessOf(tree)) {
            SafAccessStatus.OK -> Unit
            SafAccessStatus.REVOKED -> throw err("revoked", "no persisted write grant")
            SafAccessStatus.UNAVAILABLE -> throw err("unavailable", "tree not reachable")
        }
    }

    // ------------------------------------------------------------ operations

    override fun exists(treeUri: String, relativePath: String, callback: (Result<Boolean>) -> Unit) =
        runIo(callback) {
            val tree = parseTree(treeUri)
            requireWritable(tree)
            resolve(tree, segments(relativePath)) != null
        }

    override fun writeFile(
        treeUri: String,
        relativePath: String,
        bytes: ByteArray,
        overwrite: Boolean,
        callback: (Result<String>) -> Unit,
    ) = runIo(callback) {
        val tree = parseTree(treeUri)
        requireWritable(tree)
        val segs = segments(relativePath)
        val name = segs.last()
        val parentId = ensureDirs(tree, segs.dropLast(1))
        val existing = findChild(tree, parentId, name)
        val written = when {
            existing == null -> createAndWrite(tree, parentId, name, bytes)
            existing.isDir -> throw err("invalid", "path is a folder")
            !overwrite -> throw err("exists", "file exists")
            else -> replace(tree, parentId, existing, bytes)
        }
        written.toString()
    }

    override fun readFile(treeUri: String, relativePath: String, callback: (Result<ByteArray?>) -> Unit) =
        runIo(callback) {
            val tree = parseTree(treeUri)
            requireWritable(tree)
            val child = resolve(tree, segments(relativePath))
            when {
                child == null -> null
                child.isDir -> throw err("invalid", "path is a folder")
                else -> {
                    val input = resolver.openInputStream(docUri(tree, child.docId))
                        ?: throw err("unavailable", "no input stream")
                    input.use { it.readBytes() }
                }
            }
        }

    override fun mkdirs(treeUri: String, relativePath: String, callback: (Result<Unit>) -> Unit) =
        runIo(callback) {
            val tree = parseTree(treeUri)
            requireWritable(tree)
            ensureDirs(tree, segments(relativePath))
            Unit
        }

    override fun delete(treeUri: String, relativePath: String, callback: (Result<Boolean>) -> Unit) =
        runIo(callback) {
            val tree = parseTree(treeUri)
            requireWritable(tree)
            val child = resolve(tree, segments(relativePath))
            when {
                child == null -> false
                child.isDir -> throw err("invalid", "path is a folder")
                else -> DocumentsContract.deleteDocument(resolver, docUri(tree, child.docId))
            }
        }

    override fun list(treeUri: String, relativePath: String, callback: (Result<List<SafEntry>>) -> Unit) =
        runIo(callback) {
            val tree = parseTree(treeUri)
            requireWritable(tree)
            val dirId = if (relativePath.isEmpty()) {
                DocumentsContract.getTreeDocumentId(tree)
            } else {
                val dir = resolve(tree, segments(relativePath)) ?: throw err("not_found", "no such folder")
                if (!dir.isDir) throw err("invalid", "path is a file")
                dir.docId
            }
            children(tree, dirId)
                .filterNot { it.name.endsWith(TMP_SUFFIX) }
                .map { SafEntry(it.name, it.isDir) }
        }

    // --------------------------------------------------------------- helpers

    private fun parseTree(raw: String): Uri {
        val uri = Uri.parse(raw)
        if (uri.scheme != ContentResolver.SCHEME_CONTENT || !DocumentsContract.isTreeUri(uri)) {
            throw err("invalid", "not a tree uri")
        }
        return uri
    }

    /** Defense in depth: the Dart side already validated with VaultPath. */
    private fun segments(relativePath: String): List<String> {
        val segs = relativePath.split('/')
        if (relativePath.isEmpty() || segs.any { it.isEmpty() || it == "." || it == ".." || it.contains('\u0000') }) {
            throw err("invalid", "bad relative path")
        }
        return segs
    }

    private fun rootDocUri(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun docUri(tree: Uri, docId: String): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, docId)

    private fun children(tree: Uri, parentId: String): List<Child> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val projection = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
        )
        val out = ArrayList<Child>()
        resolver.query(uri, projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0) ?: continue
                val name = c.getString(1) ?: continue
                out.add(Child(id, name, c.getString(2) == Document.MIME_TYPE_DIR))
            }
        } ?: throw err("unavailable", "provider returned no cursor")
        return out
    }

    private fun findChild(tree: Uri, parentId: String, name: String): Child? =
        children(tree, parentId).firstOrNull { it.name == name }

    /** Walks [segs] without creating anything; null when any part is missing. */
    private fun resolve(tree: Uri, segs: List<String>): Child? {
        var parentId = DocumentsContract.getTreeDocumentId(tree)
        var found: Child? = null
        for ((i, seg) in segs.withIndex()) {
            val child = findChild(tree, parentId, seg) ?: return null
            if (i < segs.size - 1 && !child.isDir) return null
            found = child
            parentId = child.docId
        }
        return found
    }

    /** Resolves/creates each folder in [segs]; returns the last folder's doc id. */
    private fun ensureDirs(tree: Uri, segs: List<String>): String {
        var parentId = DocumentsContract.getTreeDocumentId(tree)
        for (seg in segs) {
            val child = findChild(tree, parentId, seg)
            parentId = when {
                child == null -> {
                    val created = DocumentsContract.createDocument(
                        resolver, docUri(tree, parentId), Document.MIME_TYPE_DIR, seg,
                    ) ?: throw err("io", "mkdir failed")
                    DocumentsContract.getDocumentId(created)
                }
                child.isDir -> child.docId
                else -> throw err("invalid", "path component is a file")
            }
        }
        return parentId
    }

    private fun queryName(uri: Uri): String? =
        resolver.query(uri, arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }

    private fun querySize(uri: Uri): Long? =
        resolver.query(uri, arrayOf(Document.COLUMN_SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null
        }

    /**
     * `createDocument` never overwrites: a collision yields "name (1)", and
     * some providers append an extension for MIME types they do not map. The
     * returned display name is verified; a mismatch is renamed back, and as a
     * last resort the file is re-created as application/octet-stream (kept
     * verbatim by the providers we target).
     */
    private fun createNamed(tree: Uri, parentId: String, name: String, mime: String): Uri {
        val parent = docUri(tree, parentId)
        val created = DocumentsContract.createDocument(resolver, parent, mime, name)
            ?: throw err("io", "create failed")
        if (queryName(created) == name) return created
        val renamed = try {
            DocumentsContract.renameDocument(resolver, created, name)
        } catch (e: UnsupportedOperationException) {
            null
        } catch (e: IllegalStateException) {
            null
        }
        if (renamed != null && queryName(renamed) == name) return renamed
        deleteQuietly(renamed ?: created)
        if (mime != MIME_BINARY) return createNamed(tree, parentId, name, MIME_BINARY)
        throw err("io", "provider changed the file name")
    }

    private fun writeBytes(uri: Uri, bytes: ByteArray) {
        // "wt" = write + truncate: never leaves stale trailing bytes.
        val out = resolver.openOutputStream(uri, "wt") ?: throw err("io", "no output stream")
        out.use {
            it.write(bytes)
            it.flush()
        }
        val size = querySize(uri)
        if (size != null && size != bytes.size.toLong()) throw err("io", "size mismatch after write")
    }

    private fun createAndWrite(tree: Uri, parentId: String, name: String, bytes: ByteArray): Uri {
        val uri = createNamed(tree, parentId, name, if (name.endsWith(".md")) MIME_MARKDOWN else MIME_BINARY)
        writeBytes(uri, bytes)
        return uri
    }

    /**
     * Atomic-ish replace: write `.<name>.vvtmp`, delete the old file, rename
     * the temp file. Providers without rename support fall back to writing the
     * final name directly; providers that refuse the temp file get an
     * in-place `"wt"` overwrite (size-verified).
     */
    private fun replace(tree: Uri, parentId: String, existing: Child, bytes: ByteArray): Uri {
        val existingUri = docUri(tree, existing.docId)
        val tmpName = ".${existing.name}$TMP_SUFFIX"
        findChild(tree, parentId, tmpName)?.let { deleteQuietly(docUri(tree, it.docId)) }
        val tmp = try {
            createNamed(tree, parentId, tmpName, MIME_BINARY)
        } catch (e: SecurityException) {
            throw e
        } catch (e: Exception) {
            // Provider refuses dot/temp files: overwrite in place below.
            null
        }
        if (tmp == null) {
            writeBytes(existingUri, bytes)
            return existingUri
        }
        try {
            writeBytes(tmp, bytes)
        } catch (e: Exception) {
            deleteQuietly(tmp)
            throw e
        }
        if (!DocumentsContract.deleteDocument(resolver, existingUri)) {
            deleteQuietly(tmp)
            throw err("io", "could not replace file")
        }
        val renamed = try {
            DocumentsContract.renameDocument(resolver, tmp, existing.name)
        } catch (e: UnsupportedOperationException) {
            null
        } catch (e: IllegalStateException) {
            null
        }
        if (renamed != null && queryName(renamed) == existing.name) return renamed
        // Rename unsupported (or renamed to something else): the bytes are in
        // memory, so write the final name directly and drop the temp file.
        val target = createAndWrite(tree, parentId, existing.name, bytes)
        deleteQuietly(renamed ?: tmp)
        return target
    }

    private fun deleteQuietly(uri: Uri) {
        try {
            DocumentsContract.deleteDocument(resolver, uri)
        } catch (e: Exception) {
            Log.w(TAG, "temp cleanup failed: ${e.javaClass.simpleName}")
        }
    }

    /** Runs [block] on the IO thread and replies on the main thread. */
    private fun <T> runIo(callback: (Result<T>) -> Unit, block: () -> T) {
        try {
            io.execute {
                val result: Result<T> = try {
                    Result.success(block())
                } catch (e: SafFlutterError) {
                    Result.failure(e)
                } catch (e: SecurityException) {
                    Result.failure(err("revoked", "permission denied"))
                } catch (e: FileNotFoundException) {
                    Result.failure(err("unavailable", "document not reachable"))
                } catch (e: IllegalArgumentException) {
                    // Providers throw this for unknown/removed document ids.
                    Result.failure(err("unavailable", "document not reachable"))
                } catch (e: Exception) {
                    // Class name only: messages may contain file names.
                    Log.w(TAG, "saf io failed: ${e.javaClass.simpleName}")
                    Result.failure(err("io", e.javaClass.simpleName))
                }
                main.post { callback(result) }
            }
        } catch (e: java.util.concurrent.RejectedExecutionException) {
            callback(Result.failure(err("unavailable", "engine detached")))
        }
    }
}
