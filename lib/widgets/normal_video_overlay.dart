import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../services/normal_video_overlay_controller.dart';
import '../services/normal_video_playback_session.dart';
import '../services/normal_video_inline_controls.dart';
import '../services/feed_service.dart';
import '../theme/app_text_styles.dart';
import 'comments_modal.dart';
import 'custom_icons.dart';
import 'share_post_sheet.dart';

class NormalVideoOverlay extends StatefulWidget {
  const NormalVideoOverlay({super.key});

  @override
  State<NormalVideoOverlay> createState() => _NormalVideoOverlayState();
}

class _NormalVideoOverlayState extends State<NormalVideoOverlay> {
  static const bool _showDebugOverlay = false;
  bool _userPausedPlayback = false;
  bool _watchdogScheduled = false;
  int _lastOpenNonce = -1;
  bool _isCaptionExpanded = false;
  Post? _lastOpenVideo;
  int? _localCommentCount;
  int? _localLikeCount;
  bool? _localLikedByMe;
  bool _showComments = false;

  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    normalVideoOverlayController.addListener(_handleOverlayChanged);
    normalVideoPlaybackSession.addListener(_handleSessionChanged);
    _handleOverlayChanged();
  }

  @override
  void dispose() {
    normalVideoOverlayController.removeListener(_handleOverlayChanged);
    normalVideoPlaybackSession.removeListener(_handleSessionChanged);
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _handleOverlayChanged() {
    final overlay = normalVideoOverlayController;
    final video = overlay.video;

    if (video != null && overlay.openNonce != _lastOpenNonce) {
      _lastOpenNonce = overlay.openNonce;
      _lastOpenVideo = video;
      _userPausedPlayback = false;
      _isCaptionExpanded = false;
      _localCommentCount = null;
      _localLikeCount = null;
      _localLikedByMe = null;
      _showComments = false;
      _commentController.clear();
      _commentFocus.unfocus();
      normalVideoPlaybackSession.setViewerOpen(true);
      setNormalVideoMuted(false);

      final resumePosition = normalVideoPlaybackSession.isActivePost(video.id)
          ? Duration.zero
          : overlay.initialPosition;

      normalVideoPlaybackSession.activate(
        video,
        initialPosition: resumePosition,
        play: true,
        muted: normalVideoMuted(),
        reason: 'global overlay open',
      );
    }

    if (video == null && _lastOpenVideo != null) {
      final closedVideo = _lastOpenVideo!;
      _lastOpenVideo = null;

      normalVideoPlaybackSession.setViewerOpen(false);
      resumeNormalVideoInline(closedVideo.id);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        normalVideoPlaybackSession.play(muted: normalVideoMuted());
      });
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _closeOverlay() {
    normalVideoOverlayController.close();
  }

  void _togglePlayback() {
    if (_commentFocus.hasFocus) {
      _commentFocus.unfocus();
      return;
    }
    final video = normalVideoOverlayController.video;
    if (video == null ||
        !normalVideoPlaybackSession.isActivePost(video.id) ||
        !normalVideoPlaybackSession.isInitialized) {
      return;
    }

    if (normalVideoPlaybackSession.isPlaying) {
      _userPausedPlayback = true;
      normalVideoPlaybackSession.pause();
    } else {
      _userPausedPlayback = false;
      normalVideoPlaybackSession.play(muted: normalVideoMuted());
    }
  }

  bool _isVideoEnded() {
    final controller = normalVideoPlaybackSession.controller;
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

  Future<void> _playAgain() async {
    _userPausedPlayback = false;
    await normalVideoPlaybackSession.seek(Duration.zero);
    await normalVideoPlaybackSession.play(muted: normalVideoMuted());
  }

  Future<void> _submitComment(Post video) async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);
    _commentController.clear();
    _commentFocus.unfocus();

    try {
      await _feedService.createComment(video.id, body);
      if (mounted) {
        setState(() {
          _localCommentCount = (_localCommentCount ?? video.commentCount) + 1;
          _isSendingComment = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment not sent.')),
        );
      }
    }
  }

  Future<void> _toggleLike(Post video) async {
    final wasLiked = _localLikedByMe ?? video.likedByMe;
    final prevCount = _localLikeCount ?? video.likeCount;
    setState(() {
      _localLikedByMe = !wasLiked;
      _localLikeCount =
          wasLiked ? (prevCount - 1).clamp(0, 999999) : prevCount + 1;
    });
    HapticFeedback.lightImpact();

    try {
      final updated = await _feedService.toggleLike(video);
      if (mounted) {
        setState(() {
          _localLikeCount = updated.likeCount;
          _localLikedByMe = updated.likedByMe;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _localLikedByMe = wasLiked;
          _localLikeCount = prevCount;
        });
      }
    }
  }

  Future<void> _openCommentsSheet(Post video) async {
    final screenHeight = MediaQuery.sizeOf(context).height;
    setState(() => _showComments = true);
    final updatedCount = await showCommentsModal(
      context: context,
      post: video,
      sheetHeight: screenHeight * 0.62,
    );
    if (mounted) {
      setState(() {
        _showComments = false;
        if (updatedCount != null) _localCommentCount = updatedCount;
      });
    }
  }

  void _scheduleStalledSessionWatchdog() {
    if (_watchdogScheduled || !normalVideoOverlayController.isOpen) {
      return;
    }

    final video = normalVideoOverlayController.video;
    final session = normalVideoPlaybackSession;
    final controller = session.controller;

    final isStalled = video != null &&
        session.isActivePost(video.id) &&
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

      final latestVideo = normalVideoOverlayController.video;
      final latestSession = normalVideoPlaybackSession;
      final latestController = latestSession.controller;

      final latestStalled = latestVideo != null &&
          latestSession.isActivePost(latestVideo.id) &&
          latestController != null &&
          !latestController.value.isInitialized &&
          !latestSession.isInitializing &&
          !latestSession.hasError;

      if (latestStalled) {
        await latestSession.activate(
          latestVideo,
          initialPosition: normalVideoOverlayController.initialPosition,
          play: true,
          muted: normalVideoMuted(),
          reason: 'global overlay watchdog stalled reactivate',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = normalVideoOverlayController.video;
    if (video == null) {
      return const SizedBox.shrink();
    }

    _scheduleStalledSessionWatchdog();

    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final showVideo = session.isActivePost(video.id) &&
        controller != null &&
        controller.value.isInitialized;

    final posterUrl = video.videoPosterUrl;
    final isEnded = _isVideoEnded();

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Positioned.fill(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Material(
          color: Colors.black,
          child: Stack(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    height: _showComments ? screenHeight * 0.38 : screenHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayback,
                      child: Stack(
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
                            Center(
                              child: CachedNetworkImage(
                                imageUrl: ApiConfig.assetUrl(posterUrl),
                                fit: BoxFit.contain,
                              ),
                            ),
                          if (!_showComments) _buildGradients(),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SafeArea(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                    ),
                                    onPressed: _closeOverlay,
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            ),
                          ),
                          // Right-side action rail
                          if (!isEnded && !_showComments)
                            _buildActionRail(video),
                          // Bottom-left metadata and caption
                          if (!isEnded && !_showComments)
                            _buildBottomOverlay(video),
                          if (session.isActivePost(video.id) &&
                              session.isInitializing)
                            const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                          if (session.isActivePost(video.id) &&
                              session.isInitialized &&
                              !session.isPlaying &&
                              !isEnded)
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 74,
                              ),
                            ),
                          if (isEnded) _buildEndedOverlay(),
                          if (_showDebugOverlay) _buildDebugOverlay(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Bottom comment input pill — sits at outer stack so it tracks the keyboard
              if (!isEnded && !_showComments) _buildCommentPill(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.38),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _EndActionButton(
                  icon: Icons.video_library_rounded,
                  label: 'More',
                  onTap: _closeOverlay,
                ),
                _EndActionButton(
                  icon: Icons.replay_rounded,
                  label: 'Play again',
                  onTap: _playAgain,
                  isPrimary: true,
                ),
                _EndActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {
                    final v = normalVideoOverlayController.video;
                    if (v != null) SharePostSheet.show(context, post: v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
            Colors.black.withValues(alpha: 0.65),
          ],
          stops: const [0.0, 0.15, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildActionRail(Post post) {
    return Positioned(
      right: 12,
      bottom: 100,
      child: SafeArea(
        left: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: (_localLikedByMe ?? post.likedByMe)
                  ? CustomIcons.heartFilled(
                      color: const Color(0xFFEF4444), size: 21.5.r)
                  : CustomIcons.heart(color: Colors.white, size: 21.5.r),
              label: _formatCount(_localLikeCount ?? post.likeCount),
              onTap: () => _toggleLike(post),
            ),
            SizedBox(height: 14.h),
            _ActionButton(
              icon: CustomIcons.comment(color: Colors.white, size: 21.5.r),
              label: _formatCount(_localCommentCount ?? post.commentCount),
              onTap: () => _openCommentsSheet(post),
            ),
            SizedBox(height: 14.h),
            _ActionButton(
              icon: CustomIcons.share(color: Colors.white, size: 21.5.r),
              onTap: () => SharePostSheet.show(context, post: post),
            ),
            SizedBox(height: 14.h),
            _ActionButton(
              icon: CustomIcons.bookmark(color: Colors.white, size: 21.5.r),
              onTap: () => _showPlaceholder('Save'),
            ),
            SizedBox(height: 14.h),
            _ActionButton(
              icon: Icon(Icons.more_vert, color: Colors.white, size: 21.5.r),
              onTap: () => _showPlaceholder('More'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(Post post) {
    final controller = normalVideoPlaybackSession.controller;
    final hasController = controller != null && controller.value.isInitialized;

    return Positioned(
      left: 16,
      right: 80,
      bottom: 76,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE5E7EB),
                  backgroundImage: post.authorAvatarUrl.trim().isEmpty
                      ? null
                      : CachedNetworkImageProvider(
                          ApiConfig.assetUrl(post.authorAvatarUrl)),
                  child: post.authorAvatarUrl.trim().isEmpty
                      ? Text(
                          post.authorFullName.isNotEmpty
                              ? post.authorFullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontWeight: FontWeight.w800,
                            fontSize: 14.sp,
                            color: const Color(0xFF111827),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorFullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KatsText.reelAuthor(context),
                            ),
                          ),
                          if (post.authorIsVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF1D9BF0),
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatTimestamp(post.createdAt),
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: Colors.white70,
                              fontSize: 12.sp,
                              shadows: const [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white70,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          Icon(
                            _privacyIcon(post.visibility),
                            color: Colors.white70,
                            size: 14.r,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Caption
            if (post.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCaptionExpanded = !_isCaptionExpanded;
                  });
                },
                child: Text(
                  post.text,
                  maxLines: _isCaptionExpanded ? null : 2,
                  overflow: _isCaptionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: KatsText.reelBody(context),
                ),
              ),
            ],
            if (hasController) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, VideoPlayerValue value, child) {
                      return Text(
                        _formatDuration(value.position),
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 14,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: const Color(0xFFFF7A45),
                          bufferedColor: Colors.white.withValues(alpha: 0.2),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(controller.value.duration),
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentPill() {
    final video = normalVideoOverlayController.video;
    if (video == null) return const SizedBox.shrink();

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = keyboardInset > 0 ? keyboardInset + 8.0 : safeBottom + 16.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                style: KatsText.reelCommentInput(context),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: KatsText.reelCommentHint(context),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(video),
              ),
            ),
            if (_isSendingComment)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _commentController,
                builder: (_, val, __) {
                  if (val.text.trim().isEmpty) return const SizedBox(width: 12);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => _submitComment(video),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action coming soon'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatCount(int count) {
    if (count == 0) return '';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) return 'Now';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[createdAt.month - 1];
    final sameYear = createdAt.year == DateTime.now().year;

    if (sameYear) return '$month ${createdAt.day}';
    return '$month ${createdAt.day}, ${createdAt.year}';
  }

  IconData _privacyIcon(String visibility) {
    switch (visibility) {
      case 'friends':
        return Icons.people_alt_rounded;
      case 'only_me':
        return Icons.lock_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  Widget _buildDebugOverlay() {
    final video = normalVideoOverlayController.video;
    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final value = controller?.value;

    final debugText = 'GLOBAL VIDEO DEBUG\n'
        'post=${video?.id ?? 'null'} active=${session.activePostId}\n'
        'viewerOpen=${session.viewerOpen} initing=${session.isInitializing} init=${session.isInitialized} playing=${session.isPlaying} err=${session.hasError}\n'
        'controllerNull=${controller == null} cInit=${value?.isInitialized ?? false} cPlaying=${value?.isPlaying ?? false}\n'
        'pos=${session.position.inMilliseconds}ms initial=${normalVideoOverlayController.initialPosition.inMilliseconds}ms userPaused=$_userPausedPlayback';

    return Positioned(
      left: 8,
      right: 8,
      top: 80,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              debugText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '00:00';
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _EndActionButton extends StatelessWidget {
  const _EndActionButton({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isPrimary ? 86 : 74,
            height: isPrimary ? 86 : 74,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isPrimary ? 44 : 38,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    this.onTap,
  });

  final Widget icon;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38.w,
            height: 38.h,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(child: icon),
          ),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: KatsText.reelCount(context),
            ),
          ],
        ],
      ),
    );
  }
}
