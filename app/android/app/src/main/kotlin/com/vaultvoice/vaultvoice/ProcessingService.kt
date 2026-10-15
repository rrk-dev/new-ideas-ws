package com.vaultvoice.vaultvoice

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
 * FND-08: foreground service that keeps the pipeline worker (Dart isolate in
 * this process) running while the app is backgrounded or the screen is off.
 *
 * Type: `dataSync` up to API 34, `mediaProcessing` on API 35+ (the type meant
 * for media transcoding / processing). Both have a 6 h per 24 h budget when
 * targeting API 35+; [onTimeout] tells Dart to checkpoint (pause the job) and
 * stops within the grace period. Started only while the app is visible
 * (Android 12+ background-start restriction) — `start` reports refusal.
 * Verified against the Android API reference (ServiceInfo, Service#onTimeout)
 * for compileSdk 36.
 *
 * The notification is generic (passed from Dart's l10n) + a percentage —
 * never recording titles or transcript content.
 */
class ProcessingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification(this, -1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            // The typed overload needs API 29; minSdk is 26.
            startForeground(NOTIFICATION_ID, notification)
        }
        // Not sticky: after a kill the pipeline resumes from its checkpoint
        // on the next launch (FND-05 recovery).
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Budget used up: Dart pauses the running job (checkpoint) and the
        // service stops now (must happen within seconds).
        onTimeoutListener?.invoke()
        stopNow()
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun stopNow() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        private const val CHANNEL_ID = "processing"
        private const val NOTIFICATION_ID = 0x50524f43 // "PROC"

        @Volatile var isRunning = false
            private set

        @Volatile private var title = ""
        @Volatile private var text = ""

        /** Called on [onTimeout] (main thread). */
        @Volatile var onTimeoutListener: (() -> Unit)? = null

        /** Throws when the OS refuses the start (app not visible). */
        fun start(ctx: Context, title: String, text: String) {
            this.title = title
            this.text = text
            ensureChannel(ctx, title)
            if (isRunning) {
                update(ctx, -1)
                return
            }
            ctx.startForegroundService(Intent(ctx, ProcessingService::class.java))
        }

        fun update(ctx: Context, percent: Int) {
            if (!isRunning) return
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification(ctx, percent))
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, ProcessingService::class.java))
        }

        private fun ensureChannel(ctx: Context, name: String) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW),
                )
            }
        }

        private fun buildNotification(ctx: Context, percent: Int): Notification {
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val content = launch?.let {
                android.app.PendingIntent.getActivity(
                    ctx,
                    0,
                    it,
                    android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                )
            }
            return Notification.Builder(ctx, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setProgress(100, percent.coerceIn(0, 100), percent < 0)
                .apply { if (content != null) setContentIntent(content) }
                .build()
        }
    }
}
