package com.zhfahim.anchor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import com.zhfahim.anchor.widget.NotesWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import java.util.UUID

// A FragmentActivity so local_auth can show the fingerprint prompt.
class MainActivity : FlutterFragmentActivity() {

    private var shareChannel: MethodChannel? = null

    private var lockChannel: MethodChannel? = null

    /**
     * The screen went off since Flutter last asked: unlocked notes lock
     * again. Kept for when the message to Flutter can't land (the engine
     * paused or not attached yet); Flutter asks for it on resume.
     */
    private var screenWentOff = false

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_SCREEN_OFF) return
            screenWentOff = true
            lockChannel?.invokeMethod("screenOff", null)
        }
    }

    /** What another app shared, until the Flutter side takes it. */
    private var pendingShare: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        attachWidgetNoteUri(intent)
        // A recreated activity (rotation, theme change) must not share again.
        if (savedInstanceState == null) readShare(intent)
        super.onCreate(savedInstanceState)
        publishShortcuts()
        // Only a registered receiver hears the screen go off; it can't be
        // declared in the manifest.
        ContextCompat.registerReceiver(
            this,
            screenOffReceiver,
            IntentFilter(Intent.ACTION_SCREEN_OFF),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (e: IllegalArgumentException) {
            // Never registered.
        }
        super.onDestroy()
    }

    /**
     * The launcher's long-press menu: New note and New checklist. They are
     * dynamic so they target whichever package this is (the fork's id
     * differs), and launch like the widget's buttons, which home_widget
     * hands to the Flutter side on both cold and warm starts.
     */
    private fun publishShortcuts() {
        if (Build.VERSION.SDK_INT < 25) return
        try {
            val manager = getSystemService(ShortcutManager::class.java) ?: return
            fun shortcut(id: String, label: String, uri: String, icon: Int) =
                ShortcutInfo.Builder(this, id)
                    .setShortLabel(label)
                    .setLongLabel(label)
                    .setIcon(Icon.createWithResource(this, icon))
                    .setIntent(
                        Intent(this, MainActivity::class.java)
                            .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                            .setData(Uri.parse(uri))
                            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    )
                    .build()
            val scheme = NotesWidgetProvider.URI_SCHEME
            manager.setDynamicShortcuts(listOf(
                shortcut("new_note", getString(R.string.shortcut_new_note), "$scheme://note/new", R.drawable.ic_shortcut_note),
                shortcut("new_checklist", getString(R.string.shortcut_new_checklist), "$scheme://note/new?checklist=1", R.drawable.ic_shortcut_checklist),
            ))
        } catch (e: Exception) {
            android.util.Log.w("AnchorShortcuts", "Couldn't publish app shortcuts", e)
        }
    }

    override fun onNewIntent(intent: Intent) {
        attachWidgetNoteUri(intent)
        if (readShare(intent)) shareChannel?.invokeMethod("shared", null)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    if (call.method == "takeShared") {
                        result.success(pendingShare)
                        pendingShare = null
                    } else {
                        result.notImplemented()
                    }
                }
            }
        lockChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCK_CHANNEL)
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    if (call.method == "takeScreenOff") {
                        result.success(screenWentOff)
                        screenWentOff = false
                    } else {
                        result.notImplemented()
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "install") return@setMethodCallHandler result.notImplemented()
                val path = call.argument<String>("path")
                    ?: return@setMethodCallHandler result.error("args", "No APK path", null)
                try {
                    installUpdate(File(path))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("install", e.message, null)
                }
            }
    }

    /**
     * Opens Android's installer with a downloaded update. Android asks the
     * user to confirm, and the first time to let Anchor install apps.
     */
    private fun installUpdate(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    // A tapped list row arrives with the note id as an extra, but the home_widget
    // plugin only reads the launch target from the intent's data URI.
    private fun attachWidgetNoteUri(intent: Intent?) {
        if (intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) return
        if (intent.data != null) return
        val noteId = intent.getStringExtra(NotesWidgetProvider.EXTRA_NOTE_ID) ?: return
        intent.data = Uri.parse("${NotesWidgetProvider.URI_SCHEME}://note/$noteId")
    }

    /**
     * Keeps text and pictures sent with Android's share sheet. Pictures are
     * copied into the app's cache, since the sender's permission to read
     * them ends with this activity. Returns whether there was anything.
     */
    private fun readShare(intent: Intent?): Boolean {
        val action = intent?.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return false

        val streams = mutableListOf<Uri>()
        if (action == Intent.ACTION_SEND) {
            streamExtra(intent)?.let(streams::add)
        } else {
            streams.addAll(streamListExtra(intent))
        }
        val files = streams.mapNotNull(::copyShared)
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        // Handled: don't share it again if the activity is re-created.
        intent.action = Intent.ACTION_MAIN

        if (files.isEmpty() && text.isNullOrBlank()) return false
        pendingShare = mapOf("title" to subject, "text" to text, "files" to files)
        return true
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }) ?: emptyList()

    private fun copyShared(uri: Uri): Map<String, String>? = try {
        val mime = contentResolver.getType(uri) ?: "application/octet-stream"
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "bin"
        val name = displayName(uri) ?: "Shared ${UUID.randomUUID().toString().take(8)}.$ext"
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val file = File(dir, "${UUID.randomUUID()}.$ext")
        contentResolver.openInputStream(uri)?.use { input ->
            file.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("Can't open $uri")
        mapOf("path" to file.absolutePath, "mimeType" to mime, "name" to name)
    } catch (e: Exception) {
        android.util.Log.w("AnchorShare", "Couldn't copy shared file $uri", e)
        null
    }

    private fun displayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }

    companion object {
        private const val SHARE_CHANNEL = "anchor/share"
        private const val UPDATE_CHANNEL = "anchor/update"
        private const val LOCK_CHANNEL = "anchor/lock"
    }
}
