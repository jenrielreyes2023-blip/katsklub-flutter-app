class User {
  const User({
    this.id,
    this.fullName,
    this.username,
    this.email,
    this.phone,
    this.roleTitle,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.gender,
    this.birthday,
    this.location,
    this.createdAt,
    this.isAdmin = false,
    this.isVerified = false,
    this.isAuthor = false,
    this.isPrivate = false,
    this.isRequested = false,
    this.isMuted = false,
    this.isBlocked = false,
    this.showAdminBadge = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.isFollowing = false,
    this.profileShowEmail = true,
    this.profileShowGender = true,
    this.profileShowBirthday = true,
    this.profileShowLocation = true,
    this.profileShowPhone = false,
    this.profileShowFollowers = true,
    this.profileShowFollowing = true,
    this.profileBorder,
    this.postcardTheme,
    this.bubbleTheme,
    this.profileEffect,
    this.avatarFrame,
    this.achievements = const [],
    this.profileLinks = const [],
    this.featuredPhotos = const [],
    this.pinnedPostId,
    this.charmPoints = 0,
    this.recentVisitors = const [],
    this.newVisitorsCount = 0,
    required this.raw,
  });

  final String? id;
  final String? fullName;
  final String? username;
  final String? email;
  final String? phone;
  final String? roleTitle;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? gender;
  final String? birthday;
  final String? location;
  final String? createdAt;
  final bool isAdmin;
  final bool isVerified;
  final bool isAuthor;
  final bool isPrivate;
  final bool isRequested;
  final bool isMuted;
  final bool isBlocked;
  final bool showAdminBadge;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final bool isFollowing;
  final bool profileShowEmail;
  final bool profileShowGender;
  final bool profileShowBirthday;
  final bool profileShowLocation;
  final bool profileShowPhone;
  final bool profileShowFollowers;
  final bool profileShowFollowing;
  final String? profileBorder;
  final String? postcardTheme;
  final String? bubbleTheme;
  final String? profileEffect;
  final String? avatarFrame;
  final List<String> achievements;
  final List<ProfileLink> profileLinks;
  final List<FeaturedPhoto> featuredPhotos;
  final int? pinnedPostId;
  final int charmPoints;
  final List<ProfileVisitorInfo> recentVisitors;
  final int newVisitorsCount;
  final Map<String, dynamic> raw;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _readString(json['id']),
      fullName: _readString(json['fullName'] ?? json['full_name']),
      username: _readString(json['username']),
      email: _readString(json['email']),
      phone: _readString(json['phone']),
      roleTitle: _readString(json['roleTitle'] ?? json['role_title']),
      avatarUrl: _readString(json['avatarUrl'] ?? json['avatar_url']),
      coverUrl: _readString(json['coverUrl'] ?? json['cover_url']),
      bio: _readString(json['bio']),
      gender: _readString(json['gender']),
      birthday: _readString(json['birthday']),
      location: _readString(json['location']),
      createdAt: _readString(json['createdAt'] ?? json['created_at']),
      isAdmin: _readBool(json['isAdmin'] ?? json['is_admin']),
      isVerified: _readBool(json['isVerified'] ?? json['is_verified']),
      isAuthor: _readBool(json['isAuthor'] ?? json['is_author']),
      isPrivate: _readBool(json['isPrivate'] ?? json['is_private']),
      isRequested: _readBool(json['isRequested'] ?? json['is_requested']),
      isMuted: _readBool(json['isMuted'] ?? json['is_muted']),
      isBlocked: _readBool(json['isBlocked'] ?? json['is_blocked']),
      showAdminBadge:
          _readBool(json['showAdminBadge'] ?? json['show_admin_badge']),
      followersCount: _readInt(
        json['followersCount'] ??
            json['followerCount'] ??
            json['followers_count'] ??
            json['follower_count'],
      ),
      followingCount:
          _readInt(json['followingCount'] ?? json['following_count']),
      postCount: _readInt(
        json['postCount'] ?? json['postsCount'] ?? json['post_count'],
      ),
      isFollowing: _readBool(
        json['isFollowing'] ??
            json['isFollowedByMe'] ??
            json['is_following'] ??
            json['is_followed_by_me'],
      ),
      profileShowEmail: _readBool(
        json['profileShowEmail'] ?? json['profile_show_email'] ?? true,
      ),
      profileShowGender: _readBool(
        json['profileShowGender'] ?? json['profile_show_gender'] ?? true,
      ),
      profileShowBirthday: _readBool(
        json['profileShowBirthday'] ?? json['profile_show_birthday'] ?? true,
      ),
      profileShowLocation: _readBool(
        json['profileShowLocation'] ?? json['profile_show_location'] ?? true,
      ),
      profileShowPhone: _readBool(
        json['profileShowPhone'] ?? json['profile_show_phone'] ?? false,
      ),
      profileShowFollowers: _readBool(
        json['profileShowFollowers'] ?? json['profile_show_followers'] ?? true,
      ),
      profileShowFollowing: _readBool(
        json['profileShowFollowing'] ?? json['profile_show_following'] ?? true,
      ),
      profileBorder:
          _readString(json['profileBorder'] ?? json['profile_border']),
      postcardTheme: _readString(
        json['postcardTheme'] ?? json['postcard_theme'],
      ),
      bubbleTheme: _readString(
        json['bubbleTheme'] ?? json['bubble_theme'],
      ),
      profileEffect: _readString(
        json['profileEffect'] ?? json['profile_effect'],
      ),
      avatarFrame: _readString(
        json['avatarFrame'] ?? json['avatar_frame'],
      ),
      achievements: _readStringList(json['achievements']),
      profileLinks: _readProfileLinks(json['profileLinks'] ?? json['profile_links']),
      featuredPhotos: _readFeaturedPhotos(json['featuredPhotos'] ?? json['featured_photos']),
      pinnedPostId: json['pinnedPostId'] != null ? _readInt(json['pinnedPostId']) : (json['pinned_post_id'] != null ? _readInt(json['pinned_post_id']) : null),
      charmPoints: _readInt(json['charmPoints'] ?? json['charm_points']),
      recentVisitors: (json['recentVisitors'] as List?)
              ?.map((item) => ProfileVisitorInfo.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      newVisitorsCount: _readInt(json['newVisitorsCount'] ?? json['new_visitors_count']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  String get displayName {
    if (_hasValue(fullName)) {
      return fullName!.trim();
    }

    if (_hasValue(username)) {
      return username!.trim();
    }

    if (_hasValue(email)) {
      return email!.trim();
    }

    return 'KatsKlub user';
  }

  int get charmLevel {
    if (username?.toLowerCase() == 'jayriel' || id == '2') {
      return 20;
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

  String get charmBadgeAsset => getCharmBadgeAsset(charmLevel);

  static String getCharmBadgeAsset(int level) {
    final lvl = level.clamp(1, 20);
    final formatted = lvl.toString().padLeft(2, '0');
    return 'assets/vip-charm/charm-$formatted.png';
  }

  String? get handle {
    if (!_hasValue(username)) {
      return null;
    }

    return '@${username!.trim()}';
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'K';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(raw);
  }

  User copyWith({
    int? followersCount,
    int? followingCount,
    int? postCount,
    bool? isFollowing,
    bool? isPrivate,
    bool? isRequested,
    bool? isMuted,
    bool? isBlocked,
    bool? profileShowEmail,
    bool? profileShowGender,
    bool? profileShowBirthday,
    bool? profileShowLocation,
    bool? profileShowPhone,
    bool? profileShowFollowers,
    bool? profileShowFollowing,
    String? profileBorder,
    String? postcardTheme,
    String? bubbleTheme,
    String? profileEffect,
    String? avatarFrame,
    String? coverUrl,
    List<String>? achievements,
    List<ProfileLink>? profileLinks,
    List<FeaturedPhoto>? featuredPhotos,
    int? pinnedPostId,
    int? charmPoints,
    List<ProfileVisitorInfo>? recentVisitors,
    int? newVisitorsCount,
    Map<String, dynamic>? raw,
  }) {
    final nextFollowersCount = followersCount ?? this.followersCount;
    final nextFollowingCount = followingCount ?? this.followingCount;
    final nextPostCount = postCount ?? this.postCount;
    final nextCharmPoints = charmPoints ?? this.charmPoints;
    final nextIsFollowing = isFollowing ?? this.isFollowing;
    final nextIsPrivate = isPrivate ?? this.isPrivate;
    final nextIsRequested = isRequested ?? this.isRequested;
    final nextIsMuted = isMuted ?? this.isMuted;
    final nextIsBlocked = isBlocked ?? this.isBlocked;
    final nextProfileShowEmail = profileShowEmail ?? this.profileShowEmail;
    final nextProfileShowGender = profileShowGender ?? this.profileShowGender;
    final nextProfileShowBirthday =
        profileShowBirthday ?? this.profileShowBirthday;
    final nextProfileShowLocation =
        profileShowLocation ?? this.profileShowLocation;
    final nextProfileShowPhone = profileShowPhone ?? this.profileShowPhone;
    final nextProfileShowFollowers =
        profileShowFollowers ?? this.profileShowFollowers;
    final nextProfileShowFollowing =
        profileShowFollowing ?? this.profileShowFollowing;
    final nextProfileBorder = profileBorder ?? this.profileBorder;
    final nextPostcardTheme = postcardTheme ?? this.postcardTheme;
    final nextBubbleTheme = bubbleTheme ?? this.bubbleTheme;
    final nextProfileEffect = profileEffect ?? this.profileEffect;
    final nextAvatarFrame = avatarFrame ?? this.avatarFrame;
    final nextCoverUrl = coverUrl ?? this.coverUrl;
    final nextAchievements = achievements ?? this.achievements;
    final nextProfileLinks = profileLinks ?? this.profileLinks;
    final nextFeaturedPhotos = featuredPhotos ?? this.featuredPhotos;
    final nextPinnedPostId = pinnedPostId ?? this.pinnedPostId;
    final nextRecentVisitors = recentVisitors ?? this.recentVisitors;
    final nextNewVisitorsCount = newVisitorsCount ?? this.newVisitorsCount;
    final nextRaw = Map<String, dynamic>.from(raw ?? this.raw)
      ..['followersCount'] = nextFollowersCount
      ..['followingCount'] = nextFollowingCount
      ..['postCount'] = nextPostCount
      ..['isFollowing'] = nextIsFollowing
      ..['isPrivate'] = nextIsPrivate
      ..['isRequested'] = nextIsRequested
      ..['isMuted'] = nextIsMuted
      ..['isBlocked'] = nextIsBlocked
      ..['profileShowEmail'] = nextProfileShowEmail
      ..['profileShowGender'] = nextProfileShowGender
      ..['profileShowBirthday'] = nextProfileShowBirthday
      ..['profileShowLocation'] = nextProfileShowLocation
      ..['profileShowPhone'] = nextProfileShowPhone
      ..['profileShowFollowers'] = nextProfileShowFollowers
      ..['profileShowFollowing'] = nextProfileShowFollowing
      ..['profileBorder'] = nextProfileBorder
      ..['postcardTheme'] = nextPostcardTheme
      ..['bubbleTheme'] = nextBubbleTheme
      ..['profileEffect'] = nextProfileEffect
      ..['profile_effect'] = nextProfileEffect
      ..['avatarFrame'] = nextAvatarFrame
      ..['avatar_frame'] = nextAvatarFrame
      ..['coverUrl'] = nextCoverUrl
      ..['cover_url'] = nextCoverUrl
      ..['achievements'] = nextAchievements
      ..['profileLinks'] = nextProfileLinks.map((l) => l.toJson()).toList()
      ..['featuredPhotos'] = nextFeaturedPhotos.map((p) => p.toJson()).toList()
      ..['pinnedPostId'] = nextPinnedPostId
      ..['recentVisitors'] = nextRecentVisitors.map((v) => v.toJson()).toList()
      ..['newVisitorsCount'] = nextNewVisitorsCount
      ..['charmPoints'] = nextCharmPoints;

    return User(
      id: id,
      fullName: fullName,
      username: username,
      email: email,
      phone: phone,
      roleTitle: roleTitle,
      avatarUrl: avatarUrl,
      coverUrl: nextCoverUrl,
      bio: bio,
      gender: gender,
      birthday: birthday,
      location: location,
      createdAt: createdAt,
      isAdmin: isAdmin,
      isVerified: isVerified,
      isAuthor: isAuthor,
      isPrivate: nextIsPrivate,
      isRequested: nextIsRequested,
      isMuted: nextIsMuted,
      isBlocked: nextIsBlocked,
      showAdminBadge: showAdminBadge,
      followersCount: nextFollowersCount,
      followingCount: nextFollowingCount,
      postCount: nextPostCount,
      isFollowing: nextIsFollowing,
      profileShowEmail: nextProfileShowEmail,
      profileShowGender: nextProfileShowGender,
      profileShowBirthday: nextProfileShowBirthday,
      profileShowLocation: nextProfileShowLocation,
      profileShowPhone: nextProfileShowPhone,
      profileShowFollowers: nextProfileShowFollowers,
      profileShowFollowing: nextProfileShowFollowing,
      profileBorder: nextProfileBorder,
      postcardTheme: nextPostcardTheme,
      bubbleTheme: nextBubbleTheme,
      profileEffect: nextProfileEffect,
      avatarFrame: nextAvatarFrame,
      achievements: nextAchievements,
      profileLinks: nextProfileLinks,
      featuredPhotos: nextFeaturedPhotos,
      pinnedPostId: nextPinnedPostId,
      charmPoints: nextCharmPoints,
      recentVisitors: nextRecentVisitors,
      newVisitorsCount: nextNewVisitorsCount,
      raw: nextRaw,
    );
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    final stringValue = value?.toString().trim().toLowerCase();
    return stringValue == 'true' || stringValue == '1';
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    final seen = <String>{};
    final strings = <String>[];
    for (final entry in value) {
      final stringValue = _readString(entry);
      if (stringValue == null || seen.contains(stringValue)) {
        continue;
      }
      seen.add(stringValue);
      strings.add(stringValue);
    }
    return strings;
  }

  static List<ProfileLink> _readProfileLinks(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((e) => e is Map<String, dynamic> ? ProfileLink.fromJson(e) : null)
        .whereType<ProfileLink>()
        .toList();
  }

  static List<FeaturedPhoto> _readFeaturedPhotos(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((e) => e is Map<String, dynamic> ? FeaturedPhoto.fromJson(e) : null)
        .whereType<FeaturedPhoto>()
        .toList();
  }
}

class ProfileLink {
  const ProfileLink({
    required this.url,
    required this.title,
    required this.faviconUrl,
    required this.position,
  });

  final String url;
  final String title;
  final String faviconUrl;
  final int position;

  factory ProfileLink.fromJson(Map<String, dynamic> json) {
    return ProfileLink(
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      faviconUrl: json['faviconUrl'] ?? json['favicon_url'] ?? '',
      position: int.tryParse(json['position']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'faviconUrl': faviconUrl,
      'position': position,
    };
  }
}

class FeaturedPhoto {
  const FeaturedPhoto({
    required this.id,
    required this.photoUrl,
    required this.caption,
    required this.position,
  });

  final int id;
  final String photoUrl;
  final String caption;
  final int position;

  factory FeaturedPhoto.fromJson(Map<String, dynamic> json) {
    return FeaturedPhoto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      photoUrl: (json['photoUrl'] ?? json['photo_url'] ?? json['imageUrl'] ?? json['image_url'] ?? json['url'] ?? '').toString(),
      caption: (json['caption'] ?? '').toString(),
      position: int.tryParse(json['position']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photoUrl': photoUrl,
      'caption': caption,
      'position': position,
    };
  }
}

class ProfileVisitorInfo {
  final String username;
  final String avatarUrl;
  final String? visitedAt;

  ProfileVisitorInfo({
    required this.username,
    required this.avatarUrl,
    this.visitedAt,
  });

  factory ProfileVisitorInfo.fromJson(Map<String, dynamic> json) {
    return ProfileVisitorInfo(
      username: (json['username'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url'] ?? '').toString(),
      visitedAt: json['visitedAt']?.toString() ?? json['visited_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'avatarUrl': avatarUrl,
      'visitedAt': visitedAt,
    };
  }
}
