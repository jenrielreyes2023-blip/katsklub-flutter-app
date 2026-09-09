import 'dart:convert';

class VoiceRoomUser {
  final int id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final int charmPoints;

  VoiceRoomUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    this.charmPoints = 0,
  });

  factory VoiceRoomUser.fromJson(Map<String, dynamic> json) {
    return VoiceRoomUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString() ?? '',
      charmPoints: json['charmPoints'] is int
          ? json['charmPoints']
          : int.tryParse(json['charm_points']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'charmPoints': charmPoints,
      };
}

class VoiceSeat {
  final int seatIndex;
  VoiceRoomUser? user;
  bool isMuted;
  bool isLocked;
  double soundLevel;

  VoiceSeat({
    required this.seatIndex,
    this.user,
    this.isMuted = false,
    this.isLocked = false,
    this.soundLevel = 0.0,
  });

  factory VoiceSeat.fromJson(Map<String, dynamic> json) {
    return VoiceSeat(
      seatIndex: json['seatIndex'] is int
          ? json['seatIndex']
          : int.tryParse(json['seat_index']?.toString() ?? '') ?? 0,
      user: json['user'] != null && json['user'] is Map
          ? VoiceRoomUser.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
      isMuted: json['isMuted'] == true || json['is_muted'] == true,
      isLocked: json['isLocked'] == true || json['is_locked'] == true,
    );
  }

  VoiceSeat copyWith({
    VoiceRoomUser? user,
    bool? isMuted,
    bool? isLocked,
    double? soundLevel,
    bool clearUser = false,
  }) {
    return VoiceSeat(
      seatIndex: seatIndex,
      user: clearUser ? null : (user ?? this.user),
      isMuted: isMuted ?? this.isMuted,
      isLocked: isLocked ?? this.isLocked,
      soundLevel: soundLevel ?? this.soundLevel,
    );
  }
}

class VoiceRoom {
  final int id;
  final String roomCode;
  final String title;
  final String description;
  final String category;
  final String theme;
  final String coverUrl;
  final int maxSeats;
  final int occupiedSeatsCount;
  final VoiceRoomUser host;
  final List<VoiceSeat> seats;
  int audienceCount;

  VoiceRoom({
    required this.id,
    required this.roomCode,
    required this.title,
    required this.description,
    required this.category,
    required this.theme,
    required this.coverUrl,
    required this.maxSeats,
    required this.occupiedSeatsCount,
    required this.host,
    required this.seats,
    this.audienceCount = 0,
  });

  factory VoiceRoom.fromJson(Map<String, dynamic> json) {
    List<VoiceSeat> parsedSeats = [];
    if (json['seats'] is List) {
      parsedSeats = (json['seats'] as List)
          .map((s) => VoiceSeat.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    } else {
      // default 8 empty seats
      parsedSeats = List.generate(8, (i) => VoiceSeat(seatIndex: i));
    }

    return VoiceRoom(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      roomCode: json['roomCode']?.toString() ?? json['room_code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Voice Room',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Chat',
      theme: json['theme']?.toString() ?? 'cosmic_night',
      coverUrl: json['coverUrl']?.toString() ?? json['cover_url']?.toString() ?? '',
      maxSeats: json['maxSeats'] is int ? json['maxSeats'] : 8,
      occupiedSeatsCount: json['occupiedSeatsCount'] is int ? json['occupiedSeatsCount'] : 0,
      host: json['host'] != null
          ? VoiceRoomUser.fromJson(Map<String, dynamic>.from(json['host']))
          : VoiceRoomUser(id: 0, username: 'Host', fullName: 'Host', avatarUrl: ''),
      seats: parsedSeats,
      audienceCount: json['audienceCount'] is int ? json['audienceCount'] : 0,
    );
  }
}

class VoiceRoomMessage {
  final String id;
  final String message;
  final VoiceRoomUser sender;
  final DateTime createdAt;
  final bool isSystem;

  VoiceRoomMessage({
    required this.id,
    required this.message,
    required this.sender,
    required this.createdAt,
    this.isSystem = false,
  });

  factory VoiceRoomMessage.fromJson(Map<String, dynamic> json) {
    return VoiceRoomMessage(
      id: json['id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      sender: json['sender'] != null
          ? VoiceRoomUser.fromJson(Map<String, dynamic>.from(json['sender']))
          : VoiceRoomUser(id: 0, username: 'System', fullName: 'System', avatarUrl: ''),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isSystem: json['isSystem'] == true,
    );
  }
}

class VoiceRoomGift {
  final String id;
  final String name;
  final double coins;
  final String icon;
  final String svgaUrl;
  final String desc;

  const VoiceRoomGift({
    required this.id,
    required this.name,
    required this.coins,
    required this.icon,
    required this.svgaUrl,
    required this.desc,
  });

  static const List<VoiceRoomGift> availableGifts = [
    VoiceRoomGift(
      id: 'gift_rose',
      name: 'Red Rose 🌹',
      coins: 5.0,
      icon: 'assets/gifts/rocket_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket_audio.svga',
      desc: 'A lovely rose to show warmth & friendship',
    ),
    VoiceRoomGift(
      id: 'gift_boba',
      name: 'Kats Boba Milk Tea 🧋',
      coins: 20.0,
      icon: 'assets/gifts/rocket_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket.svga',
      desc: 'Sweet refreshing boba milk tea treat!',
    ),
    VoiceRoomGift(
      id: 'gift_fireworks',
      name: 'Fireworks Festival 🎆',
      coins: 100.0,
      icon: 'assets/gifts/fireworks_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/fireworks_audio.svga',
      desc: 'Sky lit up with grand fireworks & sound!',
    ),
    VoiceRoomGift(
      id: 'gift_rocket',
      name: 'Cosmic Space Rocket 🚀',
      coins: 500.0,
      icon: 'assets/gifts/rocket_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket_audio.svga',
      desc: 'Launch a supersonic space rocket across the room!',
    ),
  ];
}
