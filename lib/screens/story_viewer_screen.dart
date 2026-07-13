import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/story.dart';
import '../widgets/custom_icons.dart';
import '../widgets/sensitive_content_wrapper.dart';
import '../widgets/gold_shimmer_text.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    required this.storyGroups,
    required this.initialGroupIndex,
    required this.initialStoryIndex,
    super.key,
  });

  final List<List<Story>> storyGroups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  Timer? _advanceTimer;
  bool _isPaused = false;
  double _progress = 0;
  Timer? _progressTimer;
  VideoPlayerController? _musicController;
  int _musicRequestToken = 0;
  static const _defaultStoryDuration = Duration(seconds: 5);
  static const _musicStoryDuration = Duration(seconds: 30);
  static const _progressInterval = Duration(milliseconds: 50);

  List<Story> get _currentGroup => widget.storyGroups[_currentGroupIndex];
  Story get _currentStory => _currentGroup[_currentStoryIndex];
  Duration get _currentStoryDuration {
    final videoUrl = _currentStory.videoUrl?.trim() ?? '';
    if (videoUrl.isNotEmpty) {
      return const Duration(seconds: 15);
    }
    final previewUrl = _currentStory.musicPreviewUrl?.trim() ?? '';
    return previewUrl.isEmpty ? _defaultStoryDuration : _musicStoryDuration;
  }

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndex = widget.initialStoryIndex;
    _startAutoAdvance();
    _syncMusicPreview();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _progressTimer?.cancel();
    _disposeMusicController();
    super.dispose();
  }

  void _startAutoAdvance() {
    _advanceTimer?.cancel();
    _progressTimer?.cancel();
    _progress = 0;

    _progressTimer = Timer.periodic(_progressInterval, (_) {
      if (_isPaused) return;
      setState(() {
        _progress += _progressInterval.inMilliseconds / _currentStoryDuration.inMilliseconds;
        if (_progress >= 1) {
          _progress = 1;
        }
      });
    });

    _advanceTimer = Timer(_currentStoryDuration, () {
      _nextStory();
    });
  }

  Future<void> _disposeMusicController() async {
    final controller = _musicController;
    _musicController = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _syncMusicPreview() async {
    final previewUrl = _currentStory.musicPreviewUrl?.trim() ?? '';
    final requestToken = ++_musicRequestToken;
    await _disposeMusicController();

    if (previewUrl.isEmpty) {
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(previewUrl));
      await controller.initialize();
      await controller.setVolume(1.0);
      await controller.setLooping(false);
      if (!mounted || requestToken != _musicRequestToken) {
        await controller.dispose();
        return;
      }
      _musicController = controller;
      if (!_isPaused) {
        await controller.play();
      }
    } catch (_) {
      await _disposeMusicController();
    }
  }

  void _pause() {
    setState(() => _isPaused = true);
    _musicController?.pause();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _musicController?.play();
  }

  void _nextStory() {
    // Next story in current group
    if (_currentStoryIndex < _currentGroup.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      return;
    }

    // Move to next group
    if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      return;
    }

    // Last story of last group - close viewer
    _close();
  }

  void _previousStory() {
    // Previous story in current group
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      return;
    }

    // Move to previous group's last story
    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = _currentGroup.length - 1;
      });
      _startAutoAdvance();
      _syncMusicPreview();
    }
  }

  void _close() {
    _disposeMusicController();
    Navigator.of(context).pop();
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < width * 0.3) {
      _previousStory();
    } else if (tapPosition > width * 0.7) {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _pause();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _resume();
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _ProgressBar(
                progress: _progress,
                count: _currentGroup.length,
                currentIndex: _currentStoryIndex,
              ),
              _StoryHeader(
                story: story,
                onClose: _close,
              ),
              Expanded(
                child: GestureDetector(
                  onTapDown: _onTapDown,
                  onLongPressStart: _onLongPressStart,
                  onLongPressEnd: _onLongPressEnd,
                  child: _StoryContent(story: story, isPaused: _isPaused),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reply coming soon'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Send message',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reaction sent'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: CustomIcons.heart(
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Share coming soon'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: CustomIcons.share(
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({required this.story, required this.isPaused});

  final Story story;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final imageUrl = story.imageUrl;
    final text = story.text;
    final videoUrl = story.videoUrl;

    Widget body;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body = _ImageStory(imageUrl: imageUrl);
    } else if (videoUrl != null && videoUrl.isNotEmpty) {
      body = _VideoStory(
        key: ValueKey('story-video-${story.id}'),
        videoUrl: videoUrl,
        isPaused: isPaused,
        posterUrl: story.videoPosterUrl,
        text: story.text,
      );
    } else if (text != null && text.isNotEmpty) {
      body = _TextStory(
        text: text,
        backgroundStartColor: story.backgroundStartColor,
        backgroundEndColor: story.backgroundEndColor,
      );
    } else {
      body = _PlaceholderStory(story: story);
    }

    return SensitiveContentWrapper(
      isSensitive: story.isSensitive,
      child: body,
    );
  }
}

class _ImageStory extends StatelessWidget {
  const _ImageStory({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: ApiConfig.assetUrl(imageUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 64,
          ),
        ),
      ),
    );
  }
}

class _TextStory extends StatelessWidget {
  const _TextStory({required this.text, this.backgroundStartColor, this.backgroundEndColor});

  final String text;
  final String? backgroundStartColor;
  final String? backgroundEndColor;

  Color _parseColor(String? hex, Color fallback) {
    final value = (hex ?? '').trim().replaceFirst('#', '');
    if (value.length != 6) {
      return fallback;
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return fallback;
    }
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final start = _parseColor(backgroundStartColor, const Color(0xFF667EEA));
    final end = _parseColor(backgroundEndColor, const Color(0xFF764BA2));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoStory extends StatefulWidget {
  const _VideoStory({
    super.key,
    required this.videoUrl,
    required this.isPaused,
    this.posterUrl,
    this.text,
  });

  final String videoUrl;
  final bool isPaused;
  final String? posterUrl;
  final String? text;

  @override
  State<_VideoStory> createState() => _VideoStoryState();
}

class _VideoStoryState extends State<_VideoStory> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(ApiConfig.assetUrl(widget.videoUrl)),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      if (!widget.isPaused) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error playing story video: $e');
    }
  }

  @override
  void didUpdateWidget(_VideoStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _initialized) {
      if (widget.isPaused != oldWidget.isPaused) {
        if (widget.isPaused) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget videoWidget;
    if (_initialized && _controller != null) {
      videoWidget = Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    } else {
      videoWidget = _VideoStoryPlaceholder(posterUrl: widget.posterUrl);
    }

    if (widget.text != null && widget.text!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          videoWidget,
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                widget.text!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return videoWidget;
  }
}

class _VideoStoryPlaceholder extends StatelessWidget {
  const _VideoStoryPlaceholder({this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl?.trim() ?? '';
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (poster.isNotEmpty)
            CachedNetworkImage(
              imageUrl: ApiConfig.assetUrl(poster),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            ),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderStory extends StatelessWidget {
  const _PlaceholderStory({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            story.authorUsername.toLowerCase() == 'gemini'
                ? GoldShimmerText(
                    text: story.authorFullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Text(
                    story.authorFullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              'Story content unavailable',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.count,
    required this.currentIndex,
  });

  final double progress;
  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(count, (index) {
          final isActive = index == currentIndex;
          final isCompleted = index < currentIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.3),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: isCompleted
                        ? 1.0
                        : isActive
                            ? progress
                            : 0.0,
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.story,
    required this.onClose,
  });

  final Story story;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: story.authorAvatarUrl.isEmpty
                  ? ColoredBox(
                      color: const Color(0xFFE5E7EB),
                      child: Center(
                        child: Text(
                          story.initials,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: ApiConfig.assetUrl(story.authorAvatarUrl),
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      placeholder: (context, url) => const ColoredBox(
                        color: Color(0xFFE5E7EB),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: const Color(0xFFE5E7EB),
                        child: Center(
                          child: Text(
                            story.initials,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                story.authorUsername.toLowerCase() == 'gemini'
                    ? GoldShimmerText(
                        text: story.authorFullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Text(
                        story.authorFullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                if (story.authorUsername.isNotEmpty || (story.musicTitle?.isNotEmpty ?? false))
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      children: [
                        if (story.authorUsername.isNotEmpty)
                          TextSpan(text: '@${story.authorUsername}'),
                        if (story.authorUsername.isNotEmpty && (story.musicTitle?.isNotEmpty ?? false))
                          const TextSpan(text: '  ·  '),
                        if (story.musicTitle?.isNotEmpty ?? false)
                          TextSpan(
                            text: story.musicTitle!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                if ((story.musicArtist?.isNotEmpty ?? false) && (story.musicTitle?.isNotEmpty ?? false))
                  Text(
                    story.musicArtist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
