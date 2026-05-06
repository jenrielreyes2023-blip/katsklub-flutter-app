import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import 'post_image_grid.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    required this.post,
    this.onOpenPost,
    this.onOpenImages,
    this.onOpenAuthor,
    this.onComment,
    this.onShare,
    this.onBookmark,
    this.onLike,
    super.key,
  });

  final Post post;
  final ValueChanged<Post>? onOpenPost;
  final void Function(Post post, int index)? onOpenImages;
  final ValueChanged<Post>? onOpenAuthor;
  final ValueChanged<Post>? onComment;
  final ValueChanged<Post>? onShare;
  final ValueChanged<Post>? onBookmark;
  final Future<Post> Function(Post post)? onLike;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post _post;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likeCount != widget.post.likeCount ||
        oldWidget.post.likedByMe != widget.post.likedByMe) {
      _post = widget.post;
    }
  }

  Future<void> _toggleLike() async {
    final onLike = widget.onLike;
    if (onLike == null || _isLiking) {
      return;
    }

    setState(() {
      _isLiking = true;
    });

    final previous = _post;
    setState(() {
      _post = _post.copyWith(
        likedByMe: !_post.likedByMe,
        likeCount:
            (_post.likeCount + (_post.likedByMe ? -1 : 1)).clamp(0, 1 << 31).toInt(),
      );
    });

    try {
      final updated = await onLike(previous);
      if (!mounted) return;
      setState(() {
        _post = updated;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = previous;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLiking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onOpenPost?.call(_post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostHeader(
              post: _post,
              onOpenAuthor: () => widget.onOpenAuthor?.call(_post),
            ),
            if (_post.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _post.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Color(0xFF111827),
                ),
              ),
            ],
            if (_post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              PostImageGrid(
                imageUrls: _post.imageUrls,
                onImageTap: (index) => widget.onOpenImages?.call(_post, index),
              ),
            ],
            const SizedBox(height: 12),
          _ReactionRow(
            post: _post,
            onLike: _toggleLike,
              onComment: () => widget.onComment?.call(_post),
              onShare: () => widget.onShare?.call(_post),
              onBookmark: () => widget.onBookmark?.call(_post),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onOpenAuthor,
  });

  final Post post;
  final VoidCallback onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onOpenAuthor,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: post.authorAvatarUrl.trim().isEmpty
                ? null
                : NetworkImage(ApiConfig.assetUrl(post.authorAvatarUrl)),
            child: post.authorAvatarUrl.trim().isEmpty
                ? Text(
                    post.authorInitials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onOpenAuthor,
                      child: Text(
                        post.authorFullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                  if (post.authorIsVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF2563EB),
                      size: 16,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTimestamp(post.createdAt)} · ${post.privacyLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {},
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Now';
    }

    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }

    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionIcon(
          icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
          count: post.likeCount,
          color: post.likedByMe ? const Color(0xFFE11D48) : const Color(0xFF4B5563),
          onTap: onLike,
        ),
        const SizedBox(width: 18),
        _ActionIcon(
          icon: Icons.mode_comment_outlined,
          count: post.commentCount,
          onTap: onComment,
        ),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_outlined, color: Color(0xFF4B5563)),
        ),
        const SizedBox(width: 18),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onBookmark,
          icon: const Icon(Icons.bookmark_border, color: Color(0xFF4B5563)),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
    this.color = const Color(0xFF4B5563),
    this.onTap,
  });

  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 5),
            Text(
              count > 0 ? count.toString() : '',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
