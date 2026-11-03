package com.alxndrjhn.anchorplus.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.alxndrjhn.anchorplus.MainActivity
import com.alxndrjhn.anchorplus.R
import com.alxndrjhn.anchorplus.widget.NotesWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** A note this phone shows its camera in, as a live image. */
data class LiveTransmission(val noteId: String, val title: String?, val withMic: Boolean)

/**
 * Keeps the camera (and microphone) of a live image on while the phone is
 * locked or the app is in the background: Android takes both away from an
 * app without a foreground service. Each note that shows the camera gets its
 * own "Transmitting" notification: a tap opens the note, "Stop transmission"
 * stops its live images (LiveTransmissionPlugin tells Flutter).
 *
 * The first note's notification is the service's own, under a fixed id, so
 * a change while the phone is locked only posts notifications: Android
 * doesn't let a camera service start, or start again, from the background.
 */
class LiveTransmissionService : Service() {

    /** The ids of the notifications posted beside the service's own, by note. */
    private val others = mutableMapOf<String, Int>()

    /** The foreground types the service runs with; null before it does. */
    private var types: Int? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            intent.getStringExtra(EXTRA_NOTE_ID)?.let { LiveTransmissionPlugin.stopRequested(it) }
            return START_NOT_STICKY
        }
        update()
        return START_NOT_STICKY
    }

    /** Shows [transmissions]; stops once there are none. */
    fun update() {
        val now = transmissions
        if (now.isEmpty()) {
            finish()
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        createChannel(manager)
        val wanted = typesOf(now.any { it.withMic })
        val current = types
        if (current == null || wanted != current) {
            try {
                ServiceCompat.startForeground(this, FOREGROUND_ID, notification(now.first()), wanted)
                types = wanted
            } catch (e: Exception) {
                // Started from the background, or a permission was taken back:
                // the camera still works while the app is open.
                android.util.Log.w("AnchorLive", "Couldn't start the transmission service", e)
                if (current == null) {
                    finish()
                    return
                }
            }
        }
        manager.notify(FOREGROUND_ID, notification(now.first()))
        val shown = now.drop(1).associate { it.noteId to idOf(it.noteId) }
        for ((noteId, id) in others) {
            if (noteId !in shown) manager.cancel(id)
        }
        for (transmission in now.drop(1)) {
            manager.notify(shown.getValue(transmission.noteId), notification(transmission))
        }
        others.clear()
        others.putAll(shown)
    }

    /** Stops now: the next note shown starts the service afresh. */
    private fun finish() {
        if (running === this) running = null
        stopSelf()
    }

    override fun onDestroy() {
        if (running === this) running = null
        val manager = getSystemService(NotificationManager::class.java)
        for (id in others.values) manager.cancel(id)
        others.clear()
        super.onDestroy()
    }

    private fun typesOf(withMic: Boolean): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return 0
        var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        if (withMic) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        return types
    }

    private fun createChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.live_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply { lockscreenVisibility = Notification.VISIBILITY_PUBLIC },
        )
    }

    private fun notification(transmission: LiveTransmission): Notification {
        val requestCode = idOf(transmission.noteId)
        // Opens the note as the widget's notes do (HomeWidgetLaunchHandler).
        val open = PendingIntent.getActivity(
            this,
            requestCode,
            Intent(this, MainActivity::class.java)
                .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                .setData(Uri.parse("${NotesWidgetProvider.URI_SCHEME}://note/${transmission.noteId}"))
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            requestCode,
            Intent(this, LiveTransmissionService::class.java)
                .setAction(ACTION_STOP)
                .putExtra(EXTRA_NOTE_ID, transmission.noteId),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live)
            .setContentTitle(getString(R.string.live_transmitting))
            .setContentText(transmission.title ?: getString(R.string.live_transmitting_text))
            .setContentIntent(open)
            .addAction(0, getString(R.string.live_stop_transmission), stop)
            .setOngoing(true)
            .setSilent(true)
            // Each note its own banner, not folded into one group.
            .setGroup("$CHANNEL_ID:${transmission.noteId}")
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun idOf(noteId: String) = OTHERS_ID_BASE + (noteId.hashCode() and 0xFFFF)

    companion object {
        private const val CHANNEL_ID = "anchor_live"
        private const val FOREGROUND_ID = 0x7300000
        private const val OTHERS_ID_BASE = 0x7310000
        private const val ACTION_STOP = "com.alxndrjhn.anchorplus.live.STOP"
        private const val EXTRA_NOTE_ID = "noteId"

        /** The notes shown now; the service reads them on each update. */
        @Volatile
        private var transmissions: List<LiveTransmission> = emptyList()

        private var running: LiveTransmissionService? = null

        fun show(context: Context, now: List<LiveTransmission>) {
            transmissions = now
            val service = running
            if (service != null) {
                service.update()
                return
            }
            if (now.isEmpty()) return
            try {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, LiveTransmissionService::class.java),
                )
            } catch (e: Exception) {
                // From the background (Android 12 and newer).
                android.util.Log.w("AnchorLive", "Couldn't start the transmission service", e)
            }
        }
    }
}
