package com.ethosnote.app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.ethosnote.app/share"
    private var sharedFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFile" -> {
                    result.success(sharedFilePath)
                    sharedFilePath = null // Clear after reading
                }
                else -> result.notImplemented()
            }
        }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action == Intent.ACTION_SEND) {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (uri != null) {
                // Copy shared file to app's cache directory
                try {
                    val inputStream = contentResolver.openInputStream(uri)
                    if (inputStream != null) {
                        val mimeType = contentResolver.getType(uri) ?: ""
                        val ext = when {
                            mimeType.contains("opus") -> ".opus"
                            mimeType.contains("ogg") -> ".ogg"
                            mimeType.contains("mp4") || mimeType.contains("m4a") -> ".m4a"
                            mimeType.contains("mpeg") || mimeType.contains("mp3") -> ".mp3"
                            mimeType.contains("aac") -> ".aac"
                            mimeType.startsWith("audio/") -> ".audio"
                            else -> ""
                        }
                        val outFile = File(cacheDir, "shared_${System.currentTimeMillis()}$ext")
                        outFile.outputStream().use { out ->
                            inputStream.copyTo(out)
                        }
                        inputStream.close()
                        sharedFilePath = outFile.absolutePath
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}
