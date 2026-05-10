import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../widgets/custom_icons.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
    this.postId,
    this.uploaderName,
    this.createdAt,
    this.privacyLabel,
    this.caption,
    this.likeCount,
    this.commentCount,
    super.key,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? postId;
  final String? uploaderName;
  final DateTime? createdAt;
  final String? privacyLabel;
  final String? caption;
  final int? likeCount;
  final int? commentCount;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  double _dragOffset = 0;
  double _backgroundOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex.clamp(0, widget.imageUrls.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
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

  @override
  Widget build(BuildContext context) {
    final heroTagPrefix = widget.postId ?? 'image';
    final showPostDetails = _hasPostDetails;

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
                    // X button (left)
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // Counter (center)
                    Text(
                      '${_currentIndex + 1} of ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // Share + More (right)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.ios_share_outlined,
                              color: Colors.white, size: 24),
                          onPressed: () {},
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
                child: _ImagePostDetailsOverlay(
                  uploaderName: widget.uploaderName?.trim() ?? '',
                  createdAt: widget.createdAt,
                  privacyLabel: widget.privacyLabel?.trim() ?? '',
                  caption: widget.caption?.trim() ?? '',
                  likeCount: widget.likeCount ?? 0,
                  commentCount: widget.commentCount ?? 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _hasPostDetails {
    return (widget.uploaderName?.trim().isNotEmpty ?? false) ||
        (widget.caption?.trim().isNotEmpty ?? false) ||
        widget.createdAt != null;
  }
}

class _ImagePostDetailsOverlay extends StatelessWidget {
  const _ImagePostDetailsOverlay({
    required this.uploaderName,
    required this.createdAt,
    required this.privacyLabel,
    required this.caption,
    required this.likeCount,
    required this.commentCount,
  });

  final String uploaderName;
  final DateTime? createdAt;
  final String privacyLabel;
  final String caption;
  final int likeCount;
  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.92),
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
              if (uploaderName.isNotEmpty)
                Text(
                  uploaderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (createdAt != null)
                    Text(
                      _formatTimeAgo(createdAt!),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (privacyLabel.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    Icon(
                      _privacyIcon(privacyLabel),
                      color: Colors.white.withValues(alpha: 0.78),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      privacyLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  caption,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _ViewerAction(
                    icon: CustomIcons.heart(color: Colors.white, size: 23),
                    count: likeCount,
                  ),
                  const SizedBox(width: 24),
                  _ViewerAction(
                    icon: CustomIcons.comment(color: Colors.white, size: 23),
                    count: commentCount,
                  ),
                  const SizedBox(width: 24),
                  _ViewerAction(
                    icon: CustomIcons.share(color: Colors.white, size: 23),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    this.count,
  });

  final Widget icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        if (count != null && count > 0) ...[
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
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
      placeholderBuilder: (context, size, child) => SizedBox.fromSize(
        size: size,
        child: child,
      ),
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        return flightDirection == HeroFlightDirection.push
            ? toHeroContext.widget
            : fromHeroContext.widget;
      },
      child: child,
    );
  }
}
