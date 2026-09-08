package com.katsklub.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlin.concurrent.thread

class KatsPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
        val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
        val isScreenOffOrLocked = (powerManager?.isInteractive == false) || (keyguardManager?.isKeyguardLocked == true)

        if (context.isKatsAppForeground() && !isScreenOffOrLocked) {
            return
        }

        // Ignore incoming push notifications if the user is currently logged out
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val authToken = prefs.getString("flutter.katsklub_auth_token", null)?.trim()
        val sessionCookie = prefs.getString("flutter.katsklub_session_cookie", null)?.trim()
        val userJson = prefs.getString("flutter.katsklub_user", null)?.trim()
        if (authToken.isNullOrEmpty() && sessionCookie.isNullOrEmpty() && userJson.isNullOrEmpty()) {
            abortKatsPushBroadcastIfOrdered()
            return
        }

        val data = intent.extras?.keySet()?.mapNotNull { key ->
            val value = intent.extras?.get(key)?.toString()
            if (value.isNullOrBlank()) null else key to value
        }?.toMap().orEmpty()

        val sentAt = data["sentAt"]?.toLongOrNull()
        if (sentAt != null && (System.currentTimeMillis() - sentAt) > 180000) {
            abortKatsPushBroadcastIfOrdered()
            return
        }

        val appContext = context.applicationContext

        // Dismiss ringing notification if caller hung up or call ended
        val rawType = data["type"]?.lowercase() ?: ""
        val callId = data["callId"] ?: data["call_id"]
        if (rawType == "call_ended" || rawType == "call_reject" || rawType == "call_cancel" || rawType == "call_timeout") {
            if (!callId.isNullOrBlank()) {
                appContext.cancelKatsCallNotification(callId)
            }
            abortKatsPushBroadcastIfOrdered()
            return
        }

        // Handle incoming audio / video call
        val incomingCall = data.toKatsIncomingCall()
        if (incomingCall != null) {
            abortKatsPushBroadcastIfOrdered()
            val pendingResult = goAsync()
            thread(name = "kats-call-notification") {
                try {
                    appContext.showKatsCallNotification(incomingCall)
                } finally {
                    pendingResult.finish()
                }
            }
            return
        }

        // If app is foreground and screen is on, let socket handle regular messages/social notifications
        if (context.isKatsAppForeground()) {
            return
        }

        val message = data.toKatsIncomingMessage()
        if (message != null) {
            abortKatsPushBroadcastIfOrdered()
            val pendingResult = goAsync()
            thread(name = "kats-message-notification") {
                try {
                    appContext.showKatsMessageNotification(message)
                } finally {
                    pendingResult.finish()
                }
            }
            return
        }

        val notification = data.toKatsIncomingNotification() ?: return
        abortKatsPushBroadcastIfOrdered()
        val pendingResult = goAsync()
        thread(name = "kats-social-notification") {
            try {
                appContext.showKatsSocialNotification(notification)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun abortKatsPushBroadcastIfOrdered() {
        if (isOrderedBroadcast) {
            abortBroadcast()
        }
    }
}
