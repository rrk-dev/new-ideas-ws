package com.vaultvoice.vaultvoice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log

/**
 * AUD-05: foreground service of type `microphone` that keeps a user-started
 * recording alive while the app is backgrounded or the screen is off, with
 * the always-visible ongoing notification required by SEC-09
 * (docs/adr/ADR-AUD-05-android-background-recording.md).
 *
 * The service does **no** audio work itself: capture runs in the Flutter
 * engine (`record` plugin, `AudioRecord` with MIC / VOICE_RECOGNITION only).
 * It exists so the OS keeps the process (and the while-in-use microphone
 * access granted at the user's tap) alive, and to show Pause / Resume / Stop.
 *
 * Rules (verified against the Android API reference for compileSdk 36):
 * - Started only by [RecordingIndicatorPlugin] right after the user tapped
 *   Record (activity visible): Android 14+ forbids starting a microphone FGS
 *   from the background. `startForeground` is called at once in
 *   `onStartCommand` (5 s limit).
 * - `START_NOT_STICKY`: never restarted by the system after a kill, so a
 *   recording can never start or resume without the user (SEC-09).
 * - Button taps are forwarded to Dart ([onAction]); the service never
 *   changes capture on its own.
 */
class RecordingService : Service() {
    companion object {
        private const val TAG = "VVRecordingService"
        const val CHANNEL_ID = "recording"
        const val REMINDER_CHANNEL_ID = "recording_reminders"
        const val NOTIFICATION_ID = 4101
        const val REMINDER_NOTIFICATION_ID = 4102
        const val EXTRA_SPEC = "spec"
        const val ACTION_SHOW = "com.vaultvoice.recording.SHOW"
        const val ACTION_PAUSE = "com.vaultvoice.recording.PAUSE"
        const val ACTION_RESUME = "com.vaultvoice.recording.RESUME"
        const val ACTION_STOP = "com.vaultvoice.recording.STOP"
        const val ACTION_REPOST = "com.vaultvoice.recording.REPOST"

        /** The running instance (same process), null when stopped. */
        @Volatile
        var instance: RecordingService? = null
            private set

        val isRunning: Boolean get() = instance != null

        /** Receives "pause" / "resume" / "stop" taps (set by the plugin). */
        @Volatile
        var onAction: ((String) -> Unit)? = null

        /**
         * Starts the service in the foreground with [spec], or updates the
         * running one. Throws when the OS refuses a foreground start (e.g.
         * `ForegroundServiceStartNotAllowedException` from the background).
         */
        fun show(context: Context, spec: Bundle) {
            val running = instance
            if (running != null) {
                running.updateSpec(spec)
                return
            }
            val intent = Intent(context, RecordingService::class.java)
                .setAction(ACTION_SHOW)
                .putExtra(EXTRA_SPEC, spec)
            context.startForegroundService(intent)
        }

        fun hide() {
            instance?.stopRecordingService()
        }
    }

    private var spec: Bundle? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannels()
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE -> forward("pause")
            ACTION_RESUME -> forward("resume")
            ACTION_STOP -> forward("stop")
            ACTION_REPOST -> spec?.let { notifyCurrent(it) }
            else -> {
                val s = intent?.getBundleExtra(EXTRA_SPEC)
                if (s == null) {
                    // Not started by the plugin (e.g. a stale PendingIntent
                    // after the process died): never record on our own.
                    stopSelf()
                    return START_NOT_STICKY
                }
                goForeground(s)
            }
        }
        if (spec == null) stopSelf() // an action reached a service with nothing to show
        return START_NOT_STICKY
    }

    private fun forward(action: String) {
        val handler = onAction
        if (handler == null) {
            Log.w(TAG, "notification action without a Flutter listener")
            return
        }
        handler(action)
    }

    private fun goForeground(s: Bundle) {
        spec = s
        val notification = build(s)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: RuntimeException) {
            // SecurityException (RECORD_AUDIO revoked) or
            // ForegroundServiceStartNotAllowedException (API 31+).
            Log.e(TAG, "startForeground refused: ${e.javaClass.simpleName}")
            spec = null
            stopSelf()
        }
    }

    /** Updates the notification of the running service. */
    fun updateSpec(s: Bundle) {
        spec = s
        notifyCurrent(s)
    }

    private fun notifyCurrent(s: Bundle) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, build(s))
    }

    fun stopRecordingService() {
        spec = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(REMINDER_NOTIFICATION_ID)
        stopSelf()
    }

    /** "Still recording (1h 00m)" (SEC-09 long-session reminder). */
    fun remind(text: String) {
        val n = Notification.Builder(this, REMINDER_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_recording)
            .setContentTitle(text)
            .setContentIntent(openAppIntent())
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(REMINDER_NOTIFICATION_ID, n)
    }

    private fun build(s: Bundle): Notification {
        val recording = s.getBoolean("recording")
        val b = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_recording)
            .setContentTitle(s.getString("title") ?: "Recording")
            .setContentText(s.getString("text") ?: "")
            .setStyle(Notification.BigTextStyle().bigText(s.getString("text") ?: ""))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            // Lock screen shows only the state (no recording content exists in it).
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(openAppIntent())
            // Android 14+ lets users swipe FGS notifications away: put it back.
            .setDeleteIntent(serviceIntent(ACTION_REPOST, 4))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        val base = s.getLong("chronometerBaseMs", 0L)
        if (recording && base > 0L) {
            b.setUsesChronometer(true).setWhen(base).setShowWhen(true)
        } else {
            b.setUsesChronometer(false).setShowWhen(false)
        }
        for (action in s.getStringArrayList("actions").orEmpty()) {
            when (action) {
                "pause" -> b.addAction(action(R.drawable.ic_stat_pause, s.getString("pauseLabel") ?: "Pause", ACTION_PAUSE, 1))
                "resume" -> b.addAction(action(R.drawable.ic_stat_resume, s.getString("resumeLabel") ?: "Resume", ACTION_RESUME, 2))
                "stop" -> b.addAction(action(R.drawable.ic_stat_stop, s.getString("stopLabel") ?: "Stop", ACTION_STOP, 3))
            }
        }
        return b.build()
    }

    private fun action(icon: Int, label: String, intentAction: String, code: Int): Notification.Action =
        Notification.Action.Builder(Icon.createWithResource(this, icon), label, serviceIntent(intentAction, code)).build()

    private fun serviceIntent(intentAction: String, code: Int): PendingIntent =
        PendingIntent.getService(
            this,
            code,
            Intent(this, RecordingService::class.java).setAction(intentAction),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun openAppIntent(): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun createChannels() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val recording = NotificationChannel(CHANNEL_ID, "Recording", NotificationManager.IMPORTANCE_LOW).apply {
            description = "Shown while VaultVoice is recording"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val reminders = NotificationChannel(
            REMINDER_CHANNEL_ID,
            "Recording reminders",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Reminds you that a long recording is still running"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(recording)
        nm.createNotificationChannel(reminders)
    }
}
