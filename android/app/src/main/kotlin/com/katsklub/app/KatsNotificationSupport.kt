package com.katsklub.app

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import kotlin.math.abs

internal const val KATS_MESSAGE_CHANNEL_ID = "katsklub_messages_channel"
internal const val KATS_CALL_CHANNEL_ID = "katsklub_incoming_calls_channel_v2"
internal const val KATS_REPLY_TEXT_KEY = "katsklub_reply_text"
internal const val KATS_EXTRA_THREAD_ID = "thread_id"
internal const val KATS_EXTRA_NOTIFICATION_ID = "notification_id"
internal const val KATS_API_BASE_URL = "https://katsklub.top"
private const val KATS_NOTIFICATION_AVATAR_SIZE = 256

internal data class KatsIncomingCall(
    val callId: String,
    val callerId: String,
    val callerName: String,
    val callerAvatarUrl: String?,
    val isVideo: Boolean,
    val threadId: String?,
)

internal data class KatsIncomingMessage(
    val threadId: String,
    val senderName: String,
    val body: String,
    val avatarUrl: String?,
)

internal data class KatsIncomingNotification(
    val tagKey: String,
    val type: String,
    val title: String,
    val body: String,
    val avatarUrl: String?,
    val postId: String?,
    val commentId: String?,
    val username: String?,
)


internal fun Context.ensureKatsMessageChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
        return
    }

    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val existingChannel = notificationManager.getNotificationChannel(KATS_MESSAGE_CHANNEL_ID)
    if (existingChannel != null) {
        return
    }

    val channel = NotificationChannel(
        KATS_MESSAGE_CHANNEL_ID,
        "KatsKlub Messages",
        NotificationManager.IMPORTANCE_HIGH,
    ).apply {
        description = "Direct message notifications"
        enableLights(true)
        enableVibration(true)
    }
    notificationManager.createNotificationChannel(channel)
}

internal fun Context.ensureKatsCallChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
        return
    }

    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val existingChannel = notificationManager.getNotificationChannel(KATS_CALL_CHANNEL_ID)
    if (existingChannel != null) {
        return
    }

    val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
    val audioAttributes = AudioAttributes.Builder()
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
        .build()

    val channel = NotificationChannel(
        KATS_CALL_CHANNEL_ID,
        "KatsKlub Incoming Calls",
        NotificationManager.IMPORTANCE_HIGH,
    ).apply {
        description = "High priority incoming audio and video call alerts"
        enableLights(true)
        lightColor = android.graphics.Color.GREEN
        enableVibration(true)
        vibrationPattern = longArrayOf(0, 1000, 1000, 1000, 1000, 1000)
        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        setSound(ringtoneUri, audioAttributes)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            setBypassDnd(true)
        }
    }
    notificationManager.createNotificationChannel(channel)
}

internal fun Context.isKatsAppForeground(): Boolean {
    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        ?: return false
    val packageName = packageName
    return activityManager.runningAppProcesses?.any { processInfo ->
        processInfo.processName == packageName &&
            processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
    } == true
}

internal fun Map<String, String>.toKatsIncomingMessage(): KatsIncomingMessage? {
    val threadId = firstValue(
        "threadId",
        "thread_id",
        "conversationId",
        "conversation_id",
        "chatId",
    )?.trim()
    if (threadId.isNullOrEmpty()) {
        return null
    }

    val type = firstValue("type", "notificationType", "kind", "event")
        ?.lowercase(Locale.US)
        .orEmpty()
    if (type.contains("call")) {
        return null
    }
    val looksLikeMessage = type.contains("message") ||
        containsKey("threadId") ||
        containsKey("conversationId") ||
        containsKey("conversation_id")
    if (!looksLikeMessage) {
        return null
    }

    val body = firstValue(
        "body",
        "message",
        "text",
        "gcm.notification.body",
        "google.c.a.c_l",
    )?.trim()
    if (body.isNullOrEmpty()) {
        return null
    }

    val senderName = firstValue(
        "senderName",
        "senderFullName",
        "fullName",
        "name",
        "title",
        "gcm.notification.title",
    )?.trim().takeUnless { it.isNullOrEmpty() } ?: "KatsKlub"

    val avatarUrl = firstValue(
        "senderAvatarUrl",
        "sender_avatar_url",
        "avatarUrl",
        "avatar",
        "photoUrl",
        "profileImage",
        "image",
        "gcm.notification.image",
    )?.trim().takeUnless { it.isNullOrEmpty() }

    return KatsIncomingMessage(
        threadId = threadId,
        senderName = senderName,
        body = body,
        avatarUrl = avatarUrl,
    )
}

internal fun Map<String, String>.toKatsIncomingNotification(): KatsIncomingNotification? {
    val rawType = firstValue("type", "notificationType", "kind", "event")
        ?.trim()
        ?.lowercase(Locale.US)
        ?: return null
    if (rawType.contains("message")) {
        return null
    }

    val supportedType = normalizeKatsNotificationType(rawType) ?: return null
    val body = firstValue("body", "message", "text", "gcm.notification.body")
        ?.trim()
        ?.takeUnless { it.isEmpty() }
        ?: return null
    val title = firstValue(
        "title",
        "actorName",
        "senderName",
        "fullName",
        "name",
        "gcm.notification.title",
    )?.trim().takeUnless { it.isNullOrEmpty() } ?: "KatsKlub"
    val actorId = firstValue("actorId", "actor_id", "senderId", "userId")
        ?.trim()
        ?.takeUnless { it.isEmpty() }
    val avatarUrl = firstValue(
        "actorAvatarUrl",
        "senderAvatarUrl",
        "avatarUrl",
        "avatar",
        "photoUrl",
        "profileImage",
        "image",
        "gcm.notification.image",
    )?.trim().takeUnless { it.isNullOrEmpty() }
    val postId = firstValue("postId", "post_id", "targetPostId", "entityId")
        ?.trim()
        ?.takeUnless { it.isEmpty() }
    val commentId = firstValue("commentId", "comment_id", "targetCommentId")
        ?.trim()
        ?.takeUnless { it.isEmpty() }
    val username = firstValue("username", "actorUsername", "senderUsername")
        ?.trim()
        ?.takeUnless { it.isEmpty() }
    val explicitTag = firstValue("notificationTag", "androidTag")
        ?.trim()
        ?.takeUnless { it.isEmpty() }
    val tagKey = explicitTag ?: actorId?.let { "actor:" + it } ?: listOfNotNull(
        supportedType,
        postId,
        commentId,
        username,
        title,
    ).joinToString(":")

    return KatsIncomingNotification(
        tagKey = tagKey,
        type = supportedType,
        title = title,
        body = body,
        avatarUrl = avatarUrl,
        postId = postId,
        commentId = commentId,
        username = username,
    )
}

internal fun normalizeKatsNotificationType(type: String): String? {
    return when (type) {
        "post_like", "like" -> "post_like"
        "post_comment", "comment" -> "post_comment"
        "comment_reply", "reply" -> "comment_reply"
        "repost", "post_repost", "quote" -> "repost"
        "share", "post_share" -> "share"
        "follow", "mention", "tag" -> type
        else -> null
    }
}

internal fun katsNotificationEmoji(type: String): String {
    return when (type) {
        "post_like" -> "❤️"
        "post_comment", "comment_reply" -> "💬"
        "repost" -> "🔁"
        "share" -> "📤"
        "follow" -> "👤"
        "mention", "tag" -> "🏷️"
        else -> "🔔"
    }
}

internal fun Map<String, String>.firstValue(vararg keys: String): String? {
    for (key in keys) {
        val value = this[key]
        if (!value.isNullOrBlank()) {
            return value
        }
    }
    return null
}

internal fun katsCallNotificationId(callId: String): Int {
    return 500_000 + abs(callId.hashCode() % 400_000)
}

internal fun Map<String, String>.toKatsIncomingCall(): KatsIncomingCall? {
    val type = firstValue("type", "notificationType", "kind", "event")
        ?.lowercase(Locale.US)
        .orEmpty()
    val isCallType = type == "call_invite" ||
        type == "call_incoming" ||
        type == "call" ||
        type == "incoming_call" ||
        type == "call:invite"
    val hasCallId = containsKey("callId") || containsKey("call_id")
    if (!isCallType && !hasCallId) {
        return null
    }

    val callId = firstValue("callId", "call_id")?.trim() ?: return null
    val callerId = firstValue("callerId", "caller_id", "callerUserId", "userId")?.trim() ?: ""
    val callerName = firstValue(
        "callerName",
        "caller_name",
        "callerFullName",
        "fullName",
        "name",
        "title",
        "senderName",
    )?.trim().takeUnless { it.isNullOrEmpty() } ?: "KatsKlub Member"

    val callerAvatarUrl = firstValue(
        "callerAvatarUrl",
        "caller_avatar_url",
        "callerAvatar",
        "avatarUrl",
        "avatar",
        "photoUrl",
        "image",
    )?.trim().takeUnless { it.isNullOrEmpty() }

    val rawIsVideo = firstValue("isVideo", "is_video", "mediaType", "callType")?.lowercase(Locale.US)
    val isVideo = rawIsVideo == "true" || rawIsVideo == "1" || rawIsVideo == "video"
    val threadId = firstValue("threadId", "thread_id")?.trim()

    return KatsIncomingCall(
        callId = callId,
        callerId = callerId,
        callerName = callerName,
        callerAvatarUrl = callerAvatarUrl,
        isVideo = isVideo,
        threadId = threadId,
    )
}

internal fun katsNotificationId(threadId: String): Int {
    return 100_000 + abs(threadId.hashCode() % 800_000)
}

internal fun Context.getKatsNotificationColor(): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        getColor(R.color.notification_color)
    } else {
        @Suppress("DEPRECATION")
        resources.getColor(R.color.notification_color)
    }
}

internal fun Context.showKatsMessageNotification(message: KatsIncomingMessage) {
    ensureKatsMessageChannel()

    val notificationId = katsNotificationId(message.threadId)
    val contentIntent = PendingIntent.getActivity(
        this,
        notificationId,
        Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(KATS_EXTRA_THREAD_ID, message.threadId)
        },
        pendingIntentFlags(mutable = false),
    )
    val replyIntent = PendingIntent.getBroadcast(
        this,
        notificationId,
        Intent(this, KatsDirectReplyReceiver::class.java).apply {
            putExtra(KATS_EXTRA_THREAD_ID, message.threadId)
            putExtra(KATS_EXTRA_NOTIFICATION_ID, notificationId)
        },
        pendingIntentFlags(mutable = true),
    )

    val replyInput = RemoteInput.Builder(KATS_REPLY_TEXT_KEY)
        .setLabel("Reply")
        .build()
    val replyAction = Notification.Action.Builder(
        android.R.drawable.ic_menu_send,
        "Reply",
        replyIntent,
    )
        .addRemoteInput(replyInput)
        .setAllowGeneratedReplies(true)
        .build()

    val largeIcon = message.avatarUrl?.let(::loadKatsAvatar)
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, KATS_MESSAGE_CHANNEL_ID)
    } else {
        @Suppress("DEPRECATION")
        Notification.Builder(this)
    }

    builder
        .setSmallIcon(R.drawable.ic_notification)
        .setColor(getKatsNotificationColor())
        .setContentTitle(message.senderName)
        .setContentText(message.body)
        .setAutoCancel(true)
        .setContentIntent(contentIntent)
        .setPriority(Notification.PRIORITY_HIGH)
        .setCategory(Notification.CATEGORY_MESSAGE)
        .addAction(replyAction)

    if (largeIcon != null) {
        builder.setLargeIcon(largeIcon)
    }

    @Suppress("DEPRECATION")
    builder.setStyle(Notification.BigTextStyle().bigText(message.body))

    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(notificationId, builder.build())
}

internal fun Context.showKatsCallNotification(call: KatsIncomingCall) {
    ensureKatsCallChannel()

    val notificationId = katsCallNotificationId(call.callId)

    // Full-screen incoming call intent (shows full screen caller ID on lock screen, heads-up banner when screen is on)
    val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra(EXTRA_CALL_ACTION, "incoming")
        putExtra(EXTRA_CALL_ID, call.callId)
        putExtra(EXTRA_CALLER_ID, call.callerId)
        putExtra(EXTRA_CALL_IS_VIDEO, call.isVideo)
        putExtra(EXTRA_THREAD_ID, call.threadId.orEmpty())
        putExtra("callerName", call.callerName)
        putExtra("callerAvatar", call.callerAvatarUrl.orEmpty())
    }
    val fullScreenPendingIntent = PendingIntent.getActivity(
        this,
        notificationId,
        fullScreenIntent,
        pendingIntentFlags(mutable = false),
    )

    // Accept action (launches app directly to connect call)
    val acceptIntent = Intent(this, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra(EXTRA_CALL_ACTION, "accept")
        putExtra(EXTRA_CALL_ID, call.callId)
        putExtra(EXTRA_CALLER_ID, call.callerId)
        putExtra(EXTRA_CALL_IS_VIDEO, call.isVideo)
        putExtra(EXTRA_THREAD_ID, call.threadId.orEmpty())
        putExtra("callerName", call.callerName)
        putExtra("callerAvatar", call.callerAvatarUrl.orEmpty())
    }
    val acceptPendingIntent = PendingIntent.getActivity(
        this,
        notificationId + 1,
        acceptIntent,
        pendingIntentFlags(mutable = false),
    )

    // Decline action (sends broadcast to dismiss notification and ping server reject)
    val declineIntent = Intent(this, KatsCallActionReceiver::class.java).apply {
        action = ACTION_CALL_DECLINE
        putExtra(EXTRA_CALL_ID, call.callId)
        putExtra(EXTRA_CALLER_ID, call.callerId)
        putExtra(EXTRA_THREAD_ID, call.threadId.orEmpty())
        putExtra(KATS_EXTRA_NOTIFICATION_ID, notificationId)
    }
    val declinePendingIntent = PendingIntent.getBroadcast(
        this,
        notificationId + 2,
        declineIntent,
        pendingIntentFlags(mutable = true),
    )

    val declineAction = Notification.Action.Builder(
        android.R.drawable.ic_menu_close_clear_cancel,
        "Decline",
        declinePendingIntent,
    ).build()

    val acceptAction = Notification.Action.Builder(
        android.R.drawable.ic_menu_call,
        "Accept",
        acceptPendingIntent,
    ).build()

    val callTypeLabel = if (call.isVideo) "Incoming KatsKlub Video Call..." else "Incoming KatsKlub Audio Call..."
    val largeIcon = call.callerAvatarUrl?.let(::loadKatsAvatar)

    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, KATS_CALL_CHANNEL_ID)
    } else {
        @Suppress("DEPRECATION")
        Notification.Builder(this)
    }

    val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

    builder
        .setSmallIcon(R.drawable.ic_notification)
        .setColor(getKatsNotificationColor())
        .setContentTitle(call.callerName)
        .setContentText(callTypeLabel)
        .setCategory(Notification.CATEGORY_CALL)
        .setPriority(Notification.PRIORITY_MAX)
        .setVisibility(Notification.VISIBILITY_PUBLIC)
        .setOngoing(true)
        .setAutoCancel(false)
        .setSound(ringtoneUri)
        .setFullScreenIntent(fullScreenPendingIntent, true)
        .setContentIntent(fullScreenPendingIntent)
        .addAction(declineAction)
        .addAction(acceptAction)

    if (largeIcon != null) {
        builder.setLargeIcon(largeIcon)
    }

    val notification = builder.build().apply {
        flags = flags or Notification.FLAG_INSISTENT
    }

    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(notificationId, notification)
}

internal fun Context.cancelKatsCallNotification(callId: String) {
    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
    notificationManager?.cancel(katsCallNotificationId(callId))
}

internal fun Context.showKatsSocialNotification(notification: KatsIncomingNotification) {
    ensureKatsMessageChannel()

    val notificationId = katsNotificationId(notification.tagKey)
    val contentIntent = PendingIntent.getActivity(
        this,
        notificationId,
        Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", notification.type)
            notification.postId?.let { putExtra("postId", it) }
            notification.commentId?.let { putExtra("commentId", it) }
            notification.username?.let { putExtra("username", it) }
        },
        pendingIntentFlags(mutable = false),
    )
    val largeIcon = notification.avatarUrl?.let(::loadKatsAvatar)
    val emojiBody = katsNotificationEmoji(notification.type) + " " + notification.body
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, KATS_MESSAGE_CHANNEL_ID)
    } else {
        @Suppress("DEPRECATION")
        Notification.Builder(this)
    }

    builder
        .setSmallIcon(R.drawable.ic_notification)
        .setColor(getKatsNotificationColor())
        .setContentTitle(notification.title)
        .setContentText(emojiBody)
        .setAutoCancel(true)
        .setContentIntent(contentIntent)
        .setPriority(Notification.PRIORITY_HIGH)
        .setCategory(Notification.CATEGORY_SOCIAL)

    if (largeIcon != null) {
        builder.setLargeIcon(largeIcon)
    }

    @Suppress("DEPRECATION")
    builder.setStyle(Notification.BigTextStyle().bigText(emojiBody))

    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(notification.tagKey, 0, builder.build())
}

internal fun Context.updateKatsReplyNotification(
    notificationId: Int,
    title: String,
    body: String,
) {
    ensureKatsMessageChannel()
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(this, KATS_MESSAGE_CHANNEL_ID)
    } else {
        @Suppress("DEPRECATION")
        Notification.Builder(this)
    }

    builder
        .setSmallIcon(R.drawable.ic_notification)
        .setColor(getKatsNotificationColor())
        .setContentTitle(title)
        .setContentText(body)
        .setAutoCancel(true)
        .setPriority(Notification.PRIORITY_DEFAULT)

    val notificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(notificationId, builder.build())
}

internal fun loadKatsAvatar(rawUrl: String): Bitmap? {
    val normalizedUrl = normalizeKatsUrl(rawUrl) ?: return null
    return try {
        val connection = URL(normalizedUrl).openConnection() as HttpURLConnection
        connection.connectTimeout = 2500
        connection.readTimeout = 2500
        connection.instanceFollowRedirects = true
        connection.inputStream.use { input ->
            BitmapFactory.decodeStream(input)?.toNotificationAvatar()
        }
    } catch (_: Exception) {
        null
    }
}

private fun Bitmap.toNotificationAvatar(
    size: Int = KATS_NOTIFICATION_AVATAR_SIZE,
): Bitmap {
    val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(output)

    drawCenterCroppedCircle(
        canvas = canvas,
        target = RectF(0f, 0f, size.toFloat(), size.toFloat()),
    )
    return output
}


private fun Bitmap.drawCenterCroppedCircle(canvas: Canvas, target: RectF) {
    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    val sourceSize = minOf(width, height)
    val left = ((width - sourceSize) / 2).coerceAtLeast(0)
    val top = ((height - sourceSize) / 2).coerceAtLeast(0)
    val source = Rect(left, top, left + sourceSize, top + sourceSize)

    val clipPath = Path().apply {
        addOval(target, Path.Direction.CW)
    }
    val saveCount = canvas.save()
    canvas.clipPath(clipPath)
    canvas.drawBitmap(this, source, target, paint)
    canvas.restoreToCount(saveCount)
}

internal fun normalizeKatsUrl(rawUrl: String): String? {
    val value = rawUrl.trim()
    if (value.isEmpty() || value.startsWith("data:")) {
        return null
    }
    return when {
        value.startsWith("http://") || value.startsWith("https://") -> value
        value.startsWith("/") -> "$KATS_API_BASE_URL$value"
        else -> Uri.withAppendedPath(Uri.parse("$KATS_API_BASE_URL/"), value).toString()
    }
}

internal fun pendingIntentFlags(mutable: Boolean): Int {
    val base = PendingIntent.FLAG_UPDATE_CURRENT
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
        return base
    }
    return base or if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE
}
