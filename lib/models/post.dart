class Post {
  const Post({
    required this.id,
    required this.authorFullName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.authorIsVerified,
    required this.authorIsAdmin,
    required this.authorIsAuthor,
    required this.isFollowingAuthor,
    required this.ownedByMe,
    required this.visibility,
    required this.text,
    required this.isReel,
    required this.isAlbum,
    required this.isDiscussion,
    required this.albumTitle,
    required this.discussionTitle,
    required this.discussionCoverUrl,
    required this.videoUrl,
    required this.videoPosterUrl,
    required this.videoTitle,
    this.aspectRatio,
    this.mediaAspectRatio,
    this.videoWidth,
    this.videoHeight,
    this.mediaWidth,
    this.mediaHeight,
    this.thumbnailWidth,
    this.thumbnailHeight,
    required this.createdAt,
    required this.imageUrls,
    required this.thumbnailUrls,
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
  final bool isFollowingAuthor;
  final bool ownedByMe;
  final String visibility;
  final String text;
  final bool isReel;
  final bool isAlbum;
  final bool isDiscussion;
  final String albumTitle;
  final String discussionTitle;
  final String discussionCoverUrl;
  final String videoUrl;
  final String videoPosterUrl;
  final String videoTitle;
  final double? aspectRatio;
  final double? mediaAspectRatio;
  final int? videoWidth;
  final int? videoHeight;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? thumbnailWidth;
  final int? thumbnailHeight;
  final DateTime? createdAt;
  final List<String> imageUrls;
  final List<String> thumbnailUrls;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;

  factory Post.fromJson(Map<String, dynamic> json) {
    final imageUrls = _readImageUrls(json);

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
      authorAvatarUrl: _readString(json['authorAvatarUrl']) ??
          _readString(json['avatarUrl']) ??
          '',
      authorIsVerified:
          json['authorIsVerified'] == true || json['authorIsAdmin'] == true,
      authorIsAdmin: json['authorIsAdmin'] == true,
      authorIsAuthor: json['authorIsAuthor'] == true,
      isFollowingAuthor: json['isFollowingAuthor'] == true,
      ownedByMe: json['ownedByMe'] == true,
      visibility: _readString(json['visibility']) ?? 'public',
      text: _readString(json['text']) ?? _readString(json['content']) ?? '',
      isReel: json['isReel'] == true || json['is_reel'] == true,
      isAlbum: json['isAlbum'] == true || json['is_album'] == true,
      isDiscussion:
          json['isDiscussion'] == true || json['is_discussion'] == true,
      albumTitle: _readString(json['albumTitle'] ?? json['album_title']) ?? '',
      discussionTitle:
          _readString(json['discussionTitle'] ?? json['discussion_title']) ??
              '',
      discussionCoverUrl: _readString(
              json['discussionCoverUrl'] ?? json['discussion_cover_url']) ??
          '',
      videoUrl: _readString(json['videoUrl'] ?? json['video_url']) ?? '',
      videoPosterUrl:
          _readString(json['videoPosterUrl'] ?? json['video_poster_url']) ?? '',
      videoTitle: _readString(json['videoTitle'] ?? json['video_title']) ?? '',
      aspectRatio: _readDouble(
        json['aspectRatio'] ??
            json['aspect_ratio'] ??
            json['videoAspectRatio'] ??
            json['video_aspect_ratio'],
      ),
      mediaAspectRatio: _readDouble(
        json['mediaAspectRatio'] ??
            json['media_aspect_ratio'] ??
            json['aspectRatio'] ??
            json['aspect_ratio'],
      ),
      videoWidth: _readNullableInt(json['videoWidth'] ?? json['video_width']),
      videoHeight:
          _readNullableInt(json['videoHeight'] ?? json['video_height']),
      mediaWidth: _readNullableInt(json['mediaWidth'] ?? json['media_width']),
      mediaHeight:
          _readNullableInt(json['mediaHeight'] ?? json['media_height']),
      thumbnailWidth:
          _readNullableInt(json['thumbnailWidth'] ?? json['thumbnail_width']),
      thumbnailHeight:
          _readNullableInt(json['thumbnailHeight'] ?? json['thumbnail_height']),
      createdAt: DateTime.tryParse(_readString(json['createdAt']) ?? ''),
      imageUrls: imageUrls,
      thumbnailUrls: _readThumbnailUrls(
        json,
        fallbackImageUrls: imageUrls,
      ),
      likeCount: _readInt(json['likeCount']),
      likedByMe: json['likedByMe'] == true,
      commentCount: _readInt(json['commentCount']),
    );
  }

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
  }) {
    return Post(
      id: id,
      authorFullName: authorFullName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorIsVerified: authorIsVerified,
      authorIsAdmin: authorIsAdmin,
      authorIsAuthor: authorIsAuthor,
      isFollowingAuthor: isFollowingAuthor,
      ownedByMe: ownedByMe,
      visibility: visibility,
      text: text,
      isReel: isReel,
      isAlbum: isAlbum,
      isDiscussion: isDiscussion,
      albumTitle: albumTitle,
      discussionTitle: discussionTitle,
      discussionCoverUrl: discussionCoverUrl,
      videoUrl: videoUrl,
      videoPosterUrl: videoPosterUrl,
      videoTitle: videoTitle,
      aspectRatio: aspectRatio,
      mediaAspectRatio: mediaAspectRatio,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
      createdAt: createdAt,
      imageUrls: imageUrls,
      thumbnailUrls: thumbnailUrls,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount ?? this.commentCount,
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

  String get displayTitle {
    if (isDiscussion && discussionTitle.trim().isNotEmpty) {
      return discussionTitle.trim();
    }
    if (isAlbum && albumTitle.trim().isNotEmpty) {
      return albumTitle.trim();
    }
    return '';
  }

  bool get hasVideo => videoUrl.trim().isNotEmpty;

  String get primaryVideoPosterUrl {
    if (videoPosterUrl.trim().isNotEmpty) {
      return videoPosterUrl.trim();
    }
    if (thumbnailUrls.isNotEmpty) {
      return thumbnailUrls.first;
    }
    return imageUrls.isNotEmpty ? imageUrls.first : '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorFullName': authorFullName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl,
      'authorIsVerified': authorIsVerified,
      'authorIsAdmin': authorIsAdmin,
      'authorIsAuthor': authorIsAuthor,
      'isFollowingAuthor': isFollowingAuthor,
      'ownedByMe': ownedByMe,
      'visibility': visibility,
      'text': text,
      'isReel': isReel,
      'isAlbum': isAlbum,
      'isDiscussion': isDiscussion,
      'albumTitle': albumTitle,
      'discussionTitle': discussionTitle,
      'discussionCoverUrl': discussionCoverUrl,
      'videoUrl': videoUrl,
      'videoPosterUrl': videoPosterUrl,
      'videoTitle': videoTitle,
      'aspectRatio': aspectRatio,
      'mediaAspectRatio': mediaAspectRatio,
      'videoWidth': videoWidth,
      'videoHeight': videoHeight,
      'mediaWidth': mediaWidth,
      'mediaHeight': mediaHeight,
      'thumbnailWidth': thumbnailWidth,
      'thumbnailHeight': thumbnailHeight,
      'createdAt': createdAt?.toIso8601String(),
      'imageUrls': imageUrls,
      'thumbnailUrls': thumbnailUrls,
      'likeCount': likeCount,
      'likedByMe': likedByMe,
      'commentCount': commentCount,
    };
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

    final imageUrls = json['imageUrls'];
    if (imageUrls is List) {
      for (final image in imageUrls) {
        final parsed = _readString(image);
        if (parsed != null && !urls.contains(parsed)) {
          urls.add(parsed);
        }
      }
    }

    final discussionCoverUrl =
        _readString(json['discussionCoverUrl'] ?? json['discussion_cover_url']);
    if (discussionCoverUrl != null && !urls.contains(discussionCoverUrl)) {
      urls.add(discussionCoverUrl);
    }

    return urls;
  }

  static List<String> _readThumbnailUrls(
    Map<String, dynamic> json, {
    required List<String> fallbackImageUrls,
  }) {
    final directLists = [
      json['thumbnailUrls'],
      json['thumbnail_urls'],
      json['imageThumbnailUrls'],
      json['image_thumbnail_urls'],
      json['imageThumbUrls'],
      json['image_thumb_urls'],
    ];

    for (final list in directLists) {
      final parsed = _readStringList(list);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final urls = <String>[];
    final slides = json['slides'];

    if (slides is List) {
      for (final slide in slides) {
        if (slide is Map<String, dynamic>) {
          final thumbnailUrl = _readString(
            slide['thumbnailUrl'] ??
                slide['thumbnail_url'] ??
                slide['thumbUrl'] ??
                slide['thumb_url'] ??
                slide['smallUrl'] ??
                slide['small_url'] ??
                slide['optimizedUrl'] ??
                slide['optimized_url'] ??
                slide['imageUrl'] ??
                slide['image_url'],
          );
          if (thumbnailUrl != null && !urls.contains(thumbnailUrl)) {
            urls.add(thumbnailUrl);
          }
        }
      }
    }

    final imageThumbnailUrl = _readString(
      json['thumbnailUrl'] ??
          json['thumbnail_url'] ??
          json['imageThumbnailUrl'] ??
          json['image_thumbnail_url'] ??
          json['imageThumbUrl'] ??
          json['image_thumb_url'] ??
          json['smallUrl'] ??
          json['small_url'] ??
          json['optimizedUrl'] ??
          json['optimized_url'] ??
          json['imageUrl'] ??
          json['image_url'],
    );
    if (imageThumbnailUrl != null && !urls.contains(imageThumbnailUrl)) {
      urls.add(imageThumbnailUrl);
    }

    final discussionCoverThumbnailUrl = _readString(
      json['discussionCoverThumbnailUrl'] ??
          json['discussion_cover_thumbnail_url'] ??
          json['discussionCoverThumbUrl'] ??
          json['discussion_cover_thumb_url'] ??
          json['discussionCoverUrl'] ??
          json['discussion_cover_url'],
    );
    if (discussionCoverThumbnailUrl != null &&
        !urls.contains(discussionCoverThumbnailUrl)) {
      urls.add(discussionCoverThumbnailUrl);
    }

    return urls.isEmpty ? fallbackImageUrls : urls;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    final urls = <String>[];
    for (final item in value) {
      final parsed = _readString(item);
      if (parsed != null && !urls.contains(parsed)) {
        urls.add(parsed);
      }
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

  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }

    final parsed = value is int ? value : int.tryParse(value.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static double? _readDouble(Object? value) {
    if (value == null) {
      return null;
    }

    final parsed =
        value is num ? value.toDouble() : double.tryParse(value.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
