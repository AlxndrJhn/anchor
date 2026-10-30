package com.zhfahim.anchor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Build
import java.nio.ByteBuffer

/**
 * Turns a debug recording's JPEG frames into H.264, the codec browsers
 * play: GitHub shows the report's video inline only then. Returns the
 * stream's pieces, still Annex-B, for the Dart side to put in the MP4:
 * {width, height, sps, pps, samples, times (ms), keys}.
 */
object DebugVideoEncoder {
    private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val TIMEOUT_US = 10_000L

    fun encode(jpegs: List<ByteArray>, timesMs: List<Int>): Map<String, Any> {
        require(jpegs.isNotEmpty() && jpegs.size == timesMs.size) { "No frames" }
        val first = BitmapFactory.decodeByteArray(jpegs[0], 0, jpegs[0].size)
            ?: throw IllegalArgumentException("Can't decode frame 0")
        val codec = MediaCodec.createEncoderByType(MIME)
        try {
            val (width, height) = encodedSize(codec, first.width, first.height)
            first.recycle()
            configure(codec, width, height)
            codec.start()
            return run(codec, jpegs, timesMs, width, height)
        } finally {
            codec.release()
        }
    }

    /**
     * The frame size the encoder takes: the recording's, rounded down to
     * what it accepts. Frames are scaled to it.
     */
    private fun encodedSize(codec: MediaCodec, width: Int, height: Int): Pair<Int, Int> {
        val caps = codec.codecInfo.getCapabilitiesForType(MIME).videoCapabilities
        fun down(v: Int, step: Int) = maxOf(step, v - v % step)
        for (step in listOf(2, 16)) {
            val w = down(width, maxOf(step, caps.widthAlignment))
            val h = down(height, maxOf(step, caps.heightAlignment))
            if (caps.isSizeSupported(w, h)) return w to h
        }
        throw IllegalArgumentException("Encoder can't take ${width}x$height")
    }

    private fun configure(codec: MediaCodec, width: Int, height: Int) {
        fun format(baseline: Boolean) = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            // Screen content at 5 fps: plenty for sharp text.
            setInteger(MediaFormat.KEY_BIT_RATE, maxOf(1_000_000, width * height * 4))
            setInteger(MediaFormat.KEY_FRAME_RATE, 5)
            // A key frame every second, for seeking.
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // Frames come out in the order they went in: the MP4 has no
            // composition offsets.
            if (Build.VERSION.SDK_INT >= 29) setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            if (baseline) {
                setInteger(
                    MediaFormat.KEY_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline,
                )
                setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel31)
            }
        }
        try {
            codec.configure(format(baseline = true), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: Exception) {
            // Some encoders refuse an explicit profile; their default it is.
            codec.reset()
            codec.configure(format(baseline = false), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
    }

    private fun run(
        codec: MediaCodec,
        jpegs: List<ByteArray>,
        timesMs: List<Int>,
        width: Int,
        height: Int,
    ): Map<String, Any> {
        var sps: ByteArray? = null
        var pps: ByteArray? = null
        val samples = mutableListOf<ByteArray>()
        val times = mutableListOf<Int>()
        val keys = mutableListOf<Boolean>()
        val info = MediaCodec.BufferInfo()
        var next = 0
        var lastUs = -1L
        var inputDone = false

        while (true) {
            if (!inputDone) {
                val index = codec.dequeueInputBuffer(TIMEOUT_US)
                if (index >= 0) {
                    if (next == jpegs.size) {
                        codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        val image = codec.getInputImage(index)
                            ?: throw IllegalStateException("Encoder gave no input image")
                        fillYuv(image, frameArgb(jpegs[next], width, height), width, height)
                        // Strictly increasing, or the encoder may drop it.
                        val us = maxOf(timesMs[next] * 1000L, lastUs + 1000)
                        lastUs = us
                        codec.queueInputBuffer(index, 0, width * height * 3 / 2, us, 0)
                        next++
                    }
                }
            }
            val out = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            when {
                out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val format = codec.outputFormat
                    sps = format.getByteBuffer("csd-0")?.toArray()
                    pps = format.getByteBuffer("csd-1")?.toArray()
                }
                out >= 0 -> {
                    val buffer = codec.getOutputBuffer(out)
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (buffer != null && info.size > 0 && !isConfig) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        samples.add(buffer.toArray())
                        times.add((info.presentationTimeUs / 1000).toInt())
                        keys.add(info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0)
                    }
                    codec.releaseOutputBuffer(out, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
        }
        codec.stop()
        if (sps == null || pps == null) throw IllegalStateException("Encoder gave no SPS/PPS")
        return mapOf(
            "width" to width,
            "height" to height,
            "sps" to sps,
            "pps" to pps,
            "samples" to samples,
            "times" to times,
            "keys" to keys,
        )
    }

    /** One frame's pixels, scaled to the encoded size. */
    private fun frameArgb(jpeg: ByteArray, width: Int, height: Int): IntArray {
        var bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
            ?: throw IllegalArgumentException("Can't decode a frame")
        if (bitmap.width != width || bitmap.height != height) {
            val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
            bitmap.recycle()
            bitmap = scaled
        }
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        bitmap.recycle()
        return pixels
    }

    /** ARGB to the encoder's YUV 4:2:0, BT.601 limited range. */
    private fun fillYuv(image: android.media.Image, argb: IntArray, width: Int, height: Int) {
        val (yPlane, uPlane, vPlane) = image.planes
        val y = yPlane.buffer
        val yRow = yPlane.rowStride
        val yPixel = yPlane.pixelStride
        for (row in 0 until height) {
            for (col in 0 until width) {
                val c = argb[row * width + col]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                y.put(row * yRow + col * yPixel, (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte())
            }
        }
        val u = uPlane.buffer
        val v = vPlane.buffer
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                // The top-left pixel of each 2×2 block stands for it.
                val c = argb[row * 2 * width + col * 2]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                u.put(
                    row * uPlane.rowStride + col * uPlane.pixelStride,
                    (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte(),
                )
                v.put(
                    row * vPlane.rowStride + col * vPlane.pixelStride,
                    (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte(),
                )
            }
        }
    }

    private fun ByteBuffer.toArray(): ByteArray = ByteArray(remaining()).also { get(it) }
}
