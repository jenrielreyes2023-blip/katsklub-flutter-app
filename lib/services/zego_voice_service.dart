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

  /// Observable media player state (NoPlay, Playing, Pausing, PlayEnded)
  final ValueNotifier<ZegoMediaPlayerState> mediaPlayerStateNotifier =
      ValueNotifier<ZegoMediaPlayerState>(ZegoMediaPlayerState.NoPlay);

  /// Observable media player playback progress
  final ValueNotifier<Duration> mediaPlayerProgressNotifier =
      ValueNotifier<Duration>(Duration.zero);

  /// Observable media player total track duration
  final ValueNotifier<Duration> mediaPlayerDurationNotifier =
      ValueNotifier<Duration>(Duration.zero);

  int _lastLoggedProgressSec = -1;

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

      // Diagnostic 4: State listener logging all transitions
      ZegoExpressEngine.onMediaPlayerStateUpdate =
          (ZegoMediaPlayer mediaPlayer, ZegoMediaPlayerState state, int errorCode) {
        debugPrint('[ZegoVoiceService] [STATE-UPDATE] onMediaPlayerStateUpdate: state=$state, errorCode=$errorCode');
        mediaPlayerStateNotifier.value = state;
        if (state == ZegoMediaPlayerState.PlayEnded) {
          debugPrint('[ZegoVoiceService] [STATE-UPDATE] Track reached PlayEnded. Firing onMusicCompleted');
          onMusicCompleted?.call();
        }
      };

      // Diagnostic 4: Network buffering event listener
      ZegoExpressEngine.onMediaPlayerNetworkEvent =
          (ZegoMediaPlayer mediaPlayer, ZegoMediaPlayerNetworkEvent networkEvent) {
        debugPrint('[ZegoVoiceService] [NETWORK-EVENT] onMediaPlayerNetworkEvent: $networkEvent (buffering: ${networkEvent == ZegoMediaPlayerNetworkEvent.BufferBegin})');
      };

      // Diagnostic 4: Playback progress listener (logs every 5 seconds)
      ZegoExpressEngine.onMediaPlayerPlayingProgress =
          (ZegoMediaPlayer mediaPlayer, int millisecond) {
        final progress = Duration(milliseconds: millisecond);
        mediaPlayerProgressNotifier.value = progress;
        final sec = progress.inSeconds;
        if (sec % 5 == 0 && sec != _lastLoggedProgressSec) {
          _lastLoggedProgressSec = sec;
          debugPrint('[ZegoVoiceService] [PROGRESS] Active playback progress: ${sec}s / ${(_mediaPlayerTotalDurationMs / 1000).toStringAsFixed(0)}s');
        }
      };

      // Diagnostic 4: First frame event listener
      ZegoExpressEngine.onMediaPlayerFirstFrameEvent =
          (ZegoMediaPlayer mediaPlayer, ZegoMediaPlayerFirstFrameEvent event) {
        debugPrint('[ZegoVoiceService] [FIRST-FRAME] onMediaPlayerFirstFrameEvent: $event (audio frame received/decoded)');
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
    final micGranted = status.isGranted;

    try {
      _myStreamId = 'stream_${_currentRoomId}_user_${userId}_seat_$seatIndex';
      await ZegoExpressEngine.instance.startPublishingStream(_myStreamId!);
      await ZegoExpressEngine.instance.muteMicrophone(!micGranted || _isMuted);
      _isPublishing = true;
      if (_isMuted || !micGranted) {
        mySoundLevelNotifier.value = 0.0;
      }
      debugPrint('[ZegoVoiceService] Started publishing stream: $_myStreamId (micGranted: $micGranted, muted: $_isMuted)');
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

  /// Starts playing background music streamed into Aux (so participants in room hear it)
  /// and played locally so the host monitors the audio directly.
  Future<bool> playBackgroundMusic(
    String url, {
    double volume = 0.85,
    bool playLocally = true,
  }) async {
    try {
      await ensureInitialized();

      // Diagnostic 2: Ensure ZegoMediaPlayer instance exists and log creation
      if (_mediaPlayer == null) {
        _mediaPlayer = await ZegoExpressEngine.instance.createMediaPlayer();
        debugPrint('[ZegoVoiceService] createMediaPlayer() invoked -> ${_mediaPlayer != null ? "SUCCESS (index=${_mediaPlayer!.getIndex()})" : "FAILED (null)"}');
      }
      if (_mediaPlayer == null) {
        debugPrint('[ZegoVoiceService] [DIAGNOSTIC-ERROR] Engine failed to create ZegoMediaPlayer instance!');
        return false;
      }

      final player = _mediaPlayer!;

      // Diagnostic 1: URL inspection & signed Bunny CDN signature verification
      String loadPath = url.trim();
      if (loadPath.startsWith('file://')) {
        loadPath = Uri.parse(loadPath).toFilePath();
      }

      debugPrint('================================================================');
      debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] playBackgroundMusic: URL verification');
      debugPrint('[ZegoVoiceService] Load URL: $loadPath');

      final parsedUri = Uri.tryParse(loadPath);
      if (parsedUri != null) {
        final token = parsedUri.queryParameters['token'];
        final expires = parsedUri.queryParameters['expires'];
        final isBunny = parsedUri.host.contains('b-cdn.net');
        debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] Host: ${parsedUri.host}, Path: ${parsedUri.path}');
        debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] Is Bunny CDN: $isBunny, Has Token: ${token != null}, Expires: $expires');

        if (expires != null) {
          final expInt = int.tryParse(expires);
          if (expInt != null) {
            final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final remainingSec = expInt - nowSec;
            if (remainingSec <= 0) {
              debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] ⚠️ WARNING: Bunny CDN URL signature is EXPIRED! (${remainingSec.abs()}s ago). HTTP 403 will occur.');
            } else {
              debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] ✅ Signed Bunny URL signature is VALID (remaining: ${remainingSec}s / ${(remainingSec / 60).toStringAsFixed(1)} mins)');
            }
          }
        }
      }

      // Diagnostic 2: Verify active RTC stream publishing
      debugPrint('[ZegoVoiceService] [DIAGNOSTIC 2] Stream publishing status: isPublishing=$_isPublishing, streamId=$_myStreamId');
      if (!_isPublishing) {
        if (_currentRoomId != null) {
          final streamId = _myStreamId ?? 'stream_${_currentRoomId}_host_stream';
          _myStreamId = streamId;
          debugPrint('[ZegoVoiceService] Auto-starting stream publishing ($streamId) so Aux audio can reach room guests!');
          await ZegoExpressEngine.instance.startPublishingStream(streamId);
          _isPublishing = true;
        } else {
          debugPrint('[ZegoVoiceService] [DIAGNOSTIC 2] ⚠️ WARNING: Host is NOT currently publishing an RTC stream. enableAux mixes audio into the published stream — remote guests will not hear audio until a stream is published!');
        }
      }

      // Halt any active playback before calling loadResource (required by Zego SDK)
      await player.stop();

      // Diagnostic 1: Call loadResource and thoroughly log the return result
      debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] Calling player.loadResource($loadPath)...');
      final res = await player.loadResource(loadPath);
      debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] loadResource result: errorCode=${res.errorCode}');

      if (res.errorCode != 0) {
        final errorMsg = _getZegoMediaPlayerErrorMessage(res.errorCode);
        debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] ❌ ERROR: loadResource FAILED with code ${res.errorCode}: $errorMsg');
        debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] Audio path failed. Playback will NOT start. UI must reflect failure.');
        debugPrint('================================================================');
        return false;
      }
      debugPrint('[ZegoVoiceService] [DIAGNOSTIC 1] ✅ loadResource SUCCEEDED (errorCode=0)');

      // Enable Aux so Zego Express Engine mixes media player audio into the host's published RTC stream!
      // This allows all room guests, audience members, and seated users to hear the music loud and clear!
      final publishVol = (volume * 100).round().clamp(1, 100);
      final playVol = playLocally ? publishVol : 0;

      debugPrint('[ZegoVoiceService] Configuring audio pipeline before start():');
      debugPrint('[ZegoVoiceService] - Host plays locally (volume: $playVol), Aux ENABLED with publishVolume: $publishVol to room guests');

      await player.enableRepeat(false);
      await player.enableAux(true);
      await player.setPublishVolume(publishVol);
      await player.setPlayVolume(playVol);
      await player.muteLocal(!playLocally);
      await player.setProgressInterval(1000);

      try {
        _mediaPlayerTotalDurationMs = await player.getTotalDuration();
        mediaPlayerDurationNotifier.value = Duration(milliseconds: _mediaPlayerTotalDurationMs);
      } catch (_) {
        _mediaPlayerTotalDurationMs = 0;
      }

      // Diagnostic 3: Call start() AFTER loadResource succeeds
      debugPrint('[ZegoVoiceService] Calling player.start()...');
      await player.start();

      // Re-apply aux and volumes after start() because native audio device init can reset routing
      await player.enableAux(true);
      await player.setPublishVolume(publishVol);
      await player.setPlayVolume(playVol);
      await player.muteLocal(!playLocally);

      final verifiedState = await player.getCurrentState();
      final verifiedPublishVol = await player.getPublishVolume();
      final verifiedPlayVol = await player.getPlayVolume();

      debugPrint('[ZegoVoiceService] [DIAGNOSTIC 3 & 4] Playback pipeline initialized:');
      debugPrint('[ZegoVoiceService] - Current State: $verifiedState');
      debugPrint('[ZegoVoiceService] - Verified Publish Volume: $verifiedPublishVol (Aux to guests)');
      debugPrint('[ZegoVoiceService] - Verified Play Volume: $verifiedPlayVol (Local to host)');
      debugPrint('[ZegoVoiceService] - Total Duration: ${_mediaPlayerTotalDurationMs}ms');
      debugPrint('[ZegoVoiceService] - Play Locally: $playLocally');
      debugPrint('================================================================');

      mediaPlayerStateNotifier.value = verifiedState;
      return verifiedState == ZegoMediaPlayerState.Playing;
    } catch (e) {
      debugPrint('[ZegoVoiceService] playBackgroundMusic exception: $e');
      return false;
    }
  }

  /// Maps known Zego MediaPlayer error codes to human-readable explanations
  String _getZegoMediaPlayerErrorMessage(int code) {
    switch (code) {
      case 1008001:
        return 'No MediaPlayer instance (MediaPlayerNoInstance)';
      case 1008003:
        return 'No file path provided (MediaPlayerNoFilePath)';
      case 1008004:
        return 'File path exceeds 1024 bytes (MediaPlayerFilePathTooLong)';
      case 1008005:
        return 'Unsupported audio format (MediaPlayerFileFormatError)';
      case 1008006:
        return 'File path does not exist / 403 Forbidden / 404 Not Found (MediaPlayerFilePathNotExists)';
      case 1008007:
        return 'Audio decoding failed (MediaPlayerFileDecodeError)';
      case 1008008:
        return 'No supported audio stream in media (MediaPlayerFileNoSupportedStream)';
      case 1008009:
        return 'Media file expired (MediaPlayerFileExpired)';
      case 1008010:
        return 'Demux error resolving audio stream (MediaPlayerDemuxError)';
      case 1008013:
        return 'User cancelled (MediaPlayerUserCancel)';
      case 1008014:
        return 'Player already started, call stop first (MediaPlayerAlreadyStart)';
      case 1008015:
        return 'Permission denied reading resource (MediaPlayerPermissionDenied)';
      default:
        return 'Unknown Zego error code $code';
    }
  }

  /// Sets whether Zego media player plays locally on the device speaker
  Future<void> setMediaPlayerMuteLocal(bool mute) async {
    try {
      await _mediaPlayer?.muteLocal(mute);
      if (mute) {
        await _mediaPlayer?.setPlayVolume(0);
      }
      debugPrint('[ZegoVoiceService] setMediaPlayerMuteLocal: mute=$mute');
    } catch (e) {
      debugPrint('[ZegoVoiceService] setMediaPlayerMuteLocal error: $e');
    }
  }

  /// Pauses the Aux background music stream.
  Future<void> pauseBackgroundMusic() async {
    try {
      await _mediaPlayer?.pause();
      mediaPlayerStateNotifier.value = ZegoMediaPlayerState.Pausing;
      debugPrint('[ZegoVoiceService] pauseBackgroundMusic called');
    } catch (e) {
      debugPrint('[ZegoVoiceService] pauseBackgroundMusic error: $e');
    }
  }

  /// Resumes the Aux background music stream.
  Future<void> resumeBackgroundMusic() async {
    try {
      await _mediaPlayer?.resume();
      mediaPlayerStateNotifier.value = ZegoMediaPlayerState.Playing;
      debugPrint('[ZegoVoiceService] resumeBackgroundMusic called');
    } catch (e) {
      debugPrint('[ZegoVoiceService] resumeBackgroundMusic error: $e');
    }
  }

  /// Stops Aux background music and releases resource.
  Future<void> stopBackgroundMusic() async {
    try {
      await _mediaPlayer?.stop();
      mediaPlayerStateNotifier.value = ZegoMediaPlayerState.NoPlay;
      mediaPlayerProgressNotifier.value = Duration.zero;
      debugPrint('[ZegoVoiceService] stopBackgroundMusic called');
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
      debugPrint('[ZegoVoiceService] setMusicPublishVolume: publish=$publishVol, play=$publishVol');
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
