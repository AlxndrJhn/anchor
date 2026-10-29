package com.zhfahim.anchor.widget

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.zhfahim.anchor.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class NotesWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        NotesRemoteViewsFactory(applicationContext)

    companion object {
        /** Must match `homeWidgetNotesKey` in lib/features/home_widget/data/home_widget_payload.dart. */
        const val WIDGET_NOTES_KEY = "widget_notes"
    }
}

private class NotesRemoteViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private data class WidgetNote(
        val id: String,
        val title: String,
        val snippet: String,
        val pinned: Boolean,
        /** ARGB for the light and dark theme; null for the default card. */
        val fill: Int?,
        val edge: Int?,
        val fillDark: Int?,
        val edgeDark: Int?,
    )

    private var notes: List<WidgetNote> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        notes = loadNotes()
    }

    private fun loadNotes(): List<WidgetNote> {
        val json = HomeWidgetPlugin.getData(context)
            .getString(NotesWidgetService.WIDGET_NOTES_KEY, null) ?: return emptyList()
        return try {
            val array = JSONObject(json).optJSONArray("notes") ?: return emptyList()
            (0 until array.length()).mapNotNull { i ->
                val item = array.optJSONObject(i) ?: return@mapNotNull null
                val id = item.optString("id")
                if (id.isEmpty()) return@mapNotNull null
                WidgetNote(
                    id = id,
                    title = item.optString("title"),
                    snippet = item.optString("snippet"),
                    pinned = item.optBoolean("pinned"),
                    fill = item.colorOrNull("fill"),
                    edge = item.colorOrNull("edge"),
                    fillDark = item.colorOrNull("fillDark"),
                    edgeDark = item.colorOrNull("edgeDark"),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun JSONObject.colorOrNull(key: String): Int? = if (has(key)) optLong(key).toInt() else null

    private val isDark: Boolean
        get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_note_item)
        val note = notes.getOrNull(position) ?: return views

        val dark = isDark
        val fill = (if (dark) note.fillDark else note.fill) ?: context.getColor(R.color.widget_item_bg)
        val edge = (if (dark) note.edgeDark else note.edge) ?: context.getColor(R.color.widget_item_edge)
        views.setInt(R.id.item_fill, "setColorFilter", fill)
        views.setInt(R.id.item_edge, "setColorFilter", edge)

        views.setTextViewText(R.id.item_title, note.title)
        views.setViewVisibility(
            R.id.item_title,
            if (note.title.isBlank()) View.GONE else View.VISIBLE,
        )
        views.setTextViewText(R.id.item_snippet, note.snippet)
        views.setViewVisibility(
            R.id.item_snippet,
            if (note.snippet.isBlank()) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(R.id.item_pin, if (note.pinned) View.VISIBLE else View.GONE)

        views.setOnClickFillInIntent(
            R.id.item_root,
            Intent().putExtra(NotesWidgetProvider.EXTRA_NOTE_ID, note.id),
        )
        return views
    }

    override fun getCount(): Int = notes.size

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun onDestroy() {}
}
