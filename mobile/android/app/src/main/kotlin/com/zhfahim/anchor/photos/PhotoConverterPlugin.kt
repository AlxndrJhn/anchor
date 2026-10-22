package com.zhfahim.anchor.photos

import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Turns photos the server doesn't take, such as HEIC, into JPEG. */
class PhotoConverterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var outputDir: File
    private lateinit var worker: ExecutorService
    private val mainThread = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        outputDir = File(binding.applicationContext.cacheDir, OUTPUT_FOLDER)
        worker = Executors.newSingleThreadExecutor()
        // Leftovers from earlier runs.
        worker.execute { outputDir.deleteRecursively() }
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "toJpeg") return result.notImplemented()
        val path = call.argument<String>("path")
            ?: return result.error("missing_path", "No photo path given", null)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return result.error("unsupported", "Needs Android 9 or later", null)
        }
        worker.execute {
            try {
                val jpeg = toJpeg(File(path))
                mainThread.post { result.success(jpeg.path) }
            } catch (e: IOException) {
                mainThread.post { result.error("unreadable", e.message, null) }
            } catch (e: OutOfMemoryError) {
                mainThread.post { result.error("too_large", e.message, null) }
            } catch (e: Exception) {
                mainThread.post { result.error("unreadable", e.message, null) }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun toJpeg(source: File): File {
        val folder = File(outputDir, UUID.randomUUID().toString()).apply { mkdirs() }
        val jpeg = File(folder, "${source.nameWithoutExtension}.jpg")
        try {
            JpegConverter.convert(source, jpeg)
        } catch (e: Exception) {
            folder.deleteRecursively()
            throw e
        }
        return jpeg
    }

    private companion object {
        const val CHANNEL = "anchor/photos"
        const val OUTPUT_FOLDER = "converted_photos"
    }
}
