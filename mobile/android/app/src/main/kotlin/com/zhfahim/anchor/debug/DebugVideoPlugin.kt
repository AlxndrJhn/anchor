package com.zhfahim.anchor.debug

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Encodes a debug recording's frames to H.264 for the report's video
 * (channel anchor/video, "encodeH264"), with [DebugVideoEncoder].
 */
class DebugVideoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "encodeH264") return result.notImplemented()
        val jpegs = call.argument<List<ByteArray>>("jpegs")
        val times = call.argument<List<Int>>("times")
        if (jpegs == null || times == null) return result.error("args", "No frames", null)
        // Seconds of work for a long recording: not on the UI thread.
        Thread {
            try {
                val video = DebugVideoEncoder.encode(jpegs, times)
                main.post { result.success(video) }
            } catch (e: Exception) {
                android.util.Log.w("AnchorVideo", "Couldn't encode H.264", e)
                main.post { result.error("encode", e.message, null) }
            }
        }.start()
    }

    private companion object {
        const val CHANNEL = "anchor/video"
    }
}
