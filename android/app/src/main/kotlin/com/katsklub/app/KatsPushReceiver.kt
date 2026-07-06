package com.katsklub.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlin.concurrent.thread

class KatsPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (context.isKatsAppForeground()) {
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
