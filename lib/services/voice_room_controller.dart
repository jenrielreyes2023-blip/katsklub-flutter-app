import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/voice_room.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'feed_service.dart';
import 'zego_voice_service.dart';

/// Global Singleton Controller for active Voice Room state, Socket.io signaling, and UI overlays.
class VoiceRoomController extends ChangeNotifier {
  factory VoiceRoomController() => _instance;
  VoiceRoomController._internal();
  static final VoiceRoomController _instance = VoiceRoomController._internal();

  VoiceRoom? _currentRoom;
  User? _currentUser;
  bool _isMinimized = false;
  int? _mySeatIndex;
  bool _isMuted = false;
  bool _isHostMuted = false;
  double _hostSoundLevel = 0.0;

  final List<VoiceRoomMessage> _messages = [];
  VoiceRoomGift? _activePlayingGift;
  VoiceRoomUser? _activeGiftSender;
  VoiceRoomUser? _activeGiftReceiver;

  VoiceRoom? get currentRoom => _currentRoom;
  User? get currentUser => _currentUser;
  bool get isMinimized => _isMinimized;
  int? get mySeatIndex => _mySeatIndex;
  bool get isMuted => _isMuted;
  bool get isSeated => _mySeatIndex != null && _mySeatIndex != 99;
  bool get isOnMic => isHost || isSeated;
  double get hostSoundLevel => isHost ? (ZegoVoiceService().mySoundLevelNotifier.value) : _hostSoundLevel;
  bool get isHostMuted => isHost ? _isMuted : _isHostMuted;
  bool get isHost {
    try {
      if (_currentRoom == null || _currentUser == null) return false;
      return _currentRoom!.host.id.toString() == _currentUser!.id.toString();
    } catch (_) {
      return false;
    }
  }

  bool get isHostInRoom {
    try {
      if (_currentRoom == null) return false;
      if (isHost == true) return true;
      for (final seat in _currentRoom!.seats) {
        if (seat.user != null &&
            seat.user!.id.toString() == _currentRoom!.host.id.toString()) {
          return true;
        }
      }
      final inRoom = (_currentRoom as dynamic).isHostInRoom;
      return inRoom == true;
    } catch (_) {
      return true;
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

  /// Joins a voice room, connects Zego audio, and registers socket listeners
  Future<bool> enterRoom(VoiceRoom room, User user) async {
    // If already in the same room, just un-minimize
    if (_currentRoom?.id == room.id) {
      _isMinimized = false;
      notifyListeners();
      return true;
    }

    // Leave previous room if any
    if (_currentRoom != null) {
      await leaveRoom();
    }

    _currentRoom = room;
    _currentUser = user;
    _isMinimized = false;
    _mySeatIndex = null;
    _isMuted = false;
    _isHostMuted = false;
    _hostSoundLevel = 0.0;
    _messages.clear();

    final isUserHost = room.host.id.toString() == user.id.toString();

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

    // Emit join
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:join', {
        'roomId': room.id,
        'user': {
          'id': user.id,
          'username': user.username,
          'fullName': user.fullName ?? user.username,
          'avatarUrl': user.avatarUrl ?? '',
        },
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

  void _setupSocketListeners() {
    final socket = FeedService.getSocket();
    if (socket == null) return;

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

    socket.on('voice_room:info_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'];
      if (roomId != null && roomId.toString() != _currentRoom!.id.toString()) return;

      final newTitle = data['title']?.toString();
      final isLocked = data['isLocked'] == true;
      final hasPin = data['hasPin'] == true;

      _currentRoom = _currentRoom!.copyWith(
        title: newTitle ?? _currentRoom!.title,
        isLocked: data['isLocked'] != null ? isLocked : _currentRoom!.isLocked,
        hasPin: data['hasPin'] != null ? hasPin : _currentRoom!.hasPin,
      );
      notifyListeners();
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
      if (roomId != _currentRoom!.id) return;

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
        _currentRoom!.seats[seatIndex].isLocked = isLocked;
        notifyListeners();
      }
    });

    socket.on('voice_room:audience_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final count = data['audienceCount'] as int?;
      if (count != null) {
        _currentRoom!.audienceCount = count;
      }
      if (data['isHostInRoom'] != null) {
        _currentRoom = _currentRoom!.copyWith(isHostInRoom: data['isHostInRoom'] == true);
      }
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
      final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null;
      if (userMap != null) {
        final user = VoiceRoomUser.fromJson(userMap);
        if (user.id.toString() == _currentRoom!.host.id.toString()) {
          _currentRoom = _currentRoom!.copyWith(isHostInRoom: true);
        }
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
      final userMap = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null;
      if (userMap != null) {
        final user = VoiceRoomUser.fromJson(userMap);
        if (user.id.toString() == _currentRoom!.host.id.toString()) {
          _currentRoom = _currentRoom!.copyWith(isHostInRoom: false);
        }
        notifyListeners();
      }
    });

    socket.on('voice_room:info_updated', (data) {
      if (data is! Map || _currentRoom == null) return;
      final roomId = data['roomId'] as int?;
      if (roomId != null && roomId == _currentRoom!.id) {
        final title = data['title'] as String?;
        final coverUrl = data['coverUrl'] as String?;
        final isLocked = data['isLocked'] as bool?;
        final hasPin = data['hasPin'] as bool?;
        final description = data['description'] as String?;
        _currentRoom = _currentRoom!.copyWith(
          title: title ?? _currentRoom!.title,
          coverUrl: coverUrl ?? _currentRoom!.coverUrl,
          isLocked: isLocked ?? _currentRoom!.isLocked,
          hasPin: hasPin ?? _currentRoom!.hasPin,
          description: description ?? _currentRoom!.description,
        );
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
        },
      });
    }
  }

  /// Send virtual gift
  Future<void> sendGift(VoiceRoomGift gift, VoiceRoomUser receiver) async {
    if (_currentRoom == null || _currentUser == null) return;
    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('voice_room:gift', {
        'roomId': _currentRoom!.id,
        'sender': {
          'id': _currentUser!.id,
          'username': _currentUser!.username,
          'fullName': _currentUser!.fullName ?? _currentUser!.username,
          'avatarUrl': _currentUser!.avatarUrl ?? '',
        },
        'receiver': receiver.toJson(),
        'gift': {
          'id': gift.id,
          'name': gift.name,
          'coins': gift.coins,
          'icon': gift.icon,
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

  /// Leave room completely
  Future<void> leaveRoom() async {
    if (_currentRoom == null) return;

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected && _currentUser != null) {
      socket.emit('voice_room:leave', {
        'roomId': _currentRoom!.id,
        'user': {
          'id': _currentUser!.id,
          'username': _currentUser!.username,
        },
      });
    }

    await ZegoVoiceService().leaveRoom();

    _soundSubscription?.cancel();
    ZegoVoiceService().soundLevelsNotifier.removeListener(_onSoundLevelsUpdated);
    ZegoVoiceService().mySoundLevelNotifier.removeListener(_onMySoundLevelUpdated);

    _currentRoom = null;
    _isMinimized = false;
    _mySeatIndex = null;
    _isMuted = false;
    _isHostMuted = false;
    _hostSoundLevel = 0.0;
    _messages.clear();
    _activePlayingGift = null;

    notifyListeners();
  }
}
