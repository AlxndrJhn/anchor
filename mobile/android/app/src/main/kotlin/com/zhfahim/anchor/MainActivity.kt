package com.zhfahim.anchor

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import com.zhfahim.anchor.widget.NotesWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {

    private var shareChannel: MethodChannel? = null

    /** What another app shared, until the Flutter side takes it. */
    private var pendingShare: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        attachWidgetNoteUri(intent)
        // A recreated activity (rotation, theme change) must not share again.
        if (savedInstanceState == null) readShare(intent)
        super.onCreate(savedInstanceState)
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
    }
}
