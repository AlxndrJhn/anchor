package com.zhfahim.anchor.update

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Opens Android's installer with an update of the fork downloaded from its
 * releases. Android asks the user to confirm, and the first time to let
 * Anchor install apps.
 */
class UpdateInstallerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "install") return result.notImplemented()
        val path = call.argument<String>("path")
            ?: return result.error("args", "No APK path", null)
        try {
            install(File(path))
            result.success(null)
        } catch (e: Exception) {
            result.error("install", e.message, null)
        }
    }

    private fun install(apk: File) {
        // The provider in the manifest (UpdateFileProvider), over cache/updates.
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", apk)
        context.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private companion object {
        const val CHANNEL = "anchor/update"
    }
}
