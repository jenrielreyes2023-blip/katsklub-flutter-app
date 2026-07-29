class Story {
  const Story({
    required this.id,
    required this.authorFullName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.ownedByMe,
    this.text,
    this.imageUrl,
    this.videoUrl,
    this.videoPosterUrl,
    this.createdAt,
    this.backgroundStartColor,
    this.backgroundEndColor,
    this.musicTitle,
    this.musicArtist,
    this.musicArtworkUrl,
    this.musicPreviewUrl,
    this.musicSource,
    this.isSensitive = false,
    this.viewCount = 0,
    this.reactionCount = 0,
    this.hasReacted = false,
  });

  final String id;
  final String authorFullName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool ownedByMe;
  final String? text;
  final String? imageUrl;
  final String? videoUrl;
  final String? videoPosterUrl;
  final String? createdAt;
  final String? backgroundStartColor;
  final String? backgroundEndColor;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicArtworkUrl;
  final String? musicPreviewUrl;
  final String? musicSource;
  final bool isSensitive;
  final int viewCount;
  final int reactionCount;
  final bool hasReacted;

  Story copyWith({
    int? viewCount,
    int? reactionCount,
    bool? hasReacted,
  }) {
    return Story(
      id: id,
      authorFullName: authorFullName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      ownedByMe: ownedByMe,
      text: text,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      videoPosterUrl: videoPosterUrl,
      createdAt: createdAt,
      backgroundStartColor: backgroundStartColor,
      backgroundEndColor: backgroundEndColor,
      musicTitle: musicTitle,
      musicArtist: musicArtist,
      musicArtworkUrl: musicArtworkUrl,
      musicPreviewUrl: musicPreviewUrl,
      musicSource: musicSource,
      isSensitive: isSensitive,
      viewCount: viewCount ?? this.viewCount,
      reactionCount: reactionCount ?? this.reactionCount,
      hasReacted: hasReacted ?? this.hasReacted,
    );
  }

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: _readString(json['id']) ?? '',
      authorFullName: _readString(json['authorFullName']) ??
          _readString(json['fullName']) ??
          _readString(json['author']) ??
          'KatsKlub user',
      authorUsername: _readString(json['authorUsername']) ??
          _readString(json['username']) ??
          '',
      authorAvatarUrl: _readString(json['authorAvatarUrl']) ??
          _readString(json['avatarUrl']) ??
          '',
      ownedByMe: json['ownedByMe'] == true,
      text: _readString(json['text']),
      imageUrl: _readString(json['imageUrl']) ?? _readString(json['image_url']),
      videoUrl: _readString(json['videoUrl']) ?? _readString(json['video_url']),
      videoPosterUrl: _readString(json['videoPosterUrl']) ??
          _readString(json['video_poster_url']),
      createdAt: _readString(json['createdAt']) ?? _readString(json['created_at']),
      backgroundStartColor: _readString(json['backgroundStartColor']) ?? _readString(json['background_start_color']),
      backgroundEndColor: _readString(json['backgroundEndColor']) ?? _readString(json['background_end_color']),
      musicTitle: _readString(json['musicTitle']) ?? _readString(json['music_title']),
      musicArtist: _readString(json['musicArtist']) ?? _readString(json['music_artist']),
      musicArtworkUrl: _readString(json['musicArtworkUrl']) ?? _readString(json['music_artwork_url']),
      musicPreviewUrl: _readString(json['musicPreviewUrl']) ?? _readString(json['music_preview_url']),
      musicSource: _readString(json['musicSource']) ?? _readString(json['music_source']),
      isSensitive: json['isSensitive'] == true || json['is_sensitive'] == true,
      viewCount: json['viewCount'] is int ? json['viewCount'] as int : int.tryParse(json['viewCount']?.toString() ?? '') ?? 0,
      reactionCount: json['reactionCount'] is int ? json['reactionCount'] as int : int.tryParse(json['reactionCount']?.toString() ?? '') ?? 0,
      hasReacted: json['hasReacted'] == true || json['has_reacted'] == true,
    );
  }

  String get initials {
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

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}
