package com.zhfahim.anchor.files

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Files a note's attachments need from Android (channel anchor/files):
 * "pickFolderAsZip" opens Android's folder screen and zips the picked folder,
 * subfolders included, into the cache ({path, name, files}, or null when
 * nothing was picked); "open" shows an attached file in an app that can
 * (false when no app can); "copyImage" puts a picture on the clipboard.
 */
class DeviceFilesPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null

    /** A folder pick waiting for Android's folder screen to answer. */
    private var pendingFolder: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolderAsZip" -> pickFolder(result)
            "open" -> {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mimeType")
                if (path == null || name == null) {
                    result.error("args", "No file", null)
                } else {
                    try {
                        result.success(openFile(File(path), name, mime))
                    } catch (e: Exception) {
                        result.error("open", e.message, null)
                    }
                }
            }
            "copyImage" -> {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                if (path == null || name == null) {
                    result.error("args", "No file", null)
                } else {
                    try {
                        copyImage(File(path), name, call.argument<String>("mimeType"))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("copy", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val activity = binding?.activity
        if (activity == null) {
            result.error("pick", "No activity", null)
            return
        }
        if (pendingFolder != null) {
            result.error("busy", "Already picking a folder", null)
            return
        }
        pendingFolder = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_FOLDER)
        } catch (e: Exception) {
            pendingFolder = null
            result.error("pick", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FOLDER) return false
        val result = pendingFolder ?: return true
        pendingFolder = null
        val tree = data?.data
        val activity = binding?.activity
        if (resultCode != Activity.RESULT_OK || tree == null || activity == null) {
            result.success(null)
            return true
        }
        // Zipping a big folder takes a while; not on the UI thread.
        Thread {
            try {
                val zipped = zipFolder(activity, tree)
                activity.runOnUiThread { result.success(zipped) }
            } catch (e: Exception) {
                android.util.Log.w("AnchorFiles", "Couldn't zip folder $tree", e)
                activity.runOnUiThread { result.error("zip", e.message, null) }
            }
        }.start()
        return true
    }

    /** Zips the folder at [tree], subfolders included, into the cache. */
    private fun zipFolder(context: Context, tree: Uri): Map<String, Any> {
        val resolver = context.contentResolver
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val name = folderName(context, tree, rootId)
        val dir = File(context.cacheDir, "folders").apply { mkdirs() }
        val zip = File(dir, "${UUID.randomUUID()}.zip")
        var count = 0
        ZipOutputStream(zip.outputStream().buffered()).use { out ->
            fun walk(documentId: String, prefix: String) {
                val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
                val columns = arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                )
                resolver.query(children, columns, null, null, null)?.use { cursor ->
                    while (cursor.moveToNext()) {
                        val id = cursor.getString(0)
                        val entry = prefix + (cursor.getString(1) ?: id)
                        if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                            out.putNextEntry(ZipEntry("$entry/"))
                            out.closeEntry()
                            walk(id, "$entry/")
                        } else {
                            val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                            out.putNextEntry(ZipEntry(entry))
                            resolver.openInputStream(uri)?.use { it.copyTo(out) }
                            out.closeEntry()
                            count++
                        }
                    }
                }
            }
            walk(rootId, "")
        }
        return mapOf("path" to zip.absolutePath, "name" to "$name.zip", "files" to count)
    }

    private fun folderName(context: Context, tree: Uri, rootId: String): String {
        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        val name = context.contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
        return name ?: rootId.substringAfterLast(':').substringAfterLast('/').ifEmpty { "Folder" }
    }

    /** Opens an attached file in an app that can show it; false when none can. */
    private fun openFile(file: File, name: String, mimeType: String?): Boolean {
        val activity = binding?.activity ?: return false
        val dir = File(activity.cacheDir, "open").apply { mkdirs() }
        val copy = File(dir, name.replace('/', '_'))
        file.copyTo(copy, overwrite = true)
        // The same provider that hands updates to the installer (update_paths.xml).
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", copy)
        val type = mimeType?.takeIf { it != "application/octet-stream" }
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(copy.extension.lowercase())
            ?: "*/*"
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return try {
            activity.startActivity(Intent.createChooser(intent, name))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /**
     * Puts a picture on the clipboard, for pasting into other apps. The
     * clipboard hands the reading app permission to the copy's address.
     */
    private fun copyImage(file: File, name: String, mimeType: String?) {
        val activity = binding?.activity ?: throw IllegalStateException("No activity")
        val dir = File(activity.cacheDir, "open").apply { mkdirs() }
        val copy = File(dir, name.replace('/', '_'))
        file.copyTo(copy, overwrite = true)
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", copy)
        val type = mimeType
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(copy.extension.lowercase())
            ?: "image/*"
        val clip = ClipData(ClipDescription(name, arrayOf(type)), ClipData.Item(uri))
        activity.getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
    }

    private companion object {
        const val CHANNEL = "anchor/files"
        const val PICK_FOLDER = 4711
    }
}
