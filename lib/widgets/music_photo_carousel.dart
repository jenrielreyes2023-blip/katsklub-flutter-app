import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/post.dart';
import 'loading_skeletons.dart'; // For SkeletonPulse

class MusicPhotoCarousel extends StatefulWidget {
  const MusicPhotoCarousel({
    required this.post,
    required this.activeIndex,
    required this.onPageChanged,
    this.onImageTap,
    this.onMediaReady,
    super.key,
  });

  final Post post;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onImageTap;
  final VoidCallback? onMediaReady;

  @override
  State<MusicPhotoCarousel> createState() => _MusicPhotoCarouselState();
}

class _MusicPhotoCarouselState extends State<MusicPhotoCarousel> {
  static const String _swipeHintSeenKey = 'seen_carousel_swipe_hint_v1';
  final Map<int, double> _loadedAspectRatios = {};

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _loadedUrl;
  bool _hasUserRequestedPlay = false;
  bool _isPlaying = false;
  bool _audioUnavailable = false;
  bool _userPaused = false;
  bool _showSwipeHint = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.activeIndex,
      keepPage: false,
    );
    _maybeShowSwipeHint();
  }

  Future<void> _maybeShowSwipeHint() async {
    if (widget.post.imageUrls.length <= 1) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_swipeHintSeenKey) == true) return;
      if (!mounted) return;
      setState(() => _showSwipeHint = true);
    } catch (_) {}
  }

  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    if (mounted) {
      setState(() => _showSwipeHint = false);
    }
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_swipeHintSeenKey, true))
        .catchError((_) => false);
  }

  @override
  void didUpdateWidget(MusicPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.musicPreviewUrl.trim() !=
        widget.post.musicPreviewUrl.trim()) {
      _hasUserRequestedPlay = false;
      _isPlaying = false;
      _audioUnavailable = false;
      _userPaused = false;
      unawaited(_disposePlayer());
    }
    if (widget.activeIndex != oldWidget.activeIndex &&
        _pageController.hasClients &&
        _pageController.page?.round() != widget.activeIndex) {
      _pageController.jumpToPage(widget.activeIndex);
    }
  }

  Future<bool> _ensurePlayer() async {
    final rawUrl = widget.post.musicPreviewUrl.trim();
    if (rawUrl.isEmpty) {
      await _disposePlayer();
      return false;
    }

    final url = _resolveAudioUrl(rawUrl);
    if (_loadedUrl == url && _player != null) {
      return true;
    }

    await _disposePlayer();
    final player = AudioPlayer();
    _player = player;
    _loadedUrl = url;
    _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSourceUrl(url, mimeType: 'audio/mp4');
      return true;
    } catch (error, stackTrace) {
      debugPrint('MusicPhotoCarousel: failed to load $url -> $error');
      debugPrintStack(stackTrace: stackTrace);
      await _disposePlayer();
      if (!mounted) return false;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
      return false;
    }
  }

  String _resolveAudioUrl(String rawUrl) {
    if (!kIsWeb &&
        (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
      return rawUrl;
    }
    return ApiConfig.assetUrl(rawUrl);
  }

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    _loadedUrl = null;
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      unawaited(player.dispose());
    }
  }

  void _handleVisibility(VisibilityInfo info) {
    final player = _player;
    if (info.visibleFraction >= 0.55) {
      final shouldAutoplay = !kIsWeb && !_userPaused && !_audioUnavailable;
      if ((_hasUserRequestedPlay || shouldAutoplay) &&
          player?.state != PlayerState.playing) {
        unawaited(_playPlayer());
      }
    } else if (info.visibleFraction <= 0.05) {
      if (player != null && player.state == PlayerState.playing) {
        unawaited(player.pause());
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _playPlayer() async {
    if (_audioUnavailable) return;
    final isReady = await _ensurePlayer();
    final player = _player;
    if (!isReady || player == null) return;
    try {
      await player.resume();
    } catch (_) {
      await _disposePlayer();
      if (!mounted) return;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
    }
  }

  Future<void> _toggleAudio() async {
    if (_audioUnavailable) return;
    final player = _player;
    if (player?.state == PlayerState.playing) {
      _hasUserRequestedPlay = false;
      _userPaused = true;
      await player!.pause();
      return;
    }

    _hasUserRequestedPlay = true;
    _userPaused = false;
    await _playPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final images = post.imageUrls;
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final ratio = _carouselAspectRatio();
        final height = width / ratio;

        return VisibilityDetector(
          key: ValueKey('music-carousel-${post.id}'),
          onVisibilityChanged: _handleVisibility,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    _dismissSwipeHint();
                    widget.onPageChanged(index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onImageTap?.call(index),
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.assetUrl(images[index]),
                        fit: BoxFit.contain,
                        imageBuilder: (context, provider) {
                          widget.onMediaReady?.call();
                          _resolveImageRatio(index, provider);
                          return Image(
                            image: provider,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                        placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFEDEFF3),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF8A8D91),
                            size: 34,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: _CarouselCountPill(
                    current: widget.activeIndex + 1,
                    total: images.length,
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: _CarouselDots(
                      count: images.length,
                      activeIndex: widget.activeIndex,
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: _CarouselMusicButton(
                    isPlaying: _isPlaying,
                    isUnavailable: _audioUnavailable,
                    onTap: _toggleAudio,
                  ),
                ),
                if (_showSwipeHint && images.length > 1)
                  Positioned.fill(
                    child: _CarouselSwipeHint(onDismiss: _dismissSwipeHint),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resolveImageRatio(int index, ImageProvider provider) {
    if (index != 0) return;
    if (_loadedAspectRatios.containsKey(index)) return;

    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      final double width = info.image.width.toDouble();
      final double height = info.image.height.toDouble();
      if (width > 0 && height > 0) {
        final double ratio = width / height;
        if (_loadedAspectRatios[index] != ratio) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _loadedAspectRatios[index] = ratio;
            });
          });
        }
      }
      stream.removeListener(listener);
    }, onError: (exception, stackTrace) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  double _carouselAspectRatio() {
    if (widget.post.imageUrls.isEmpty) return 1.0;

    if (_loadedAspectRatios.containsKey(0)) {
      return _loadedAspectRatios[0]!;
    }

    if (widget.post.imageAspectRatios.isNotEmpty) {
      final dbRatio = widget.post.imageAspectRatios[0];
      if (dbRatio != null && dbRatio > 0) {
        return dbRatio.toDouble();
      }
    }

    return 1.0;
  }
}

class _CarouselSwipeHint extends StatefulWidget {
  const _CarouselSwipeHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_CarouselSwipeHint> createState() => _CarouselSwipeHintState();
}

class _CarouselSwipeHintState extends State<_CarouselSwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _fadeTimer;
  Timer? _dismissTimer;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
    _fadeTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _opacity = 0);
    });
    _dismissTimer = Timer(const Duration(milliseconds: 3500), widget.onDismiss);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 400),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(-20 * t, 0),
                child: child,
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.swipe_left_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Swipe to see more',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselMusicButton extends StatelessWidget {
  const _CarouselMusicButton({
    required this.isPlaying,
    required this.isUnavailable,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isUnavailable;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final icon = isUnavailable
        ? Icons.music_off_rounded
        : isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;
    final tooltip = isUnavailable
        ? 'Music unavailable'
        : isPlaying
            ? 'Pause music'
            : 'Play music';

    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            isUnavailable ? const Color(0x66000000) : const Color(0xB3000000),
        shape: const CircleBorder(),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          iconSize: 23,
          color: Colors.white,
          disabledColor: const Color(0x99FFFFFF),
          onPressed: isUnavailable ? null : () => unawaited(onTap()),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _CarouselCountPill extends StatelessWidget {
  const _CarouselCountPill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$current/$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == activeIndex ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
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
