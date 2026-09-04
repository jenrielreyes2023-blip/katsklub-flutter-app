import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import '../models/post.dart'; // For LinkPreview
import '../services/youtube_service.dart';
import '../services/normal_video_playback_session.dart';
import '../services/normal_video_inline_controls.dart';
import 'loading_skeletons.dart'; // For SkeletonPulse

typedef YouTubeOpenCallback = Future<void> Function({String? streamUrl});

class YouTubePreviewCard extends StatefulWidget {
  const YouTubePreviewCard({
    required this.preview,
    this.videoId,
    required this.onTap,
    this.onTapDown,
    super.key,
  });

  final LinkPreview preview;
  final String? videoId;
  final YouTubeOpenCallback onTap;
  final VoidCallback? onTapDown;

  @override
  State<YouTubePreviewCard> createState() => _YouTubePreviewCardState();
}

class _YouTubePreviewCardState extends State<YouTubePreviewCard> {
  static final Map<String, String> _streamCache = {};
  static _YouTubePreviewCardState? _activeCard;

  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isLoadingStream = false;
  bool _wasMostlyVisible = false;
  String? _resolvedStreamUrl;

  String get _effectiveVideoId {
    final direct = widget.videoId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final match = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    ).firstMatch(widget.preview.url);
    return match?.group(1) ?? '';
  }

  @override
  void initState() {
    super.initState();
    normalVideoPlaybackSession.addListener(_handleSessionChanged);
    normalVideoMutedNotifier.addListener(_handleMuteChanged);
  }

  @override
  void dispose() {
    normalVideoPlaybackSession.removeListener(_handleSessionChanged);
    normalVideoMutedNotifier.removeListener(_handleMuteChanged);
    if (_activeCard == this) {
      _activeCard = null;
    }
    _disposeController();
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    if ((normalVideoPlaybackSession.viewerOpen ||
            normalVideoPlaybackSession.isPlaying) &&
        _isPlaying) {
      _pause();
    }
  }

  void _handleMuteChanged() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    _controller!.setVolume(normalVideoMuted() ? 0.0 : 1.0);
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        await c.pause();
        await c.dispose();
      } catch (_) {}
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final isVisible = info.visibleFraction >= 0.6;
    final isHidden = info.visibleFraction <= 0.05;

    if (isHidden) {
      _wasMostlyVisible = false;
      if (_isPlaying) {
        _pause();
      }
      return;
    }

    if (isVisible && !_wasMostlyVisible) {
      _wasMostlyVisible = true;
      if (normalVideoPlaybackSession.viewerOpen) return;
      _play();
    }
  }

  Future<String?> _resolveStream(String videoId) async {
    if (videoId.isEmpty) return null;
    if (_streamCache.containsKey(videoId)) {
      final cached = _streamCache[videoId];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    // 1. Direct device-side stream extraction via youtube_explode_dart
    try {
      final yt = yte.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      yt.close();
      final muxed = manifest.muxed.withHighestBitrate();
      final url = muxed.url.toString();
      if (url.isNotEmpty) {
        _streamCache[videoId] = url;
        return url;
      }
    } catch (_) {}

    // 2. Server-side API fallback
    try {
      final url = await YouTubeService().getStreamUrl(videoId);
      if (url != null && url.isNotEmpty) {
        _streamCache[videoId] = url;
        return url;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _play() async {
    final videoId = _effectiveVideoId;
    if (videoId.isEmpty) return;

    if (_activeCard != null && _activeCard != this) {
      _activeCard?._pause();
    }
    _activeCard = this;

    if (normalVideoPlaybackSession.isPlaying) {
      normalVideoPlaybackSession.pause();
    }

    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.hasError) {
        await _disposeController();
        _streamCache.remove(videoId);
      } else {
        await _controller!.setVolume(normalVideoMuted() ? 0.0 : 1.0);
        await _controller!.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
        return;
      }
    }

    if (_isLoadingStream) return;
    setState(() {
      _isLoadingStream = true;
    });

    try {
      final streamUrl = await _resolveStream(videoId);
      if (!mounted ||
          !_wasMostlyVisible ||
          streamUrl == null ||
          streamUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingStream = false;
          });
        }
        return;
      }

      _resolvedStreamUrl = streamUrl;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(normalVideoMuted() ? 0.0 : 1.0);

      if (!mounted || !_wasMostlyVisible) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      await controller.play();

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isLoadingStream = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStream = false;
        });
      }
    }
  }

  void _pause() {
    if (_controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    } else {
      _isPlaying = false;
    }
    if (_activeCard == this) {
      _activeCard = null;
    }
  }

  void _toggleMute() {
    final nextMuted = !normalVideoMuted();
    setNormalVideoMuted(nextMuted);
    _controller?.setVolume(nextMuted ? 0.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.preview.imageUrl.trim();
    final title = widget.preview.title.trim().isNotEmpty
        ? widget.preview.title.trim()
        : 'YouTube video';

    final controller = _controller;
    final showInlinePlayer =
        controller != null && controller.value.isInitialized && _isPlaying;

    return VisibilityDetector(
      key: ValueKey(
          'yt-feed-$_effectiveVideoId-${widget.preview.url.hashCode}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => widget.onTapDown?.call(),
        onTap: () {
          _pause();
          widget.onTap(streamUrl: _resolvedStreamUrl);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (showInlinePlayer)
                    IgnorePointer(
                      ignoring: true,
                      child: _InlineVideoCover(controller: controller),
                    )
                  else if (imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: 800,
                      maxWidthDiskCache: 800,
                      placeholder: (_, __) =>
                          const _ImageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) => _fallback(),
                    )
                  else
                    _fallback(),
                  if (!showInlinePlayer)
                    Container(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  if (_isLoadingStream)
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  if (!showInlinePlayer && !_isLoadingStream)
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.56),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCCDC2626),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'YouTube',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showInlinePlayer)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: normalVideoMutedNotifier,
                        builder: (context, muted, __) {
                          return _InlineSoundButton(
                            muted: muted,
                            onTap: _toggleMute,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Color(0xFF65676B),
          size: 44,
        ),
      ),
    );
  }
}

class _InlineVideoCover extends StatelessWidget {
  const _InlineVideoCover({
    required this.controller,
  });

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return VideoPlayer(controller);
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _InlineSoundButton extends StatelessWidget {
  const _InlineSoundButton({
    required this.muted,
    required this.onTap,
  });

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: muted ? const StadiumBorder() : const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: muted ? 12 : 8,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
              if (muted) ...[
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Text(
                    'Tap for sound',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    required this.preview,
    required this.onTap,
    this.onTapDown,
    this.isYouTube = false,
    super.key,
  });

  final LinkPreview preview;
  final Future<void> Function() onTap;
  final VoidCallback? onTapDown;
  final bool isYouTube;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : preview.domain.trim();
    final description = preview.description.trim();
    final domain = preview.domain.trim().isNotEmpty
        ? preview.domain.trim()
        : preview.url.trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTapDown: (_) => onTapDown?.call(),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 1.91,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: 800,
                      maxWidthDiskCache: 800,
                      placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) => _linkFallback(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isYouTube) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'YouTube',
                              style: TextStyle(
                                color: const Color(0xFFDC2626),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                          fontSize: 13.sp,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(
          isYouTube ? Icons.play_circle_outline_rounded : Icons.link_rounded,
          color: const Color(0xFF65676B),
          size: 34,
        ),
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: ColoredBox(
        color: Color(0xFFE6EBF2),
        child: SizedBox.expand(),
      ),
    );
  }
}
