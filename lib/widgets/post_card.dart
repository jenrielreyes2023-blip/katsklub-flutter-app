import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import 'post_image_grid.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _PostHeader(post: post),
          if (post.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Color(0xFF111827),
              ),
            ),
          ],
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            PostImageGrid(imageUrls: post.imageUrls),
          ],
          const SizedBox(height: 12),
          _ReactionRow(post: post),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
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
  const _ReactionRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionIcon(
          icon: Icons.favorite_border,
          count: post.likeCount,
        ),
        const SizedBox(width: 18),
        _ActionIcon(
          icon: Icons.mode_comment_outlined,
          count: post.commentCount,
        ),
        const Spacer(),
        const Icon(Icons.ios_share_outlined, color: Color(0xFF4B5563)),
        const SizedBox(width: 18),
        const Icon(Icons.bookmark_border, color: Color(0xFF4B5563)),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
  });

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF4B5563)),
        const SizedBox(width: 5),
        Text(
          count > 0 ? count.toString() : '',
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
