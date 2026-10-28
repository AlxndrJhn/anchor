package com.zhfahim.anchor

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import com.zhfahim.anchor.files.DeviceFilesPlugin
import com.zhfahim.anchor.lock.ScreenOffPlugin
import com.zhfahim.anchor.photos.PhotoConverterPlugin
import com.zhfahim.anchor.share.ShareFolderPlugin
import com.zhfahim.anchor.update.UpdateInstallerPlugin
import com.zhfahim.anchor.widget.NotesWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs

// A FragmentActivity so local_auth can show the fingerprint prompt (locked
// notes).
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        attachWidgetNoteUri(intent)
        super.onCreate(savedInstanceState)
        preferFastestRefreshRate()
        publishShortcuts()
    }

    /**
     * The launcher's long-press menu: New note and New checklist. They are
     * dynamic so they target whichever package this is (the fork's id
     * differs), and launch like the widget's buttons, which home_widget
     * hands to the Flutter side on both cold and warm starts.
     */
    private fun publishShortcuts() {
        if (Build.VERSION.SDK_INT < 25) return
        try {
            val manager = getSystemService(ShortcutManager::class.java) ?: return
            fun shortcut(id: String, label: String, uri: String, icon: Int) =
                ShortcutInfo.Builder(this, id)
                    .setShortLabel(label)
                    .setLongLabel(label)
                    .setIcon(Icon.createWithResource(this, icon))
                    .setIntent(
                        Intent(this, MainActivity::class.java)
                            .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                            .setData(Uri.parse(uri))
                            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    )
                    .build()
            val scheme = NotesWidgetProvider.URI_SCHEME
            manager.setDynamicShortcuts(listOf(
                shortcut("new_note", getString(R.string.shortcut_new_note), "$scheme://note/new", R.drawable.ic_shortcut_note),
                shortcut("new_checklist", getString(R.string.shortcut_new_checklist), "$scheme://note/new?checklist=1", R.drawable.ic_shortcut_checklist),
            ))
        } catch (e: Exception) {
            android.util.Log.w("AnchorShortcuts", "Couldn't publish app shortcuts", e)
        }
    }

    override fun onNewIntent(intent: Intent) {
        attachWidgetNoteUri(intent)
        super.onNewIntent(intent)
    }

    /**
     * FlutterFragmentActivity's own fragment, built the same way (this app
     * never uses a cached engine), but one whose SystemNavigator.pop moves
     * the app to the background, as FlutterActivity's popSystemNavigator did.
     */
    override fun createFlutterFragment(): FlutterFragment {
        val builder = FlutterFragment.NewEngineFragmentBuilder(BackgroundingFlutterFragment::class.java)
            .dartEntrypoint(dartEntrypointFunctionName)
            .dartEntrypointArgs(dartEntrypointArgs ?: emptyList())
            .appBundlePath(appBundlePath)
            .flutterShellArgs(FlutterShellArgs.fromIntent(intent))
            .handleDeeplinking(shouldHandleDeeplinking())
            .renderMode(renderMode)
            .transparencyMode(TransparencyMode.opaque)
            .shouldAttachEngineToActivity(shouldAttachEngineToActivity())
            .shouldDelayFirstAndroidViewDraw(renderMode == RenderMode.surface)
            .shouldAutomaticallyHandleOnBackPressed(true)
        dartEntrypointLibraryUri?.let { builder.dartLibraryUri(it) }
        getInitialRoute()?.let { builder.initialRoute(it) }
        return builder.build()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PhotoConverterPlugin())
        flutterEngine.plugins.add(ShareFolderPlugin(listens = true))
        flutterEngine.plugins.add(UpdateInstallerPlugin())
        flutterEngine.plugins.add(ScreenOffPlugin())
        flutterEngine.plugins.add(DeviceFilesPlugin())
    }

    private fun preferFastestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay)
            ?: return
        val current = display.mode
        val fastest = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        window.attributes = window.attributes.apply { preferredDisplayModeId = fastest.modeId }
    }

    // home_widget reads the launch target only from the intent's data URI.
    private fun attachWidgetNoteUri(intent: Intent?) {
        if (intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) return
        if (intent.data != null) return
        val noteId = intent.getStringExtra(NotesWidgetProvider.EXTRA_NOTE_ID) ?: return
        intent.data = Uri.parse("${NotesWidgetProvider.URI_SCHEME}://note/$noteId")
    }
}

/** SystemNavigator.pop moves the app to the background instead of closing it. */
class BackgroundingFlutterFragment : FlutterFragment() {
    override fun popSystemNavigator(): Boolean = activity?.moveTaskToBack(true) ?: false
}
