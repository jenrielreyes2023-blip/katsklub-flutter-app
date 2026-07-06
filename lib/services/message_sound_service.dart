import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageSoundService {
  MessageSoundService._();

  static const String _incomingAsset = 'sounds/message_in.mp3';
  static const String _outgoingAsset = 'sounds/message_out.mp3';

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint("MessageSoundService: Initialized");
  }

  static Future<void> playIncoming() async {
    try {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.5);
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(_incomingAsset), mode: PlayerMode.lowLatency);
      debugPrint("MessageSoundService: Playing incoming sound");
    } catch (e, stack) {
      debugPrint("MessageSoundService.playIncoming error: $e\n$stack");
    }
  }

  static Future<void> playOutgoing() async {
    try {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.5);
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(_outgoingAsset), mode: PlayerMode.lowLatency);
      debugPrint("MessageSoundService: Playing outgoing sound");
    } catch (e, stack) {
      debugPrint("MessageSoundService.playOutgoing error: $e\n$stack");
    }
  }
}
