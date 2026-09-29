import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'profile_music_picker_sheet.dart';

class ProfileMusicBadge extends StatefulWidget {
  const ProfileMusicBadge({
    required this.user,
    required this.isOwnProfile,
    this.isTabActive = true,
    this.onUserUpdated,
    super.key,
  });

  final User user;
  final bool isOwnProfile;
  final bool isTabActive;
  final ValueChanged<User>? onUserUpdated;

  @override
  State<ProfileMusicBadge> createState() => _ProfileMusicBadgeState();
}

class _ProfileMusicBadgeState extends State<ProfileMusicBadge>
    with SingleTickerProviderStateMixin {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _isPlaying = false;
  bool _userPaused = false;
  bool _hasAttemptedAutoplay = false;

  late final AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    if (widget.user.hasProfileMusic) {
      _initPlayerAndAutoplay();
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
        _resumeMusic();
      }
    }
  }

  @override
  void dispose() {
    _discController.dispose();
    _disposePlayer();
    super.dispose();
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
      await player.setVolume(0.55); // Pleasant 55% volume, gentle on listeners
      await player.setSourceUrl(url);

      // Autoplay if tab is currently active
      if (widget.isTabActive && !_hasAttemptedAutoplay && !_userPaused) {
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
    if (!_isPlaying && _player != null && !_userPaused) {
      await _player?.resume();
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.15 && _isPlaying) {
      _pauseMusic();
    } else if (info.visibleFraction >= 0.50 && !_isPlaying && !_userPaused && widget.isTabActive) {
      _resumeMusic();
    }
  }

  Future<void> _openMusicPicker() async {
    await ProfileMusicPickerSheet.show(
      context: context,
      currentTitle: widget.user.profileMusicTitle,
      currentArtist: widget.user.profileMusicArtist,
      currentArtwork: widget.user.profileMusicArtwork,
      currentMusicUrl: widget.user.profileMusicUrl,
      onSelected: (song) async {
        final result = await AuthService().updateProfileMusic(
          musicUrl: song.previewUrl,
          musicTitle: song.title,
          musicArtist: song.artist,
          musicArtwork: song.artworkUrl,
        );
        if (result.ok && result.user != null) {
          widget.onUserUpdated?.call(result.user!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile song set to "${song.title}" 🎵'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      onRemove: () async {
        final result = await AuthService().updateProfileMusic(
          musicUrl: null,
          musicTitle: null,
          musicArtist: null,
          musicArtwork: null,
        );
        if (result.ok && result.user != null) {
          widget.onUserUpdated?.call(result.user!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile song removed.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMusic = widget.user.hasProfileMusic;

    // If no song and NOT own profile, do not render an empty card
    if (!hasMusic && !widget.isOwnProfile) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If own profile and no song yet, show inviting CTA
    if (!hasMusic && widget.isOwnProfile) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openMusicPicker,
            borderRadius: BorderRadius.circular(14.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1B1E) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C32) : const Color(0xFFE5E7EB),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34.r,
                    height: 34.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: const Color(0xFFFF7A45),
                      size: 20.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a Profile Song',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Music plays when people visit your profile 🎧',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 11.5.sp,
                            color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: const Color(0xFFFF7A45),
                    size: 20.r,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Active Profile Song Card
    final title = widget.user.profileMusicTitle?.trim() ?? 'Profile Song';
    final artist = widget.user.profileMusicArtist?.trim() ?? '';
    final artwork = widget.user.profileMusicArtwork?.trim();

    final cardBgColor = isDark
        ? const Color(0xFF18191D)
        : const Color(0xFFF8F9FA);
    final borderColor = isDark
        ? const Color(0xFF2B2C33)
        : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final artistColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);

    return VisibilityDetector(
      key: ValueKey('profile_music_detector_${widget.user.username}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: _isPlaying
                  ? const Color(0xFFFF7A45).withValues(alpha: 0.4)
                  : borderColor,
              width: _isPlaying ? 1.2 : 0.9,
            ),
            boxShadow: [
              if (_isPlaying)
                BoxShadow(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              // Spinning Vinyl Disc
              GestureDetector(
                onTap: _togglePlayPause,
                child: AnimatedBuilder(
                  animation: _discController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _discController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF111113),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Grooves
                        Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                        ),
                        // Album Center Hole
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: artwork != null && artwork.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: artwork,
                                  width: 22.r,
                                  height: 22.r,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 22.r,
                                    height: 22.r,
                                    color: const Color(0xFFFF7A45),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 22.r,
                                    height: 22.r,
                                    color: const Color(0xFFFF7A45),
                                    child: const Icon(Icons.music_note, size: 12, color: Colors.white),
                                  ),
                                )
                              : Container(
                                  width: 22.r,
                                  height: 22.r,
                                  color: const Color(0xFFFF7A45),
                                  child: const Icon(Icons.music_note, size: 12, color: Colors.white),
                                ),
                        ),
                        // Center dot
                        Container(
                          width: 5.r,
                          height: 5.r,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Title, Artist & Equalizer bars
              Expanded(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (_isPlaying) ...[
                            SizedBox(width: 8.w),
                            _EqualizerMiniBars(isActive: _isPlaying),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        artist.isNotEmpty ? artist : 'Profile Soundtrack',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                          color: artistColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Play / Pause Circle Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _isPlaying
                      ? const Color(0xFFFF7A45)
                      : (isDark ? const Color(0xFF27282F) : const Color(0xFFE5E7EB)),
                  foregroundColor: _isPlaying
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF1F2937)),
                  padding: EdgeInsets.all(6.r),
                  minimumSize: Size(34.r, 34.r),
                ),
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20.r,
                ),
                onPressed: _togglePlayPause,
              ),

              // Edit / Change Button (if own profile)
              if (widget.isOwnProfile)
                IconButton(
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.all(6.r),
                    minimumSize: Size(30.r, 30.r),
                  ),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18.r,
                    color: artistColor,
                  ),
                  onPressed: _openMusicPicker,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EqualizerMiniBars extends StatefulWidget {
  const _EqualizerMiniBars({required this.isActive});

  final bool isActive;

  @override
  State<_EqualizerMiniBars> createState() => _EqualizerMiniBarsState();
}

class _EqualizerMiniBarsState extends State<_EqualizerMiniBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_EqualizerMiniBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(4 + (val * 9)),
            SizedBox(width: 2.w),
            _bar(12 - (val * 8)),
            SizedBox(width: 2.w),
            _bar(6 + ((1.0 - val) * 7)),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 2.5.w,
      height: height.h.clamp(3.0, 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A45),
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }
}
