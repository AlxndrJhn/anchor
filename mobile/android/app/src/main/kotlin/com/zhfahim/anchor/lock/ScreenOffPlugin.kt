package com.zhfahim.anchor.lock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Tells Flutter when the screen turns off, so locked notes opened since
 * lock again ("screenOff"). Only a registered receiver hears it; it can't be
 * declared in the manifest. The fact is kept for when the message can't land
 * (the engine paused): Flutter asks for it on resume ("takeScreenOff").
 */
class ScreenOffPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var screenWentOff = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != Intent.ACTION_SCREEN_OFF) return
            screenWentOff = true
            channel?.invokeMethod("screenOff", null)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        ContextCompat.registerReceiver(
            binding.applicationContext,
            receiver,
            IntentFilter(Intent.ACTION_SCREEN_OFF),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        try {
            binding.applicationContext.unregisterReceiver(receiver)
        } catch (e: IllegalArgumentException) {
            // Never registered.
        }
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "takeScreenOff") return result.notImplemented()
        result.success(screenWentOff)
        screenWentOff = false
    }

    private companion object {
        const val CHANNEL = "anchor/lock"
    }
}
