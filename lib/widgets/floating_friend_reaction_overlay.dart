import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';

/// Represents a friend's interaction (like or repost) on a post.
class FriendPostActivity {
  const FriendPostActivity({
    required this.username,
    required this.avatarUrl,
    this.isLiked = false,
    this.isReposted = false,
  });

  final String username;
  final String avatarUrl;
  final bool isLiked;
  final bool isReposted;

  bool get hasActivity => isLiked || isReposted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendPostActivity &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          avatarUrl == other.avatarUrl &&
          isLiked == other.isLiked &&
          isReposted == other.isReposted;

  @override
  int get hashCode =>
      username.hashCode ^
      avatarUrl.hashCode ^
      isLiked.hashCode ^
      isReposted.hashCode;
}

/// A lightweight, 120fps butter-smooth floating draggable Top-3 Mountain Arch friend reaction overlay.
/// Features a non-overlapping Mountain Peak elevation and gentle floating zero-g bobbing motion.
class FloatingFriendReactionOverlay extends StatefulWidget {
  const FloatingFriendReactionOverlay({
    required this.activities,
    this.onTap,
    this.isPositioned = true,
    super.key,
  });

  final List<FriendPostActivity> activities;
  final VoidCallback? onTap;
  final bool isPositioned;

  @override
  State<FloatingFriendReactionOverlay> createState() =>
      _FloatingFriendReactionOverlayState();
}

class _FloatingFriendReactionOverlayState
    extends State<FloatingFriendReactionOverlay>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset?> _customOffsetNotifier =
      ValueNotifier<Offset?>(null);
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _floatAnimation = Tween<double>(begin: -3.5, end: 3.5).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _customOffsetNotifier.dispose();
    super.dispose();
  }

  void _showInfoToast(BuildContext context) {
    final active = widget.activities.where((a) => a.hasActivity).toList();
    if (active.isEmpty) return;

    final names = active.map((a) => '@${a.username}').join(', ');
    final hasRepost = active.any((a) => a.isReposted);
    final actionText = hasRepost ? 'reposted & liked' : 'liked';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasRepost ? Icons.repeat_rounded : Icons.favorite_rounded,
              color: hasRepost
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFF2D55),
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$names $actionText this post',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      ),
    );
  }

  Widget _buildMountainCluster(List<FriendPostActivity> items) {
    if (items.length == 1) {
      return _SingleAvatarBadge(
        key: ValueKey('avatar_${items.first.username}'),
        activity: items.first,
      );
    }

    if (items.length == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SingleAvatarBadge(
            key: ValueKey('avatar_${items[0].username}'),
            activity: items[0],
          ),
          const SizedBox(width: 8),
          Transform.translate(
            offset: const Offset(0, -8),
            child: _SingleAvatarBadge(
              key: ValueKey('avatar_${items[1].username}'),
              activity: items[1],
            ),
          ),
        ],
      );
    }

    // Top 3 Mountain Peak 🏔️ Formation (Non-overlapping with horizontal spacing + peak elevation)
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. Left Avatar (Base elevation)
        _SingleAvatarBadge(
          key: ValueKey('avatar_${items[0].username}'),
          activity: items[0],
        ),
        const SizedBox(width: 8),
        // 2. Center Peak Avatar 🏔️ (Elevated Peak)
        Transform.translate(
          offset: const Offset(0, -12),
          child: _SingleAvatarBadge(
            key: ValueKey('avatar_${items[1].username}'),
            activity: items[1],
          ),
        ),
        const SizedBox(width: 8),
        // 3. Right Avatar (Base elevation)
        _SingleAvatarBadge(
          key: ValueKey('avatar_${items[2].username}'),
          activity: items[2],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeItems =
        widget.activities.where((a) => a.hasActivity).take(3).toList();

    if (activeItems.isEmpty) {
      if (!widget.isPositioned) {
        return const SizedBox.shrink();
      }
      return const Positioned(
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        child: SizedBox.shrink(),
      );
    }

    final Widget clusterChild = GestureDetector(
      onPanUpdate: (details) {
        _customOffsetNotifier.value =
            (_customOffsetNotifier.value ?? Offset.zero) + details.delta;
      },
      onDoubleTap: () {
        _customOffsetNotifier.value = null;
      },
      onTap: () {
        widget.onTap?.call();
        _showInfoToast(context);
      },
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(top: 14), // Margin for peak elevation
            child: _buildMountainCluster(activeItems),
          ),
        ),
      ),
    );

    if (!widget.isPositioned) {
      return clusterChild;
    }

    return ValueListenableBuilder<Offset?>(
      valueListenable: _customOffsetNotifier,
      builder: (context, customPos, child) {
        final right = customPos != null ? 12 - customPos.dx : 12.0;
        final bottom = customPos != null ? 12 - customPos.dy : 12.0;

        return Positioned(
          right: right,
          bottom: bottom,
          child: child!,
        );
      },
      child: clusterChild,
    );
  }
}

/// Standalone, GPU-cached plain circular avatar badge.
/// Plain circle without outer white border, with subtle shadow.
class _SingleAvatarBadge extends StatelessWidget {
  const _SingleAvatarBadge({
    required this.activity,
    super.key,
  });

  final FriendPostActivity activity;

  @override
  Widget build(BuildContext context) {
    final isReposted = activity.isReposted;
    final badgeColor = isReposted
        ? const Color(0xFF10B981) // Emerald Green for Repost
        : const Color(0xFFFF2D55); // Pink/Red for Like
    final badgeIcon = isReposted
        ? Icons.repeat_rounded
        : Icons.favorite_rounded;

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Plain Circular Avatar (no white border)
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: ClipOval(
              child: activity.avatarUrl.trim().isEmpty
                  ? Container(
                      color: const Color(0xFF334155),
                      alignment: Alignment.center,
                      child: Text(
                        activity.username.isNotEmpty
                            ? activity.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: ApiConfig.assetUrl(activity.avatarUrl),
                      fit: BoxFit.cover,
                      memCacheWidth: 80,
                      maxWidthDiskCache: 80,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (context, url) => const ColoredBox(
                        color: Color(0xFF334155),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF334155),
                        alignment: Alignment.center,
                        child: Text(
                          activity.username.isNotEmpty
                              ? activity.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Mini Reaction Badge (Bottom-Right corner, plain circle)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                badgeIcon,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
