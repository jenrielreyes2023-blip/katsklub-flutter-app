class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.body,
    required this.createdAt,
    required this.parentCommentId,
    required this.replyToUserId,
    required this.replyToUsername,
    required this.replyToFullName,
    required this.replyCount,
    required this.authorId,
    required this.authorFullName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.authorIsVerified,
    required this.authorIsAuthor,
    required this.authorIsAdmin,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final int id;
  final String postId;
  final String body;
  final DateTime? createdAt;
  final int? parentCommentId;
  final String? replyToUserId;
  final String? replyToUsername;
  final String? replyToFullName;
  final int replyCount;
  final String? authorId;
  final String authorFullName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool authorIsVerified;
  final bool authorIsAuthor;
  final bool authorIsAdmin;
  final int likeCount;
  final bool likedByMe;

  PostComment copyWith({
    int? replyCount,
    int? likeCount,
    bool? likedByMe,
  }) {
    return PostComment(
      id: id,
      postId: postId,
      body: body,
      createdAt: createdAt,
      parentCommentId: parentCommentId,
      replyToUserId: replyToUserId,
      replyToUsername: replyToUsername,
      replyToFullName: replyToFullName,
      replyCount: replyCount ?? this.replyCount,
      authorId: authorId,
      authorFullName: authorFullName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorIsVerified: authorIsVerified,
      authorIsAuthor: authorIsAuthor,
      authorIsAdmin: authorIsAdmin,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: _readInt(json['id']),
      postId: _readString(json['postId'] ?? json['post_id']) ?? '',
      body: _readString(json['body'] ?? json['content']) ?? '',
      createdAt: DateTime.tryParse(_readString(json['createdAt'] ?? json['created_at']) ?? ''),
      parentCommentId: _readNullableInt(
          json['parentCommentId'] ?? json['parent_comment_id']),
      replyToUserId:
          _readString(json['replyToUserId'] ?? json['reply_to_user_id']),
      replyToUsername:
          _readString(json['replyToUsername'] ?? json['reply_to_username']),
      replyToFullName:
          _readString(json['replyToFullName'] ?? json['reply_to_full_name']),
      replyCount: _readInt(json['replyCount'] ?? json['reply_count']),
      authorId: _readString(json['authorId'] ?? json['author_id']),
      authorFullName: _readString(
            json['authorFullName'] ?? json['author_full_name'],
          ) ??
          'KatsKlub user',
      authorUsername:
          _readString(json['authorUsername'] ?? json['author_username']) ?? '',
      authorAvatarUrl:
          _readString(json['authorAvatarUrl'] ?? json['author_avatar_url']) ??
              '',
      authorIsVerified: json['authorIsVerified'] == true ||
          json['author_is_verified'] == true,
      authorIsAuthor:
          json['authorIsAuthor'] == true || json['author_is_author'] == true,
      authorIsAdmin:
          json['authorIsAdmin'] == true || json['author_is_admin'] == true,
      likeCount: _readInt(json['likeCount'] ?? json['like_count']),
      likedByMe: json['likedByMe'] == true || json['liked_by_me'] == true || json['liked'] == true,
    );
  }

  String get displayName {
    final name = authorFullName.trim();
    if (name.isNotEmpty) {
      return name;
    }

    final username = authorUsername.trim().replaceFirst(RegExp(r'^@'), '');
    return username.isNotEmpty ? username : 'KatsKlub user';
  }

  String get usernameLabel {
    final username = authorUsername.trim().replaceFirst(RegExp(r'^@'), '');
    return username.isEmpty ? '' : '@$username';
  }

  String get authorInitials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return 'K';
    }
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  String get timeAgo {
    final created = createdAt;
    if (created == null) {
      return '';
    }

    final diff = DateTime.now().difference(created.toLocal());
    if (diff.inSeconds < 60) {
      return 'now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }
    if (diff.inDays < 365) {
      return '${(diff.inDays / 7).floor()}w';
    }
    return '${(diff.inDays / 365).floor()}y';
  }

  static String? _readString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
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
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
