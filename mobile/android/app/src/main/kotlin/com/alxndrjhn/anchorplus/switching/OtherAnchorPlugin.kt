package com.alxndrjhn.anchorplus.switching

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Anchor app someone is switching from, still on this phone (channel
 * anchor/other_app): "find" gives its {package, label}, or null when none is
 * installed; "open" starts it; "showDetails" opens its page in Android's
 * settings, where it can be uninstalled. The packages must be listed under
 * <queries> in the manifest, or Android hides them.
 */
class OtherAnchorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

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
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context ?: return result.success(null)
        when (call.method) {
            "find" -> result.success(find(context))
            "open" -> {
                val pkg = call.argument<String>("package")
                    ?.takeIf { it in PACKAGES } ?: return result.success(false)
                val launch = context.packageManager.getLaunchIntentForPackage(pkg)
                    ?: return result.success(false)
                result.success(start(context, launch))
            }
            "showDetails" -> {
                val pkg = call.argument<String>("package")
                    ?.takeIf { it in PACKAGES } ?: return result.success(false)
                val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.fromParts("package", pkg, null))
                result.success(start(context, details))
            }
            else -> result.notImplemented()
        }
    }

    private fun find(context: Context): Map<String, String>? {
        val pm = context.packageManager
        for (pkg in PACKAGES) {
            val info = try {
                pm.getApplicationInfo(pkg, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                continue
            }
            return mapOf("package" to pkg, "label" to pm.getApplicationLabel(info).toString())
        }
        return null
    }

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    companion object {
        const val CHANNEL = "anchor/other_app"

        /** The official app, then this fork's id before fork-0.18.0.69. */
        val PACKAGES = listOf("com.zhfahim.anchor", "com.zhfahim.anchor.fork")
    }
}
