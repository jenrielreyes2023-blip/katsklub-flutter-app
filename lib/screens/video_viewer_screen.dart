import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../services/feed_service.dart';
import '../services/normal_video_playback_session.dart';

class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({
    required this.initialVideo,
    required this.initialVideoId,
    this.initialPosition = Duration.zero,
    this.onWillClose,
    super.key,
  });

  final Post initialVideo;
  final String initialVideoId;
  final Duration initialPosition;
  final ValueChanged<VideoViewerResult>? onWillClose;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class VideoViewerResult {
  const VideoViewerResult({
    required this.videoId,
    required this.position,
    required this.wasPlaying,
  });

  final String videoId;
  final Duration position;
  final bool wasPlaying;
}

class _VideoPlaybackSnapshot {
  const _VideoPlaybackSnapshot({
    required this.position,
    required this.isPlaying,
  });

  final Duration position;
  final bool isPlaying;
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  static const int _pageSize = 20;

  final FeedService _feedService = FeedService();
  late final PageController _pageController;
  late List<Post> _videos;
  final Map<String, _VideoPlaybackSnapshot> _playbackSnapshots =
      <String, _VideoPlaybackSnapshot>{};
  int _currentIndex = 0;
  int _nextOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _videos = [widget.initialVideo];
    _playbackSnapshots[widget.initialVideoId] = _VideoPlaybackSnapshot(
      position: widget.initialPosition,
      isPlaying: true,
    );
    _pageController = PageController(initialPage: 0);
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialVideos() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _nextOffset = 0;
    });

    try {
      final page = await _feedService.loadFeed(offset: 0, limit: _pageSize);
      if (!mounted) return;

      final mergedVideos = _randomizedInitialPlaylist(page.posts);

      setState(() {
        _videos = mergedVideos;
        _currentIndex = 0;
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
        _isLoading = false;
      });

      if (_pageController.page?.round() != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(0);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading || !_hasMore) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final page = await _feedService.loadFeed(
        offset: _nextOffset,
        limit: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _videos = _mergeVideos(_videos, page.posts);
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  List<Post> _randomizedInitialPlaylist(List<Post> posts) {
    final tappedVideo = widget.initialVideo;
    final remaining = _mergeVideos(
      const <Post>[],
      posts,
    ).where((video) => video.id != widget.initialVideoId).toList();

    remaining.shuffle(math.Random());
    return [tappedVideo, ...remaining];
  }

  List<Post> _mergeVideos(List<Post> existing, List<Post> incoming) {
    final merged = <Post>[...existing];
    final seen = existing.map((video) => video.id).toSet();

    for (final video in incoming) {
      if (video.videoUrl.trim().isNotEmpty && seen.add(video.id)) {
        merged.add(video);
      }
    }

    return merged;
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    normalVideoPlaybackSession.activate(
      _videos[index],
      play: true,
      reason: 'viewer page changed',
    );

    if (_hasMore && index >= _videos.length - 4) {
      _loadMoreVideos();
    }
  }

  void _handlePlaybackChanged(
    Post video,
    Duration position,
    bool isPlaying,
  ) {
    _playbackSnapshots[video.id] = _VideoPlaybackSnapshot(
      position: position,
      isPlaying: isPlaying,
    );
  }

  VideoViewerResult _currentResult() {
    final video =
        _videos.isNotEmpty ? _videos[_currentIndex] : widget.initialVideo;
    return VideoViewerResult(
      videoId: video.id,
      position: normalVideoPlaybackSession.isActivePost(video.id)
          ? normalVideoPlaybackSession.position
          : (_playbackSnapshots[video.id]?.position ?? Duration.zero),
      wasPlaying: normalVideoPlaybackSession.isActivePost(video.id)
          ? normalVideoPlaybackSession.isPlaying
          : (_playbackSnapshots[video.id]?.isPlaying ?? true),
    );
  }

  void _closeWithResult() {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    final result = _currentResult();
    widget.onWillClose?.call(result);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<VideoViewerResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeWithResult();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _videos.isEmpty
              ? const Center(
                  child: Text(
                    'No videos available',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _videos.length,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return _VideoPage(
                      key: ValueKey('video-${video.id}'),
                      video: video,
                      isActive: index == _currentIndex,
                      initialPosition: video.id == widget.initialVideoId
                          ? widget.initialPosition
                          : Duration.zero,
                      onPlaybackChanged: _handlePlaybackChanged,
                      onBack: _closeWithResult,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.video,
    required this.isActive,
    required this.initialPosition,
    required this.onPlaybackChanged,
    required this.onBack,
    super.key,
  });

  final Post video;
  final bool isActive;
  final Duration initialPosition;
  final void Function(Post video, Duration position, bool isPlaying)
      onPlaybackChanged;
  final VoidCallback onBack;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  static const bool _showDebugOverlay = false;
  bool _watchdogScheduled = false;
  bool _userPausedPlayback = false;

  @override
  void initState() {
    super.initState();
    normalVideoPlaybackSession.addListener(_handleSessionChanged);
    _activateIfNeeded();
  }

  @override
  void didUpdateWidget(_VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _userPausedPlayback = false;
      }
      _activateIfNeeded();
    }
  }

  @override
  void dispose() {
    normalVideoPlaybackSession.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _activateIfNeeded() {
    if (!widget.isActive) {
      return;
    }
    normalVideoPlaybackSession.activate(
      widget.video,
      initialPosition: widget.initialPosition,
      play: true,
      reason: 'viewer mount active page',
    );
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    final session = normalVideoPlaybackSession;
    if (session.isActivePost(widget.video.id)) {
      widget.onPlaybackChanged(
        widget.video,
        session.position,
        session.isPlaying,
      );
    }
    setState(() {});
  }

  void _scheduleStalledSessionWatchdog() {
    if (_watchdogScheduled || !widget.isActive) {
      return;
    }

    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final isStalled = session.isActivePost(widget.video.id) &&
        controller != null &&
        !controller.value.isInitialized &&
        !session.isInitializing &&
        !session.hasError;

    if (!isStalled) {
      return;
    }

    _watchdogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      _watchdogScheduled = false;

      final latestSession = normalVideoPlaybackSession;
      final latestController = latestSession.controller;

      final latestStalled = widget.isActive &&
          latestSession.isActivePost(widget.video.id) &&
          latestController != null &&
          !latestController.value.isInitialized &&
          !latestSession.isInitializing &&
          !latestSession.hasError;

      if (latestStalled) {
        latestSession
            .debugLog('viewer watchdog stalled controller; reactivate');
        await latestSession.activate(
          widget.video,
          initialPosition: widget.initialPosition,
          play: true,
          muted: false,
          reason: 'viewer watchdog stalled reactivate',
        );
        return;
      }
    });
  }

  void _togglePlayback() {
    if (!normalVideoPlaybackSession.isActivePost(widget.video.id)) {
      return;
    }
    if (normalVideoPlaybackSession.isPlaying) {
      normalVideoPlaybackSession.pause();
    } else {
      normalVideoPlaybackSession.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleStalledSessionWatchdog();

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoPlayer(),
          _buildGradients(),
          if (_showDebugOverlay) _buildDebugOverlay(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _VideoTopBar(onBack: widget.onBack),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 150,
            child: SafeArea(
              child: _VideoActionRail(video: widget.video),
            ),
          ),
          Positioned(
            left: 16,
            right: 90,
            bottom: 95,
            child: SafeArea(
              child: _VideoCreatorInfo(video: widget.video),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              child: _VideoCommentInput(),
            ),
          ),
          if (normalVideoPlaybackSession.isActivePost(widget.video.id) &&
              normalVideoPlaybackSession.isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (normalVideoPlaybackSession.isActivePost(widget.video.id) &&
              normalVideoPlaybackSession.hasError)
            const Center(
              child: Icon(
                Icons.video_file_outlined,
                color: Colors.white70,
                size: 48,
              ),
            ),
          if (normalVideoPlaybackSession.isActivePost(widget.video.id) &&
              normalVideoPlaybackSession.isInitialized &&
              !normalVideoPlaybackSession.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 74,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final value = controller?.value;

    final debugText = 'VIDEO DEBUG\n'
        'post=${widget.video.id} active=${session.activePostId} pageActive=${widget.isActive}\n'
        'viewerOpen=${session.viewerOpen} initing=${session.isInitializing} init=${session.isInitialized} playing=${session.isPlaying} err=${session.hasError}\n'
        'controllerNull=${controller == null} cInit=${value?.isInitialized ?? false} cPlaying=${value?.isPlaying ?? false}\n'
        'pos=${session.position.inMilliseconds}ms initial=${widget.initialPosition.inMilliseconds}ms userPaused=$_userPausedPlayback';

    return Positioned(
      left: 8,
      right: 8,
      top: 80,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: TextEditingController(text: debugText),
            readOnly: true,
            maxLines: null,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.25,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              helperText: 'Tap/long-press text then Copy',
              helperStyle: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            onTap: () {
              // Select all text so mobile copy menu is easier to use.
              final editable = primaryFocus?.context?.findRenderObject();
              if (editable != null) {}
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final posterUrl = widget.video.videoPosterUrl;
    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final showVideo = widget.isActive &&
        session.isActivePost(widget.video.id) &&
        controller != null &&
        controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (showVideo)
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          )
        else if (posterUrl.isNotEmpty)
          Hero(
            tag: 'video_${widget.video.id}',
            child: CachedNetworkImage(
              imageUrl: ApiConfig.assetUrl(posterUrl),
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildGradients() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.15, 0.6, 1.0],
        ),
      ),
    );
  }
}

class _VideoTopBar extends StatelessWidget {
  const _VideoTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _VideoActionRail extends StatelessWidget {
  const _VideoActionRail({required this.video});

  final Post video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.favorite_border,
          label: video.likeCount.toString(),
          onTap: () {},
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.comment_outlined,
          label: video.commentCount.toString(),
          onTap: () {},
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {},
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCreatorInfo extends StatelessWidget {
  const _VideoCreatorInfo({required this.video});

  final Post video;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: video.authorAvatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(
                      ApiConfig.assetUrl(video.authorAvatarUrl),
                    )
                  : null,
              child: video.authorAvatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              video.authorUsername,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (video.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            video.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _VideoCommentInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Add a comment...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Icon(Icons.send, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}
