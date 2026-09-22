package com.frostbornlegends.frostborngame

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — WebView file-upload bridge.
// ============================================================
// The WebView's <input type="file"> triggers an Android chooser
// through this MethodChannel and returns the picked content:// URIs
// back to the Dart side. Doing this in Kotlin avoids depending on
// file_picker — every published file_picker >= 10.x is Kotlin-only
// and its own Kotlin Gradle Plugin collides with Flutter's built-in
// KGP, breaking GeneratedPluginRegistrant.
//
// The channel name must match `_uploadBridge` in
// lib/hearth/scenes/great_gate_scene.dart.
// ============================================================
class MainActivity : FlutterActivity() {

    private val bridgeName = "hearth/filepick"
    private val pickRequest = 0x5F17
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bridgeName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> {
                        val multiple = call.argument<Boolean>("multiple") ?: false
                        val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                        launchChooser(multiple, mimes, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Complete any abandoned pending result before starting a new one.
        pending?.success(emptyList<String>())
        pending = result

        val filtered = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                filtered.isEmpty() -> type = "*/*"
                filtered.size == 1 -> type = filtered[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, filtered.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pending = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pending
        pending = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}
