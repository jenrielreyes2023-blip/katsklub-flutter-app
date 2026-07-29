import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../config/api_config.dart';
import 'media_post_load_registry.dart';

class PostImageGrid extends StatelessWidget {
  const PostImageGrid({
    required this.imageUrls,
    this.initialAspectRatios,
    this.postId,
    this.displayImageUrls,
    this.onImageTap,
    this.onMediaReady,
    this.fit,
    super.key,
  });

  final List<String> imageUrls;
  final List<double?>? initialAspectRatios;
  final String? postId;
  final List<String>? displayImageUrls;
  final ValueChanged<int>? onImageTap;
  final VoidCallback? onMediaReady;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final renderUrls = _renderUrls();
    final maxVisible = imageUrls.length >= 5 ? 5 : 4;
    final visibleImages = renderUrls.take(maxVisible).toList();

    if (visibleImages.length == 1) {
      return GestureDetector(
        onTap: () => onImageTap?.call(0),
        child: _SinglePostImage(
          url: visibleImages.first,
          initialAspectRatio: _initialAspectRatioFor(0),
          postId: postId,
          onMediaReady: onMediaReady,
          fit: fit,
        ),
      );
    }

    final firstRatio = _initialAspectRatioFor(0);
    final isLandscape = firstRatio != null && firstRatio > 1.2;
    final isPortrait = firstRatio != null && firstRatio < 0.8;
    const spacing = 2.0;

    return RepaintBoundary(
      child: _buildStaggeredGrid(
        context: context,
        visibleImages: visibleImages,
        isLandscape: isLandscape,
        isPortrait: isPortrait,
        spacing: spacing,
      ),
    );
  }

  Widget _buildStaggeredGrid({
    required BuildContext context,
    required List<String> visibleImages,
    required bool isLandscape,
    required bool isPortrait,
    required double spacing,
  }) {
    final count = visibleImages.length;
    final totalCount = imageUrls.length;

    if (count == 2) {
      if (isLandscape) {
        return StaggeredGrid.count(
          crossAxisCount: 1,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: [
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 0.5,
              child: _buildTile(visibleImages[0], 0),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 0.5,
              child: _buildTile(visibleImages[1], 1),
            ),
          ],
        );
      } else {
        return StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: [
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 2.0,
              child: _buildTile(visibleImages[0], 0),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 2.0,
              child: _buildTile(visibleImages[1], 1),
            ),
          ],
        );
      }
    }

    if (count == 3) {
      if (isLandscape) {
        return StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: [
            StaggeredGridTile.count(
              crossAxisCellCount: 2,
              mainAxisCellCount: 1.2,
              child: _buildTile(visibleImages[0], 0),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 0.8,
              child: _buildTile(visibleImages[1], 1),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 0.8,
              child: _buildTile(visibleImages[2], 2),
            ),
          ],
        );
      } else {
        return StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: [
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 2.0,
              child: _buildTile(visibleImages[0], 0),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 1.0,
              child: _buildTile(visibleImages[1], 1),
            ),
            StaggeredGridTile.count(
              crossAxisCellCount: 1,
              mainAxisCellCount: 1.0,
              child: _buildTile(visibleImages[2], 2),
            ),
          ],
        );
      }
    }

    // 4 or more photos (2x2 grid with overflow badge on 4th tile)
    final extraCount = totalCount - 4;
    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      children: [
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: _buildTile(visibleImages[0], 0),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: _buildTile(visibleImages[1], 1),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: _buildTile(visibleImages[2], 2),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: _buildTile(
            visibleImages[3],
            3,
            extraCount: extraCount > 0 ? extraCount : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTile(
    String url,
    int index, {
    int? extraCount,
  }) {
    return RepaintBoundary(
      key: ValueKey('grid-tile-$index-$url'),
      child: GestureDetector(
        onTap: () => onImageTap?.call(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AdaptiveImageTile(
              url: url,
              sampleIndex: index,
              fit: BoxFit.cover,
              cacheWidth: 600,
              postId: postId,
              onMediaReady: onMediaReady,
            ),
            if (extraCount != null)
              Container(
                color: Colors.black.withOpacity(0.55),
                alignment: Alignment.center,
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _renderUrls() {
    final display = displayImageUrls;
    if (display == null || display.isEmpty) {
      return imageUrls;
    }

    return List<String>.generate(imageUrls.length, (index) {
      if (index < display.length && display[index].trim().isNotEmpty) {
        return display[index];
      }

      return imageUrls[index];
    });
  }

  double? _initialAspectRatioFor(int index) {
    final ratios = initialAspectRatios;
    if (ratios == null || index >= ratios.length) {
      return null;
    }

    final ratio = ratios[index];
    if (ratio == null || ratio <= 0) {
      return null;
    }

    return ratio;
  }
}

class _SinglePostImage extends StatefulWidget {
  const _SinglePostImage({
    required this.url,
    this.initialAspectRatio,
    this.postId,
    this.onMediaReady,
    this.fit,
  });

  final String url;
  final double? initialAspectRatio;
  final String? postId;
  final VoidCallback? onMediaReady;
  final BoxFit? fit;

  @override
  State<_SinglePostImage> createState() => _SinglePostImageState();
}

class _SinglePostImageState extends State<_SinglePostImage> {
  static final Map<String, double> _ratioCache = <String, double>{};
  static const double _placeholderAspectRatio = 1.0;
  static const double _maxLandscapeAspectRatio = 1.91;

  double? _aspectRatio;
  BoxFit _fit = BoxFit.cover;

  @override
  void initState() {
    super.initState();
    _hydrateAspectRatio();
  }

  @override
  void didUpdateWidget(_SinglePostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.initialAspectRatio != widget.initialAspectRatio) {
      _aspectRatio = null;
      _fit = BoxFit.cover;
      _hydrateAspectRatio();
    }
  }

  void _hydrateAspectRatio() {
    final initialRatio = widget.initialAspectRatio;
    if (initialRatio != null && initialRatio > 0) {
      _ratioCache[widget.url] = initialRatio;
      _applyRatio(initialRatio, triggerSetState: false);
      return;
    }

    final cachedRatio = _ratioCache[widget.url];
    if (cachedRatio != null && cachedRatio > 0) {
      _applyRatio(cachedRatio, triggerSetState: false);
      return;
    }

    _resolveRatio();
  }

  Future<void> _resolveRatio() async {
    final ratio = await _ImageAspectResolver.resolve(widget.url);
    if (!mounted || ratio == null || ratio <= 0) {
      return;
    }

    _ratioCache[widget.url] = ratio;

    if (!mounted) {
      return;
    }

    _applyRatio(ratio, triggerSetState: true);
  }

  void _applyRatio(double ratio, {required bool triggerSetState}) {
    final normalizedRatio =
        ratio > _maxLandscapeAspectRatio ? _maxLandscapeAspectRatio : ratio;
    final fit = widget.fit ?? (ratio < 1 ? BoxFit.contain : BoxFit.cover);

    if (_aspectRatio == normalizedRatio && _fit == fit) {
      return;
    }

    if (!triggerSetState || !mounted) {
      _aspectRatio = normalizedRatio;
      _fit = fit;
      return;
    }

    setState(() {
      _aspectRatio = normalizedRatio;
      _fit = fit;
    });
  }

  Widget _buildImageContent() {
    return _AdaptiveImageTile(
      url: widget.url,
      sampleIndex: 0,
      fit: _fit,
      cacheWidth: 600,
      postId: widget.postId,
      onMediaReady: widget.onMediaReady,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio;

    Widget content = AspectRatio(
      aspectRatio: ratio ?? _placeholderAspectRatio,
      child: _buildImageContent(),
    );

    final heroTag = widget.postId != null
        ? 'post-image-${widget.postId}-0'
        : 'image-${widget.url}';

    return Hero(
      tag: heroTag,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        final toHero = toHeroContext.widget as Hero;
        if (flightDirection == HeroFlightDirection.push) {
          return toHero.child;
        }
        return fromHeroContext.widget;
      },
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );
  }
}

class _AdaptiveImageTile extends StatefulWidget {
  const _AdaptiveImageTile({
    required this.url,
    required this.sampleIndex,
    required this.fit,
    this.cacheWidth = 600,
    this.postId,
    this.onMediaReady,
  });

  final String url;
  final int sampleIndex;
  final BoxFit fit;
  final int cacheWidth;
  final String? postId;
  final VoidCallback? onMediaReady;

  @override
  State<_AdaptiveImageTile> createState() => _AdaptiveImageTileState();
}

class _AdaptiveImageTileState extends State<_AdaptiveImageTile> {
  bool _mediaReadyFired = false;

  void _notifyMediaReady() {
    if (_mediaReadyFired) return;
    final pid = widget.postId;
    if (pid != null && MediaPostLoadRegistry.isReady(pid)) {
      _mediaReadyFired = true;
      return;
    }
    _mediaReadyFired = true;
    widget.onMediaReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.startsWith('sample://')) {
      return _SampleImage(index: widget.sampleIndex);
    }

    return CachedNetworkImage(
      imageUrl: ApiConfig.assetUrl(widget.url),
      imageBuilder: (context, imageProvider) {
        if (!_mediaReadyFired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notifyMediaReady();
          });
        }
        return Image(
          image: imageProvider,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
        );
      },
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: widget.cacheWidth,
      maxWidthDiskCache: widget.cacheWidth,
      placeholder: (context, url) => const ColoredBox(
        color: Color(0xFF252627),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF252627),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF8A8D91),
        ),
      ),
    );
  }
}

class _SampleImage extends StatelessWidget {
  const _SampleImage({
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final gradients = [
      const [Color(0xFF60A5FA), Color(0xFFA78BFA)],
      const [Color(0xFFF97316), Color(0xFFFACC15)],
      const [Color(0xFF34D399), Color(0xFF06B6D4)],
      const [Color(0xFFFB7185), Color(0xFFC084FC)],
    ];
    final colors = gradients[index % gradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.white.withOpacity(0.82),
        size: 34,
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
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(height == 0 ? null : width / height);
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
