import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/post.dart';
import '../theme/app_text_styles.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white : const Color(0xFF111827);
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

class _ActionIcon extends StatefulWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
    this.color = const Color(0xFF65676B),
    this.onTap,
    super.key,
  });

  final Widget icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  int _prevCount = 0;

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
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _prevCount = widget.count;
  }

  @override
  void didUpdateWidget(covariant _ActionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count && widget.count > oldWidget.count) {
      _controller.forward().then((_) => _controller.reverse());
    }
    _prevCount = widget.count;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999.r),
      onTap: widget.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(scale: _scale, child: widget.icon),
            if (widget.count > 0) ...[
              SizedBox(width: 5.w),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  _formatCount(widget.count),
                  key: ValueKey<int>(widget.count),
                  style: KatsText.countLabel(context, widget.color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
