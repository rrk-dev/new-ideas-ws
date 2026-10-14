package com.vaultvoice.vaultvoice.modeldownload

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * MDL-02: foreground service of type `dataSync` that keeps the process (and
 * the Dart download) alive while the app is backgrounded or the screen is
 * off. Started only from a user action in the foreground (tap "Download" or
 * resume-on-launch) — never from the background (Android 12+ restriction).
 *
 * Android 15+ (targetSdk 35): `dataSync` has a 6 h / 24 h budget;
 * [onTimeout] stops the service within the grace period and the Dart side
 * resumes the download (HTTP Range) next time the app is opened.
 * Verified against the Android API reference for compileSdk 36.
 *
 * The notification shows only the public catalog model name + progress.
 */
class ModelDownloadService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val notification = buildNotification(this, title, 0, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        currentTitle = title
        // Not sticky: after a kill the app resumes the download on launch.
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15+: the dataSync budget is used up. Stop now; the partial
        // file stays and the download resumes from its length later.
        stopSelfNow()
    }

    private fun stopSelfNow() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        private const val CHANNEL_ID = "model_downloads"
        private const val NOTIFICATION_ID = 0x4d444c // "MDL"
        private const val EXTRA_TITLE = "title"
        @Volatile private var currentTitle = ""

        fun start(ctx: Context, title: String) {
            ensureChannel(ctx)
            val intent = Intent(ctx, ModelDownloadService::class.java).putExtra(EXTRA_TITLE, title)
            ctx.startForegroundService(intent)
        }

        fun update(ctx: Context, received: Long, total: Long) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val permille = if (total > 0) ((received * 1000) / total).toInt() else 0
            nm.notify(NOTIFICATION_ID, buildNotification(ctx, currentTitle, permille, 1000))
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, ModelDownloadService::class.java))
        }

        private fun ensureChannel(ctx: Context) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Model downloads", NotificationManager.IMPORTANCE_LOW),
                )
            }
        }

        private fun buildNotification(ctx: Context, title: String, progress: Int, max: Int): Notification =
            Notification.Builder(ctx, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setContentTitle("Downloading model")
                .setContentText(title)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(max, progress, max == 0)
                .build()
    }
}
