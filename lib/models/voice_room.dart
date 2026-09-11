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
      name: 'Red Rose',
      coins: 5.0,
      icon: 'assets/gifts/rocket_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket_audio.svga',
      desc: 'A lovely rose to show warmth & friendship',
    ),
    VoiceRoomGift(
      id: 'gift_boba',
      name: 'Kats Boba Milk Tea',
      coins: 20.0,
      icon: 'assets/gifts/rocket_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket.svga',
      desc: 'Sweet refreshing boba milk tea treat!',
    ),
    VoiceRoomGift(
      id: 'gift_fireworks',
      name: 'Fireworks Festival',
      coins: 100.0,
      icon: 'assets/gifts/fireworks_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/fireworks_audio.svga',
      desc: 'Sky lit up with grand fireworks & sound!',
    ),
    VoiceRoomGift(
      id: 'gift_rocket',
      name: 'Cosmic Space Rocket',
      coins: 500.0,
      icon: 'assets/gifts/rocket_icon.png',
      svgaUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_gifts/rocket_audio.svga',
      desc: 'Launch a supersonic space rocket across the room!',
    ),
  ];
}
