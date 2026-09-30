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
import '../widgets/share_post_sheet.dart';
import 'image_viewer_screen.dart';
import 'repost_post_screen.dart';

class VerticalGalleryScreen extends StatefulWidget {
  const VerticalGalleryScreen({
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
  State<VerticalGalleryScreen> createState() => _VerticalGalleryScreenState();
}

class _VerticalGalleryScreenState extends State<VerticalGalleryScreen> {
  late final ScrollController _scrollController;
  final FeedService _feedService = FeedService();
  late List<GlobalKey> _imageKeys;
  Post? _post;
  bool _didScrollToInitialImage = false;
  bool _likePending = false;
  StreamSubscription<Post>? _postUpdatedSubscription;
  StreamSubscription<CommentCountChange>? _commentCountSubscription;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _scrollController = ScrollController();
    _imageKeys = _buildImageKeys(widget.imageUrls.length);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialImage();
    });
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
  void didUpdateWidget(VerticalGalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _post = widget.post;
    }
    if (oldWidget.imageUrls.length != widget.imageUrls.length) {
      _imageKeys = _buildImageKeys(widget.imageUrls.length);
      _didScrollToInitialImage = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialImage();
      });
    }
  }

  @override
  void dispose() {
    _postUpdatedSubscription?.cancel();
    _commentCountSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<GlobalKey> _buildImageKeys(int length) {
    return List<GlobalKey>.generate(
      length,
      (index) => GlobalKey(debugLabel: 'vertical-gallery-image-$index'),
    );
  }

  void _scrollToInitialImage() {
    if (!mounted || _didScrollToInitialImage || widget.imageUrls.isEmpty) {
      return;
    }

    final initialIndex =
        widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    final context = _imageKeys[initialIndex].currentContext;
    if (context == null) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _scrollToInitialImage();
        }
      });
      return;
    }

    _didScrollToInitialImage = true;
    Scrollable.ensureVisible(
      context,
      alignment: 0,
      duration: Duration.zero,
      curve: Curves.linear,
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_post);
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
              size: 24.sp,
            ),
            onPressed: () => Navigator.of(context).pop(_post),
          ),
          title: Text(
            '${widget.imageUrls.length} photos',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < widget.imageUrls.length; index++)
                _buildGalleryItem(context, index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryItem(BuildContext context, int index) {
    final post = _post;
    final url = widget.imageUrls[index];
    final heroTagPrefix = post?.id ?? widget.postId ?? 'image';

    final likedByMe = post?.likedByMe ?? false;
    final likeCount =
        post?.likeCount ?? widget.likeCount ?? 0;
    final commentCount =
        post?.commentCount ?? widget.commentCount ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
    const likedColor = Color(0xFFE11D48);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0)
          Container(
            height: 8.h,
            width: double.infinity,
            color: isDark ? const Color(0xFF242526) : const Color(0xFFE5E7EB),
          ),
        GestureDetector(
          onTap: () => _openLightbox(context, index),
          child: _VerticalGalleryImage(
            key: _imageKeys[index],
            url: url,
            heroTag: '${heroTagPrefix}_$index',
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999.r),
                onTap: post != null ? _toggleLike : null,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      likedByMe
                          ? CustomIcons.heartFilled(
                              color: likedColor,
                              size: 22.sp,
                            )
                          : CustomIcons.heart(
                              color: inactiveColor,
                              size: 22.sp,
                            ),
                      if (likeCount > 0) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '$likeCount',
                          style: TextStyle(
                            color: likedByMe ? likedColor : inactiveColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              InkWell(
                borderRadius: BorderRadius.circular(999.r),
                onTap: post != null ? _openComments : null,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIcons.comment(
                        color: inactiveColor,
                        size: 22.sp,
                      ),
                      if (commentCount > 0) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '$commentCount',
                          style: TextStyle(
                            color: inactiveColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              InkWell(
                borderRadius: BorderRadius.circular(999.r),
                onTap: post != null ? _repostPost : null,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: CustomIcons.repost(
                    color: inactiveColor,
                    size: 22.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              InkWell(
                borderRadius: BorderRadius.circular(999.r),
                onTap: post != null ? _sharePost : null,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: CustomIcons.share(
                    color: inactiveColor,
                    size: 22.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  Future<void> _openLightbox(BuildContext context, int index) async {
    final updated = await Navigator.of(context).push<Post>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImageViewerScreen(
          imageUrls: widget.imageUrls,
          initialIndex: index,
          post: _post,
          currentUser: widget.currentUser,
          postId: widget.postId,
          uploaderName: widget.uploaderName,
          createdAt: widget.createdAt,
          privacyLabel: widget.privacyLabel,
          caption: widget.caption,
          likeCount: _post?.likeCount ?? widget.likeCount,
          commentCount: _post?.commentCount ?? widget.commentCount,
          repostCount: _post?.repostCount ?? widget.repostCount,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        opaque: true,
        barrierColor: Colors.black,
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _post = updated;
      });
    }
  }
}

class _VerticalGalleryImage extends StatefulWidget {
  const _VerticalGalleryImage({
    super.key,
    required this.url,
    required this.heroTag,
  });

  final String url;
  final String heroTag;

  @override
  State<_VerticalGalleryImage> createState() => _VerticalGalleryImageState();
}

class _VerticalGalleryImageState extends State<_VerticalGalleryImage> {
  static final Map<String, double> _ratioCache = <String, double>{};

  double _aspectRatio = 1;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(_VerticalGalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspectRatio = 1;
      _resolveAspectRatio();
    }
  }

  Future<void> _resolveAspectRatio() async {
    final cached = _ratioCache[widget.url];
    if (cached != null && cached > 0) {
      setState(() {
        _aspectRatio = cached;
      });
      return;
    }

    final ratio = await _ImageAspectResolver.resolve(widget.url);
    if (!mounted || ratio == null || ratio <= 0) {
      return;
    }

    _ratioCache[widget.url] = ratio;
    setState(() {
      _aspectRatio = ratio;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final frameHeight = width / _aspectRatio.clamp(0.45, 2.2);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
    final emptyBgColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    final iconColor = isDark ? const Color(0xFF4E5152) : const Color(0xFF9CA3AF);

    return SizedBox(
      width: double.infinity,
      height: frameHeight,
      child: ColoredBox(
        color: placeholderColor,
        child: widget.url.startsWith('sample://')
            ? Container(
                color: emptyBgColor,
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: iconColor,
                ),
              )
            : CachedNetworkImage(
                imageUrl: ApiConfig.assetUrl(widget.url),
                imageBuilder: (context, imageProvider) => _GalleryImageHero(
                  tag: widget.heroTag,
                  child: Image(
                    image: imageProvider,
                    width: double.infinity,
                    height: frameHeight,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                  ),
                ),
                width: double.infinity,
                height: frameHeight,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                useOldImageOnUrlChange: true,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                placeholder: (context, url) =>
                    ColoredBox(color: placeholderColor),
                errorWidget: (context, url, error) => Container(
                  color: emptyBgColor,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: iconColor,
                  ),
                ),
              ),
      ),
    );
  }
}

class _GalleryImageHero extends StatelessWidget {
  const _GalleryImageHero({
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

class _ImageAspectResolver {
  static Future<double?> resolve(String url) async {
    if (url.startsWith('sample://')) {
      return 1;
    }

    final provider = CachedNetworkImageProvider(ApiConfig.assetUrl(url));
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<double?>();
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        final height = info.image.height.toDouble();
        if (!completer.isCompleted) {
          completer.complete(
            height == 0 ? null : info.image.width.toDouble() / height,
          );
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }
}
