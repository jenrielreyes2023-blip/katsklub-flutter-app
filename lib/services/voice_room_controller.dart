import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../models/user.dart';
import '../models/voice_room.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'feed_service.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'zego_voice_service.dart';
import 'global_audio_player_service.dart';
import 'voice_room_foreground_service.dart';
import '../models/voice_room_music_track.dart';

/// Builds the local-playback audio source for voice-room music.
@visibleForTesting
AudioSource buildVoiceRoomAudioSource({
  required Uri uri,
  Map<String, String>? headers,
  required String id,
  required String title,
  required String artist,
  required String artworkUrl,
}) {
  return AudioSource.uri(
    uri,
    headers: headers,
  );
}

/// Runs one stage of voice-room music startup with a timeout so a lost
/// platform response can never hang playback startup (and its loading UI)
/// forever. Logs breadcrumbs to pinpoint slow stages in logcat.
@visibleForTesting
Future<T> runMusicStage<T>(
  String stage,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  debugPrint('[VoiceRoomController] stage start: $stage');
  try {
    final result = await action().timeout(timeout);
    debugPrint('[VoiceRoomController] stage done: $stage');
    return result;
  } catch (e) {
    debugPrint('[VoiceRoomController] stage failed: $stage ($e)');
    rethrow;
  }
}

/// Global Singleton Controller for active Voice Room state, Socket.io signaling, and UI overlays.
class VoiceRoomController extends ChangeNotifier {
  factory VoiceRoomController() => _instance;
  VoiceRoomController._internal();
  static final VoiceRoomController _instance = VoiceRoomController._internal();

  /// Optional hooks to silence other audio sources (profile music, media players, etc.)
  static final List<VoidCallback> _silenceAudioHooks = [];

  /// Callback registered by the active UI overlay to restore VoiceRoomScreen
  static VoidCallback? onOpenActiveRoom;

  /// Restores active room to full screen
  static void openActiveRoom() {
    final controller = VoiceRoomController();
    if (controller.currentRoom == null) return;
    controller.maximize();
    onOpenActiveRoom?.call();
  }

  static void addSilenceAudioHook(VoidCallback hook) {
    if (!_silenceAudioHooks.contains(hook)) {
      _silenceAudioHooks.add(hook);
    }
  }

  static void removeSilenceAudioHook(VoidCallback hook) {
    _silenceAudioHooks.remove(hook);
  }

  static void silenceExternalAudio() {
    try {
      GlobalAudioPlayerService.instance.setPlaying(false);
    } catch (_) {}
    for (final hook in List<VoidCallback>.from(_silenceAudioHooks)) {
      try {
        hook();
      } catch (e) {
        debugPrint('[VoiceRoomController] silenceExternalAudio error: $e');
      }
    }
  }

  VoiceRoom? _currentRoom;
  User? _currentUser;
  bool _isMinimized = false;
  int? _mySeatIndex;
  bool _isMuted = false;
  bool _isHostMuted = false;
  double _hostSoundLevel = 0.0;

  final List<VoiceRoomMessage> _messages = [];
  final Map<String, DateTime> _recentJoinTimestamps = {};
  VoiceRoomGift? _activePlayingGift;
  VoiceRoomUser? _activeGiftSender;
  VoiceRoomUser? _activeGiftReceiver;
  int _giftPlayToken = 0;
  bool _isMusicEnabled = false;
  StreamSubscription<PlayerState>? _roomMusicPlayerStateSub;
  StreamSubscription<Duration?>? _roomMusicPlayerDurationSub;
  VoiceRoomMusicTrack? _roomCdnTrack;
  Duration? _roomMusicCurrentDuration;
  bool _isRoomMusicPlaying = false;
  bool _isRoomMusicLoading = false;
  double _roomMusicVolume = 0.85;
  bool _localPlaybackActive = false;

  VoiceRoom? get currentRoom => _currentRoom;
  User? get currentUser => _currentUser ?? AuthService().currentUser;
  bool get isMinimized => _isMinimized;
  int? get mySeatIndex => _mySeatIndex;
  bool get isMuted => _isMuted;
  bool get isSeated => _mySeatIndex != null && _mySeatIndex != 99;
  bool get isOnMic => isHost || isSeated;
  double get hostSoundLevel => isHost ? (ZegoVoiceService().mySoundLevelNotifier.value) : _hostSoundLevel;
  bool get isHostMuted => isHost ? _isMuted : _isHostMuted;
  int get giftPlayToken => _giftPlayToken;
  bool get isMusicEnabled => _isMusicEnabled;
  VoiceRoomMusicTrack? get roomCdnTrack => _roomCdnTrack;
  Duration? get roomMusicCurrentDuration => _roomMusicCurrentDuration;
  String get roomMusicTitle => _roomCdnTrack?.title ?? '';
  String get roomMusicArtist => _roomCdnTrack?.artist ?? '';
  String get roomMusicArtwork => _roomCdnTrack?.artworkUrl ?? '';
  bool get isRoomMusicPlaying => _isRoomMusicPlaying;
  bool get isRoomMusicLoading => _isRoomMusicLoading;
  double get roomMusicVolume => _roomMusicVolume;

  final List<VoiceRoomMusicTrack> _musicQueue = [];
  List<VoiceRoomMusicTrack> get musicQueue => List.unmodifiable(_musicQueue);
  int _currentQueueIndex = -1;
  int get currentQueueIndex => _currentQueueIndex;

  void addToQueue(VoiceRoomMusicTrack track) {
    if (_currentRoom == null) return;
    final socket = FeedService.getSocket();
    final user = currentUser;
    final payload = {
      'roomId': _currentRoom!.id,
      'track': track.toJson(),
      'userId': user?.id,
      'user': {
        'id': user?.id,
        'username': user?.username,
        'fullName': user?.fullName ?? user?.username,
        'avatarUrl': user?.avatarUrl ?? '',
      },
    };

    if (socket != null && socket.connected) {
      debugPrint('[VoiceRoomController] 🎵 Emitting voice_room:music_queue_add: roomId=${_currentRoom!.id}, track=${track.title}, userId=${user?.id}');
      socket.emit('voice_room:music_queue_add', payload);
    } else {
      debugPrint('[VoiceRoomController] ⚠️ Socket not yet connected for addToQueue. Hooking onSocketReady...');
      FeedService.onSocketReady((s) {
        if (s.connected && _currentRoom != null) {
          debugPrint('[VoiceRoomController] Socket ready -> emitting queued voice_room:music_queue_add: track=${track.title}');
          s.emit('voice_room:music_queue_add', payload);
        }
      });
    }
  }

  void removeFromQueue(int index) {
    if (_currentRoom == null) return;
    if (index >= 0 && index < _musicQueue.length) {
      final track = _musicQueue[index];
      final socket = FeedService.getSocket();
      final user = currentUser;
      final payload = {
        'roomId': _currentRoom!.id,
        'trackId': track.id,
        'index': index,
        'userId': user?.id,
        'user': {
          'id': user?.id,
          'username': user?.username,
        },
      };

      if (socket != null && socket.connected) {
        debugPrint('[VoiceRoomController] 🗑️ Emitting voice_room:music_queue_remove: roomId=${_currentRoom!.id}, trackId=${track.id}, index=$index, userId=${user?.id}');
        socket.emit('voice_room:music_queue_remove', payload);
      }
    }
  }

  void clearQueue() {
    if (!isHost || _currentRoom == null) return;
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:music_queue_clear', {
        'roomId': _currentRoom!.id,
      });
    }
  }

  Future<void> playQueueIndex(int index) async {
    if (!isHost || _currentRoom == null) return;
    if (index >= 0 && index < _musicQueue.length) {
      _currentQueueIndex = index;
      await playCdnMusic(_musicQueue[index], queueIndex: index);
    }
  }

  bool _isAdvancingQueue = false;

  /// Triggered automatically when Zego media player completes the track.
  Future<void> _onTrackCompleted({bool fromZego = false}) async {
    if (!isHost) return;
    if (_isAdvancingQueue) return;
    _isAdvancingQueue = true;
    try {
      debugPrint('[VoiceRoomController] Host auto-advancing queue (total in queue: ${_musicQueue.length}, current index: $_currentQueueIndex)');
      await skipToNextMusic();
    } catch (e) {
      debugPrint('[VoiceRoomController] _onTrackCompleted error: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 1500));
      _isAdvancingQueue = false;
    }
  }

  Future<void> skipToNextMusic() async {
    if (!isHost) return;
    if (_musicQueue.isEmpty) {
      await stopRoomMusic();
      return;
    }

    if (_currentQueueIndex >= 0 && _currentQueueIndex + 1 < _musicQueue.length) {
      _currentQueueIndex++;
    } else {
      _currentQueueIndex = 0;
    }

    final next = _musicQueue[_currentQueueIndex];
    debugPrint('[VoiceRoomController] Host auto-loop queue -> playing index $_currentQueueIndex: ${next.title}');
    await playCdnMusic(next, queueIndex: _currentQueueIndex);
  }

  Future<void> skipToPreviousMusic() async {
    if (!isHost) return;
    if (_musicQueue.isEmpty) return;

    if (_currentQueueIndex > 0) {
      _currentQueueIndex--;
    } else {
      _currentQueueIndex = _musicQueue.length - 1;
    }

    final prev = _musicQueue[_currentQueueIndex];
    debugPrint('[VoiceRoomController] Host previous track -> playing index $_currentQueueIndex: ${prev.title}');
    await playCdnMusic(prev, queueIndex: _currentQueueIndex);
  }

  void toggleMusicEnabled([bool? enable]) {
    if (!isHost || _currentRoom == null) return;
    final target = enable ?? !_isMusicEnabled;
    if (!target) {
      unawaited(_stopLocalMusicInternal());
    }
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:music_toggle', {
        'roomId': _currentRoom!.id,
        'isEnabled': target,
      });
    }
  }

  Future<void> playCdnMusic(VoiceRoomMusicTrack track, {int? queueIndex}) async {
    // SINGLE SOURCE OF TRUTH: Only host plays audio & streams via Zego Aux
    if (!isHost) {
      addToQueue(track);
      return;
    }

    _roomCdnTrack = track;
    final qIdx = queueIndex ?? _musicQueue.indexWhere((t) => t.id == track.id);
    if (qIdx != -1) {
      _currentQueueIndex = qIdx;
    } else {
      _musicQueue.add(track);
      _currentQueueIndex = _musicQueue.length - 1;
    }
    _isMusicEnabled = true;
    _isRoomMusicLoading = true;
    _isRoomMusicPlaying = false; // Do not show playing until audio path confirms success!
    notifyListeners();

    try {
      final streamUrl = track.streamUrl;
      debugPrint('[VoiceRoomController] Starting playback for track: "${track.title}" by "${track.artist}"');
      debugPrint('[VoiceRoomController] Stream URL: $streamUrl');

      // Primary Audio Path: Stream into Zego RTC Aux for guests AND monitor locally for host!
      final zegoSuccess = await ZegoVoiceService().playBackgroundMusic(
        streamUrl,
        volume: _roomMusicVolume,
        playLocally: true, // Crucial: Host hears music directly via ZegoMediaPlayer
      );

      if (!zegoSuccess) {
        debugPrint('[VoiceRoomController] ❌ ZegoVoiceService failed to play track. Aborting.');
        _localPlaybackActive = false;
        _isRoomMusicPlaying = false;
        _isRoomMusicLoading = false;
        notifyListeners();
        return;
      }

      _localPlaybackActive = true;
      _isRoomMusicPlaying = true;
      _isRoomMusicLoading = false;
      _roomMusicCurrentDuration = ZegoVoiceService().mediaPlayerDurationNotifier.value;
      notifyListeners();

      // Emit track change to socket (Single Source of Truth)
      final socket = FeedService.getSocket();
      if (socket != null && socket.connected && _currentRoom != null) {
        socket.emit('voice_room:music_play', {
          'roomId': _currentRoom!.id,
          'track': track.toJson(),
          'queueIndex': _currentQueueIndex,
        });
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] playCdnMusic error: $e');
      _isRoomMusicPlaying = false;
    } finally {
      _isRoomMusicLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePauseRoomMusic() async {
    if (!isHost) return;
    if (_roomCdnTrack == null) return;
    try {
      final targetPlaying = !_isRoomMusicPlaying;
      if (!targetPlaying) {
        await ZegoVoiceService().pauseBackgroundMusic();
        _isRoomMusicPlaying = false;
      } else {
        await ZegoVoiceService().resumeBackgroundMusic();
        _isRoomMusicPlaying = true;
      }
      notifyListeners();

      final socket = FeedService.getSocket();
      if (socket != null && socket.connected && _currentRoom != null) {
        socket.emit('voice_room:music_pause', {
          'roomId': _currentRoom!.id,
          'isPlaying': _isRoomMusicPlaying,
        });
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] togglePauseRoomMusic error: $e');
    }
  }

  Future<void> _stopLocalMusicInternal() async {
    try {
      await _roomMusicPlayerStateSub?.cancel();
      _roomMusicPlayerStateSub = null;
      await _roomMusicPlayerDurationSub?.cancel();
      _roomMusicPlayerDurationSub = null;
      _localPlaybackActive = false;
      _isRoomMusicPlaying = false;
      _isRoomMusicLoading = false;
      await ZegoVoiceService().stopBackgroundMusic();
      await GlobalAudioPlayerService.instance.stopVoiceRoomMusic();
    } catch (e) {
      debugPrint('[VoiceRoomController] _stopLocalMusicInternal error: $e');
    }
  }

  Future<void> stopRoomMusic() async {
    if (!isHost) return;
    await _stopLocalMusicInternal();
    _roomCdnTrack = null;
    _currentQueueIndex = -1;
    notifyListeners();

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected && _currentRoom != null) {
      socket.emit('voice_room:music_pause', {
        'roomId': _currentRoom!.id,
        'isPlaying': false,
      });
    }
  }

  Future<void> setRoomMusicVolume(double volume) async {
    _roomMusicVolume = volume.clamp(0.0, 1.0);
    try {
      await GlobalAudioPlayerService.instance.setVolume(_roomMusicVolume);
      await ZegoVoiceService().setMusicPublishVolume(_roomMusicVolume);
    } catch (_) {}
    notifyListeners();
  }

  bool get isHost {
    try {
      final room = _currentRoom;
      if (room == null) return false;
      final user = currentUser;
      if (user == null) return false;
      final hostId = room.host.id.toString().trim();
      final myId = user.id?.toString().trim();
      return myId != null && myId.isNotEmpty && myId == hostId;
    } catch (_) {
      return false;
    }
  }

  bool get isHostInRoom {
    try {
      if (_currentRoom == null) return false;
      // If the local user is the host and the room is active in this controller,
      // the host is ALWAYS in the room (even when minimized or running in background).
      if (isHost) return true;
      return _currentRoom!.isHostInRoom == true;
    } catch (_) {
      return false;
    }
  }

  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    if (_currentRoom == null) return;
    final socket = FeedService.getSocket();
    final user = currentUser;
    if (socket != null && socket.connected && user != null) {
      socket.emit('voice_room:heartbeat', {
        'roomId': _currentRoom!.id,
        'userId': user.id,
        'isHost': isHost,
      });
    }
  }
  List<VoiceRoomMessage> get messages => List.unmodifiable(_messages);
  VoiceRoomGift? get activePlayingGift => _activePlayingGift;
  VoiceRoomUser? get activeGiftSender => _activeGiftSender;
  VoiceRoomUser? get activeGiftReceiver => _activeGiftReceiver;

  StreamSubscription? _soundSubscription;

  /// Dissolves the current room or specified room (Host only, temporary rooms only)
  Future<bool> dissolveRoom([int? targetRoomId]) async {
    final room = _currentRoom;
    if (room != null && room.isPermanent) {
      debugPrint('[VoiceRoomController] Permanent rooms cannot be dissolved');
      return false;
    }
    final roomId = targetRoomId ?? room?.id;
    if (roomId == null) return false;

    try {
      final token = await AuthService().getToken();
      var res = await http.post(
        ApiConfig.uri('/api/voice-rooms/$roomId/close'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 404) {
        res = await http.post(
          ApiConfig.uri('/api/voice-rooms/$roomId/dissolve'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
      }

      if (res.statusCode == 200) {
        if (_currentRoom?.id == roomId) {
          await leaveRoom();
        }
        return true;
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] dissolveRoom error: $e');
    }
    return false;
  }

  /// Rename room (Host only)
  Future<bool> renameRoom(String newTitle) async {
    return updateRoomInfo(title: newTitle);
  }

  /// Update room info (title, coverUrl/iconUrl, description)
  Future<bool> updateRoomInfo({String? title, String? coverUrl, String? description}) async {
    if (_currentRoom == null) return false;

    try {
      final token = await AuthService().getToken();
      final res = await http.patch(
        ApiConfig.uri('/api/voice-rooms/${_currentRoom!.id}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          if (coverUrl != null) 'coverUrl': coverUrl.trim(),
          if (description != null) 'description': description.trim(),
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true) {
          _currentRoom = _currentRoom!.copyWith(
            title: title != null && title.trim().isNotEmpty ? title.trim() : _currentRoom!.title,
            coverUrl: coverUrl != null ? coverUrl.trim() : _currentRoom!.coverUrl,
            description: description != null ? description.trim() : _currentRoom!.description,
          );
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] Update room info error: $e');
    }
    return false;
  }

  /// Fetch list of room admins
  Future<List<VoiceRoomUser>> fetchAdmins(int roomId) async {
    try {
      final res = await http.get(ApiConfig.uri('/api/voice-rooms/$roomId/admins'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['admins'] is List) {
          final admins = (data['admins'] as List)
              .map((a) => VoiceRoomUser.fromJson(Map<String, dynamic>.from(a)))
              .toList();
          if (_currentRoom != null && _currentRoom!.id == roomId) {
            _currentRoom = _currentRoom!.copyWith(admins: admins);
            notifyListeners();
          }
          return admins;
        }
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] fetchAdmins error: $e');
    }
    try {
      return _currentRoom?.admins ?? <VoiceRoomUser>[];
    } catch (_) {
      return <VoiceRoomUser>[];
    }
  }

  /// Add a room admin (host only, max 4 admins)
  Future<Map<String, dynamic>> addAdmin(int roomId, {int? targetUserId, String? identifier}) async {
    try {
      final token = await AuthService().getToken();
      final res = await http.post(
        ApiConfig.uri('/api/voice-rooms/$roomId/admins'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (targetUserId != null) 'targetUserId': targetUserId,
          if (identifier != null && identifier.trim().isNotEmpty) 'identifier': identifier.trim(),
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        if (data['admins'] is List) {
          final admins = (data['admins'] as List)
              .map((a) => VoiceRoomUser.fromJson(Map<String, dynamic>.from(a)))
              .toList();
          if (_currentRoom != null && _currentRoom!.id == roomId) {
            _currentRoom = _currentRoom!.copyWith(admins: admins);
            notifyListeners();
          }
        }
        return {'ok': true, 'message': data['message'] ?? 'Admin added'};
      }
      return {'ok': false, 'error': data['error'] ?? 'Failed to add admin'};
    } catch (e) {
      debugPrint('[VoiceRoomController] addAdmin error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Remove a room admin (host only)
  Future<bool> removeAdmin(int roomId, int targetUserId) async {
    try {
      final token = await AuthService().getToken();
      final res = await http.delete(
        ApiConfig.uri('/api/voice-rooms/$roomId/admins/$targetUserId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        if (data['admins'] is List) {
          final admins = (data['admins'] as List)
              .map((a) => VoiceRoomUser.fromJson(Map<String, dynamic>.from(a)))
              .toList();
          if (_currentRoom != null && _currentRoom!.id == roomId) {
            _currentRoom = _currentRoom!.copyWith(admins: admins);
            notifyListeners();
          }
        }
        return true;
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] removeAdmin error: $e');
    }
    return false;
  }

  /// Lock or unlock room (Host only, with optional 4-digit PIN)
  Future<bool> toggleRoomLock(bool isLocked, {String? pin}) async {
    if (_currentRoom == null) return false;

    try {
      final token = await AuthService().getToken();
      final res = await http.patch(
        ApiConfig.uri('/api/voice-rooms/${_currentRoom!.id}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'isLocked': isLocked,
          if (isLocked && pin != null) 'pin': pin.trim(),
        }),
      );

      if (res.statusCode == 200) {
        _currentRoom = _currentRoom!.copyWith(
          isLocked: isLocked,
          hasPin: isLocked && pin != null && pin.trim().isNotEmpty,
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] Toggle lock error: $e');
    }
    return false;
  }

  /// Verify 4-digit PIN to enter locked room
  Future<bool> verifyRoomPin(int roomId, String pin) async {
    try {
      final token = await AuthService().getToken();
      final res = await http.post(
        ApiConfig.uri('/api/voice-rooms/$roomId/verify-pin'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'pin': pin.trim()}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ok'] == true && data['verified'] == true;
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] verifyRoomPin error: $e');
    }
    return false;
  }

  /// Refreshes room details (seats, admins, host presence) directly from the API
  Future<void> refreshRoomDetails([int? targetRoomId]) async {
    final roomId = targetRoomId ?? _currentRoom?.id;
    if (roomId == null) return;

    try {
      final token = await AuthService().getToken();
      final res = await http.get(
        ApiConfig.uri('/api/voice-rooms/$roomId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['room'] is Map && _currentRoom != null && _currentRoom!.id == roomId) {
          final refreshedRoom = VoiceRoom.fromJson(Map<String, dynamic>.from(data['room']));
          final liveAudience = refreshedRoom.audienceCount > 0
              ? refreshedRoom.audienceCount
              : (_currentRoom!.audienceCount > 0 ? _currentRoom!.audienceCount : 1);
          _currentRoom = refreshedRoom.copyWith(
            audienceCount: liveAudience,
            isHostInRoom: isHost ? true : refreshedRoom.isHostInRoom,
          );

          // Re-sync local seat state
          final myId = _currentUser?.id?.toString();
          if (isHost) {
            _mySeatIndex = 99;
          } else if (myId != null) {
            int? foundSeat;
            bool foundMuted = false;
            for (final s in refreshedRoom.seats) {
              if (s.user?.id.toString() == myId) {
                foundSeat = s.seatIndex;
                foundMuted = s.isMuted;
                break;
              }
            }
            if (foundSeat != _mySeatIndex) {
              _mySeatIndex = foundSeat;
              if (foundSeat != null) {
                _isMuted = foundMuted;
                await ZegoVoiceService().startSpeaking(
                  userId: myId,
                  seatIndex: foundSeat,
                );
              } else {
                await ZegoVoiceService().stopSpeaking();
              }
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[VoiceRoomController] refreshRoomDetails error: $e');
    }
  }

  /// Joins a voice room, connects Zego audio, and registers socket listeners
  Future<bool> enterRoom(VoiceRoom room, User user) async {
    // If already in the same room, just un-minimize
    if (_currentRoom?.id == room.id) {
      _isMinimized = false;
      unawaited(VoiceRoomForegroundService.start(
        roomId: room.id.toString(),
        title: 'In a voiceroom. ID: ${room.id}',
        text: 'Tap to return',
      ));
      notifyListeners();
      return true;
    }

    // Silence any playing profile music, playlists, or external media
    silenceExternalAudio();

    // Leave previous room if any
    if (_currentRoom != null) {
      await leaveRoom();
    }

    final isUserHost = room.host.id.toString() == user.id.toString();

    _currentRoom = room.copyWith(
      audienceCount: room.audienceCount > 0 ? room.audienceCount : 1,
      isHostInRoom: isUserHost ? true : room.isHostInRoom,
    );
    _currentUser = user;
    _isMinimized = false;
    _mySeatIndex = null;
    _isMuted = false;
    _isHostMuted = false;
    _hostSoundLevel = 0.0;
    _messages.clear();

    if (isUserHost) {
      // Host automatically occupies the main Stage Seat (seat 99)
      _mySeatIndex = 99;
      _isMuted = false;
      // Ensure host is removed from any guest seats in memory
      for (int i = 0; i < room.seats.length; i++) {
        if (room.seats[i].user?.id.toString() == user.id.toString()) {
          room.seats[i] = room.seats[i].copyWith(clearUser: true, user: null);
        }
      }
    } else {
      // Check if guest is already in a seat in the room
      for (final seat in room.seats) {
        if (seat.user?.id.toString() == user.id.toString()) {
          _mySeatIndex = seat.seatIndex;
          _isMuted = seat.isMuted;
          break;
        }
      }
    }

    // Connect to ZegoCloud RTC
    final zegoOk = await ZegoVoiceService().joinRoom(
      roomId: room.roomCode.isNotEmpty ? room.roomCode : 'room_${room.id}',
      userId: user.id.toString(),
      userName: user.fullName ?? user.username ?? 'User',
    );

    if (!zegoOk) {
      debugPrint('[VoiceRoomController] Failed to connect to ZegoCloud audio');
    }

    // If seated or host on stage, start speaking
    if (_mySeatIndex != null) {
      await ZegoVoiceService().startSpeaking(
        userId: user.id.toString(),
        seatIndex: _mySeatIndex!,
      );
    }

    // Setup Socket.io listeners
    _setupSocketListeners();

    // Fetch latest fresh room details (seats, presence, admins) in background
    unawaited(refreshRoomDetails(room.id));

    // Emit join
    void sendJoin(dynamic s) {
      if (s == null || s.connected != true) return;
      debugPrint('[VoiceRoomController] 🚪 Emitting voice_room:join: roomId=${room.id}, userId=${user.id}');
      s.emit('voice_room:join', {
        'roomId': room.id,
        'user': {
          'id': user.id,
          'username': user.username,
          'fullName': user.fullName ?? user.username,
          'avatarUrl': user.avatarUrl ?? '',
          'avatarFrame': user.avatarFrame,
        },
      });
    }

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      sendJoin(socket);
    } else {
      FeedService.onSocketReady((s) {
        if (_currentRoom?.id == room.id) {
          sendJoin(s);
        }
      });
    }

    // Initial messages upon entering room (Description, Regulations & High Quality notice)
    final roomDesc = room.description.trim();
    _messages.add(
      VoiceRoomMessage(
        id: 'sys-desc-${DateTime.now().millisecondsSinceEpoch}',
        message: 'Notice: ${roomDesc.isNotEmpty ? roomDesc : "Welcome to ${room.title}!"}',
        sender: VoiceRoomUser(id: 0, username: 'Notice', fullName: 'Notice', avatarUrl: ''),
        createdAt: DateTime.now(),
        isSystem: true,
      ),
    );

    _messages.add(
      VoiceRoomMessage(
        id: 'sys-regulations-${DateTime.now().millisecondsSinceEpoch}',
        message: 'System: Violence, pornography, gambling, scamming, and vulgarity are strictly forbidden in the voice room. We advocate healthy gaming and internet police officers will be cruising 24/7. Please report whenever you find any violations and abide by Regulations Of The Voice Room.',
        sender: VoiceRoomUser(id: 0, username: 'System', fullName: 'System', avatarUrl: ''),
        createdAt: DateTime.now().add(const Duration(milliseconds: 50)),
        isSystem: true,
      ),
    );

    _messages.add(
      VoiceRoomMessage(
        id: 'sys-hq-${DateTime.now().millisecondsSinceEpoch}',
        message: 'System: This room applies high quality mode. The tone quality will be improved and more traffic will be consumed.',
        sender: VoiceRoomUser(id: 0, username: 'System', fullName: 'System', avatarUrl: ''),
        createdAt: DateTime.now().add(const Duration(milliseconds: 100)),
        isSystem: true,
      ),
    );

    // Bind sound levels to seats
    _soundSubscription?.cancel();
    ZegoVoiceService().soundLevelsNotifier.addListener(_onSoundLevelsUpdated);
    ZegoVoiceService().mySoundLevelNotifier.addListener(_onMySoundLevelUpdated);
    ZegoVoiceService().onMusicCompleted = () => _onTrackCompleted(fromZego: true);
    ZegoVoiceService().mediaPlayerStateNotifier.addListener(_onZegoMediaPlayerStateChanged);
    ZegoVoiceService().mediaPlayerDurationNotifier.addListener(_onZegoMediaPlayerDurationChanged);

    // Keep host & room connection alive with periodic heartbeat
    _startHeartbeat();

    // Start ongoing foreground service to keep voice room connection & audio alive in background
    unawaited(VoiceRoomForegroundService.start(
      roomId: room.id.toString(),
      title: 'In a voiceroom. ID: ${room.id}',
      text: 'Tap to return',
    ));

    notifyListeners();
    return true;
  }

  void _onSoundLevelsUpdated() {
    if (_currentRoom == null) return;
    final levels = ZegoVoiceService().soundLevelsNotifier.value;
    bool changed = false;

    final roomCode = _currentRoom!.roomCode.isNotEmpty
        ? _currentRoom!.roomCode
        : 'room_${_currentRoom!.id}';

    // Track remote host sound level if not local host
    if (!isHost) {
      final hostStreamId =
          'stream_${roomCode}_user_${_currentRoom!.host.id}_seat_99';
      final hostLvl = levels[hostStreamId] ?? 0.0;
      if ((_hostSoundLevel - hostLvl).abs() > 2.0) {
        _hostSoundLevel = hostLvl;
        changed = true;
      }
    }

    for (final seat in _currentRoom!.seats) {
      if (seat.user != null) {
        final streamId =
            'stream_${roomCode}_user_${seat.user!.id}_seat_${seat.seatIndex}';
        final lvl = levels[streamId] ?? 0.0;
        if ((seat.soundLevel - lvl).abs() > 2.0) {
          seat.soundLevel = lvl;
          changed = true;
        }
      } else {
        if (seat.soundLevel > 0) {
          seat.soundLevel = 0;
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _onMySoundLevelUpdated() {
    if (_currentRoom == null) return;
    final lvl = ZegoVoiceService().mySoundLevelNotifier.value;
    if (isHost) {
      if ((_hostSoundLevel - lvl).abs() > 2.0) {
        _hostSoundLevel = lvl;
        notifyListeners();
      }
    } else if (_mySeatIndex != null && _mySeatIndex! < _currentRoom!.seats.length) {
      _currentRoom!.seats[_mySeatIndex!].soundLevel = lvl;
      notifyListeners();
    }
  }

  void _onZegoMediaPlayerStateChanged() {
    if (!isHost) return;
    final state = ZegoVoiceService().mediaPlayerStateNotifier.value;
    final isPlaying = state == ZegoMediaPlayerState.Playing;
    if (_isRoomMusicPlaying != isPlaying && state != ZegoMediaPlayerState.NoPlay) {
      _isRoomMusicPlaying = isPlaying;
      notifyListeners();
    }
  }

  void _onZegoMediaPlayerDurationChanged() {
    _roomMusicCurrentDuration = ZegoVoiceService().mediaPlayerDurationNotifier.value;
    notifyListeners();
  }

  void _removeSocketListeners() {
    final socket = FeedService.getSocket();
    if (socket == null) return;

    socket.off('voice_room:sync_state');
    socket.off('voice_room:host_presence');
    socket.off('voice_room:seat_updated');
    socket.off('voice_room:seat_mute_changed');
    socket.off('voice_room:seat_lock_changed');
    socket.off('voice_room:host_mute_changed');
    socket.off('voice_room:audience_updated');
    socket.off('voice_room:new_message');
    socket.off('voice_room:gift_broadcast');
    socket.off('voice_room:kicked_from_seat');
    socket.off('voice_room:closed');
    socket.off('voice_room:user_joined');
    socket.off('voice_room:user_left');
    socket.off('voice_room:info_updated');
    socket.off('voice_room:admins_updated');
    socket.off('voice_room:music_updated');
    socket.off('voice_room:music_host_transferred');
    socket.off('connect');
  }

  void _setupSocketListeners() {
    final socket = FeedService.getSocket();
    if (socket == null) return;

    _removeSocketListeners();

    // On socket reconnect: re-emit voice_room:join and refresh room details
    socket.off('connect');
    socket.on('connect', (_) {
      final user = currentUser;
      if (_currentRoom != null && user != null) {
        socket.emit('voice_room:join', {
          'roomId': _currentRoom!.id,
          'user': {
            'id': user.id,
            'username': user.username,
            'fullName': user.fullName ?? user.username,
            'avatarUrl': user.avatarUrl ?? '',
            'avatarFrame': user.avatarFrame,
          },
        });
        _sendHeartbeat();
        unawaited(refreshRoomDetails(_currentRoom!.id));
      }
    });

    // Complete snapshot of occupied seats and host status received from server
    socket.on('voice_room:sync_state', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final rawSeats = data['seats'];
      if (rawSeats is List) {
        final syncedSeats = rawSeats
            .map((s) => VoiceSeat.fromJson(Map<String, dynamic>.from(s)))
            .toList();

        // Host never occupies guest seats
        if (isHost) {
          final myId = currentUser?.id?.toString();
          for (int i = 0; i < syncedSeats.length; i++) {
            if (syncedSeats[i].user?.id.toString() == myId) {
              syncedSeats[i] = syncedSeats[i].copyWith(clearUser: true, user: null);
            }
          }
        }

        // Deduplicate seats: each user can only occupy one seat
        final seenUserIds = <String>{};
        for (int i = 0; i < syncedSeats.length; i++) {
          final u = syncedSeats[i].user;
          if (u != null) {
            final uid = u.id.toString();
            if (seenUserIds.contains(uid)) {
              syncedSeats[i] = syncedSeats[i].copyWith(clearUser: true, user: null);
            } else {
              seenUserIds.add(uid);
            }
          }
        }

        final hostPresent = isHost ? true : (data['isHostInRoom'] == true);
        _currentRoom = _currentRoom!.copyWith(
          seats: syncedSeats,
          isHostInRoom: hostPresent,
          audienceCount: data['audienceCount'] is int ? data['audienceCount'] : _currentRoom!.audienceCount,
        );

        // Sync local mic seat state if guest
        final localUser = currentUser;
        if (!isHost && localUser != null) {
          final myId = localUser.id.toString();
          int? mySeat;
          bool myMuted = false;
          for (final s in syncedSeats) {
            if (s.user?.id.toString() == myId) {
              mySeat = s.seatIndex;
              myMuted = s.isMuted;
              break;
            }
          }
          if (mySeat != _mySeatIndex) {
            _mySeatIndex = mySeat;
            if (mySeat != null) {
              _isMuted = myMuted;
              ZegoVoiceService().startSpeaking(
                userId: myId,
                seatIndex: mySeat,
              );
            } else {
              ZegoVoiceService().stopSpeaking();
            }
          }
        }

        notifyListeners();
      }

      // Sync room music state snapshot
      if (data['musicState'] != null) {
        _handleRoomMusicUpdated(data['musicState']);
      }
    });

    // Real-time host presence changes (entered, left, disconnected)
    socket.on('voice_room:host_presence', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final isHostIn = isHost ? true : (data['isHostInRoom'] == true);
      _currentRoom = _currentRoom!.copyWith(isHostInRoom: isHostIn);
      notifyListeners();
    });

    socket.on('voice_room:info_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final newTitle = data['title']?.toString();
      final coverUrl = data['coverUrl']?.toString();
      final description = data['description']?.toString();
      final isLocked = data['isLocked'] == true;
      final hasPin = data['hasPin'] == true;

      _currentRoom = _currentRoom!.copyWith(
        title: newTitle ?? _currentRoom!.title,
        coverUrl: coverUrl ?? _currentRoom!.coverUrl,
        description: description ?? _currentRoom!.description,
        isLocked: data['isLocked'] != null ? isLocked : _currentRoom!.isLocked,
        hasPin: data['hasPin'] != null ? hasPin : _currentRoom!.hasPin,
      );
      notifyListeners();
    });

    // Real-time shared room music updates (play, pause, queue add/remove, track advance, stop)
    socket.on('voice_room:music_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;
      _handleRoomMusicUpdated(data);
    });

    // Room DJ/Host ownership transfer
    socket.on('voice_room:music_host_transferred', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;
      _handleRoomMusicUpdated(data);
    });

    socket.on('voice_room:host_mute_changed', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() == _currentRoom!.id.toString()) {
        _isHostMuted = data['isMuted'] == true;
        if (isHost) {
          _isMuted = _isHostMuted;
          ZegoVoiceService().setMuted(_isMuted);
        }
        notifyListeners();
      }
    });

    socket.on('voice_room:seat_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final seatIndex = data['seatIndex'] as int?;
      if (seatIndex == null || seatIndex >= _currentRoom!.seats.length) return;

      final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null;
      final newUser = userMap != null ? VoiceRoomUser.fromJson(userMap) : null;
      final isMuted = data['isMuted'] == true;
      final isLocked = data['isLocked'] == true;

      // The room host stays exclusively on the main stage, never in guest seats (0..7)
      if (newUser != null && newUser.id.toString() == _currentRoom!.host.id.toString()) {
        return;
      }

      // Defense-in-depth: A user can only occupy ONE seat at a time!
      // If newUser is taking seatIndex, clear newUser from any other seat in the room
      if (newUser != null) {
        final newUserId = newUser.id.toString();
        for (int i = 0; i < _currentRoom!.seats.length; i++) {
          if (i != seatIndex &&
              _currentRoom!.seats[i].user != null &&
              _currentRoom!.seats[i].user!.id.toString() == newUserId) {
            _currentRoom!.seats[i] = _currentRoom!.seats[i].copyWith(
              clearUser: true,
              user: null,
            );
          }
        }
      }

      _currentRoom!.seats[seatIndex] = _currentRoom!.seats[seatIndex].copyWith(
        user: newUser,
        clearUser: newUser == null,
        isMuted: isMuted,
        isLocked: isLocked,
      );

      // Check if it relates to me (guests only, host stays on stage)
      if (!isHost) {
        if (newUser != null && newUser.id.toString() == _currentUser?.id?.toString()) {
          _mySeatIndex = seatIndex;
          _isMuted = isMuted;
          ZegoVoiceService().startSpeaking(
            userId: _currentUser!.id.toString(),
            seatIndex: seatIndex,
          );
        } else if (_mySeatIndex == seatIndex && newUser == null) {
          _mySeatIndex = null;
          ZegoVoiceService().stopSpeaking();
        }
      }

      notifyListeners();
    });

    socket.on('voice_room:seat_mute_changed', (data) {
      if (data is! Map || _currentRoom == null) return;
      final seatIndex = data['seatIndex'] as int?;
      final isMuted = data['isMuted'] == true;

      if (seatIndex != null && seatIndex < _currentRoom!.seats.length) {
        _currentRoom!.seats[seatIndex] = _currentRoom!.seats[seatIndex].copyWith(
          isMuted: isMuted,
        );
        if (_mySeatIndex == seatIndex) {
          _isMuted = isMuted;
          ZegoVoiceService().setMuted(isMuted);
        }
        notifyListeners();
      }
    });

    socket.on('voice_room:seat_lock_changed', (data) {
      if (data is! Map || _currentRoom == null) return;
      final seatIndex = data['seatIndex'] as int?;
      final isLocked = data['isLocked'] == true;

      if (seatIndex != null && seatIndex < _currentRoom!.seats.length) {
        _currentRoom!.seats[seatIndex] = _currentRoom!.seats[seatIndex].copyWith(
          isLocked: isLocked,
        );
        notifyListeners();
      }
    });

    socket.on('voice_room:audience_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final count = data['audienceCount'] as int?;
      final isHostPresent = isHost ? true : (data['isHostInRoom'] == true);
      _currentRoom = _currentRoom!.copyWith(
        audienceCount: count ?? _currentRoom!.audienceCount,
        isHostInRoom: isHost ? true : (data['isHostInRoom'] != null ? isHostPresent : _currentRoom!.isHostInRoom),
      );
      notifyListeners();
    });

    socket.on('voice_room:new_message', (data) {
      if (data is! Map || _currentRoom == null) return;
      final msg = VoiceRoomMessage.fromJson(Map<String, dynamic>.from(data));
      _messages.add(msg);
      if (_messages.length > 100) {
        _messages.removeAt(0);
      }
      notifyListeners();
    });

    socket.on('voice_room:gift_broadcast', (data) {
      if (data is! Map || _currentRoom == null) return;
      final giftMap = data['gift'] is Map ? Map<String, dynamic>.from(data['gift']) : null;
      final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : null;
      final receiverMap = data['receiver'] is Map ? Map<String, dynamic>.from(data['receiver']) : null;

      if (giftMap != null && senderMap != null && receiverMap != null) {
        final gift = VoiceRoomGift(
          id: giftMap['id']?.toString() ?? '',
          name: giftMap['name']?.toString() ?? '',
          coins: (giftMap['coins'] as num?)?.toDouble() ?? 0.0,
          icon: giftMap['icon']?.toString() ?? '',
          svgaUrl: giftMap['svgaUrl']?.toString() ?? '',
          desc: giftMap['desc']?.toString() ?? '',
        );
        final sender = VoiceRoomUser.fromJson(senderMap);
        final receiver = VoiceRoomUser.fromJson(receiverMap);

        // If not sent by me, play animation and add to messages (sender already played optimistically)
        final myId = currentUser?.id?.toString();
        if (myId == null || sender.id.toString() != myId) {
          _playGiftAnimation(gift, sender, receiver);
          _messages.add(
            VoiceRoomMessage(
              id: 'gift-${DateTime.now().millisecondsSinceEpoch}',
              message: '${sender.fullName} sent ${gift.name} to ${receiver.fullName}!',
              sender: sender,
              createdAt: DateTime.now(),
              isSystem: true,
            ),
          );
          notifyListeners();
        }
      }
    });

    socket.on('voice_room:kicked_from_seat', (_) {
      _mySeatIndex = null;
      ZegoVoiceService().stopSpeaking();
      notifyListeners();
    });

    socket.on('voice_room:closed', (_) {
      leaveRoom();
    });

    socket.on('voice_room:user_joined', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null;
      if (userMap != null) {
        final user = VoiceRoomUser.fromJson(userMap);
        if (user.id.toString() == _currentRoom!.host.id.toString()) {
          _currentRoom = _currentRoom!.copyWith(isHostInRoom: true);
        }

        // Never show "joined the room" for the local user themselves (prevents spam on reconnect / minimize)
        final myId = currentUser?.id?.toString();
        if (myId != null && user.id.toString() == myId) {
          notifyListeners();
          return;
        }

        // Deduplicate join messages for the same user within 5 minutes
        final uid = user.id.toString();
        final now = DateTime.now();
        final lastJoin = _recentJoinTimestamps[uid];
        if (lastJoin != null && now.difference(lastJoin).inMinutes < 5) {
          notifyListeners();
          return;
        }
        _recentJoinTimestamps[uid] = now;

        _messages.add(
          VoiceRoomMessage(
            id: 'join-${DateTime.now().millisecondsSinceEpoch}',
            message: '${user.fullName} joined the room',
            sender: user,
            createdAt: DateTime.now(),
            isSystem: true,
          ),
        );
        notifyListeners();
      }
    });

    socket.on('voice_room:user_left', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null;
      if (userMap != null) {
        final user = VoiceRoomUser.fromJson(userMap);
        if (user.id.toString() == _currentRoom!.host.id.toString()) {
          // If the local user is the host, do not mark host as left
          if (!isHost) {
            _currentRoom = _currentRoom!.copyWith(isHostInRoom: false);
          }
        }
        notifyListeners();
      }
    });

    socket.on('voice_room:admins_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'] as int?;
      if (roomId != null && roomId == _currentRoom!.id && data['admins'] is List) {
        final admins = (data['admins'] as List)
            .map((a) => VoiceRoomUser.fromJson(Map<String, dynamic>.from(a)))
            .toList();
        _currentRoom = _currentRoom!.copyWith(admins: admins);
        notifyListeners();
      }
    });
  }

  void _playGiftAnimation(VoiceRoomGift gift, VoiceRoomUser sender, VoiceRoomUser receiver) {
    _giftPlayToken++;
    _activePlayingGift = gift;
    _activeGiftSender = sender;
    _activeGiftReceiver = receiver;
    notifyListeners();

    // Auto clear after 4.5 seconds
    Timer(const Duration(milliseconds: 4500), () {
      if (_activePlayingGift?.id == gift.id) {
        _activePlayingGift = null;
        _activeGiftSender = null;
        _activeGiftReceiver = null;
        notifyListeners();
      }
    });
  }

  /// Request or take seat (Guests only)
  Future<void> takeSeat(int seatIndex) async {
    if (_currentRoom == null || _currentUser == null) return;
    if (isHost) {
      debugPrint('[VoiceRoomController] Host is already on the main stage mic');
      return;
    }
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:take_seat', {
        'roomId': _currentRoom!.id,
        'seatIndex': seatIndex,
        'user': {
          'id': _currentUser!.id,
          'username': _currentUser!.username,
          'fullName': _currentUser!.fullName ?? _currentUser!.username,
          'avatarUrl': _currentUser!.avatarUrl ?? '',
          'avatarFrame': _currentUser!.avatarFrame,
          'charmPoints': _currentUser!.charmPoints,
        },
      });
    }
  }

  /// Leave seat to become audience (Guests only)
  Future<void> leaveSeat() async {
    if (_currentRoom == null || _mySeatIndex == null) return;
    if (isHost) {
      debugPrint('[VoiceRoomController] Host cannot leave stage seat to audience');
      return;
    }
    final socket = FeedService.getSocket();
    final seatIdx = _mySeatIndex!;

    if (socket != null && socket.connected) {
      socket.emit('voice_room:leave_seat', {
        'roomId': _currentRoom!.id,
        'seatIndex': seatIdx,
        'userId': _currentUser?.id,
      });
    }

    _mySeatIndex = null;
    await ZegoVoiceService().stopSpeaking();
    notifyListeners();
  }

  /// Toggle mic mute
  Future<void> toggleMute() async {
    if (_mySeatIndex == null && !isHost) return;

    _isMuted = !_isMuted;
    if (isHost) {
      _isHostMuted = _isMuted;
    } else if (_mySeatIndex != null && _currentRoom != null) {
      for (final seat in _currentRoom!.seats) {
        if (seat.seatIndex == _mySeatIndex) {
          seat.isMuted = _isMuted;
        }
      }
    }
    notifyListeners();

    // Sync with Zego RTC service
    await ZegoVoiceService().setMuted(_isMuted);

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected && _currentRoom != null) {
      if (isHost) {
        socket.emit('voice_room:toggle_host_mute', {
          'roomId': _currentRoom!.id,
          'isMuted': _isMuted,
        });
      } else {
        socket.emit('voice_room:toggle_mute_seat', {
          'roomId': _currentRoom!.id,
          'seatIndex': _mySeatIndex,
          'isMuted': _isMuted,
        });
      }
    }
  }

  /// Mute or unmute user on seat (Host and Admins)
  Future<void> muteSeat(int seatIndex, bool isMuted) async {
    if (_currentRoom == null) return;
    for (final seat in _currentRoom!.seats) {
      if (seat.seatIndex == seatIndex) {
        seat.isMuted = isMuted;
      }
    }
    if (_mySeatIndex == seatIndex) {
      _isMuted = isMuted;
      await ZegoVoiceService().setMuted(isMuted);
    }
    notifyListeners();

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:toggle_mute_seat', {
        'roomId': _currentRoom!.id,
        'seatIndex': seatIndex,
        'isMuted': isMuted,
      });
    }
  }

  /// Lock or unlock seat (Host only)
  Future<void> lockSeat(int seatIndex, bool isLocked) async {
    if (_currentRoom == null || _currentUser == null) return;
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:lock_seat', {
        'roomId': _currentRoom!.id,
        'seatIndex': seatIndex,
        'isLocked': isLocked,
        'hostId': _currentUser!.id,
      });
    }
  }

  /// Kick user from seat (Host only)
  Future<void> kickSeat(int seatIndex) async {
    if (_currentRoom == null || _currentUser == null) return;
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:kick_seat', {
        'roomId': _currentRoom!.id,
        'seatIndex': seatIndex,
        'hostId': _currentUser!.id,
      });
    }
  }

  /// Send chat message
  void sendChatMessage(String text) {
    if (_currentRoom == null || _currentUser == null || text.trim().isEmpty) return;
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:chat', {
        'roomId': _currentRoom!.id,
        'message': text.trim(),
        'sender': {
          'id': _currentUser!.id,
          'username': _currentUser!.username,
          'fullName': _currentUser!.fullName ?? _currentUser!.username,
          'avatarUrl': _currentUser!.avatarUrl ?? '',
          'avatarFrame': _currentUser!.avatarFrame ?? '',
          'charmPoints': _currentUser!.charmPoints,
          'charmLevel': _currentUser!.charmLevel,
        },
      });
    }
  }

  /// Send virtual gift
  Future<void> sendGift(VoiceRoomGift gift, VoiceRoomUser receiver) async {
    if (_currentRoom == null || _currentUser == null) return;

    final sender = VoiceRoomUser(
      id: int.tryParse(_currentUser!.id ?? '') ?? 0,
      username: _currentUser!.username ?? '',
      fullName: _currentUser!.fullName ?? _currentUser!.username ?? 'User',
      avatarUrl: _currentUser!.avatarUrl ?? '',
    );

    // Play immediately on sender's screen for zero-latency instant feedback
    _playGiftAnimation(gift, sender, receiver);

    // Add local chat notification immediately
    _messages.add(
      VoiceRoomMessage(
        id: 'gift-${DateTime.now().millisecondsSinceEpoch}',
        message: '${sender.fullName} sent ${gift.name} to ${receiver.fullName}!',
        sender: sender,
        createdAt: DateTime.now(),
        isSystem: true,
      ),
    );
    notifyListeners();

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:gift', {
        'roomId': _currentRoom!.id,
        'sender': sender.toJson(),
        'receiver': receiver.toJson(),
        'gift': {
          'id': gift.id,
          'name': gift.name,
          'coins': gift.coins,
          'icon': gift.icon,
          'emoji': gift.emoji,
          'svgaUrl': gift.svgaUrl,
          'desc': gift.desc,
        },
      });
    }
  }

  /// Minimize to floating mini player
  void minimize() {
    _isMinimized = true;
    notifyListeners();
  }

  /// Maximize from mini player
  void maximize() {
    _isMinimized = false;
    notifyListeners();
  }

  /// Leave room completely and reset all room state
  Future<void> leaveRoom() async {
    final room = _currentRoom;
    final user = currentUser;

    if (room != null) {
      try {
        final socket = FeedService.getSocket();
        if (socket != null && socket.connected && user != null) {
          socket.emit('voice_room:leave', {
            'roomId': room.id,
            'user': {
              'id': user.id,
              'username': user.username,
            },
          });
        }
      } catch (e) {
        debugPrint('[VoiceRoomController] leaveRoom socket error: $e');
      }

      try {
        await ZegoVoiceService().leaveRoom();
      } catch (e) {
        debugPrint('[VoiceRoomController] leaveRoom zego error: $e');
      }
    }

    try {
      _removeSocketListeners();
    } catch (_) {}

    try {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _soundSubscription?.cancel();
      _soundSubscription = null;
      ZegoVoiceService().soundLevelsNotifier.removeListener(_onSoundLevelsUpdated);
      ZegoVoiceService().mySoundLevelNotifier.removeListener(_onMySoundLevelUpdated);
      ZegoVoiceService().mediaPlayerStateNotifier.removeListener(_onZegoMediaPlayerStateChanged);
      ZegoVoiceService().mediaPlayerDurationNotifier.removeListener(_onZegoMediaPlayerDurationChanged);
      ZegoVoiceService().onMusicCompleted = null;
    } catch (_) {}

    try {
      await _roomMusicPlayerStateSub?.cancel();
      _roomMusicPlayerStateSub = null;
      await _roomMusicPlayerDurationSub?.cancel();
      _roomMusicPlayerDurationSub = null;
      await GlobalAudioPlayerService.instance.stopVoiceRoomMusic();
      await ZegoVoiceService().stopBackgroundMusic();
    } catch (_) {}

    // Stop voice room foreground service
    unawaited(VoiceRoomForegroundService.stop());

    _currentRoom = null;
    _currentUser = null;
    _isMinimized = false;
    _mySeatIndex = null;
    _isMuted = false;
    _isHostMuted = false;
    _hostSoundLevel = 0.0;
    _messages.clear();
    _recentJoinTimestamps.clear();
    _activePlayingGift = null;
    _activeGiftSender = null;
    _activeGiftReceiver = null;
    _isMusicEnabled = false;
    _roomCdnTrack = null;
    _musicQueue.clear();
    _currentQueueIndex = -1;
    _isRoomMusicPlaying = false;
    _isRoomMusicLoading = false;

    notifyListeners();
  }

  /// Handles incoming shared room music state updates from Socket.io
  void _handleRoomMusicUpdated(dynamic rawData) {
    if (rawData is! Map || _currentRoom == null) return;
    final data = Map<String, dynamic>.from(rawData);

    final isEnabled = data['isEnabled'] == true;
    final isPlaying = data['isPlaying'] == true;
    final currentQueueIndex = (data['currentQueueIndex'] as num?)?.toInt() ?? -1;

    VoiceRoomMusicTrack? track;
    final rawTrack = data['currentTrack'];
    if (rawTrack is Map) {
      try {
        track = VoiceRoomMusicTrack.fromJson(Map<String, dynamic>.from(rawTrack));
      } catch (_) {}
    }

    final newQueue = <VoiceRoomMusicTrack>[];
    final rawQueue = data['queue'];
    if (rawQueue is List) {
      for (final item in rawQueue) {
        if (item is Map) {
          try {
            newQueue.add(VoiceRoomMusicTrack.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }

    _isMusicEnabled = isEnabled;
    _roomCdnTrack = track;
    _currentQueueIndex = currentQueueIndex;
    _musicQueue.clear();
    _musicQueue.addAll(newQueue);

    // SINGLE SOURCE OF TRUTH (Requirement 2):
    // If local user is the host and no song is actively playing,
    // but the queue has tracks (e.g. queue went from empty to non-empty from a guest add):
    if (isHost && _isMusicEnabled && _roomCdnTrack == null && _musicQueue.isNotEmpty) {
      debugPrint('[VoiceRoomController] Host auto-starting playback for newly queued song: ${_musicQueue.first.title}');
      final firstTrack = _musicQueue.first;
      unawaited(playCdnMusic(firstTrack, queueIndex: 0));
      return;
    }

    // If music was disabled, stopped, or host left:
    if (!_isMusicEnabled || (!isPlaying && track == null)) {
      _isRoomMusicPlaying = false;
      if (_localPlaybackActive) {
        unawaited(_stopLocalMusicInternal());
      }
      notifyListeners();
      return;
    }

    _isRoomMusicPlaying = isPlaying;

    if (!isHost) {
      // Guest devices NEVER stream into Zego Aux or just_audio.
      // Guests hear the music via Zego RTC room audio stream published by the host.
      if (_localPlaybackActive) {
        unawaited(_stopLocalMusicInternal());
      }
    }

    notifyListeners();
  }
}
