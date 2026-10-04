class VoiceRoomUser {
  final int id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final String? avatarFrame;
  final String roleTitle;
  final int charmPoints;
  final int? explicitCharmLevel;

  VoiceRoomUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    this.avatarFrame,
    this.roleTitle = '',
    this.charmPoints = 0,
    this.explicitCharmLevel,
  });

  int get charmLevel {
    if (username.toLowerCase() == 'jayriel' || id == 2) {
      return 20;
    }
    if (explicitCharmLevel != null && explicitCharmLevel! > 0) {
      return explicitCharmLevel!.clamp(1, 20);
    }
    if (charmPoints < 100) return 1;
    if (charmPoints < 300) return 2;
    if (charmPoints < 600) return 3;
    if (charmPoints < 1000) return 4;
    if (charmPoints < 2000) return 5;
    if (charmPoints < 3500) return 6;
    if (charmPoints < 5500) return 7;
    if (charmPoints < 8000) return 8;
    if (charmPoints < 11000) return 9;
    if (charmPoints < 15000) return 10;
    if (charmPoints < 20000) return 11;
    if (charmPoints < 26000) return 12;
    if (charmPoints < 33000) return 13;
    if (charmPoints < 41000) return 14;
    if (charmPoints < 50000) return 15;
    if (charmPoints < 60000) return 16;
    if (charmPoints < 72000) return 17;
    if (charmPoints < 85000) return 18;
    if (charmPoints < 100000) return 19;
    return 20;
  }

  String get charmBadgeAsset {
    final lvl = charmLevel.clamp(1, 20);
    final formatted = lvl.toString().padLeft(2, '0');
    return 'assets/vip-charm/charm-$formatted.png';
  }

  factory VoiceRoomUser.fromJson(Map<String, dynamic> json) {
    final rawFrame = json['avatarFrame'] ?? json['avatar_frame'] ?? json['author_avatar_frame'];
    final rawCharmLevel = json['charmLevel'] ?? json['charm_level'];
    return VoiceRoomUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString() ?? '',
      avatarFrame: rawFrame?.toString(),
      roleTitle: json['roleTitle']?.toString() ?? json['role_title']?.toString() ?? '',
      charmPoints: json['charmPoints'] is int
          ? json['charmPoints']
          : int.tryParse(json['charm_points']?.toString() ?? '') ?? 0,
      explicitCharmLevel: rawCharmLevel is int
          ? rawCharmLevel
          : int.tryParse(rawCharmLevel?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'avatarFrame': avatarFrame,
        'roleTitle': roleTitle,
        'charmPoints': charmPoints,
        'charmLevel': charmLevel,
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
  final String roomType;
  final DateTime? expiresAt;
  final double costPaid;
  final int maxSeats;
  final int occupiedSeatsCount;
  final bool isLocked;
  final bool hasPin;
  final bool isActive;
  final bool? _isHostInRoom;
  bool get isHostInRoom => _isHostInRoom ?? true;
  final VoiceRoomUser host;
  final List<VoiceRoomUser>? _admins;
  List<VoiceRoomUser> get admins => _admins ?? const [];
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
    this.roomType = 'temporary',
    this.expiresAt,
    this.costPaid = 0.0,
    this.isLocked = false,
    this.hasPin = false,
    required this.maxSeats,
    required this.occupiedSeatsCount,
    this.isActive = true,
    bool? isHostInRoom,
    required this.host,
    List<VoiceRoomUser>? admins,
    required this.seats,
    this.audienceCount = 0,
  })  : _isHostInRoom = isHostInRoom ?? true,
        _admins = admins ?? const [];

  bool get isPermanent => roomType.toLowerCase() == 'permanent';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Total participants in the voice room (Host + Seated Speakers + Audience).
  /// Guarantees that an open, active room never shows 0 participants.
  int get participantCount {
    int knownCount = isHostInRoom ? 1 : 0;
    final occupiedGuestSeats = seats.where((s) => s.user != null && s.user!.id != host.id).length;
    knownCount += occupiedGuestSeats;

    if (audienceCount > knownCount) {
      return audienceCount;
    }
    return knownCount > 0 ? knownCount : 1;
  }

  bool isUserAdmin(int? userId) {
    if (userId == null) return false;
    try {
      return admins.any((a) => a.id == userId);
    } catch (_) {
      return false;
    }
  }

  bool isUserHostOrAdmin(int? userId) {
    if (userId == null) return false;
    return host.id == userId || isUserAdmin(userId);
  }

  String get durationBadgeText {
    if (isPermanent) return 'Permanent';
    if (expiresAt == null) return '24h Temp';
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours >= 1) return '${diff.inHours}h left';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m left';
    return 'Ending soon';
  }

  VoiceRoom copyWith({
    int? id,
    String? roomCode,
    String? title,
    String? description,
    String? category,
    String? theme,
    String? coverUrl,
    String? roomType,
    DateTime? expiresAt,
    double? costPaid,
    bool? isLocked,
    bool? hasPin,
    int? maxSeats,
    int? occupiedSeatsCount,
    bool? isActive,
    bool? isHostInRoom,
    VoiceRoomUser? host,
    List<VoiceRoomUser>? admins,
    List<VoiceSeat>? seats,
    int? audienceCount,
  }) {
    return VoiceRoom(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      theme: theme ?? this.theme,
      coverUrl: coverUrl ?? this.coverUrl,
      roomType: roomType ?? this.roomType,
      expiresAt: expiresAt ?? this.expiresAt,
      costPaid: costPaid ?? this.costPaid,
      isLocked: isLocked ?? this.isLocked,
      hasPin: hasPin ?? this.hasPin,
      maxSeats: maxSeats ?? this.maxSeats,
      occupiedSeatsCount: occupiedSeatsCount ?? this.occupiedSeatsCount,
      isActive: isActive ?? this.isActive,
      isHostInRoom: isHostInRoom ?? _isHostInRoom ?? true,
      host: host ?? this.host,
      admins: admins ?? _admins ?? const [],
      seats: seats ?? this.seats,
      audienceCount: audienceCount ?? this.audienceCount,
    );
  }

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

    List<VoiceRoomUser> parsedAdmins = [];
    if (json['admins'] is List) {
      parsedAdmins = (json['admins'] as List)
          .map((a) => VoiceRoomUser.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }

    DateTime? parsedExpiresAt;
    if (json['expiresAt'] != null || json['expires_at'] != null) {
      final raw = json['expiresAt'] ?? json['expires_at'];
      if (raw is String && raw.isNotEmpty) {
        parsedExpiresAt = DateTime.tryParse(raw)?.toLocal();
      }
    }

    final parsedCost = (json['costPaid'] as num?)?.toDouble() ??
        (json['cost_paid'] as num?)?.toDouble() ??
        0.0;

    final parsedIsActive = json['isActive'] == true ||
        json['is_active'] == true ||
        (json['isActive'] == null && json['is_active'] == null);

    final parsedIsLocked = json['isLocked'] == true || json['is_locked'] == true;
    final parsedHasPin = json['hasPin'] == true || json['has_pin'] == true;
    final parsedIsHostInRoom = json['isHostInRoom'] == true || json['is_host_in_room'] == true;

    final parsedHost = json['host'] != null
        ? VoiceRoomUser.fromJson(Map<String, dynamic>.from(json['host']))
        : VoiceRoomUser(id: 0, username: 'Host', fullName: 'Host', avatarUrl: '');

    // Defense-in-depth: Host belongs on stage (seat 99), never in guest seats (0..7)
    if (parsedHost.id != 0) {
      for (int i = 0; i < parsedSeats.length; i++) {
        if (parsedSeats[i].user != null &&
            parsedSeats[i].user!.id.toString() == parsedHost.id.toString()) {
          parsedSeats[i] = parsedSeats[i].copyWith(clearUser: true, user: null);
        }
      }
    }

    return VoiceRoom(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      roomCode: json['roomCode']?.toString() ?? json['room_code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Voice Room',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Chat',
      theme: json['theme']?.toString() ?? 'cosmic_night',
      coverUrl: json['coverUrl']?.toString() ?? json['cover_url']?.toString() ?? '',
      roomType: json['roomType']?.toString() ?? json['room_type']?.toString() ?? 'temporary',
      expiresAt: parsedExpiresAt,
      costPaid: parsedCost,
      isLocked: parsedIsLocked,
      hasPin: parsedHasPin,
      maxSeats: json['maxSeats'] is int ? json['maxSeats'] : 8,
      occupiedSeatsCount: json['occupiedSeatsCount'] is int ? json['occupiedSeatsCount'] : 0,
      isActive: parsedIsActive,
      isHostInRoom: parsedIsHostInRoom,
      host: parsedHost,
      admins: parsedAdmins,
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
  final String emoji;
  final String svgaUrl;
  final String desc;

  const VoiceRoomGift({
    required this.id,
    required this.name,
    required this.coins,
    required this.icon,
    this.emoji = '🎁',
    required this.svgaUrl,
    required this.desc,
  });

  static const List<VoiceRoomGift> availableGifts = [
    VoiceRoomGift(
      id: 'gift_rose',
      name: 'Red Rose',
      coins: 5.0,
      icon: 'assets/gifts/rocket_icon.png',
      emoji: '🌹',
      svgaUrl: 'assets/gifts/rose.svga',
      desc: 'Delicate blooming red rose with soft glowing petals',
    ),
    VoiceRoomGift(
      id: 'gift_boba',
      name: 'Kats Boba Tea',
      coins: 20.0,
      icon: 'assets/gifts/rocket_icon.png',
      emoji: '🧋',
      svgaUrl: 'assets/gifts/boba.svga',
      desc: 'Sweet refreshing brown sugar boba milk tea treat!',
    ),
    VoiceRoomGift(
      id: 'gift_heart',
      name: 'Crystal Heart',
      coins: 50.0,
      icon: 'assets/gifts/rocket_icon.png',
      emoji: '💖',
      svgaUrl: 'assets/gifts/heartbeat.svga',
      desc: 'Luminous romantic beating heart with sparkling diamond glow',
    ),
    VoiceRoomGift(
      id: 'gift_crown',
      name: 'Royal Crown',
      coins: 100.0,
      icon: 'assets/gifts/fireworks_icon.png',
      emoji: '👑',
      svgaUrl: 'assets/gifts/kingset.svga',
      desc: 'Exquisite king crown jewelry with royal golden aura',
    ),
    VoiceRoomGift(
      id: 'gift_fireworks',
      name: 'Fireworks Festival',
      coins: 250.0,
      icon: 'assets/gifts/fireworks_icon.png',
      emoji: '🎆',
      svgaUrl: 'assets/gifts/halloween.svga',
      desc: 'Sky lit up with grand celebratory fireworks display!',
    ),
    VoiceRoomGift(
      id: 'gift_rocket',
      name: 'Cosmic Rocket',
      coins: 500.0,
      icon: 'assets/gifts/rocket_icon.png',
      emoji: '🚀',
      svgaUrl: 'assets/gifts/rocket.svga',
      desc: 'Launch a supersonic space rocket blasting across the room!',
    ),
    VoiceRoomGift(
      id: 'gift_super_car',
      name: 'Porsche Supercar',
      coins: 1000.0,
      icon: 'assets/gifts/rocket_icon.png',
      emoji: '🏎️',
      svgaUrl: 'assets/gifts/posche.svga',
      desc: 'Luxury racing supercar speeding with dynamic roar',
    ),
    VoiceRoomGift(
      id: 'gift_galaxy',
      name: 'Celestial Galaxy',
      coins: 2500.0,
      icon: 'assets/gifts/fireworks_icon.png',
      emoji: '🌌',
      svgaUrl: 'assets/gifts/galaxy.svga',
      desc: 'Breathtaking celestial galaxy with glowing stellar aura',
    ),
  ];
}
