package com.alxndrjhn.anchorplus.live

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Runs LiveTransmissionService while this phone shows a live image: "show"
 * with the notes that show the camera now ([{noteId, title, withMic}], empty
 * to stop). Tells Flutter when a note's "Stop transmission" was tapped
 * ("stopNote" with its id).
 */
class LiveTransmissionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        attached = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (attached === this) attached = null
        channel?.setMethodCallHandler(null)
        channel = null
        // No Flutter left to show the camera.
        LiveTransmissionService.show(binding.applicationContext, emptyList())
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "show") return result.notImplemented()
        val context = context ?: return result.success(null)
        val now = (call.arguments as? List<*>).orEmpty().mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val noteId = map["noteId"] as? String ?: return@mapNotNull null
            LiveTransmission(
                noteId = noteId,
                title = (map["title"] as? String)?.takeIf { it.isNotBlank() },
                withMic = map["withMic"] as? Boolean ?: false,
            )
        }
        LiveTransmissionService.show(context, now)
        result.success(null)
    }

    companion object {
        private const val CHANNEL = "anchor/live"
        private var attached: LiveTransmissionPlugin? = null

        fun stopRequested(noteId: String) {
            Handler(Looper.getMainLooper()).post {
                attached?.channel?.invokeMethod("stopNote", noteId)
            }
        }
    }
}
