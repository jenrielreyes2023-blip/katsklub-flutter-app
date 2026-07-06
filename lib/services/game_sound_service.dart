import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class GameSoundService {
  GameSoundService._();

  static const String _correctAsset = 'sounds/message_in.mp3';
  static const String _wrongAsset = 'sounds/message_out.mp3';

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint("GameSoundService: Initialized");
  }

  // Fire-and-forget sound playback using audioplayers (better for SFX)
  static Future<void> playCorrect() async {
    _playSound(_correctAsset, 1.0);
  }

  static Future<void> playWrong() async {
    _playSound(_wrongAsset, 1.0);
  }

  static Future<void> playTimeout() async {
    _playSound(_wrongAsset, 0.8);
  }

  static Future<void> playResults() async {
    _playSound(_correctAsset, 1.0);
  }

  static void _playSound(String asset, double volume) async {
    try {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(volume);
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(asset), mode: PlayerMode.lowLatency);
      debugPrint("GameSoundService: Playing $asset at volume $volume");
    } catch (e) {
      debugPrint("GameSoundService._playSound error: $e");
    }
  }
}
