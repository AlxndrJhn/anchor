package com.zhfahim.anchor.share

import android.content.Intent
import android.net.Uri
import android.os.Build

class SharedIntent(val subject: String, val text: String, val uris: List<Uri>, val type: String?) {

    companion object {
        fun read(intent: Intent): SharedIntent? {
            val action = intent.action
            if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
                ?: intent.getCharSequenceExtra(Intent.EXTRA_TITLE)?.toString()
                ?: ""
            val isMultiple = action == Intent.ACTION_SEND_MULTIPLE
            // Some apps share styled text.
            val texts = if (isMultiple) {
                intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)?.map { it.toString() }.orEmpty()
            } else {
                listOfNotNull(intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString())
            }
            val uris = LinkedHashSet<Uri>()
            uris.addAll(streamsOf(intent, isMultiple))
            val clip = intent.clipData
            val clipTexts = mutableListOf<String>()
            if (clip != null) {
                for (i in 0 until clip.itemCount) {
                    val item = clip.getItemAt(i)
                    item.uri?.let(uris::add)
                    item.text?.toString()?.let(clipTexts::add)
                }
            }
            val text = texts.ifEmpty { clipTexts }.joinToString("\n").trim()
            if (text.isEmpty() && uris.isEmpty()) return null
            return SharedIntent(subject.trim(), text, uris.toList(), intent.type)
        }

        @Suppress("DEPRECATION")
        private fun streamsOf(intent: Intent, isMultiple: Boolean): List<Uri> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Some apps send a single Uri with SEND_MULTIPLE.
                val list = if (isMultiple) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    null
                }
                return list ?: listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java))
            }
            return when (val stream = intent.extras?.get(Intent.EXTRA_STREAM)) {
                is Uri -> listOf(stream)
                is ArrayList<*> -> stream.filterIsInstance<Uri>()
                else -> emptyList()
            }
        }
    }
}
