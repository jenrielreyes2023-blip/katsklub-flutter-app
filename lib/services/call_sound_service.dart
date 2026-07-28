import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class CallSoundService {
  CallSoundService._();
  static AudioPlayer? _player;

  static Future<void> playIncomingRingtone() async {
    await stop();
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      await _player!.play(
        UrlSource('https://actions.google.com/sounds/v1/communication/phone_ring.ogg'),
      );
    } catch (e) {
      debugPrint('[CallSound] Error playing ringtone: $e');
    }
  }

  static Future<void> playOutgoingRingback() async {
    await stop();
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      await _player!.play(
        UrlSource('https://actions.google.com/sounds/v1/communication/phone_dialing.ogg'),
      );
    } catch (e) {
      debugPrint('[CallSound] Error playing ringback: $e');
    }
  }

  static Future<void> stop() async {
    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }
    } catch (e) {
      debugPrint('[CallSound] Error stopping player: $e');
    }
  }
}
