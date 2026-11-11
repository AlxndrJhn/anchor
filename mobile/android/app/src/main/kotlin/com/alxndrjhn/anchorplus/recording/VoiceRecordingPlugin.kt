package com.alxndrjhn.anchorplus.recording

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Runs VoiceRecordingService while a voice recording is on: "start" before
 * the recorder starts, "stop" once it has stopped.
 */
class VoiceRecordingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        // No Flutter left to record.
        VoiceRecordingService.stop(binding.applicationContext)
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context ?: return result.success(null)
        when (call.method) {
            "start" -> VoiceRecordingService.start(context)
            "stop" -> VoiceRecordingService.stop(context)
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    companion object {
        private const val CHANNEL = "anchor/recording"
    }
}
