import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/post.dart';
import 'media_post_load_registry.dart';

bool hasSnappableMedia(Post post) {
  return post.imageUrls.isNotEmpty || post.hasVideo;
}

class MediaPostSnapCoordinator {
  MediaPostSnapCoordinator({
    required this.controller,
    required this.topInsetBuilder,
    this.minFlingVelocity = 2400,
    this.snapLeadDistance = 28,
    this.hardClampEnabled = false,
    this.onClampStateChanged,
  }) {
    if (hardClampEnabled) {
      MediaPostLoadRegistry.changes.addListener(_onRegistryChanged);
    }
  }

  final ScrollController controller;
  final double Function() topInsetBuilder;
  final double minFlingVelocity;
  final double snapLeadDistance;
  final bool hardClampEnabled;
  final ValueChanged<bool>? onClampStateChanged;

  final Map<String, GlobalKey> _postKeys = <String, GlobalKey>{};
  bool _ballisticSnapArmed = false;
  bool _snapTriggeredForGesture = false;
  double? _scrollStartPixels;
  double? _pendingTargetOffset;
  ScrollDirection _lastUserDirection = ScrollDirection.idle;

  double? _hardClampOffset;
  String? _hardClampPostId;
  List<Post> _postsCache = const <Post>[];
  bool Function(Post)? _isMediaPostCache;
  bool _isClamping = false;

  void clearKeys() {
    _postKeys.clear();
  }

  GlobalKey keyForPost(Post post) {
    return _postKeys.putIfAbsent(
      post.id,
      () => GlobalKey(debugLabel: 'media-snap-${post.id}'),
    );
  }

  void dispose() {
    if (hardClampEnabled) {
      MediaPostLoadRegistry.changes.removeListener(_onRegistryChanged);
    }
  }

  bool handleNotification(
    ScrollNotification notification, {
    required List<Post> posts,
    required bool enabled,
    required bool Function(Post post) isMediaPost,
  }) {
    if (!enabled ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }

    _postsCache = posts;
    _isMediaPostCache = isMediaPost;

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _scrollStartPixels = notification.metrics.pixels;
      _lastUserDirection = ScrollDirection.idle;
      _pendingTargetOffset = null;
      _snapTriggeredForGesture = false;
      _ballisticSnapArmed = false;
      return false;
    }

    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _lastUserDirection = notification.direction;
      if (hardClampEnabled &&
          notification.direction == ScrollDirection.reverse) {
        _refreshHardClampTarget();
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (hardClampEnabled) {
        _enforceHardClamp(notification.metrics.pixels);
      }

      if (_ballisticSnapArmed && notification.dragDetails == null) {
        _maybePrepareTarget(posts: posts, isMediaPost: isMediaPost);
        _maybeClampToTarget(notification.metrics.pixels);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final releaseVelocity =
          notification.dragDetails?.primaryVelocity?.abs() ?? 0;
      if (_lastUserDirection == ScrollDirection.reverse &&
          releaseVelocity >= minFlingVelocity) {
        _ballisticSnapArmed = true;
      } else if (notification.dragDetails != null) {
        _resetGestureState();
      }

      if (notification.dragDetails == null) {
        _resetGestureState();
        if (hardClampEnabled) {
          _setClampingState(false);
        }
      }
    }

    return false;
  }

  void _refreshHardClampTarget() {
    if (!controller.hasClients ||
        _postsCache.isEmpty ||
        _isMediaPostCache == null) {
      _hardClampOffset = null;
      _hardClampPostId = null;
      return;
    }

    final measured = <_MeasuredPost>[];
    for (final post in _postsCache) {
      final key = _postKeys[post.id];
      final context = key?.currentContext;
      if (context == null) continue;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final viewport = RenderAbstractViewport.of(renderObject);
      final reveal = viewport.getOffsetToReveal(renderObject, 0);
      measured.add(
        _MeasuredPost(post: post, revealOffset: reveal.offset),
      );
    }

    if (measured.isEmpty) {
      _hardClampOffset = null;
      _hardClampPostId = null;
      return;
    }

    measured.sort((a, b) => a.revealOffset.compareTo(b.revealOffset));
    final headerInset = topInsetBuilder();
    final currentPixels = controller.position.pixels;
    final originOffset = currentPixels + headerInset + 4;

    for (final candidate in measured) {
      if (candidate.revealOffset > originOffset &&
          _isMediaPostCache!(candidate.post) &&
          shouldGuardOnSuperFling(candidate.post)) {
        _hardClampOffset = (candidate.revealOffset - headerInset).clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        );
        _hardClampPostId = candidate.post.id;
        return;
      }
    }

    _hardClampOffset = null;
    _hardClampPostId = null;
  }

  void _enforceHardClamp(double currentPixels) {
    final clampOffset = _hardClampOffset;
    if (clampOffset == null ||
        _lastUserDirection != ScrollDirection.reverse ||
        !controller.hasClients) {
      if (_isClamping) {
        _setClampingState(false);
      }
      return;
    }

    if (currentPixels >= clampOffset) {
      controller.jumpTo(clampOffset);
      _setClampingState(true);
    } else if (currentPixels < clampOffset - 80) {
      _setClampingState(false);
    }
  }

  void _onRegistryChanged() {
    final clampedId = _hardClampPostId;
    if (clampedId != null && MediaPostLoadRegistry.isReady(clampedId)) {
      _refreshHardClampTarget();
      if (_hardClampOffset == null) {
        _setClampingState(false);
      }
    }
  }

  void _setClampingState(bool value) {
    if (_isClamping == value) return;
    _isClamping = value;
    onClampStateChanged?.call(value);
  }

  void _maybePrepareTarget({
    required List<Post> posts,
    required bool Function(Post post) isMediaPost,
  }) {
    final startPixels = _scrollStartPixels;
    if (_pendingTargetOffset != null ||
        startPixels == null ||
        _lastUserDirection != ScrollDirection.reverse ||
        !controller.hasClients ||
        posts.isEmpty) {
      return;
    }

    final measuredPosts = <_MeasuredPost>[];
    for (final post in posts) {
      final key = _postKeys[post.id];
      final context = key?.currentContext;
      if (context == null) {
        continue;
      }

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }

      final viewport = RenderAbstractViewport.of(renderObject);
      final reveal = viewport.getOffsetToReveal(renderObject, 0);
      measuredPosts.add(
        _MeasuredPost(
          post: post,
          revealOffset: reveal.offset,
        ),
      );
    }

    if (measuredPosts.length < 2) {
      return;
    }

    measuredPosts.sort((a, b) => a.revealOffset.compareTo(b.revealOffset));

    final headerInset = topInsetBuilder();
    final originOffset = startPixels + headerInset + 4;

    for (final candidate in measuredPosts) {
      if (candidate.revealOffset > originOffset &&
          isMediaPost(candidate.post) &&
          shouldGuardOnSuperFling(candidate.post)) {
        _pendingTargetOffset = (candidate.revealOffset - headerInset).clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        );
        return;
      }
    }
  }

  void _maybeClampToTarget(double currentPixels) {
    final targetOffset = _pendingTargetOffset;
    if (_snapTriggeredForGesture ||
        targetOffset == null ||
        _lastUserDirection != ScrollDirection.reverse ||
        !controller.hasClients) {
      return;
    }

    if (currentPixels < targetOffset - snapLeadDistance) {
      return;
    }

    _snapTriggeredForGesture = true;
    controller.jumpTo(targetOffset);
  }

  void _resetGestureState() {
    _scrollStartPixels = null;
    _lastUserDirection = ScrollDirection.idle;
    _pendingTargetOffset = null;
    _snapTriggeredForGesture = false;
    _ballisticSnapArmed = false;
  }
}

class _MeasuredPost {
  const _MeasuredPost({
    required this.post,
    required this.revealOffset,
  });

  final Post post;
  final double revealOffset;
}

class MediaLoadingChip extends StatelessWidget {
  const MediaLoadingChip({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: visible
            ? Container(
                key: const ValueKey('media-loading-chip'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFEE8F3F)),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Loading images…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(key: ValueKey('media-loading-chip-empty')),
      ),
    );
  }
}
