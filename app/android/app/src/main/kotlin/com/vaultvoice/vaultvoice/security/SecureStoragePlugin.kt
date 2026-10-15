package com.vaultvoice.vaultvoice.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

/**
 * SEC-01 (ADR-SEC-01-file-encryption): data keys for encryption at rest.
 *
 * A random 32-byte data key (e.g. the sqlite3mc database key) is wrapped with
 * AES-256-GCM by a non-exportable AndroidKeyStore key ("vv_master") and the
 * wrapped blob (`iv(12) || ciphertext+tag`) is stored in
 * `noBackupFilesDir/vv_keys/<name>.key` (never backed up; backups are also
 * disabled in the manifest). StrongBox is used when the device has it;
 * `setUserAuthenticationRequired(false)` so background recording/processing
 * can open the database while the device is locked. Jetpack Security
 * (EncryptedFile/EncryptedSharedPreferences) is deprecated, hence plain
 * Keystore + javax.crypto (API 23+ APIs; minSdk 26).
 *
 * `filesDir` (where `vv/` lives) is credential-encrypted storage under
 * file-based encryption, the default on every API 29+ device.
 *
 * Channel `vaultvoice/secure_storage`:
 * - `getOrCreateKey({name})` -> `{key: ByteArray(32), hardwareBacked: Boolean}`
 * - `deleteKey({name})`, `deleteAllKeys()`
 * - `protectDirectory({path})` -> `{protectionClass, excludedFromBackup}`
 *
 * Keystore operations can block (StrongBox is slow): they run on a single
 * background thread, results are posted back to the platform thread.
 */
class SecureStoragePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private val worker = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("unavailable", "detached", null)
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        when (call.method) {
            "getOrCreateKey", "deleteKey" -> {
                val name = call.argument<String>("name")
                if (name == null || !NAME.matches(name)) {
                    return result.error("invalid_name", "invalid key name", null)
                }
                worker.execute {
                    try {
                        val reply: Any? = if (call.method == "getOrCreateKey") {
                            getOrCreate(ctx, name)
                        } else {
                            keyFile(ctx, name).delete()
                            null
                        }
                        main.post { result.success(reply) }
                    } catch (e: Exception) {
                        // Never include key material or paths in the error.
                        main.post { result.error("keystore", e.javaClass.simpleName, null) }
                    }
                }
            }
            "deleteAllKeys" -> worker.execute {
                try {
                    keysDir(ctx).deleteRecursively()
                    keyStore().deleteEntry(MASTER_ALIAS)
                    main.post { result.success(null) }
                } catch (e: Exception) {
                    main.post { result.error("keystore", e.javaClass.simpleName, null) }
                }
            }
            "protectDirectory" -> {
                val path = call.argument<String>("path")
                    ?: return result.error("invalid_path", "missing path", null)
                File(path).mkdirs()
                result.success(
                    mapOf(
                        "protectionClass" to "credentialEncrypted",
                        // allowBackup=false + dataExtractionRules/fullBackupContent
                        // exclude every domain (AndroidManifest.xml).
                        "excludedFromBackup" to true,
                    ),
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun getOrCreate(ctx: Context, name: String): Map<String, Any> {
        val master = masterKey(ctx)
        val file = keyFile(ctx, name)
        val key = if (file.exists()) {
            unwrap(master, file.readBytes())
        } else {
            val fresh = ByteArray(KEY_BYTES).also { SecureRandom().nextBytes(it) }
            val dir = keysDir(ctx).apply { mkdirs() }
            val tmp = File(dir, "$name.tmp")
            tmp.writeBytes(wrap(master, fresh))
            if (!tmp.renameTo(file)) throw IllegalStateException("rename failed")
            fresh
        }
        return mapOf("key" to key, "hardwareBacked" to isHardwareBacked(master))
    }

    private fun wrap(master: SecretKey, plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, master)
        return cipher.iv + cipher.doFinal(plain)
    }

    private fun unwrap(master: SecretKey, blob: ByteArray): ByteArray {
        if (blob.size <= IV_BYTES) throw IllegalStateException("short blob")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            master,
            GCMParameterSpec(TAG_BITS, blob, 0, IV_BYTES),
        )
        val key = cipher.doFinal(blob, IV_BYTES, blob.size - IV_BYTES)
        if (key.size != KEY_BYTES) throw IllegalStateException("bad key size")
        return key
    }

    private fun masterKey(ctx: Context): SecretKey {
        val ks = keyStore()
        (ks.getKey(MASTER_ALIAS, null) as? SecretKey)?.let { return it }
        val strongBox = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        return try {
            generateMaster(strongBox)
        } catch (e: Exception) {
            if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                e is StrongBoxUnavailableException
            ) {
                generateMaster(false)
            } else {
                throw e
            }
        }
    }

    private fun generateMaster(strongBox: Boolean): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            MASTER_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(false)
            .apply {
                if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    setIsStrongBoxBacked(true)
                }
            }
            .build()
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(spec)
        return generator.generateKey()
    }

    private fun isHardwareBacked(key: SecretKey): Boolean = try {
        val factory = SecretKeyFactory.getInstance(key.algorithm, KEYSTORE)
        val info = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            info.securityLevel != KeyProperties.SECURITY_LEVEL_SOFTWARE
        } else {
            @Suppress("DEPRECATION")
            info.isInsideSecureHardware
        }
    } catch (e: Exception) {
        false
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun keysDir(ctx: Context) = File(ctx.noBackupFilesDir, "vv_keys")

    private fun keyFile(ctx: Context, name: String) = File(keysDir(ctx), "$name.key")

    companion object {
        const val CHANNEL = "vaultvoice/secure_storage"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val MASTER_ALIAS = "vv_master"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val KEY_BYTES = 32
        private const val IV_BYTES = 12
        private const val TAG_BITS = 128
        private val NAME = Regex("^[A-Za-z0-9._-]{1,64}$")
    }
}
