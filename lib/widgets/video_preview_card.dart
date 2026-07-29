import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../models/post.dart';
import '../services/normal_video_playback_session.dart';
import '../services/normal_video_inline_controls.dart';
import '../services/normal_video_overlay_controller.dart';
import 'normal_video_overlay_host.dart';
import 'media_post_load_registry.dart';
import 'loading_skeletons.dart'; // For SkeletonPulse

class VideoPreviewCard extends StatefulWidget {
  const VideoPreviewCard({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  State<VideoPreviewCard> createState() => VideoPreviewCardState();
}

class VideoPreviewCardState extends State<VideoPreviewCard> {
  bool _wasMostlyVisible = false;

  @override
  void initState() {
    super.initState();
    normalVideoPlaybackSession.addListener(_handleSessionChanged);
  }

  @override
  void dispose() {
    normalVideoPlaybackSession.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openFullscreenVideo(Post post, Duration initialPosition) {
    normalVideoOverlayController.open(
      post,
      initialPosition: initialPosition,
    );
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) => const NormalVideoPageRoute(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.6;
    final hidden = info.visibleFraction <= 0.05;
    final session = normalVideoPlaybackSession;

    if (hidden) {
      _wasMostlyVisible = false;
      if (session.isActivePost(widget.post.id) &&
          !session.viewerOpen &&
          session.controller != null &&
          session.controller!.value.isInitialized) {
        session.pause();
      }
      return;
    }

    if (visible && !_wasMostlyVisible) {
      _wasMostlyVisible = true;

      if (session.viewerOpen) {
        return;
      }

      final alreadyActive = session.isActivePost(widget.post.id) &&
          session.controller != null &&
          session.controller!.value.isInitialized;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || session.viewerOpen) return;
        if (alreadyActive) {
          normalVideoPlaybackSession.play(muted: normalVideoMuted());
        } else {
          normalVideoPlaybackSession.activate(
            widget.post,
            play: true,
            muted: normalVideoMuted(),
            reason: 'feed inline autoplay',
          );
        }
      });
    }
  }

  bool _isInlineVideoEnded(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return false;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;

    if (duration <= Duration.zero) {
      return false;
    }

    return position >= duration - const Duration(milliseconds: 350);
  }

  Future<void> _playInlineAgain() async {
    await normalVideoPlaybackSession.seek(Duration.zero);
    await normalVideoPlaybackSession.play(muted: normalVideoMuted());
  }

  void _shareInlineVideo(Post post) {
    final url = post.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }

    Clipboard.setData(
      ClipboardData(text: ApiConfig.assetUrl(url)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video link copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildInlineEndedOverlay(Post post) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.38),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InlineEndActionButton(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  onTap: () => _openFullscreenVideo(
                    post,
                    normalVideoPlaybackSession.position,
                  ),
                ),
                _InlineEndActionButton(
                  icon: Icons.replay_rounded,
                  label: 'Play again',
                  onTap: _playInlineAgain,
                  isPrimary: true,
                ),
                _InlineEndActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _shareInlineVideo(post),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final posterUrl = post.primaryVideoPosterUrl;
    final rawRatio = post.mediaAspectRatio ??
        post.aspectRatio ??
        ((post.videoWidth != null &&
                post.videoHeight != null &&
                post.videoHeight! > 0)
            ? post.videoWidth! / post.videoHeight!
            : 1.0);

    final previewRatio = rawRatio < 1 ? 4 / 5 : rawRatio.clamp(1.0, 1.91);

    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final showInlineVideo = session.isActivePost(post.id) &&
        !session.viewerOpen &&
        controller != null &&
        controller.value.isInitialized;
    final isEnded = showInlineVideo && _isInlineVideoEnded(controller);
    if (showInlineVideo) {
      MediaPostLoadRegistry.markReady(post.id);
    }

    return VisibilityDetector(
      key: ValueKey('normal-video-${post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isEnded) {
            return;
          }

          _openFullscreenVideo(
            post,
            showInlineVideo ? session.position : Duration.zero,
          );
        },
        child: AspectRatio(
          aspectRatio: previewRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showInlineVideo)
                IgnorePointer(
                  ignoring: true,
                  child: _InlineVideoCover(controller: controller),
                )
              else if (posterUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: ApiConfig.assetUrl(posterUrl),
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  memCacheWidth: 800,
                  maxWidthDiskCache: 800,
                  imageBuilder: (context, imageProvider) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      MediaPostLoadRegistry.markReady(post.id);
                    });
                    return Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    );
                  },
                  placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                  errorWidget: (_, __, ___) => _videoFallback(),
                )
              else
                _videoFallback(),
              if (!showInlineVideo)
                Container(
                  color: Colors.black.withOpacity(0.18),
                ),
              if ((!showInlineVideo || !session.isPlaying) && !isEnded)
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              if (isEnded) _buildInlineEndedOverlay(post),
              if (showInlineVideo && !isEnded)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: normalVideoMutedNotifier,
                    builder: (context, muted, __) {
                      return _InlineSoundButton(
                        muted: muted,
                        onTap: () => setNormalVideoMuted(!muted),
                      );
                    },
                  ),
                ),
              if (post.isReel)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.video_library_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'REEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Icon(
        Icons.videocam_outlined,
        color: Color(0xFF65676B),
        size: 42,
      ),
    );
  }
}

class _InlineEndActionButton extends StatelessWidget {
  const _InlineEndActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isPrimary ? 62 : 52,
            height: isPrimary ? 62 : 52,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white : Colors.black.withOpacity(0.58),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.72),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.black : Colors.white,
              size: isPrimary ? 34 : 28,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
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
      color: Colors.black.withOpacity(0.55),
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
