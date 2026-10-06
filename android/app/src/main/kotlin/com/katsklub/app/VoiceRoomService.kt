package com.katsklub.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class VoiceRoomService : Service() {

    companion object {
        const val CHANNEL_ID = "katsklub_voice_room_channel_v2"
        const val NOTIFICATION_ID = 8801
        const val ACTION_START = "com.katsklub.app.ACTION_START_VOICE_ROOM"
        const val ACTION_STOP = "com.katsklub.app.ACTION_STOP_VOICE_ROOM"
        const val EXTRA_ROOM_ID = "extra_room_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_TEXT = "extra_text"

        fun start(
            context: Context,
            roomId: String? = null,
            title: String? = null,
            text: String? = null
        ) {
            val defaultTitle = if (!roomId.isNullOrBlank()) {
                "In a voiceroom. ID: $roomId"
            } else {
                "In a voiceroom."
            }
            val defaultText = "Tap to return"
            val intent = Intent(context, VoiceRoomService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ROOM_ID, roomId)
                putExtra(EXTRA_TITLE, title ?: defaultTitle)
                putExtra(EXTRA_TEXT, text ?: defaultText)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, VoiceRoomService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val roomId = intent?.getStringExtra(EXTRA_ROOM_ID)?.ifBlank { null }
        val defaultTitle = if (!roomId.isNullOrBlank()) {
            "In a voiceroom. ID: $roomId"
        } else {
            "In a voiceroom."
        }
        val defaultText = "Tap to return"
        val title = intent?.getStringExtra(EXTRA_TITLE)?.ifBlank { null } ?: defaultTitle
        val text = intent?.getStringExtra(EXTRA_TEXT)?.ifBlank { null } ?: defaultText

        createNotificationChannel()

        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "voice_room")
            if (!roomId.isNullOrBlank()) {
                putExtra("roomId", roomId)
            }
            putExtra("clickTime", System.currentTimeMillis().toString())
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            notificationIntent,
            pendingIntentFlags(mutable = false)
        )

        val smallIconRes = R.drawable.ic_notification

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(smallIconRes)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())

        @Suppress("DEPRECATION")
        builder.setPriority(Notification.PRIORITY_HIGH)

        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            try {
                // Delete legacy low-importance channel if it existed
                notificationManager.deleteNotificationChannel("katsklub_voice_room_channel")
            } catch (_: Exception) {}

            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Voice Room",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Voice room background connection and audio"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                    setSound(null, null)
                }
                notificationManager.createNotificationChannel(channel)
            }
        }
    }
}
