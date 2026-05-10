class User {
  const User({
    this.id,
    this.fullName,
    this.username,
    this.email,
    this.roleTitle,
    this.avatarUrl,
    this.bio,
    this.createdAt,
    this.isAdmin = false,
    this.isVerified = false,
    this.isAuthor = false,
    this.showAdminBadge = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.isFollowing = false,
    required this.raw,
  });

  final String? id;
  final String? fullName;
  final String? username;
  final String? email;
  final String? roleTitle;
  final String? avatarUrl;
  final String? bio;
  final String? createdAt;
  final bool isAdmin;
  final bool isVerified;
  final bool isAuthor;
  final bool showAdminBadge;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final bool isFollowing;
  final Map<String, dynamic> raw;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _readString(json['id']),
      fullName: _readString(json['fullName'] ?? json['full_name']),
      username: _readString(json['username']),
      email: _readString(json['email']),
      roleTitle: _readString(json['roleTitle'] ?? json['role_title']),
      avatarUrl: _readString(json['avatarUrl'] ?? json['avatar_url']),
      bio: _readString(json['bio']),
      createdAt: _readString(json['createdAt'] ?? json['created_at']),
      isAdmin: _readBool(json['isAdmin'] ?? json['is_admin']),
      isVerified: _readBool(json['isVerified'] ?? json['is_verified']),
      isAuthor: _readBool(json['isAuthor'] ?? json['is_author']),
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
    int? postCount,
    bool? isFollowing,
    Map<String, dynamic>? raw,
  }) {
    return User(
      id: id,
      fullName: fullName,
      username: username,
      email: email,
      roleTitle: roleTitle,
      avatarUrl: avatarUrl,
      bio: bio,
      createdAt: createdAt,
      isAdmin: isAdmin,
      isVerified: isVerified,
      isAuthor: isAuthor,
      showAdminBadge: showAdminBadge,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      postCount: postCount ?? this.postCount,
      isFollowing: isFollowing ?? this.isFollowing,
      raw: raw ?? this.raw,
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
}
