import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/post.dart';
import 'custom_icons.dart';

class ReactionRow extends StatelessWidget {
  const ReactionRow({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onRepost,
    required this.onBookmark,
    super.key,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onRepost;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFF65676B);
    const likedColor = Color(0xFFE11D48);
    
    final showCounts = !(post.isGhost && !post.ownedByMe);

    if (post.isGhost) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ActionIcon(
            icon: post.likedByMe
                ? CustomIcons.heartFilled(color: likedColor, size: 23)
                : CustomIcons.heart(color: inactiveColor, size: 23),
            count: showCounts ? post.likeCount : 0,
            color: post.likedByMe ? likedColor : inactiveColor,
            onTap: onLike,
          ),
          const SizedBox(width: 24),
          _ActionIcon(
            icon: CustomIcons.dm(color: inactiveColor, size: 23),
            count: showCounts ? post.commentCount : 0,
            onTap: onComment,
          ),
          const SizedBox(width: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CustomIcons.ghost(
                color: const Color(0xFFFF7A59),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                _getGhostTimeRemainingShort(post.createdAt),
                style: const TextStyle(
                  color: Color(0xFFFF7A59),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionIcon(
          icon: post.likedByMe
              ? CustomIcons.heartFilled(color: likedColor, size: 23)
              : CustomIcons.heart(color: inactiveColor, size: 23),
          count: showCounts ? post.likeCount : 0,
          color: post.likedByMe ? likedColor : inactiveColor,
          onTap: onLike,
        ),
        const SizedBox(width: 24),
        _ActionIcon(
          icon: CustomIcons.comment(color: inactiveColor, size: 23),
          count: showCounts ? post.commentCount : 0,
          onTap: onComment,
        ),
        const SizedBox(width: 24),
        _ActionIcon(
          icon: CustomIcons.repost(color: inactiveColor, size: 23),
          count: showCounts ? post.repostCount : 0,
          onTap: onRepost,
        ),
        const SizedBox(width: 24),
        _ActionIcon(
          icon: CustomIcons.share(color: inactiveColor, size: 23),
          count: 0,
          onTap: onShare,
        ),
        const Spacer(),
        _ActionIcon(
          icon: CustomIcons.bookmark(
            color: post.bookmarkedByMe
                ? Theme.of(context).colorScheme.primary
                : inactiveColor,
            size: 23,
            isFilled: post.bookmarkedByMe,
          ),
          count: 0,
          onTap: onBookmark,
        ),
      ],
    );
  }

  String _getGhostTimeRemainingShort(DateTime? createdAt) {
    if (createdAt == null) return '';
    final expiresAt = createdAt.add(const Duration(hours: 24));
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '(Expired)';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '(${hours}h)';
    } else {
      return '(${minutes}m)';
    }
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
    this.color = const Color(0xFF65676B),
    this.onTap,
  });

  final Widget icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  String _formatCount(int value) {
    if (value >= 1000000) {
      double val = value / 1000000.0;
      String str = val.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}M';
    }
    if (value >= 1000) {
      double val = value / 1000.0;
      String str = val.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}K';
    }
    return value.toString();
  }

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
            icon,
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: color,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.33,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
