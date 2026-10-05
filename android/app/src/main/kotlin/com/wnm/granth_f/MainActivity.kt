package com.wnm.granth_f

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private var backInvoked: OnBackInvokedCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.wnm.granthf/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "publish" -> {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name")
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    val pictures = call.argument<Boolean>("pictures") ?: false
                    if (path == null || name == null) {
                        result.error("arg", "missing", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(publish(path, name, mime, pictures))
                    } catch (error: Exception) {
                        result.error("save", error.message, null)
                    }
                }
                "open" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mime") ?: "application/pdf"
                    if (path == null) {
                        result.error("arg", "missing", null)
                        return@setMethodCallHandler
                    }
                    try {
                        open(path, mime)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("open", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hookBack()
    }

    override fun onResume() {
        super.onResume()
        hookBack()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Deprecated("Back is owned by the app until the exit card confirms.")
    override fun onBackPressed() {
        sendBackToFlutter()
    }

    private fun hookBack() {
        if (Build.VERSION.SDK_INT < 33) return
        backInvoked?.let { onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
        val callback = OnBackInvokedCallback { sendBackToFlutter() }
        backInvoked = callback
        onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_OVERLAY, callback)
    }

    private fun sendBackToFlutter() {
        val engine = flutterEngine ?: return
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.wnm.granthf/nav").invokeMethod("back", null)
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= 33) {
            backInvoked?.let { onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
        }
        super.onDestroy()
    }

    private fun publish(path: String, name: String, mime: String, pictures: Boolean): Boolean {
        val collection = if (pictures) {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        }
        val relative = if (pictures) {
            Environment.DIRECTORY_PICTURES + "/Granth"
        } else {
            Environment.DIRECTORY_DOWNLOADS + "/Granth"
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relative)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(collection, values) ?: return false
        contentResolver.openOutputStream(uri)?.use { output ->
            FileInputStream(File(path)).use { input -> input.copyTo(output) }
        }
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        contentResolver.update(uri, values, null, null)
        return true
    }

    private fun open(path: String, mime: String) {
        val file = File(path)
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent.createChooser(intent, "खोलें"))
        }
    }
}
