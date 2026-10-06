import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages the native Android Voice Room foreground service.
///
/// Keeps the voice room RTC connection and background audio active in the OS
/// using a high-priority, pinned ongoing notification without media session
/// controls or Spotify-like lockscreen player.
class VoiceRoomForegroundService {
  static const MethodChannel _channel =
      MethodChannel('com.katsklub.app/voice_room_service');

  /// Starts a pinned, high-priority ongoing Android foreground service notification.
  static Future<void> start({
    String? roomId,
    String title = 'Katsklub',
    String? text,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final defaultText = (roomId != null && roomId.isNotEmpty)
          ? 'In a voiceroom. ID: $roomId'
          : 'In a voiceroom.';
      await _channel.invokeMethod('start', {
        if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
        'title': title,
        'text': text ?? defaultText,
      });
    } catch (e) {
      debugPrint('[VoiceRoomForegroundService] start error: $e');
    }
  }

  /// Stops the foreground service and clears the notification.
  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[VoiceRoomForegroundService] stop error: $e');
    }
  }
}
