import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/playlist_screen.dart';
import '../services/global_audio_player_service.dart';

class GlobalAudioMiniPlayer extends StatefulWidget {
  const GlobalAudioMiniPlayer({super.key});

  @override
  State<GlobalAudioMiniPlayer> createState() => _GlobalAudioMiniPlayerState();
}

class _GlobalAudioMiniPlayerState extends State<GlobalAudioMiniPlayer>
    with SingleTickerProviderStateMixin {
  static const double _discSize = 52;
  static const double _collapsedVisibleWidth = _discSize / 2;
  static const double _expandedPanelWidth = 144;
  static const double _expandedGap = 8;
  static const double _expandedInset = 12;
  static const double _topInset = 20;
  static const double _bottomInset = 20;
  static const Duration _snapDuration = Duration(milliseconds: 220);
  static const Duration _rotationDuration = Duration(seconds: 14);
  static const Duration _autoCollapseDelay = Duration(seconds: 7);

  late final AnimationController _rotationController;

  bool _isDockedLeft = false;
  bool _isExpanded = false;
  bool _isDragging = false;
  bool _hasInitializedPosition = false;
  bool _wasPlaying = false;

  Timer? _autoCollapseTimer;
  double _top = 180;
  double? _dragLeft;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: _rotationDuration,
    );
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  void _syncRotation(bool playing) {
    if (playing == _wasPlaying) {
      return;
    }
    _wasPlaying = playing;
    if (playing) {
      _rotationController.repeat(
        min: _rotationController.value,
        max: 1,
        period: _rotationDuration,
      );
    } else {
      _rotationController.stop(canceled: false);
    }
  }

  void _ensureInitialPosition(Size size, EdgeInsets padding) {
    if (_hasInitializedPosition || size.height <= 0) {
      return;
    }
    _hasInitializedPosition = true;
    _top = _clampTop(size.height * 0.32, size.height, padding);
  }

  double _clampTop(double value, double height, EdgeInsets padding) {
    final minTop = padding.top + _topInset;
    final maxTop = height - padding.bottom - _discSize - _bottomInset;
    if (maxTop <= minTop) {
      return minTop;
    }
    return value.clamp(minTop, maxTop).toDouble();
  }

  double _collapsedLeft(double width) {
    return _isDockedLeft
        ? -(_discSize - _collapsedVisibleWidth)
        : width - _collapsedVisibleWidth;
  }

  double _expandedLeft(double width) {
    final expandedWidth = _discSize + _expandedGap + _expandedPanelWidth;
    return _isDockedLeft
        ? _expandedInset
        : width - expandedWidth - _expandedInset;
  }

  double _restingLeft(double width) {
    return _isExpanded ? _expandedLeft(width) : _collapsedLeft(width);
  }

  void _scheduleAutoCollapse() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = Timer(_autoCollapseDelay, () {
      if (!mounted || !_isExpanded || _isDragging) {
        return;
      }
      setState(() {
        _isExpanded = false;
      });
    });
  }

  void _cancelAutoCollapse() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = null;
  }

  Future<void> _openPlaylist(BuildContext context, int? playlistId) async {
    if (playlistId == null) {
      return;
    }
    _cancelAutoCollapse();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(playlistId: playlistId),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isExpanded = false;
    });
  }

  Future<void> _openTrackDetails(BuildContext context, GlobalAudioQueueItem track) async {
    _cancelAutoCollapse();
    if (track.playlistId != null) {
      await _openPlaylist(context, track.playlistId);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalAudioPlayerService>(
      builder: (context, player, child) {
        final track = player.currentTrack;
        if (track == null || player.hidden) {
          _syncRotation(false);
          return const SizedBox.shrink();
        }

        _syncRotation(player.playing);

        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);
        _ensureInitialPosition(size, padding);
        final top = _clampTop(_top, size.height, padding);
        final left = _isDragging
            ? (_dragLeft ?? _restingLeft(size.width))
            : _restingLeft(size.width);

        final maxLeft = _isExpanded
            ? size.width -
                (_discSize + _expandedGap + _expandedPanelWidth) -
                _expandedInset
            : size.width - _collapsedVisibleWidth;

        return AnimatedPositioned(
          duration: _isDragging ? Duration.zero : _snapDuration,
          curve: Curves.easeOutCubic,
          top: top,
          left: left,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_isExpanded) {
                setState(() {
                  _isExpanded = true;
                });
                _scheduleAutoCollapse();
                return;
              }
              _cancelAutoCollapse();
              unawaited(_openPlaylist(context, track.playlistId));
            },
            onPanStart: (_) {
              _cancelAutoCollapse();
              setState(() {
                _isDragging = true;
                _dragLeft = _restingLeft(size.width);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _dragLeft =
                    ((_dragLeft ?? _restingLeft(size.width)) + details.delta.dx)
                        .clamp(-(_discSize - _collapsedVisibleWidth), maxLeft)
                        .toDouble();
                _top = _clampTop(_top + details.delta.dy, size.height, padding);
              });
            },
            onPanEnd: (_) {
              final currentLeft = _dragLeft ?? _restingLeft(size.width);
              final discCenterX = _isExpanded
                  ? (_isDockedLeft
                      ? currentLeft + (_discSize / 2)
                      : currentLeft +
                          _expandedPanelWidth +
                          _expandedGap +
                          (_discSize / 2))
                  : currentLeft + (_discSize / 2);
              setState(() {
                _isDockedLeft = discCenterX < (size.width / 2);
                _isDragging = false;
                _isExpanded = false;
                _dragLeft = null;
              });
            },
            onPanCancel: () {
              _cancelAutoCollapse();
              setState(() {
                _isDragging = false;
                _isExpanded = false;
                _dragLeft = null;
              });
            },
            child: _DiscBody(
              rotation: _rotationController,
              artworkUrl: track.artworkUrl,
              title: track.title,
              artist: track.artist,
              playing: player.playing,
              isExpanded: _isExpanded,
              isDockedLeft: _isDockedLeft,
              canOpen: track.playlistId != null || track.source == 'youtube',
              onOpen: () {
                _cancelAutoCollapse();
                unawaited(_openTrackDetails(context, track));
              },
            ),
          ),
        );
      },
    );
  }
}

class _DiscBody extends StatelessWidget {
  const _DiscBody({
    required this.rotation,
    required this.artworkUrl,
    required this.title,
    required this.artist,
    required this.playing,
    required this.isExpanded,
    required this.isDockedLeft,
    required this.canOpen,
    required this.onOpen,
  });

  final Animation<double> rotation;
  final String artworkUrl;
  final String title;
  final String artist;
  final bool playing;
  final bool isExpanded;
  final bool isDockedLeft;
  final bool canOpen;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? 'Audio track' : title.trim();
    final safeArtist = artist.trim();
    final alignment =
        isDockedLeft ? Alignment.centerRight : Alignment.centerLeft;

    final panel = isExpanded
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canOpen ? onOpen : null,
              child: Container(
                width: _GlobalAudioMiniPlayerState._expandedPanelWidth,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: isDockedLeft
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      safeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          isDockedLeft ? TextAlign.left : TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (safeArtist.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        safeArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign:
                            isDockedLeft ? TextAlign.left : TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: alignment,
                      child: Text(
                        canOpen ? 'Tap to open player' : 'Player unavailable',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    final disc = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: rotation,
          child: Container(
            width: _GlobalAudioMiniPlayerState._discSize,
            height: _GlobalAudioMiniPlayerState._discSize,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF8FAFC),
                          Color(0xFFD1D5DB),
                          Color(0xFF9CA3AF),
                        ],
                      ),
                    ),
                  ),
                  if (artworkUrl.trim().isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: artworkUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const SizedBox.shrink(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.88),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: isExpanded
          ? _GlobalAudioMiniPlayerState._discSize +
              _GlobalAudioMiniPlayerState._expandedGap +
              _GlobalAudioMiniPlayerState._expandedPanelWidth
          : _GlobalAudioMiniPlayerState._discSize,
      height: _GlobalAudioMiniPlayerState._discSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isDockedLeft
            ? [
                disc,
                if (panel != null) ...[
                  const SizedBox(
                    width: _GlobalAudioMiniPlayerState._expandedGap,
                  ),
                  panel,
                ],
              ]
            : [
                if (panel != null) ...[
                  panel,
                  const SizedBox(
                    width: _GlobalAudioMiniPlayerState._expandedGap,
                  ),
                ],
                disc,
              ],
      ),
    );
  }
}
