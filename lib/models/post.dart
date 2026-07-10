import 'user.dart';

class PostSlide {
  const PostSlide({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
    required this.likeCount,
    required this.likedByMe,
  });

  final int id;
  final String imageUrl;
  final int sortOrder;
  final int likeCount;
  final bool likedByMe;

  factory PostSlide.fromJson(Map<String, dynamic> json) {
    return PostSlide(
      id: _readInt(json['id']),
      imageUrl: _readString(json['imageUrl'] ?? json['image_url']) ?? '',
      sortOrder: _readInt(json['sortOrder'] ?? json['sort_order']),
      likeCount: _readInt(json['likeCount'] ?? json['like_count']),
      likedByMe: json['likedByMe'] == true || json['liked_by_me'] == true,
    );
  }

  static String? _readString(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static int _readInt(Object? value) {
    if (value == null) return 0;
    final parsed = value is int ? value : int.tryParse(value.toString());
    return parsed != null && parsed >= 0 ? parsed : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
      'likeCount': likeCount,
      'likedByMe': likedByMe,
    };
  }

  PostSlide copyWith({
    int? id,
    String? imageUrl,
    int? sortOrder,
    int? likeCount,
    bool? likedByMe,
  }) {
    return PostSlide(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class LinkPreview {
  const LinkPreview({
    required this.url,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.domain,
  });

  final String url;
  final String title;
  final String description;
  final String imageUrl;
  final String domain;

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: _readStringValue(json['url']) ?? '',
      title: _readStringValue(json['title']) ?? '',
      description: _readStringValue(json['description']) ?? '',
      imageUrl: _readStringValue(json['imageUrl'] ?? json['image_url']) ?? '',
      domain: _readStringValue(json['domain']) ?? '',
    );
  }

  static String? _readStringValue(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'domain': domain,
    };
  }
}

class PollVoterPreview {
  const PollVoterPreview({
    required this.optionIndex,
    required this.fullName,
    required this.username,
    required this.avatarUrl,
  });

  final int optionIndex;
  final String fullName;
  final String username;
  final String avatarUrl;

  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final handle = username.trim();
    return handle.isNotEmpty ? handle : 'KatsKlub user';
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'K';
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  factory PollVoterPreview.fromJson(Map<String, dynamic> json) {
    return PollVoterPreview(
      optionIndex: _readInt(json['optionIndex'] ?? json['option_index']),
      fullName: _readString(json['fullName'] ?? json['full_name']) ?? '',
      username: _readString(json['username']) ?? '',
      avatarUrl: _readString(json['avatarUrl'] ?? json['avatar_url']) ?? '',
    );
  }

  static String? _readString(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static int _readInt(Object? value) {
    if (value == null) return 0;
    final parsed = value is int ? value : int.tryParse(value.toString());
    return parsed != null && parsed >= 0 ? parsed : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'optionIndex': optionIndex,
      'fullName': fullName,
      'username': username,
      'avatarUrl': avatarUrl,
    };
  }
}

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
    this.authorProfileBorder,
    this.authorPostcardTheme,
    required this.ownedByMe,
    required this.visibility,
    required this.repostOriginalPostId,
    this.originalPost,
    required this.text,
    required this.isReel,
    required this.isAlbum,
    required this.isDiscussion,
    this.isPoll = false,
    this.pollQuestion = '',
    this.pollOptions = const <String>[],
    this.pollOptionVotes = const <int>[],
    this.pollVoters = const <PollVoterPreview>[],
    this.pollVotes = 0,
    this.pollEndTime,
    this.hasVoted = false,
    this.selectedOptionIndex,
    required this.albumTitle,
    required this.discussionTitle,
    required this.discussionCoverUrl,
    required this.videoUrl,
    required this.videoPosterUrl,
    required this.videoTitle,
    this.videoVolume = 1.0,
    required this.youtubeVideoId,
    this.musicTitle = '',
    this.musicArtist = '',
    this.musicArtworkUrl = '',
    this.musicPreviewUrl = '',
    this.musicSource = '',
    this.linkPreview,
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
    required this.imageAspectRatios,
    required this.thumbnailUrls,
    required this.likeCount,
    required this.likedByMe,
    required this.bookmarkedByMe,
    required this.commentCount,
    required this.repostCount,
    this.withUsers = const [],
    this.isSensitive = false,
    this.location = '',
    this.feeling = '',
    this.isPinned = false,
    this.isGhost = false,
    this.slides = const [],
    this.repostedByText,
  });

  final String id;
  final String authorFullName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool authorIsVerified;
  final bool authorIsAdmin;
  final bool authorIsAuthor;
  final bool isFollowingAuthor;
  final String? authorProfileBorder;
  final String? authorPostcardTheme;
  final bool ownedByMe;
  final String visibility;
  final String repostOriginalPostId;
  final Post? originalPost;
  final String text;
  final bool isReel;
  final bool isAlbum;
  final bool isDiscussion;
  final bool isPoll;
  final String albumTitle;
  final String discussionTitle;
  final String discussionCoverUrl;
  final String videoUrl;
  final String videoPosterUrl;
  final String videoTitle;
  final double videoVolume;
  final String youtubeVideoId;
  final String musicTitle;
  final String musicArtist;
  final String musicArtworkUrl;
  final String musicPreviewUrl;
  final String musicSource;
  final LinkPreview? linkPreview;
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
  final List<double?> imageAspectRatios;
  final List<String> thumbnailUrls;
  final List<PostSlide> slides;
  final int likeCount;
  final bool likedByMe;
  final bool bookmarkedByMe;
  final int commentCount;
  final int repostCount;
  final List<User> withUsers;
  final String pollQuestion;
  final List<String> pollOptions;
  final List<int> pollOptionVotes;
  final List<PollVoterPreview> pollVoters;
  final int pollVotes;
  final DateTime? pollEndTime;
  final bool hasVoted;
  final int? selectedOptionIndex;
  final bool isSensitive;
  final String location;
  final String feeling;
  final bool isPinned;
  final bool isGhost;
  final String? repostedByText;

  factory Post.fromJson(Map<String, dynamic> json) {
    final imageUrls = _readImageUrls(json);
    final imageAspectRatios = _readImageAspectRatios(
      json,
      imageUrls: imageUrls,
    );

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
      authorProfileBorder: _readString(json['authorProfileBorder'] ??
          json['author_profile_border'] ??
          json['profileBorder'] ??
          json['profile_border']),
      authorPostcardTheme: _readString(
        json['authorPostcardTheme'] ??
            json['author_postcard_theme'] ??
            json['postcardTheme'] ??
            json['postcard_theme'],
      ),
      ownedByMe: json['ownedByMe'] == true,
      visibility: _readString(json['visibility']) ?? 'public',
      repostOriginalPostId: _readString(
            json['repostOriginalPostId'] ?? json['repost_original_post_id'],
          ) ??
          '',
      originalPost:
          _readNestedPost(json['originalPost'] ?? json['original_post']),
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
      videoVolume: _readVideoVolume(json),
      youtubeVideoId:
          _readString(json['youtubeVideoId'] ?? json['youtube_video_id']) ?? '',
      musicTitle: _readString(json['musicTitle'] ?? json['music_title']) ?? '',
      musicArtist:
          _readString(json['musicArtist'] ?? json['music_artist']) ?? '',
      musicArtworkUrl:
          _readString(json['musicArtworkUrl'] ?? json['music_artwork_url']) ??
              '',
      musicPreviewUrl:
          _readString(json['musicPreviewUrl'] ?? json['music_preview_url']) ??
              '',
      musicSource:
          _readString(json['musicSource'] ?? json['music_source']) ?? '',
      linkPreview: _readLinkPreview(json),
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
      imageAspectRatios: imageAspectRatios,
      thumbnailUrls: _readThumbnailUrls(
        json,
        fallbackImageUrls: imageUrls,
      ),
      likeCount: _readInt(json['likeCount']),
      likedByMe: json['likedByMe'] == true,
      bookmarkedByMe:
          json['bookmarkedByMe'] == true || json['bookmarked_by_me'] == true,
      commentCount: _readInt(json['commentCount']),
      repostCount: _readInt(json['repostCount']),
      withUsers: _readUsers(json['withUsers'] ?? json['with_users']),
      isPoll: json['isPoll'] == true || json['is_poll'] == true,
      pollQuestion:
          _readString(json['pollQuestion'] ?? json['poll_question']) ?? '',
      pollOptions: _readStringList(json['pollOptions'] ?? json['poll_options']),
      pollOptionVotes:
          _readIntList(json['pollOptionVotes'] ?? json['poll_option_votes']),
      pollVoters: _readPollVoters(json['pollVoters'] ?? json['poll_voters']),
      pollVotes: _readInt(json['pollVotes'] ?? json['poll_votes']),
      pollEndTime: DateTime.tryParse(
        _readString(json['pollEndTime'] ?? json['poll_end_time']) ?? '',
      ),
      hasVoted: json['hasVoted'] == true || json['has_voted'] == true,
      selectedOptionIndex: _readNullableInt(
        json['selectedOptionIndex'] ?? json['selected_option_index'],
      ),
      isSensitive: json['isSensitive'] == true || json['is_sensitive'] == true,
      isGhost: json['isGhost'] == true || json['is_ghost'] == true,
      location: _readString(json['location']) ?? '',
      feeling: _readString(json['feeling']) ?? '',
      isPinned: json['isPinned'] == true || json['is_pinned'] == true,
      slides: _readSlides(json),
      repostedByText: _readString(json['repostedByText'] ?? json['reposted_by_text']),
    );
  }

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
    bool? bookmarkedByMe,
    bool? isFollowingAuthor,
    int? commentCount,
    int? repostCount,
    String? repostOriginalPostId,
    Post? originalPost,
    String? authorPostcardTheme,
    List<User>? withUsers,
    bool? isPoll,
    String? pollQuestion,
    List<String>? pollOptions,
    List<int>? pollOptionVotes,
    List<PollVoterPreview>? pollVoters,
    int? pollVotes,
    DateTime? pollEndTime,
    bool? hasVoted,
    int? selectedOptionIndex,
    bool? isSensitive,
    String? location,
    String? feeling,
    bool? isPinned,
    bool? isGhost,
    List<PostSlide>? slides,
  }) {
    return Post(
      id: id,
      authorFullName: authorFullName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorIsVerified: authorIsVerified,
      authorIsAdmin: authorIsAdmin,
      authorIsAuthor: authorIsAuthor,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      authorProfileBorder: authorProfileBorder,
      authorPostcardTheme: authorPostcardTheme ?? this.authorPostcardTheme,
      ownedByMe: ownedByMe,
      visibility: visibility,
      repostOriginalPostId: repostOriginalPostId ?? this.repostOriginalPostId,
      originalPost: originalPost ?? this.originalPost,
      text: text,
      isReel: isReel,
      isAlbum: isAlbum,
      isDiscussion: isDiscussion,
      isPoll: isPoll ?? this.isPoll,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollOptionVotes: pollOptionVotes ?? this.pollOptionVotes,
      pollVoters: pollVoters ?? this.pollVoters,
      pollVotes: pollVotes ?? this.pollVotes,
      pollEndTime: pollEndTime ?? this.pollEndTime,
      hasVoted: hasVoted ?? this.hasVoted,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      isSensitive: isSensitive ?? this.isSensitive,
      location: location ?? this.location,
      feeling: feeling ?? this.feeling,
      albumTitle: albumTitle,
      discussionTitle: discussionTitle,
      discussionCoverUrl: discussionCoverUrl,
      videoUrl: videoUrl,
      videoPosterUrl: videoPosterUrl,
      videoTitle: videoTitle,
      videoVolume: videoVolume,
      youtubeVideoId: youtubeVideoId,
      musicTitle: musicTitle,
      musicArtist: musicArtist,
      musicArtworkUrl: musicArtworkUrl,
      musicPreviewUrl: musicPreviewUrl,
      musicSource: musicSource,
      linkPreview: linkPreview,
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
      imageAspectRatios: imageAspectRatios,
      thumbnailUrls: thumbnailUrls,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      withUsers: withUsers ?? this.withUsers,
      isPinned: isPinned ?? this.isPinned,
      isGhost: isGhost ?? this.isGhost,
      slides: slides ?? this.slides,
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

  bool get hasWithUsers => withUsers.isNotEmpty;

  bool get hasVideo => videoUrl.trim().isNotEmpty;

  bool get hasMusicPreview => musicPreviewUrl.trim().isNotEmpty;

  bool get isRepost =>
      repostOriginalPostId.trim().isNotEmpty || originalPost != null;

  LinkPreview? get resolvedLinkPreview {
    final preview = linkPreview;
    if (preview != null &&
        (preview.url.isNotEmpty ||
            preview.title.isNotEmpty ||
            preview.description.isNotEmpty ||
            preview.imageUrl.isNotEmpty)) {
      return preview;
    }

    if (youtubeVideoId.trim().isEmpty) {
      return null;
    }

    final videoId = youtubeVideoId.trim();
    return LinkPreview(
      url: 'https://www.youtube.com/watch?v=$videoId',
      title: 'YouTube video',
      description: '',
      imageUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      domain: 'YouTube',
    );
  }

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
      'authorProfileBorder': authorProfileBorder,
      'authorPostcardTheme': authorPostcardTheme,
      'ownedByMe': ownedByMe,
      'visibility': visibility,
      'repostOriginalPostId': repostOriginalPostId,
      'originalPost': originalPost?.toJson(),
      'text': text,
      'isReel': isReel,
      'isAlbum': isAlbum,
      'isDiscussion': isDiscussion,
      'isPoll': isPoll,
      'albumTitle': albumTitle,
      'discussionTitle': discussionTitle,
      'discussionCoverUrl': discussionCoverUrl,
      'videoUrl': videoUrl,
      'videoPosterUrl': videoPosterUrl,
      'videoTitle': videoTitle,
      'videoVolume': videoVolume,
      'youtubeVideoId': youtubeVideoId,
      'musicTitle': musicTitle,
      'musicArtist': musicArtist,
      'musicArtworkUrl': musicArtworkUrl,
      'musicPreviewUrl': musicPreviewUrl,
      'musicSource': musicSource,
      'linkPreview': linkPreview?.toJson(),
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
      'imageAspectRatios': imageAspectRatios,
      'thumbnailUrls': thumbnailUrls,
      'likeCount': likeCount,
      'likedByMe': likedByMe,
      'bookmarkedByMe': bookmarkedByMe,
      'commentCount': commentCount,
      'repostCount': repostCount,
      'withUsers': withUsers.map((user) => user.toJson()).toList(),
      'isSensitive': isSensitive,
      'isGhost': isGhost,
      'location': location,
      'feeling': feeling,
      // Poll fields
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'pollOptionVotes': pollOptionVotes,
      'pollVoters': pollVoters.map((voter) => voter.toJson()).toList(),
      'pollVotes': pollVotes,
      'pollEndTime': pollEndTime?.toIso8601String(),
      'hasVoted': hasVoted,
      'selectedOptionIndex': selectedOptionIndex,
    };
  }

  static Post? _readNestedPost(Object? value) {
    if (value is Map<String, dynamic>) {
      return Post.fromJson(value);
    }
    return null;
  }

  static List<User> _readUsers(Object? value) {
    if (value is! List) {
      return const <User>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(User.fromJson)
        .where((user) => (user.id ?? '').trim().isNotEmpty)
        .toList();
  }

  static LinkPreview? _readLinkPreview(Map<String, dynamic> json) {
    final value = json['linkPreview'] ?? json['link_preview'];
    if (value is Map<String, dynamic>) {
      final preview = LinkPreview.fromJson(value);
      if (preview.url.isNotEmpty ||
          preview.title.isNotEmpty ||
          preview.description.isNotEmpty ||
          preview.imageUrl.isNotEmpty) {
        return preview;
      }
    }

    final url = _readString(json['linkUrl'] ?? json['link_url']);
    final title = _readString(json['linkTitle'] ?? json['link_title']) ?? '';
    final description =
        _readString(json['linkDescription'] ?? json['link_description']) ?? '';
    final imageUrl =
        _readString(json['linkImageUrl'] ?? json['link_image_url']) ?? '';
    final domain = _readString(json['linkDomain'] ?? json['link_domain']) ?? '';

    if (url == null &&
        title.isEmpty &&
        description.isEmpty &&
        imageUrl.isEmpty) {
      return null;
    }

    return LinkPreview(
      url: url ?? '',
      title: title,
      description: description,
      imageUrl: imageUrl,
      domain: domain,
    );
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

  static List<PostSlide> _readSlides(Map<String, dynamic> json) {
    final rawSlides = json['slides'];
    final slides = <PostSlide>[];
    if (rawSlides is List) {
      for (final entry in rawSlides) {
        if (entry is Map<String, dynamic>) {
          slides.add(PostSlide.fromJson(entry));
        }
      }
    }
    return slides;
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

  static List<double?> _readImageAspectRatios(
    Map<String, dynamic> json, {
    required List<String> imageUrls,
  }) {
    final ratios = <double?>[];
    final slides = json['slides'];

    if (slides is List) {
      for (final slide in slides) {
        if (slide is! Map<String, dynamic>) {
          continue;
        }

        final imageUrl = _readString(slide['imageUrl'] ?? slide['image_url']);
        if (imageUrl == null) {
          continue;
        }

        ratios.add(_readAspectRatio(slide));
      }
    }

    if (ratios.isEmpty && imageUrls.isNotEmpty) {
      ratios.add(_readAspectRatio(json));
    }

    if (ratios.length < imageUrls.length) {
      ratios
          .addAll(List<double?>.filled(imageUrls.length - ratios.length, null));
    }

    if (ratios.length > imageUrls.length) {
      return ratios.take(imageUrls.length).toList(growable: false);
    }

    return List<double?>.unmodifiable(ratios);
  }

  static double? _readAspectRatio(Map<String, dynamic> json) {
    return _readDouble(
          json['imageAspectRatio'] ??
              json['image_aspect_ratio'] ??
              json['mediaAspectRatio'] ??
              json['media_aspect_ratio'] ??
              json['aspectRatio'] ??
              json['aspect_ratio'],
        ) ??
        _ratioFromDimensions(
          width: json['imageWidth'] ??
              json['image_width'] ??
              json['mediaWidth'] ??
              json['media_width'] ??
              json['width'],
          height: json['imageHeight'] ??
              json['image_height'] ??
              json['mediaHeight'] ??
              json['media_height'] ??
              json['height'],
        ) ??
        _ratioFromDimensions(
          width: json['thumbnailWidth'] ?? json['thumbnail_width'],
          height: json['thumbnailHeight'] ?? json['thumbnail_height'],
        );
  }

  static double? _ratioFromDimensions({
    required Object? width,
    required Object? height,
  }) {
    final parsedWidth = _readNullableInt(width);
    final parsedHeight = _readNullableInt(height);
    if (parsedWidth == null || parsedHeight == null || parsedHeight == 0) {
      return null;
    }

    return parsedWidth / parsedHeight;
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

  static List<PollVoterPreview> _readPollVoters(Object? value) {
    if (value is! List) {
      return const <PollVoterPreview>[];
    }

    return value
        .whereType<Map>()
        .map((item) =>
            PollVoterPreview.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static List<int> _readIntList(Object? value) {
    if (value is! List) {
      return const <int>[];
    }

    return value.map(_readNullableInt).whereType<int>().toList(growable: false);
  }

  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }

    final parsed = value is int ? value : int.tryParse(value.toString());
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static double? _readDouble(Object? value) {
    if (value == null) {
      return null;
    }

    final parsed =
        value is num ? value.toDouble() : double.tryParse(value.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static double _readVideoVolume(Map<String, dynamic> json) {
    final raw = json['videoVolume'] ?? json['video_volume'];
    if (raw is num) {
      final v = raw.toDouble();
      if (v.isNaN) return 1.0;
      return v.clamp(0.0, 1.0).toDouble();
    }
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null && !parsed.isNaN) {
        return parsed.clamp(0.0, 1.0).toDouble();
      }
    }
    final muted = json['videoMuted'] == true || json['video_muted'] == true;
    return muted ? 0.0 : 1.0;
  }
}
