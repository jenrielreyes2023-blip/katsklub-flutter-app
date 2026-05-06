class Post {
  const Post({
    required this.id,
    required this.authorFullName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.authorIsVerified,
    required this.authorIsAdmin,
    required this.authorIsAuthor,
    required this.ownedByMe,
    required this.visibility,
    required this.text,
    required this.createdAt,
    required this.imageUrls,
    required this.likeCount,
    required this.likedByMe,
    required this.commentCount,
  });

  final String id;
  final String authorFullName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool authorIsVerified;
  final bool authorIsAdmin;
  final bool authorIsAuthor;
  final bool ownedByMe;
  final String visibility;
  final String text;
  final DateTime? createdAt;
  final List<String> imageUrls;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: _readString(json['id']) ?? '',
      authorFullName: _readString(json['authorFullName']) ??
          _readString(json['fullName']) ??
          _readString(json['author']) ??
          'KatsKlub user',
      authorUsername: _readString(json['authorUsername']) ??
          _readString(json['username']) ??
          _readString(json['author']) ??
          '',
      authorAvatarUrl:
          _readString(json['authorAvatarUrl']) ?? _readString(json['avatarUrl']) ?? '',
      authorIsVerified:
          json['authorIsVerified'] == true || json['authorIsAdmin'] == true,
      authorIsAdmin: json['authorIsAdmin'] == true,
      authorIsAuthor: json['authorIsAuthor'] == true,
      ownedByMe: json['ownedByMe'] == true,
      visibility: _readString(json['visibility']) ?? 'public',
      text: _readString(json['text']) ?? _readString(json['content']) ?? '',
      createdAt: DateTime.tryParse(_readString(json['createdAt']) ?? ''),
      imageUrls: _readImageUrls(json),
      likeCount: _readInt(json['likeCount']),
      likedByMe: json['likedByMe'] == true,
      commentCount: _readInt(json['commentCount']),
    );
  }

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
  }) {
    return Post(
      id: id,
      authorFullName: authorFullName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorIsVerified: authorIsVerified,
      authorIsAdmin: authorIsAdmin,
      authorIsAuthor: authorIsAuthor,
      ownedByMe: ownedByMe,
      visibility: visibility,
      text: text,
      createdAt: createdAt,
      imageUrls: imageUrls,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount,
    );
  }

  String get authorInitials {
    final parts = authorFullName
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

  String get privacyLabel {
    switch (visibility) {
      case 'friends':
        return 'Friends';
      case 'only_me':
        return 'Only me';
      default:
        return 'Public';
    }
  }

  static List<String> _readImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];
    final slides = json['slides'];

    if (slides is List) {
      for (final slide in slides) {
        if (slide is Map<String, dynamic>) {
          final imageUrl = _readString(slide['imageUrl'] ?? slide['image_url']);
          if (imageUrl != null) {
            urls.add(imageUrl);
          }
        }
      }
    }

    final imageUrl = _readString(json['imageUrl'] ?? json['image_url']);
    if (imageUrl != null && !urls.contains(imageUrl)) {
      urls.add(imageUrl);
    }

    return urls;
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
