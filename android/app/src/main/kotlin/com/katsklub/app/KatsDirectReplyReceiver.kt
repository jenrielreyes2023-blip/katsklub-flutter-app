package com.katsklub.app

import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class KatsDirectReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val replyText = RemoteInput.getResultsFromIntent(intent)
            ?.getCharSequence(KATS_REPLY_TEXT_KEY)
            ?.toString()
            ?.trim()
        val threadId = intent.getStringExtra(KATS_EXTRA_THREAD_ID)?.trim()
        val notificationId = intent.getIntExtra(
            KATS_EXTRA_NOTIFICATION_ID,
            threadId?.let(::katsNotificationId) ?: 0,
        )

        if (replyText.isNullOrEmpty() || threadId.isNullOrEmpty()) {
            return
        }

        val pendingResult = goAsync()
        thread(name = "kats-direct-reply") {
            val appContext = context.applicationContext
            val sent = sendReply(appContext, threadId, replyText)
            if (notificationId != 0) {
                appContext.updateKatsReplyNotification(
                    notificationId,
                    if (sent) "Reply sent" else "Reply failed",
                    if (sent) replyText else "Open KatsKlub and try again.",
                )
            }
            pendingResult.finish()
        }
    }

    private fun sendReply(context: Context, threadId: String, replyText: String): Boolean {
        val authToken = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.katsklub_auth_token", null)
            ?.trim()
        if (authToken.isNullOrEmpty()) {
            return false
        }

        return try {
            val encodedThreadId = java.net.URLEncoder.encode(threadId, "UTF-8")
            val connection = URL(
                "$KATS_API_BASE_URL/api/messages/threads/$encodedThreadId/messages",
            ).openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 6000
            connection.readTimeout = 6000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $authToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write("""{"body":${replyText.toJsonString()}}""")
            }

            connection.responseCode in 200..299
        } catch (_: Exception) {
            false
        }
    }

    private fun String.toJsonString(): String {
        val builder = StringBuilder(length + 2)
        builder.append('"')
        for (char in this) {
            when (char) {
                '\\' -> builder.append("\\\\")
                '"' -> builder.append("\\\"")
                '\b' -> builder.append("\\b")
                '\u000C' -> builder.append("\\f")
                '\n' -> builder.append("\\n")
                '\r' -> builder.append("\\r")
                '\t' -> builder.append("\\t")
                else -> {
                    if (char.code < 0x20) {
                        builder.append("\\u")
                        builder.append(char.code.toString(16).padStart(4, '0'))
                    } else {
                        builder.append(char)
                    }
                }
            }
        }
        builder.append('"')
        return builder.toString()
    }
}
