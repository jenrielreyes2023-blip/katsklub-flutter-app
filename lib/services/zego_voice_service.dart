import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

/// Global Singleton Service managing ZegoCloud RTC Engine for KatsKlub Voice Rooms.
class ZegoVoiceService {
  factory ZegoVoiceService() => _instance;
  ZegoVoiceService._internal();
  static final ZegoVoiceService _instance = ZegoVoiceService._internal();

  static const int appID = 741492118;
  static const String appSign =
      '9523bf62f17e975eec86f300be82541f3b95e255f876af6a3c16543590196088';

  bool _isInitialized = false;
  String? _currentRoomId;
  String? _myStreamId;
  bool _isPublishing = false;
  bool _isMuted = false;
  ZegoMediaPlayer? _mediaPlayer;
  int _mediaPlayerTotalDurationMs = 0;

  /// Callback fired when Zego media player completes playback of a track
  void Function()? onMusicCompleted;

  // StreamId -> SoundLevel (0.0 to 100.0)
  final ValueNotifier<Map<String, double>> soundLevelsNotifier =
      ValueNotifier<Map<String, double>>({});

  final ValueNotifier<double> mySoundLevelNotifier = ValueNotifier<double>(0.0);

  bool get isPublishing => _isPublishing;
  bool get isMuted => _isMuted;
  String? get currentRoomId => _currentRoomId;

  /// Initializes Zego Express Engine. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    try {
      final profile = ZegoEngineProfile(
        appID,
        ZegoScenario.StandardVoiceCall,
        appSign: appSign,
      );

      await ZegoExpressEngine.createEngineWithProfile(profile);

      // Register callbacks
      ZegoExpressEngine.onCapturedSoundLevelUpdate = (double soundLevel) {
        mySoundLevelNotifier.value = _isMuted ? 0.0 : soundLevel;
      };

      ZegoExpressEngine.onRemoteSoundLevelUpdate =
          (Map<String, double> soundLevels) {
        soundLevelsNotifier.value = Map<String, double>.from(soundLevels);
      };

      ZegoExpressEngine.onMediaPlayerStateUpdate =
          (ZegoMediaPlayer mediaPlayer, ZegoMediaPlayerState state, int errorCode) {
        debugPrint('[ZegoVoiceService] onMediaPlayerStateUpdate: state=$state, errorCode=$errorCode');
        if (state == ZegoMediaPlayerState.PlayEnded) {
          onMusicCompleted?.call();
        }
      };

      ZegoExpressEngine.onMediaPlayerPlayingProgress =
          (ZegoMediaPlayer mediaPlayer, int millisecond) {
        if (_mediaPlayerTotalDurationMs > 0 &&
            millisecond >= _mediaPlayerTotalDurationMs - 600) {
          debugPrint(
              '[ZegoVoiceService] onMediaPlayerPlayingProgress reached end: $millisecond / $_mediaPlayerTotalDurationMs');
          onMusicCompleted?.call();
        }
      };

      ZegoExpressEngine.onRoomStreamUpdate =
          (String roomID, ZegoUpdateType updateType, List<ZegoStream> streamList,
              Map<String, dynamic> extendedData) {
        for (final stream in streamList) {
          if (updateType == ZegoUpdateType.Add) {
            // Automatically play remote audio stream
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
          } else if (updateType == ZegoUpdateType.Delete) {
            ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
          }
        }
      };

      _isInitialized = true;
      debugPrint('[ZegoVoiceService] Initialized successfully with AppID $appID');
    } catch (e) {
      debugPrint('[ZegoVoiceService] Engine init error: $e');
    }
  }

  /// Join a Voice Room in ZegoCloud
  Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
  }) async {
    await ensureInitialized();

    // Leave existing room if any
    if (_currentRoomId != null && _currentRoomId != roomId) {
      await leaveRoom();
    }

    try {
      final user = ZegoUser(userId, userName);
      final roomConfig = ZegoRoomConfig.defaultConfig()
        ..isUserStatusNotify = true;

      final result = await ZegoExpressEngine.instance.loginRoom(
        roomId,
        user,
        config: roomConfig,
      );

      if (result.errorCode == 0) {
        _currentRoomId = roomId;
        // Start sound level monitoring every 200ms
        await ZegoExpressEngine.instance.startSoundLevelMonitor(
          config: ZegoSoundLevelConfig(200, false),
        );
        debugPrint('[ZegoVoiceService] Logged in to room $roomId successfully');
        return true;
      } else {
        debugPrint('[ZegoVoiceService] loginRoom failed: code ${result.errorCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[ZegoVoiceService] loginRoom exception: $e');
      return false;
    }
  }

  /// Start publishing microphone audio (when taking a seat)
  Future<bool> startSpeaking({
    required String userId,
    required int seatIndex,
  }) async {
    if (_currentRoomId == null) return false;

    // Check microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return false;
    }

    try {
      _myStreamId = 'stream_${_currentRoomId}_user_${userId}_seat_$seatIndex';
      await ZegoExpressEngine.instance.startPublishingStream(_myStreamId!);
      await ZegoExpressEngine.instance.muteMicrophone(_isMuted);
      _isPublishing = true;
      if (_isMuted) {
        mySoundLevelNotifier.value = 0.0;
      }
      debugPrint('[ZegoVoiceService] Started publishing stream: $_myStreamId (muted: $_isMuted)');
      return true;
    } catch (e) {
      debugPrint('[ZegoVoiceService] startSpeaking error: $e');
      return false;
    }
  }

  /// Stop publishing microphone audio (when leaving a seat to become audience)
  Future<void> stopSpeaking() async {
    if (!_isPublishing) return;

    try {
      if (_myStreamId != null) {
        await ZegoExpressEngine.instance.stopPublishingStream();
        _myStreamId = null;
      }
      await ZegoExpressEngine.instance.muteMicrophone(true);
      _isPublishing = false;
      _isMuted = false;
      mySoundLevelNotifier.value = 0.0;
      debugPrint('[ZegoVoiceService] Stopped publishing stream (Audience mode)');
    } catch (e) {
      debugPrint('[ZegoVoiceService] stopSpeaking error: $e');
    }
  }

  /// Toggle microphone mute
  Future<bool> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) {
      mySoundLevelNotifier.value = 0.0;
    }
    if (_isPublishing) {
      try {
        await ZegoExpressEngine.instance.muteMicrophone(_isMuted);
      } catch (e) {
        debugPrint('[ZegoVoiceService] toggleMute error: $e');
      }
    }
    return _isMuted;
  }

  /// Explicitly set microphone mute state (e.g. when muted by admin or host)
  Future<void> setMuted(bool mute) async {
    _isMuted = mute;
    if (mute) {
      mySoundLevelNotifier.value = 0.0;
    }
    if (!_isPublishing) return;

    try {
      await ZegoExpressEngine.instance.muteMicrophone(mute);
    } catch (e) {
      debugPrint('[ZegoVoiceService] setMuted error: $e');
    }
  }

  /// Leave room and reset engine state
  Future<void> leaveRoom() async {
    if (_currentRoomId == null) return;

    try {
      await stopBackgroundMusic();
      await stopSpeaking();
      await ZegoExpressEngine.instance.stopSoundLevelMonitor();
      await ZegoExpressEngine.instance.logoutRoom(_currentRoomId!);
      _currentRoomId = null;
      soundLevelsNotifier.value = {};
      mySoundLevelNotifier.value = 0.0;
      debugPrint('[ZegoVoiceService] Left room and cleared engine state');
    } catch (e) {
      debugPrint('[ZegoVoiceService] leaveRoom error: $e');
    }
  }

  /// Starts playing background music streamed into Aux (so other participants in room hear it).
  Future<bool> playBackgroundMusic(String url, {double volume = 0.85, bool playLocally = false}) async {
    try {
      await ensureInitialized();
      _mediaPlayer ??= await ZegoExpressEngine.instance.createMediaPlayer();
      if (_mediaPlayer != null) {
        await _mediaPlayer!.enableAux(true);
        // muteLocal(!playLocally): if just_audio is playing locally, mute Zego local playback to avoid echo.
        // If just_audio failed or playLocally is requested, unmute local so user hears audio.
        await _mediaPlayer!.muteLocal(!playLocally);
        final publishVol = (volume * 100).round().clamp(0, 100);
        await _mediaPlayer!.setPublishVolume(publishVol);
        if (playLocally) {
          await _mediaPlayer!.setPlayVolume(publishVol);
        }
        await _mediaPlayer!.stop();

        String loadPath = url;
        if (loadPath.startsWith('file://')) {
          loadPath = Uri.parse(loadPath).toFilePath();
        }

        final res = await _mediaPlayer!.loadResource(loadPath);
        if (res.errorCode == 0) {
          // In ZegoExpressEngine, properties like enableRepeat, enableAux, and volume
          // MUST be applied AFTER loadResource has succeeded!
          await _mediaPlayer!.enableRepeat(false);
          await _mediaPlayer!.enableAux(true);
          await _mediaPlayer!.muteLocal(!playLocally);
          final publishVol = (volume * 100).round().clamp(0, 100);
          await _mediaPlayer!.setPublishVolume(publishVol);
          if (playLocally) {
            await _mediaPlayer!.setPlayVolume(publishVol);
          }
          await _mediaPlayer!.setProgressInterval(500);
          try {
            _mediaPlayerTotalDurationMs = await _mediaPlayer!.getTotalDuration();
          } catch (_) {
            _mediaPlayerTotalDurationMs = 0;
          }
          await _mediaPlayer!.start();
          // Reinforce repeat false after start to guarantee single play
          await _mediaPlayer!.enableRepeat(false);
          debugPrint('[ZegoVoiceService] Background music Aux started: $loadPath (duration: $_mediaPlayerTotalDurationMs ms, playLocally: $playLocally)');
          return true;
        } else {
          debugPrint('[ZegoVoiceService] MediaPlayer loadResource returned: ${res.errorCode}');
        }
      }
    } catch (e) {
      debugPrint('[ZegoVoiceService] playBackgroundMusic error: $e');
    }
    return false;
  }

  /// Sets whether Zego media player plays locally on the device speaker
  Future<void> setMediaPlayerMuteLocal(bool mute) async {
    try {
      await _mediaPlayer?.muteLocal(mute);
    } catch (e) {
      debugPrint('[ZegoVoiceService] setMediaPlayerMuteLocal error: $e');
    }
  }

  /// Pauses the Aux background music stream.
  Future<void> pauseBackgroundMusic() async {
    try {
      await _mediaPlayer?.pause();
    } catch (e) {
      debugPrint('[ZegoVoiceService] pauseBackgroundMusic error: $e');
    }
  }

  /// Resumes the Aux background music stream.
  Future<void> resumeBackgroundMusic() async {
    try {
      await _mediaPlayer?.resume();
    } catch (e) {
      debugPrint('[ZegoVoiceService] resumeBackgroundMusic error: $e');
    }
  }

  /// Stops Aux background music and releases resource.
  Future<void> stopBackgroundMusic() async {
    try {
      await _mediaPlayer?.stop();
    } catch (e) {
      debugPrint('[ZegoVoiceService] stopBackgroundMusic error: $e');
    }
  }

  /// Sets publish volume for Aux background music.
  Future<void> setMusicPublishVolume(double volume) async {
    try {
      final publishVol = (volume * 100).round().clamp(0, 100);
      await _mediaPlayer?.setPublishVolume(publishVol);
      await _mediaPlayer?.setPlayVolume(publishVol);
    } catch (e) {
      debugPrint('[ZegoVoiceService] setMusicPublishVolume error: $e');
    }
  }

  /// Sets repeat playback for background music.
  Future<void> enableRepeat(bool enable) async {
    try {
      await _mediaPlayer?.enableRepeat(enable);
    } catch (e) {
      debugPrint('[ZegoVoiceService] enableRepeat error: $e');
    }
  }

  /// Set Voice Changer preset
  Future<void> setVoiceChanger(ZegoVoiceChangerPreset preset) async {
    try {
      await ZegoExpressEngine.instance.setVoiceChangerPreset(preset);
    } catch (e) {
      debugPrint('[ZegoVoiceService] setVoiceChanger error: $e');
    }
  }

  /// Set Reverb preset
  Future<void> setReverb(ZegoReverbPreset preset) async {
    try {
      await ZegoExpressEngine.instance.setReverbPreset(preset);
    } catch (e) {
      debugPrint('[ZegoVoiceService] setReverb error: $e');
    }
  }
}
