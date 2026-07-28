import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import 'loading_skeletons.dart';
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

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        const spacing = 2.0;

        final firstRatio = _initialAspectRatioFor(0);
        final isLandscape = firstRatio != null && firstRatio > 1.2;
        final isPortrait = firstRatio != null && firstRatio < 0.8;

        if (visibleImages.length == 2) {
          if (isLandscape) {
            final tileHeight = (width - spacing) / 2;
            return SizedBox(
              height: tileHeight * 1.5,
              child: Column(
                children: [
                  Expanded(child: _buildTile(visibleImages[0], 0)),
                  const SizedBox(height: spacing),
                  Expanded(child: _buildTile(visibleImages[1], 1)),
                ],
              ),
            );
          } else {
            final tileWidth = (width - spacing) / 2;
            final double height = isPortrait ? tileWidth * 1.25 : tileWidth;
            return SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(child: _buildTile(visibleImages[0], 0)),
                  const SizedBox(width: spacing),
                  Expanded(child: _buildTile(visibleImages[1], 1)),
                ],
              ),
            );
          }
        }

        if (visibleImages.length == 3) {
          if (isLandscape) {
            final topHeight = width * 0.5625;
            final bottomHeight = (width - spacing) / 2;
            return SizedBox(
              height: topHeight + spacing + bottomHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: topHeight,
                    width: double.infinity,
                    child: _buildTile(visibleImages[0], 0),
                  ),
                  const SizedBox(height: spacing),
                  SizedBox(
                    height: bottomHeight,
                    child: Row(
                      children: [
                        Expanded(child: _buildTile(visibleImages[1], 1)),
                        const SizedBox(width: spacing),
                        Expanded(child: _buildTile(visibleImages[2], 2)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            final leftWidth = width * 0.6;
            final rightWidth = width - leftWidth - spacing;
            final double height = leftWidth * 1.1;
            return SizedBox(
              height: height,
              child: Row(
                children: [
                  SizedBox(
                    width: leftWidth,
                    height: double.infinity,
                    child: _buildTile(visibleImages[0], 0),
                  ),
                  const SizedBox(width: spacing),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      children: [
                        Expanded(child: _buildTile(visibleImages[1], 1)),
                        const SizedBox(height: spacing),
                        Expanded(child: _buildTile(visibleImages[2], 2)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        }

        if (visibleImages.length == 4) {
          if (isLandscape) {
            final topHeight = width * 0.55;
            final bottomHeight = (width - 2 * spacing) / 3;
            return SizedBox(
              height: topHeight + spacing + bottomHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: topHeight,
                    width: double.infinity,
                    child: _buildTile(visibleImages[0], 0),
                  ),
                  const SizedBox(height: spacing),
                  SizedBox(
                    height: bottomHeight,
                    child: Row(
                      children: [
                        Expanded(child: _buildTile(visibleImages[1], 1)),
                        const SizedBox(width: spacing),
                        Expanded(child: _buildTile(visibleImages[2], 2)),
                        const SizedBox(width: spacing),
                        Expanded(child: _buildTile(visibleImages[3], 3)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else if (isPortrait) {
            final leftWidth = width * 0.6;
            final rightWidth = width - leftWidth - spacing;
            final double height = leftWidth * 1.35;
            return SizedBox(
              height: height,
              child: Row(
                children: [
                  SizedBox(
                    width: leftWidth,
                    height: double.infinity,
                    child: _buildTile(visibleImages[0], 0),
                  ),
                  const SizedBox(width: spacing),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      children: [
                        Expanded(child: _buildTile(visibleImages[1], 1)),
                        const SizedBox(height: spacing),
                        Expanded(child: _buildTile(visibleImages[2], 2)),
                        const SizedBox(height: spacing),
                        Expanded(child: _buildTile(visibleImages[3], 3)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            final tileHeight = (width - spacing) / 2;
            final extraCount = imageUrls.length - 4;
            return SizedBox(
              height: width,
              child: Column(
                children: [
                  SizedBox(
                    height: tileHeight,
                    child: Row(
                      children: [
                        Expanded(child: _buildTile(visibleImages[0], 0)),
                        const SizedBox(width: spacing),
                        Expanded(child: _buildTile(visibleImages[1], 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: spacing),
                  SizedBox(
                    height: tileHeight,
                    child: Row(
                      children: [
                        Expanded(child: _buildTile(visibleImages[2], 2)),
                        const SizedBox(width: spacing),
                        Expanded(
                          child: _buildTile(
                            visibleImages[3],
                            3,
                            extraCount: extraCount > 0 ? extraCount : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        }

        final topRowHeight = (width - spacing) / 2;
        final bottomRowHeight = (width - 2 * spacing) / 3;
        final totalHeight = topRowHeight + spacing + bottomRowHeight;
        final extraCount = imageUrls.length - 5;

        return SizedBox(
          height: totalHeight,
          child: Column(
            children: [
              SizedBox(
                height: topRowHeight,
                child: Row(
                  children: [
                    Expanded(child: _buildTile(visibleImages[0], 0)),
                    const SizedBox(width: spacing),
                    Expanded(child: _buildTile(visibleImages[1], 1)),
                  ],
                ),
              ),
              const SizedBox(height: spacing),
              SizedBox(
                height: bottomRowHeight,
                child: Row(
                  children: [
                    Expanded(child: _buildTile(visibleImages[2], 2)),
                    const SizedBox(width: spacing),
                    Expanded(child: _buildTile(visibleImages[3], 3)),
                    const SizedBox(width: spacing),
                    Expanded(
                      child: _buildTile(
                        visibleImages[4],
                        4,
                        extraCount: extraCount > 0 ? extraCount : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  }

  Widget _buildTile(
    String url,
    int index, {
    int? extraCount,
  }) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => onImageTap?.call(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AdaptiveImageTile(
              url: url,
              sampleIndex: index,
              fit: BoxFit.cover,
              cacheWidth: 400,
              postId: postId,
              onMediaReady: onMediaReady,
            ),
            if (extraCount != null)
              Container(
                color: Colors.black.withOpacity(0.45),
                alignment: Alignment.center,
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
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
    final ratio = _aspectRatio ?? _placeholderAspectRatio;

    return AspectRatio(
      aspectRatio: ratio,
      child: _AdaptiveImageTile(
        url: widget.url,
        sampleIndex: 0,
        fit: _fit,
        cacheWidth: 800,
        postId: widget.postId,
        onMediaReady: widget.onMediaReady,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectivePostId = widget.postId?.trim();
    final useHero = effectivePostId != null && effectivePostId.isNotEmpty;
    final heroTag = useHero ? '${effectivePostId}_0' : null;
    final content = _buildImageContent();

    if (!useHero) {
      return content;
    }

    return Hero(
      tag: heroTag!,
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
    this.cacheWidth = 400,
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
      placeholder: (context, url) => const SkeletonPulse(
        child: ColoredBox(
          color: Color(0xFFE6EBF2),
          child: SizedBox.expand(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.image_not_supported_outlined),
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: Color(0xFF9CA3AF),
          size: 20,
        ),
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
