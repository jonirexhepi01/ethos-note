package com.ethosnote.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.ethosnote.app/share"
    private val DEEP_LINK_CHANNEL = "com.ethosnote.app/deeplink"
    private val CONTACTS_CHANNEL = "com.ethosnote.app/contacts"
    private val BATTERY_CHANNEL = "com.ethosnote.app/battery"
    private var sharedFilePath: String? = null
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create 3 notification channels (v2) for different alert types (Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Delete ALL legacy channels (cached with wrong settings)
            for (old in listOf("event_reminders_v2", "event_sound", "event_vibration", "event_both")) {
                notificationManager.deleteNotificationChannel(old)
            }

            val defaultSound = android.media.RingtoneManager.getDefaultUri(
                android.media.RingtoneManager.TYPE_NOTIFICATION
            )
            val audioAttrs = android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            // Channel: sound only (v2)
            notificationManager.createNotificationChannel(
                NotificationChannel("event_sound_v2", "Promemoria (suono)", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Solo suono, senza vibrazione"
                    enableVibration(false)
                    setSound(defaultSound, audioAttrs)
                }
            )
            // Channel: vibration only (v2)
            notificationManager.createNotificationChannel(
                NotificationChannel("event_vibration_v2", "Promemoria (vibrazione)", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Solo vibrazione, senza suono"
                    enableVibration(true)
                    setSound(null, null)
                }
            )
            // Channel: sound + vibration (v2)
            notificationManager.createNotificationChannel(
                NotificationChannel("event_both_v2", "Promemoria (suono + vibrazione)", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Suono e vibrazione insieme"
                    enableVibration(true)
                    setSound(defaultSound, audioAttrs)
                }
            )
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

        // Contacts insert channel — supports multiple emails, phones and structured address
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACTS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openContactInsert" -> {
                    val name = call.argument<String>("name") ?: ""
                    val phones = call.argument<List<String>>("phones") ?: emptyList()
                    val emails = call.argument<List<String>>("emails") ?: emptyList()
                    val company = call.argument<String>("company") ?: ""
                    val jobTitle = call.argument<String>("jobTitle") ?: ""
                    val street = call.argument<String>("street") ?: ""
                    val city = call.argument<String>("city") ?: ""
                    val postalCode = call.argument<String>("postalCode") ?: ""
                    val province = call.argument<String>("province") ?: ""
                    val website = call.argument<String>("website") ?: ""

                    val intent = Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI)

                    if (name.isNotEmpty()) {
                        intent.putExtra(ContactsContract.Intents.Insert.NAME, name)
                    }

                    // Phones (up to 3 via direct extras)
                    if (phones.isNotEmpty()) {
                        intent.putExtra(ContactsContract.Intents.Insert.PHONE, phones[0])
                        intent.putExtra(ContactsContract.Intents.Insert.PHONE_TYPE, CommonDataKinds.Phone.TYPE_WORK)
                    }
                    if (phones.size > 1) {
                        intent.putExtra(ContactsContract.Intents.Insert.SECONDARY_PHONE, phones[1])
                        intent.putExtra(ContactsContract.Intents.Insert.SECONDARY_PHONE_TYPE, CommonDataKinds.Phone.TYPE_MOBILE)
                    }
                    if (phones.size > 2) {
                        intent.putExtra(ContactsContract.Intents.Insert.TERTIARY_PHONE, phones[2])
                        intent.putExtra(ContactsContract.Intents.Insert.TERTIARY_PHONE_TYPE, CommonDataKinds.Phone.TYPE_OTHER)
                    }

                    // Emails (up to 3 via direct extras)
                    if (emails.isNotEmpty()) {
                        intent.putExtra(ContactsContract.Intents.Insert.EMAIL, emails[0])
                        intent.putExtra(ContactsContract.Intents.Insert.EMAIL_TYPE, CommonDataKinds.Email.TYPE_WORK)
                    }
                    if (emails.size > 1) {
                        intent.putExtra(ContactsContract.Intents.Insert.SECONDARY_EMAIL, emails[1])
                        intent.putExtra(ContactsContract.Intents.Insert.SECONDARY_EMAIL_TYPE, CommonDataKinds.Email.TYPE_WORK)
                    }
                    if (emails.size > 2) {
                        intent.putExtra(ContactsContract.Intents.Insert.TERTIARY_EMAIL, emails[2])
                        intent.putExtra(ContactsContract.Intents.Insert.TERTIARY_EMAIL_TYPE, CommonDataKinds.Email.TYPE_OTHER)
                    }

                    // Company & Job title
                    if (company.isNotEmpty()) {
                        intent.putExtra(ContactsContract.Intents.Insert.COMPANY, company)
                    }
                    if (jobTitle.isNotEmpty()) {
                        intent.putExtra(ContactsContract.Intents.Insert.JOB_TITLE, jobTitle)
                    }

                    // Structured address + website via DATA extras
                    val data = ArrayList<ContentValues>()

                    if (street.isNotEmpty() || city.isNotEmpty() || postalCode.isNotEmpty() || province.isNotEmpty()) {
                        val addr = ContentValues()
                        addr.put(ContactsContract.Data.MIMETYPE, CommonDataKinds.StructuredPostal.CONTENT_ITEM_TYPE)
                        addr.put(CommonDataKinds.StructuredPostal.STREET, street)
                        addr.put(CommonDataKinds.StructuredPostal.CITY, city)
                        addr.put(CommonDataKinds.StructuredPostal.POSTCODE, postalCode)
                        addr.put(CommonDataKinds.StructuredPostal.REGION, province)
                        addr.put(CommonDataKinds.StructuredPostal.TYPE, CommonDataKinds.StructuredPostal.TYPE_WORK)
                        data.add(addr)
                    }

                    if (website.isNotEmpty()) {
                        val web = ContentValues()
                        web.put(ContactsContract.Data.MIMETYPE, CommonDataKinds.Website.CONTENT_ITEM_TYPE)
                        web.put(CommonDataKinds.Website.URL, website)
                        web.put(CommonDataKinds.Website.TYPE, CommonDataKinds.Website.TYPE_WORK)
                        data.add(web)
                    }

                    if (data.isNotEmpty()) {
                        intent.putParcelableArrayListExtra(ContactsContract.Intents.Insert.DATA, data)
                    }

                    intent.putExtra("finishActivityOnSaveCompleted", true)
                    startActivityForResult(intent, 0)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        // Push deep link to Flutter immediately (warm start)
        // Note: do NOT clear pendingDeepLink here — the Dart side clears it
        // via the getDeepLink call. Clearing here causes a race condition if
        // the Dart side isn't ready yet.
        if (pendingDeepLink != null) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, DEEP_LINK_CHANNEL)
                    .invokeMethod("onDeepLink", pendingDeepLink)
            }
        }
        // Replace activity intent with a clean one to prevent stale re-delivery
        setIntent(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER))
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        // Handle deep links from widgets (ethosnote:// scheme)
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            val uri = intent.data
            if (uri != null && uri.scheme == "ethosnote") {
                pendingDeepLink = uri.toString()
                // Clear intent data to prevent re-delivery on activity recreation
                intent.action = null
                intent.data = null
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
                    contentResolver.openInputStream(uri)?.use { inputStream ->
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
                        // Clean old shared files before creating a new one
                        cacheDir.listFiles()?.filter { it.name.startsWith("shared_") }?.forEach {
                            try { it.delete() } catch (_: Exception) {}
                        }
                        val outFile = File(cacheDir, "shared_${System.currentTimeMillis()}$ext")
                        outFile.outputStream().use { out ->
                            inputStream.copyTo(out)
                        }
                        sharedFilePath = outFile.absolutePath
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            } else if (intent.hasExtra(Intent.EXTRA_TEXT)) {
                val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (sharedText != null) {
                    pendingDeepLink = "ethosnote://flash?text=${java.net.URLEncoder.encode(sharedText, "UTF-8")}"
                }
            }
        }
    }
}
