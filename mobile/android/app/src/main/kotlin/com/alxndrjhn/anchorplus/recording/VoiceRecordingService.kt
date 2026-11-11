package com.alxndrjhn.anchorplus.recording

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.alxndrjhn.anchorplus.MainActivity
import com.alxndrjhn.anchorplus.R

/**
 * Keeps the microphone of a voice recording on while the phone is locked or
 * the app is in the background: without a foreground service Android takes
 * the microphone away, and the recording comes out silent or broken. Shows
 * "Recording audio" for as long as it runs; a tap opens the app.
 */
class VoiceRecordingService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!wanted) {
            stopSelf()
            return START_NOT_STICKY
        }
        val manager = getSystemService(NotificationManager::class.java)
        createChannel(manager)
        val types = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            0
        }
        try {
            ServiceCompat.startForeground(this, FOREGROUND_ID, notification(), types)
        } catch (e: Exception) {
            // Started from the background, or the permission was taken back:
            // recording still works while the app is open.
            android.util.Log.w("AnchorRecording", "Couldn't start the recording service", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun createChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.recording_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply { lockscreenVisibility = Notification.VISIBILITY_PUBLIC },
        )
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live)
            .setContentTitle(getString(R.string.recording_title))
            .setContentText(getString(R.string.recording_text))
            .setContentIntent(open)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "anchor_recording"
        private const val FOREGROUND_ID = 0x7400000

        /** Whether a recording is on; a late start stops at once without one. */
        @Volatile
        private var wanted = false

        fun start(context: Context) {
            wanted = true
            try {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, VoiceRecordingService::class.java),
                )
            } catch (e: Exception) {
                // From the background (Android 12 and newer).
                android.util.Log.w("AnchorRecording", "Couldn't start the recording service", e)
            }
        }

        fun stop(context: Context) {
            wanted = false
            context.stopService(Intent(context, VoiceRecordingService::class.java))
        }
    }
}
