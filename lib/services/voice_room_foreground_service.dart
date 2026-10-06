import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages the native Android Voice Room foreground service.
///
/// Keeps the voice room RTC connection and background audio active in the OS
/// using a plain, low-importance ongoing notification without any media session
/// controls or Spotify-like lockscreen player.
class VoiceRoomForegroundService {
  static const MethodChannel _channel =
      MethodChannel('com.katsklub.app/voice_room_service');

  /// Starts a quiet, plain ongoing Android foreground service notification.
  static Future<void> start({
    String title = 'Katsklub',
    String text = 'Nasa voice room ka',
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start', {
        'title': title,
        'text': text,
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
