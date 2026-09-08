package com.katsklub.app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlin.concurrent.thread

const val ACTION_CALL_DECLINE = "com.katsklub.app.ACTION_CALL_DECLINE"
const val ACTION_CALL_ACCEPT = "com.katsklub.app.ACTION_CALL_ACCEPT"
const val EXTRA_CALL_ID = "kats_call_id"
const val EXTRA_CALL_ACTION = "kats_call_action"
const val EXTRA_CALLER_ID = "kats_caller_id"
const val EXTRA_CALL_IS_VIDEO = "kats_call_is_video"
const val EXTRA_THREAD_ID = "kats_thread_id"

class KatsCallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val callId = intent.getStringExtra(EXTRA_CALL_ID).orEmpty()
        val callerId = intent.getStringExtra(EXTRA_CALLER_ID).orEmpty()
        val isVideo = intent.getBooleanExtra(EXTRA_CALL_IS_VIDEO, false)
        val threadId = intent.getStringExtra(EXTRA_THREAD_ID).orEmpty()
        val notificationId = intent.getIntExtra(KATS_EXTRA_NOTIFICATION_ID, 0)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (notificationId != 0) {
            notificationManager?.cancel(notificationId)
        } else if (callId.isNotEmpty()) {
            notificationManager?.cancel(katsCallNotificationId(callId))
        }

        when (intent.action) {
            ACTION_CALL_DECLINE -> {
                // Best-effort reject ping if token exists
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.katsklub_auth_token", null)?.trim()
                if (!token.isNullOrEmpty() && callId.isNotEmpty()) {
                    val pendingResult = goAsync()
                    thread(name = "kats-call-decline") {
                        try {
                            notifyCallRejected(token, callId, callerId)
                        } finally {
                            pendingResult.finish()
                        }
                    }
                }
            }
            ACTION_CALL_ACCEPT -> {
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(EXTRA_CALL_ACTION, "accept")
                    putExtra(EXTRA_CALL_ID, callId)
                    putExtra(EXTRA_CALLER_ID, callerId)
                    putExtra(EXTRA_CALL_IS_VIDEO, isVideo)
                    putExtra(EXTRA_THREAD_ID, threadId)
                }
                context.startActivity(launchIntent)
            }
        }
    }

    private fun notifyCallRejected(token: String, callId: String, callerId: String) {
        try {
            val url = java.net.URL("$KATS_API_BASE_URL/api/calls/reject")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.doOutput = true
            conn.connectTimeout = 5000
            conn.readTimeout = 5000
            val json = "{\"callId\":\"$callId\",\"callerUserId\":\"$callerId\"}"
            conn.outputStream.use { it.write(json.toByteArray()) }
            conn.responseCode
            conn.disconnect()
        } catch (_: Throwable) {}
    }
}
