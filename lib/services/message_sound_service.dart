import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageSoundService {
  MessageSoundService._();

  static const String _incomingAsset = 'sounds/message_in.mp3';
  static const String _outgoingAsset = 'sounds/message_out.mp3';

  static AudioPlayer? _incomingPlayer;
  static AudioPlayer? _outgoingPlayer;
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _incomingPlayer = AudioPlayer();
      _outgoingPlayer = AudioPlayer();
      debugPrint("MessageSoundService: Initialized");
    } catch (e) {
      debugPrint("MessageSoundService init error: $e");
    }
  }

  static Future<void> playIncoming() async {
    try {
      final player = _incomingPlayer ?? AudioPlayer();
      await player.stop();
      await player.play(AssetSource(_incomingAsset));
      debugPrint("MessageSoundService: Playing incoming sound");
    } catch (e, stack) {
      debugPrint("MessageSoundService.playIncoming error: $e\n$stack");
    }
  }

  static Future<void> playOutgoing() async {
    try {
      final player = _outgoingPlayer ?? AudioPlayer();
      await player.stop();
      await player.play(AssetSource(_outgoingAsset));
      debugPrint("MessageSoundService: Playing outgoing sound");
    } catch (e, stack) {
      debugPrint("MessageSoundService.playOutgoing error: $e\n$stack");
    }
  }
}
