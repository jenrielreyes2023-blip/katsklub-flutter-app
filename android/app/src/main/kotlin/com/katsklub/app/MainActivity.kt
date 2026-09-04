package com.katsklub.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val KATS_NOTIFICATION_TAP_CHANNEL = "com.katsklub.app/notification_taps"

class MainActivity : AudioServiceActivity() {
    private var notificationTapChannel: MethodChannel? = null
    private var pendingNotificationTapData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingNotificationTapData = extractKatsNotificationTapData(intent)
        super.onCreate(savedInstanceState)
        createUrgentNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationTapChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KATS_NOTIFICATION_TAP_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialNotificationData" -> {
                        val data = pendingNotificationTapData
                        pendingNotificationTapData = null
                        result.success(data)
                    }
                    "clearAllNotifications" -> {
                        val notificationManager =
                            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.cancelAll()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val data = extractKatsNotificationTapData(intent) ?: return
        val channel = notificationTapChannel
        if (channel == null) {
            pendingNotificationTapData = data
        } else {
            channel.invokeMethod("notificationTap", data)
        }
    }

    private fun createUrgentNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "katsklub_urgent_channel"
            val channelName = "KatsKlub Urgent Notifications"
            val channelDescription = "Used for urgent notifications like messages and comments"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val soundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/notification_in")
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
                setSound(soundUri, audioAttributes)
            }

            val notificationManager =
                applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun extractKatsNotificationTapData(intent: Intent?): Map<String, String>? {
        val extras = intent?.extras ?: return null
        val data = mutableMapOf<String, String>()

        fun copyExtra(sourceKey: String, targetKey: String = sourceKey) {
            val value = extras.get(sourceKey)?.toString()?.trim()
            if (!value.isNullOrEmpty()) {
                data[targetKey] = value
            }
        }

        copyExtra("type")
        copyExtra("postId")
        copyExtra("commentId")
        copyExtra("username")
        copyExtra(KATS_EXTRA_THREAD_ID, "threadId")

        if (!data.containsKey("type") && data.containsKey("threadId")) {
            data["type"] = "message"
        }

        return data.takeIf { it.isNotEmpty() }
    }
}
