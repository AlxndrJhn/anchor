package com.zhfahim.anchor.photos

import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.File
import java.io.IOException

/** Turns a photo Android can read, such as HEIC, into JPEG. */
object JpegConverter {

    private const val MAX_SIDE = 4096
    private const val JPEG_QUALITY = 90

    /** Throws [IOException] when [source] can't be read or [target] written. */
    @RequiresApi(Build.VERSION_CODES.P)
    fun convert(source: File, target: File) {
        val bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(source)) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val longest = maxOf(info.size.width, info.size.height)
            if (longest > MAX_SIDE) {
                val scale = MAX_SIDE.toFloat() / longest
                decoder.setTargetSize(
                    (info.size.width * scale).toInt().coerceAtLeast(1),
                    (info.size.height * scale).toInt().coerceAtLeast(1),
                )
            }
        }
        try {
            val isWritten = target.outputStream().use {
                bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it)
            }
            if (!isWritten) throw IOException("Couldn't write ${target.name}")
        } finally {
            bitmap.recycle()
        }
    }
}
