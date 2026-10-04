import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/voice_room_controller.dart';
import '../utils/app_route_observer.dart';

class ProfileMusicBadge extends StatefulWidget {
  const ProfileMusicBadge({
    required this.user,
    this.isTabActive = true,
    super.key,
  });

  final User user;
  final bool isTabActive;

  static final Set<_ProfileMusicBadgeState> _activeInstances = {};

  static void pauseAll() {
    for (final instance in List<_ProfileMusicBadgeState>.from(_activeInstances)) {
      instance._pauseMusic();
    }
  }

  static void stopAll() {
    for (final instance in List<_ProfileMusicBadgeState>.from(_activeInstances)) {
      instance._disposePlayer();
    }
  }

  @override
  State<ProfileMusicBadge> createState() => _ProfileMusicBadgeState();
}

class _ProfileMusicBadgeState extends State<ProfileMusicBadge>
    with SingleTickerProviderStateMixin, RouteAware {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _isPlaying = false;
  bool _userPaused = false;
  bool _hasAttemptedAutoplay = false;

  late final AnimationController _discController;

  @override
  void initState() {
    super.initState();
    ProfileMusicBadge._activeInstances.add(this);
    VoiceRoomController.addSilenceAudioHook(ProfileMusicBadge.pauseAll);
    VoiceRoomController().addListener(_onVoiceRoomChanged);

    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (widget.user.hasProfileMusic) {
      _initPlayerAndAutoplay();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(ProfileMusicBadge oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMusic = oldWidget.user.profileMusicUrl?.trim();
    final newMusic = widget.user.profileMusicUrl?.trim();

    if (oldMusic != newMusic) {
      _disposePlayer();
      _hasAttemptedAutoplay = false;
      _userPaused = false;
      if (widget.user.hasProfileMusic) {
        _initPlayerAndAutoplay();
      }
    } else if (oldWidget.isTabActive != widget.isTabActive) {
      if (!widget.isTabActive) {
        _pauseMusic();
      } else if (!_userPaused && widget.user.hasProfileMusic && !_isPlaying) {
        if (VoiceRoomController().currentRoom == null) {
          _resumeMusic();
        }
      }
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    VoiceRoomController.removeSilenceAudioHook(ProfileMusicBadge.pauseAll);
    VoiceRoomController().removeListener(_onVoiceRoomChanged);
    ProfileMusicBadge._activeInstances.remove(this);
    _discController.dispose();
    _disposePlayer();
    super.dispose();
  }

  @override
  void didPushNext() {
    // Route covered by another screen (e.g. VoiceRoom, Reels, PostDetail)
    _pauseMusic();
  }

  @override
  void didPopNext() {
    // Returned back to the profile screen
    if (!_userPaused && widget.user.hasProfileMusic && !_isPlaying && widget.isTabActive) {
      if (VoiceRoomController().currentRoom == null) {
        _resumeMusic();
      }
    }
  }

  void _onVoiceRoomChanged() {
    // Pause automatically if user joins or enters a voice room
    if (VoiceRoomController().currentRoom != null && _isPlaying) {
      _pauseMusic();
    }
  }

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      unawaited(player.dispose());
    }
    if (mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _initPlayerAndAutoplay() async {
    final rawUrl = widget.user.profileMusicUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;

    // Never autoplay profile music if the user is currently inside a voice room / Klubhouse!
    if (VoiceRoomController().currentRoom != null) {
      return;
    }

    final url = _resolveAudioUrl(rawUrl);

    try {
      final player = AudioPlayer();
      _player = player;

      _stateSubscription = player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        final playing = (state == PlayerState.playing);
        if (_isPlaying != playing) {
          setState(() => _isPlaying = playing);
          if (playing) {
            _discController.repeat();
          } else {
            _discController.stop();
          }
        }
      });

      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.55);
      await player.setSourceUrl(url);

      if (widget.isTabActive &&
          !_hasAttemptedAutoplay &&
          !_userPaused &&
          VoiceRoomController().currentRoom == null) {
        _hasAttemptedAutoplay = true;
        await player.resume();
      }
    } catch (e) {
      debugPrint('ProfileMusicBadge init error: $e');
    }
  }

  String _resolveAudioUrl(String rawUrl) {
    if (!kIsWeb && (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
      return rawUrl;
    }
    return ApiConfig.assetUrl(rawUrl);
  }

  Future<void> _togglePlayPause() async {
    if (VoiceRoomController().currentRoom != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot play music while in a voice room.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final player = _player;
    if (player == null) {
      _userPaused = false;
      await _initPlayerAndAutoplay();
      return;
    }

    if (_isPlaying) {
      _userPaused = true;
      await player.pause();
    } else {
      _userPaused = false;
      await player.resume();
    }
  }

  Future<void> _pauseMusic() async {
    if (_isPlaying && _player != null) {
      await _player?.pause();
    }
  }

  Future<void> _resumeMusic() async {
    if (VoiceRoomController().currentRoom != null) {
      return;
    }
    if (!_isPlaying && _player != null && !_userPaused) {
      await _player?.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.hasProfileMusic) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.user.profileMusicTitle?.trim() ?? 'Song';
    final artist = widget.user.profileMusicArtist?.trim() ?? '';
    final artwork = widget.user.profileMusicArtwork?.trim();

    final displayText = artist.isNotEmpty ? '$title - $artist' : title;
    final textColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
    final iconColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Small spinning circular album cover (no fancy outer vinyl design)
        GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _discController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _discController.value * 2 * math.pi,
                child: child,
              );
            },
            child: ClipOval(
              child: artwork != null && artwork.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: artwork,
                      width: 17.r,
                      height: 17.r,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 17.r,
                        height: 17.r,
                        color: Colors.grey.shade400,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 17.r,
                        height: 17.r,
                        color: const Color(0xFFFF7A45),
                        child: Icon(Icons.music_note_rounded, size: 10.r, color: Colors.white),
                      ),
                    )
                  : Container(
                      width: 17.r,
                      height: 17.r,
                      color: const Color(0xFFFF7A45),
                      child: Icon(Icons.music_note_rounded, size: 10.r, color: Colors.white),
                    ),
            ),
          ),
        ),
        SizedBox(width: 6.w),

        // Slow Running Marquee Text loop for long titles
        GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: _MarqueeText(
            text: displayText,
            maxWidth: 140.w,
            isPlaying: _isPlaying,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        SizedBox(width: 4.w),

        // Small Play / Pause button (no background, minimalist)
        GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 16.r,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _MarqueeText extends StatefulWidget {
  const _MarqueeText({
    required this.text,
    required this.style,
    this.maxWidth = 140.0,
    this.isPlaying = true,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;
  final bool isPlaying;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0.0;
  bool _needsMarquee = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _calculateWidth();
  }

  @override
  void didUpdateWidget(_MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.maxWidth != widget.maxWidth) {
      _calculateWidth();
    }
  }

  void _calculateWidth() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    _textWidth = painter.width;
    _needsMarquee = _textWidth > widget.maxWidth;

    if (_needsMarquee) {
      // Gentle, slow scroll: roughly 26 pixels per second
      final durationMs = ((_textWidth + 36) / 26.0 * 1000).toInt().clamp(3000, 24000);
      _controller.duration = Duration(milliseconds: durationMs);
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsMarquee) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    const spacing = 36.0;
    final totalSpan = _textWidth + spacing;

    return SizedBox(
      width: widget.maxWidth,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final offset = -(_controller.value * totalSpan);
            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.text, style: widget.style),
                      const SizedBox(width: spacing),
                      Text(widget.text, style: widget.style),
                      const SizedBox(width: spacing),
                      Text(widget.text, style: widget.style),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
