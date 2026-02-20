package com.ethosnote.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.ethosnote.app/share"
    private val DEEP_LINK_CHANNEL = "com.ethosnote.app/deeplink"
    private var sharedFilePath: String? = null
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create notification channel (required for Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "event_reminders",
                "Promemoria eventi",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifiche promemoria per gli eventi del calendario"
            }
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }

        // Share channel (existing)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFile" -> {
                    result.success(sharedFilePath)
                    sharedFilePath = null // Clear after reading
                }
                else -> result.notImplemented()
            }
        }

        // Deep link channel (new for widgets)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeepLink" -> {
                    result.success(pendingDeepLink)
                    pendingDeepLink = null // Clear after reading
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

        // Handle deep links from widgets (ethosnote:// scheme)
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            val uri = intent.data
            if (uri != null && uri.scheme == "ethosnote") {
                pendingDeepLink = uri.toString()
                return
            }
        }

        if (intent.action == Intent.ACTION_SEND) {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
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
