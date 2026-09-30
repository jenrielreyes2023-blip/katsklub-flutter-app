import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/custom_icons.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/post_with_users_line.dart';
import '../widgets/share_post_sheet.dart';
import '../widgets/special_name_text.dart';
import '../widgets/user_avatar_with_frame.dart';
import 'hashtag_screen.dart';
import 'repost_post_screen.dart';
import 'user_profile_screen.dart';

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
  StreamSubscription<Post>? _postUpdatedSubscription;
  StreamSubscription<CommentCountChange>? _commentCountSubscription;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _currentIndex =
        widget.initialIndex.clamp(0, widget.imageUrls.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);

    final targetId = _post?.id ?? widget.postId;
    _postUpdatedSubscription =
        FeedService.postUpdatedStream.listen((updatedPost) {
      if (!mounted) return;
      final currentTargetId = _post?.id ?? widget.postId;
      if (currentTargetId != null && updatedPost.id == currentTargetId) {
        setState(() {
          _post = updatedPost;
        });
      }
    });

    _commentCountSubscription =
        FeedService.commentCountChangedStream.listen((change) {
      if (!mounted) return;
      final currentTargetId = _post?.id ?? widget.postId;
      if (currentTargetId != null && change.postId == currentTargetId) {
        setState(() {
          if (_post != null) {
            _post = _post!.copyWith(commentCount: change.commentCount);
          }
        });
      }
    });

    if (targetId != null && targetId.trim().isNotEmpty) {
      _loadFreshPost(targetId.trim());
    }
  }

  Future<void> _loadFreshPost(String postId) async {
    try {
      final fresh = await _feedService.loadPost(postId);
      if (!mounted || fresh == null) return;
      setState(() {
        _post = fresh;
      });
      FeedService.notifyPostUpdated(fresh);
    } catch (_) {}
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
    _postUpdatedSubscription?.cancel();
    _commentCountSubscription?.cancel();
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
      Navigator.of(context).pop(_post);
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
      FeedService.notifyPostUpdated(updatedPost);
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


  Future<void> _openComments() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final updatedCount = await showCommentsModal(context: context, post: post);
    if (!mounted || updatedCount == null) {
      return;
    }

    final updatedPost = post.copyWith(commentCount: updatedCount);
    setState(() {
      _post = updatedPost;
    });
    FeedService.notifyCommentCountChanged(
      postId: post.id,
      commentCount: updatedCount,
    );
    FeedService.notifyPostUpdated(updatedPost);
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
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white, size: 24.sp),
                      onPressed: () => Navigator.pop(context, _post),
                    ),
                    Text(
                      '${_currentIndex + 1} of ${widget.imageUrls.length}',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.ios_share_outlined,
                              color: Colors.white, size: 22.sp),
                          onPressed: shareAction,
                        ),
                        IconButton(
                          icon: Icon(Icons.more_vert,
                              color: Colors.white, size: 22.sp),
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
                  final likeCount =
                      effectivePost?.likeCount ?? widget.likeCount ?? 0;
                  final likedByMe = effectivePost?.likedByMe ?? false;
                  final commentCount =
                      effectivePost?.commentCount ?? widget.commentCount ?? 0;

                  return _ImagePostDetailsOverlay(
                    post: effectivePost,
                    uploaderName: effectivePost?.authorFullName ??
                        widget.uploaderName?.trim() ??
                        '',
                    createdAt: effectivePost?.createdAt ?? widget.createdAt,
                    privacyLabel: effectivePost?.privacyLabel ??
                        widget.privacyLabel?.trim() ??
                        '',
                    caption: effectivePost?.text ?? widget.caption?.trim() ?? '',
                    likeCount: likeCount,
                    likedByMe: likedByMe,
                    commentCount: commentCount,
                    repostCount:
                        effectivePost?.repostCount ?? widget.repostCount ?? 0,
                    withUsers: effectivePost?.withUsers ?? const <User>[],
                    onLike: effectivePost != null ? _toggleLike : null,
                    onComment: effectivePost != null ? _openComments : null,
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
    this.post,
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

  final Post? post;
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
    final clean = username.trim().replaceAll('@', '');
    if (clean.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: clean),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Colors.white;
    const likedColor = Color(0xFFE11D48);

    final post = widget.post;
    final authorUsername = post?.authorUsername.trim() ?? '';
    final displayName = widget.uploaderName.isNotEmpty
        ? widget.uploaderName
        : (post?.authorFullName.trim().isNotEmpty == true
            ? post!.authorFullName
            : authorUsername);
    final avatarUrl = post?.authorAvatarUrl ?? '';
    final initials = post?.authorInitials ??
        (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K');
    final hasAuthor = displayName.isNotEmpty || avatarUrl.isNotEmpty;

    // Feed inline post body typography (SF Pro Rounded 13.sp w500)
    final captionStyle = TextStyle(
      fontFamily: 'SF Pro Rounded',
      color: Colors.white,
      fontSize: 13.sp,
      height: 1.33,
      letterSpacing: -0.2,
      fontWeight: FontWeight.w500,
    );
    final captionLinkStyle = TextStyle(
      fontFamily: 'SF Pro Rounded',
      color: Colors.white,
      fontSize: 13.sp,
      height: 1.33,
      letterSpacing: -0.2,
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
          padding: EdgeInsets.fromLTRB(16.w, 40.h, 16.w, 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAuthor)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (avatarUrl.isNotEmpty || initials.isNotEmpty) ...[
                      UserAvatarWithFrame(
                        avatarUrl: avatarUrl,
                        initials: initials,
                        radius: 17,
                        isAdmin: post?.authorIsAdmin ?? false,
                        framePath: post?.authorAvatarFrame,
                        onTap: authorUsername.isNotEmpty
                            ? () => _openMention(context, authorUsername)
                            : null,
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: authorUsername.isNotEmpty
                                      ? () => _openMention(context, authorUsername)
                                      : null,
                                  child: SpecialNameText(
                                    username: authorUsername,
                                    displayName: displayName,
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      height: 1.33,
                                      letterSpacing: -0.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              if (post?.authorIsVerified == true) ...[
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.verified,
                                  color: const Color(0xFF1D9BF0),
                                  size: 14.sp,
                                ),
                              ],
                              if (post != null && post.feeling.isNotEmpty) ...[
                                SizedBox(width: 4.w),
                                Text(
                                  'is feeling',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    fontSize: 13.sp,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  post.feeling,
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 1.h),
                          Row(
                            children: [
                              if (widget.createdAt != null)
                                Text(
                                  _formatTimeAgo(widget.createdAt!),
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 10.5.sp,
                                    height: 1.33,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              if (widget.privacyLabel.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: Colors.white.withValues(alpha: 0.72),
                                      fontSize: 10.5.sp,
                                      height: 1.33,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _privacyIcon(widget.privacyLabel),
                                  color: Colors.white.withValues(alpha: 0.72),
                                  size: 11.5.sp,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (widget.withUsers.isNotEmpty) ...[
                SizedBox(height: 3.h),
                PostWithUsersLine(
                  users: widget.withUsers,
                  prefix: 'is — with ',
                  prefixHighlight: '— with',
                  prefixHighlightStyle: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                  linkStyle: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                  onUserTap: (username) => _openMention(context, username),
                ),
              ],
              if (widget.caption.isNotEmpty) ...[
                SizedBox(height: 8.h),
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
                          SizedBox(height: 4.h),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleExpanded,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              child: Text(
                                _expanded ? 'See less' : 'See more',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF7A45),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
              SizedBox(height: 10.h),
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
                  SizedBox(width: 24.w),
                  _ViewerActionButton(
                    icon: CustomIcons.comment(color: inactiveColor, size: 23),
                    count: widget.commentCount,
                    color: inactiveColor,
                    onTap: widget.onComment,
                  ),
                  SizedBox(width: 24.w),
                  _ViewerActionButton(
                    icon: CustomIcons.repost(color: inactiveColor, size: 23),
                    count: widget.repostCount,
                    color: inactiveColor,
                    onTap: widget.onRepost,
                  ),
                  SizedBox(width: 24.w),
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

  static String _formatCount(int value) {
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
      borderRadius: BorderRadius.circular(999.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count > 0) ...[
              SizedBox(width: 5.w),
              Text(
                _formatCount(count),
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: color,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
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
