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
      await ZegoExpressEngine.instance.muteMicrophone(false);
      _isPublishing = true;
      _isMuted = false;
      debugPrint('[ZegoVoiceService] Started publishing stream: $_myStreamId');
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
    if (!_isPublishing) return false;

    try {
      _isMuted = !_isMuted;
      await ZegoExpressEngine.instance.muteMicrophone(_isMuted);
      if (_isMuted) {
        mySoundLevelNotifier.value = 0.0;
      }
      return _isMuted;
    } catch (e) {
      debugPrint('[ZegoVoiceService] toggleMute error: $e');
      return _isMuted;
    }
  }

  /// Leave room and reset engine state
  Future<void> leaveRoom() async {
    if (_currentRoomId == null) return;

    try {
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
