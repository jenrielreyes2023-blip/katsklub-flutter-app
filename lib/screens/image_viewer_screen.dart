import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/custom_icons.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/post_with_users_line.dart';
import '../widgets/share_post_sheet.dart';
import 'hashtag_screen.dart';
import 'repost_post_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
    this.post,
    this.currentUser,
    this.postId,
    this.uploaderName,
    this.createdAt,
    this.privacyLabel,
    this.caption,
    this.likeCount,
    this.commentCount,
    this.repostCount,
    super.key,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final Post? post;
  final User? currentUser;
  final String? postId;
  final String? uploaderName;
  final DateTime? createdAt;
  final String? privacyLabel;
  final String? caption;
  final int? likeCount;
  final int? commentCount;
  final int? repostCount;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  final FeedService _feedService = FeedService();
  late int _currentIndex;
  Post? _post;
  double _dragOffset = 0;
  double _backgroundOpacity = 1.0;
  bool _likePending = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _currentIndex =
        widget.initialIndex.clamp(0, widget.imageUrls.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant ImageViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _post = widget.post;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      _backgroundOpacity = (1.0 - (_dragOffset.abs() / 300)).clamp(0.0, 1.0);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
        _backgroundOpacity = 1.0;
      });
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null || _likePending) {
      return;
    }

    setState(() {
      _likePending = true;
    });

    try {
      final updatedPost = await _feedService.toggleLike(post);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = updatedPost;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_errorMessage(error, fallback: 'Failed to like post.'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _likePending = false;
        });
      }
    }
  }

  Future<void> _toggleSlideLike(int slideId) async {
    final post = _post;
    if (post == null || _likePending) {
      return;
    }

    setState(() {
      _likePending = true;
    });

    final slideIndex = post.slides.indexWhere((s) => s.id == slideId);
    if (slideIndex < 0) return;
    final slide = post.slides[slideIndex];
    final previous = post;

    setState(() {
      final updatedSlides = List<PostSlide>.from(post.slides);
      updatedSlides[slideIndex] = slide.copyWith(
        likedByMe: !slide.likedByMe,
        likeCount: (slide.likeCount + (slide.likedByMe ? -1 : 1))
            .clamp(0, 1 << 31)
            .toInt(),
      );
      _post = post.copyWith(slides: updatedSlides);
    });

    try {
      final updatedPost = await _feedService.toggleSlideLike(post: previous, slideId: slideId);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = updatedPost;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _post = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_errorMessage(error, fallback: 'Failed to like image.'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _likePending = false;
        });
      }
    }
  }

  Future<void> _openComments() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final updatedCount = await showCommentsModal(context: context, post: post);
    if (!mounted || updatedCount == null) {
      return;
    }

    setState(() {
      _post = post.copyWith(commentCount: updatedCount);
    });
  }

  Future<void> _openSlideComments(int slideId) async {
    final post = _post;
    if (post == null) {
      return;
    }

    final slideIndex = post.slides.indexWhere((s) => s.id == slideId);
    if (slideIndex < 0) return;
    final slide = post.slides[slideIndex];

    final updatedCount = await showCommentsModal(
      context: context,
      post: post,
      slideId: slide.id,
      initialSlideCommentCount: slide.commentCount,
    );

    if (!mounted || updatedCount == null) {
      return;
    }

    setState(() {
      final updatedSlides = List<PostSlide>.from(post.slides);
      updatedSlides[slideIndex] = slide.copyWith(commentCount: updatedCount);
      _post = post.copyWith(slides: updatedSlides);
    });
  }

  Future<void> _repostPost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final repostedPost = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => RepostPostScreen(
          originalPost: post,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (!mounted || repostedPost == null) {
      return;
    }

    setState(() {
      _post = repostedPost.originalPost ??
          post.copyWith(repostCount: post.repostCount + 1);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post reposted.')),
    );
  }

  void _sharePost() {
    final post = _post;
    if (post == null) {
      return;
    }

    SharePostSheet.show(
      context,
      post: post,
      currentUser: widget.currentUser,
    );
  }

  String _errorMessage(Object error, {required String fallback}) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    return message.isEmpty ? fallback : message;
  }

  @override
  Widget build(BuildContext context) {
    final effectivePost = _post;
    final heroTagPrefix = effectivePost?.id ?? widget.postId ?? 'image';
    final showPostDetails = _hasPostDetails(effectivePost);
    final shareAction = effectivePost != null ? _sharePost : () {};

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _backgroundOpacity),
      body: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final url = widget.imageUrls[index];
                  return InteractiveViewer(
                    child: Center(
                      child: url.startsWith('sample://')
                          ? Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: const Color(0xFF111827),
                              child: const Icon(
                                Icons.image_outlined,
                                color: Colors.white70,
                                size: 72,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: ApiConfig.assetUrl(url),
                              imageBuilder: (context, imageProvider) =>
                                  _ViewerImageHero(
                                tag: '${heroTagPrefix}_$index',
                                child: Image(
                                  image: imageProvider,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              ),
                              fit: BoxFit.contain,
                              useOldImageOnUrlChange: true,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholderFadeInDuration: Duration.zero,
                              placeholder: (context, url) =>
                                  const SizedBox.shrink(),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      '${_currentIndex + 1} of ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.ios_share_outlined,
                              color: Colors.white, size: 24),
                          onPressed: shareAction,
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white, size: 24),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (showPostDetails)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: () {
                  final hasSlide = effectivePost != null &&
                      effectivePost.slides.isNotEmpty &&
                      _currentIndex < effectivePost.slides.length &&
                      effectivePost.slides[_currentIndex].id > 0;
                  final slide = hasSlide ? effectivePost.slides[_currentIndex] : null;

                  return _ImagePostDetailsOverlay(
                    uploaderName: effectivePost?.authorFullName ??
                        widget.uploaderName?.trim() ??
                        '',
                    createdAt: effectivePost?.createdAt ?? widget.createdAt,
                    privacyLabel: effectivePost?.privacyLabel ??
                        widget.privacyLabel?.trim() ??
                        '',
                    caption: effectivePost?.text ?? widget.caption?.trim() ?? '',
                    likeCount: slide != null ? slide.likeCount : (effectivePost?.likeCount ?? widget.likeCount ?? 0),
                    likedByMe: slide != null ? slide.likedByMe : (effectivePost?.likedByMe ?? false),
                    commentCount: slide != null ? slide.commentCount : (effectivePost?.commentCount ?? widget.commentCount ?? 0),
                    repostCount:
                        effectivePost?.repostCount ?? widget.repostCount ?? 0,
                    withUsers: effectivePost?.withUsers ?? const <User>[],
                    onLike: effectivePost != null
                        ? (slide != null ? () => _toggleSlideLike(slide.id) : _toggleLike)
                        : null,
                    onComment: effectivePost != null
                        ? (slide != null ? () => _openSlideComments(slide.id) : _openComments)
                        : null,
                    onRepost: effectivePost != null ? _repostPost : null,
                    onShare: effectivePost != null ? _sharePost : null,
                  );
                }(),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasPostDetails(Post? post) {
    return (post?.authorFullName.trim().isNotEmpty ??
            widget.uploaderName?.trim().isNotEmpty ??
            false) ||
        (post?.text.trim().isNotEmpty ??
            widget.caption?.trim().isNotEmpty ??
            false) ||
        post?.createdAt != null ||
        widget.createdAt != null;
  }
}

class _ImagePostDetailsOverlay extends StatefulWidget {
  const _ImagePostDetailsOverlay({
    required this.uploaderName,
    required this.createdAt,
    required this.privacyLabel,
    required this.caption,
    required this.likeCount,
    required this.likedByMe,
    required this.commentCount,
    required this.repostCount,
    required this.withUsers,
    this.onLike,
    this.onComment,
    this.onRepost,
    this.onShare,
  });

  final String uploaderName;
  final DateTime? createdAt;
  final String privacyLabel;
  final String caption;
  final int likeCount;
  final bool likedByMe;
  final int commentCount;
  final int repostCount;
  final List<User> withUsers;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onRepost;
  final VoidCallback? onShare;

  @override
  State<_ImagePostDetailsOverlay> createState() =>
      _ImagePostDetailsOverlayState();
}

class _ImagePostDetailsOverlayState extends State<_ImagePostDetailsOverlay> {
  static const int _collapsedCaptionLines = 4;

  bool _expanded = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  void _openHashtag(BuildContext context, String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagScreen(tag: tag),
      ),
    );
  }

  void _openMention(BuildContext context, String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Colors.white;
    const likedColor = Color(0xFFFF6B81);
    final captionStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
    );
    final captionLinkStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: _expanded ? 0.82 : 0.72),
            Colors.black.withValues(alpha: _expanded ? 0.97 : 0.92),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.uploaderName.isNotEmpty)
                Text(
                  widget.uploaderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (widget.withUsers.isNotEmpty) ...[
                const SizedBox(height: 3),
                PostWithUsersLine(
                  users: widget.withUsers,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  linkStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                  onUserTap: (username) => _openMention(context, username),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                children: [
                  if (widget.createdAt != null)
                    Text(
                      _formatTimeAgo(widget.createdAt!),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (widget.privacyLabel.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    Icon(
                      _privacyIcon(widget.privacyLabel),
                      color: Colors.white.withValues(alpha: 0.78),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.privacyLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.caption.isNotEmpty) ...[
                const SizedBox(height: 9),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final canExpand = _captionExceedsCollapsedLines(
                      context,
                      maxWidth: constraints.maxWidth,
                      style: captionStyle,
                    );

                    final captionText = HashtagText(
                      text: widget.caption,
                      maxLines: _expanded ? null : _collapsedCaptionLines,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: captionStyle,
                      hashtagStyle: captionLinkStyle,
                      mentionStyle: captionLinkStyle,
                      onHashtagTap: (tag) => _openHashtag(context, tag),
                      onMentionTap: (username) =>
                          _openMention(context, username),
                    );

                    Widget captionBody = captionText;
                    if (_expanded) {
                      captionBody = ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.38,
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: captionText,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: captionBody,
                        ),
                        if (canExpand) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleExpanded,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _expanded ? 'Less' : 'More',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _ViewerActionButton(
                    icon: widget.likedByMe
                        ? CustomIcons.heartFilled(color: likedColor, size: 23)
                        : CustomIcons.heart(color: inactiveColor, size: 23),
                    count: widget.likeCount,
                    color: widget.likedByMe ? likedColor : inactiveColor,
                    onTap: widget.onLike,
                  ),
                  const SizedBox(width: 24),
                  _ViewerActionButton(
                    icon: CustomIcons.comment(color: inactiveColor, size: 23),
                    count: widget.commentCount,
                    color: inactiveColor,
                    onTap: widget.onComment,
                  ),
                  const SizedBox(width: 24),
                  _ViewerActionButton(
                    icon: CustomIcons.repost(color: inactiveColor, size: 23),
                    count: widget.repostCount,
                    color: inactiveColor,
                    onTap: widget.onRepost,
                  ),
                  const SizedBox(width: 24),
                  _ViewerActionButton(
                    icon: CustomIcons.share(color: inactiveColor, size: 23),
                    count: 0,
                    color: inactiveColor,
                    onTap: widget.onShare,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _captionExceedsCollapsedLines(
    BuildContext context, {
    required double maxWidth,
    required TextStyle style,
  }) {
    if (maxWidth.isInfinite || maxWidth <= 0) {
      return widget.caption.length > 140 || widget.caption.contains('\n');
    }

    final painter = TextPainter(
      text: TextSpan(text: widget.caption, style: style),
      maxLines: _collapsedCaptionLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }

  static IconData _privacyIcon(String label) {
    switch (label.trim().toLowerCase()) {
      case 'friends':
        return Icons.people_alt_outlined;
      case 'only me':
        return Icons.lock_outline_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  static String _formatTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Now';
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
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w';
    }
    if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()}mo';
    }
    return '${(diff.inDays / 365).floor()}y';
  }
}

class _ViewerActionButton extends StatelessWidget {
  const _ViewerActionButton({
    required this.icon,
    required this.count,
    required this.color,
    this.onTap,
  });

  final Widget icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViewerImageHero extends StatelessWidget {
  const _ViewerImageHero({
    required this.tag,
    required this.child,
  });

  final String tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      placeholderBuilder: (context, size, child) =>
          SizedBox.fromSize(size: size),
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        if (flightDirection == HeroFlightDirection.pop) {
          return toHeroContext.widget;
        }
        return fromHeroContext.widget;
      },
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}
