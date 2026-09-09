import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/voice_room.dart';
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

  final List<VoiceRoomMessage> _messages = [];
  VoiceRoomGift? _activePlayingGift;
  VoiceRoomUser? _activeGiftSender;
  VoiceRoomUser? _activeGiftReceiver;

  VoiceRoom? get currentRoom => _currentRoom;
  User? get currentUser => _currentUser;
  bool get isMinimized => _isMinimized;
  int? get mySeatIndex => _mySeatIndex;
  bool get isMuted => _isMuted;
  bool get isSeated => _mySeatIndex != null;
  List<VoiceRoomMessage> get messages => List.unmodifiable(_messages);
  VoiceRoomGift? get activePlayingGift => _activePlayingGift;
  VoiceRoomUser? get activeGiftSender => _activeGiftSender;
  VoiceRoomUser? get activeGiftReceiver => _activeGiftReceiver;

  StreamSubscription? _soundSubscription;

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
    _messages.clear();

    // Check if user is already in a seat in the room
    for (final seat in room.seats) {
      if (seat.user?.id.toString() == user.id.toString()) {
        _mySeatIndex = seat.seatIndex;
        _isMuted = seat.isMuted;
        break;
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

    // If seated, start speaking
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

    // Welcome message
    _messages.add(
      VoiceRoomMessage(
        id: 'sys-welcome',
        message: 'Welcome to ${room.title}! Please be respectful and keep the vibe cozy. ✨',
        sender: VoiceRoomUser(id: 0, username: 'System', fullName: 'System', avatarUrl: ''),
        createdAt: DateTime.now(),
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

    for (final seat in _currentRoom!.seats) {
      if (seat.user != null) {
        final streamId =
            'stream_${_currentRoom!.roomCode}_user_${seat.user!.id}_seat_${seat.seatIndex}';
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
    if (_currentRoom == null || _mySeatIndex == null) return;
    final lvl = ZegoVoiceService().mySoundLevelNotifier.value;
    if (_mySeatIndex! < _currentRoom!.seats.length) {
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
    socket.off('voice_room:audience_updated');
    socket.off('voice_room:new_message');
    socket.off('voice_room:gift_broadcast');
    socket.off('voice_room:kicked_from_seat');
    socket.off('voice_room:closed');
    socket.off('voice_room:user_joined');
    socket.off('voice_room:user_left');

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

      _currentRoom!.seats[seatIndex] = _currentRoom!.seats[seatIndex].copyWith(
        user: newUser,
        clearUser: newUser == null,
        isMuted: isMuted,
        isLocked: isLocked,
      );

      // Check if it relates to me
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

      notifyListeners();
    });

    socket.on('voice_room:seat_mute_changed', (data) {
      if (data is! Map || _currentRoom == null) return;
      final seatIndex = data['seatIndex'] as int?;
      final isMuted = data['isMuted'] == true;

      if (seatIndex != null && seatIndex < _currentRoom!.seats.length) {
        _currentRoom!.seats[seatIndex].isMuted = isMuted;
        if (_mySeatIndex == seatIndex) {
          _isMuted = isMuted;
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
        notifyListeners();
      }
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
            message: '🎁 ${sender.fullName} sent ${gift.name} to ${receiver.fullName}!',
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
        _messages.add(
          VoiceRoomMessage(
            id: 'join-${DateTime.now().millisecondsSinceEpoch}',
            message: '✨ ${user.fullName} joined the room',
            sender: user,
            createdAt: DateTime.now(),
            isSystem: true,
          ),
        );
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

  /// Request or take seat
  Future<void> takeSeat(int seatIndex) async {
    if (_currentRoom == null || _currentUser == null) return;
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

  /// Leave seat to become audience
  Future<void> leaveSeat() async {
    if (_currentRoom == null || _mySeatIndex == null) return;
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
    if (_mySeatIndex == null) return;
    final newMute = await ZegoVoiceService().toggleMute();
    _isMuted = newMute;

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected && _currentRoom != null) {
      socket.emit('voice_room:toggle_mute_seat', {
        'roomId': _currentRoom!.id,
        'seatIndex': _mySeatIndex,
        'isMuted': _isMuted,
      });
    }

    notifyListeners();
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
    _messages.clear();
    _activePlayingGift = null;

    notifyListeners();
  }
}
