import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import '../services/global_audio_player_service.dart';
import '../services/music_service.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    required this.playlistId,
    super.key,
  });

  final int playlistId;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final MusicService _musicService = MusicService();

  Playlist? _playlist;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final playlist = await _musicService.getPlaylist(widget.playlistId);
    if (!mounted) {
      return;
    }

    setState(() {
      _playlist = playlist;
      _isLoading = false;
      if (playlist == null) {
        _errorMessage = 'Playlist unavailable.';
      }
    });
  }

  List<Track> _playableTracks(Playlist playlist) {
    return playlist.tracks
        .where((track) => track.playableUrl.isNotEmpty)
        .toList(growable: false);
  }

  List<GlobalAudioQueueItem> _queueForPlaylist(Playlist playlist) {
    final fallbackArtwork = playlist.resolvedCoverUrl;
    return _playableTracks(playlist)
        .map(
          (track) => GlobalAudioQueueItem(
            id: 'playlist:${playlist.id}:track:${track.id}',
            src: track.playableUrl,
            title: track.title.isEmpty ? 'Audio track' : track.title,
            artist: track.artist,
            artworkUrl: track.resolvedArtworkUrl.isEmpty
                ? fallbackArtwork
                : track.resolvedArtworkUrl,
            playlistId: playlist.id,
            trackId: track.id,
          ),
        )
        .toList(growable: false);
  }

  bool _isCurrentQueue(
    GlobalAudioPlayerService player,
    List<GlobalAudioQueueItem> queue,
  ) {
    return player.queueMatches(queue);
  }

  Future<void> _playPlaylist(
    BuildContext context,
    Playlist playlist, {
    int? startTrackId,
  }) async {
    final queue = _queueForPlaylist(playlist);
    if (queue.isEmpty) {
      _showMessage('This playlist has no playable audio tracks yet.');
      return;
    }

    final player = context.read<GlobalAudioPlayerService>();
    final startIndex = startTrackId == null
        ? 0
        : queue.indexWhere((item) => item.trackId == startTrackId);
    final boundedIndex = startIndex < 0 ? 0 : startIndex;

    if (_isCurrentQueue(player, queue)) {
      await player.playTrack(boundedIndex);
      return;
    }

    await player.setPlaylist(queue, startIndex: boundedIndex);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openQueueSheet(
    BuildContext context,
    Playlist playlist,
    GlobalAudioPlayerService player,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      isScrollControlled: true,
      builder: (sheetContext) => _PlaylistQueueSheet(
        playlist: playlist,
        currentTrackId: _isCurrentQueue(player, _queueForPlaylist(playlist))
            ? player.currentTrack?.trackId
            : null,
        isPlayingCurrentQueue:
            _isCurrentQueue(player, _queueForPlaylist(playlist)) &&
                player.playing,
        onTrackTap: (track) async {
          Navigator.of(sheetContext).pop();
          if (track.playableUrl.isEmpty) {
            _showMessage('This track has no playable audio source yet.');
            return;
          }
          await _playPlaylist(context, playlist, startTrackId: track.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_playlist == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: _PlaylistErrorState(
          message: _errorMessage ?? 'Playlist unavailable.',
          onRetry: _loadPlaylist,
        ),
      );
    }

    return Consumer<GlobalAudioPlayerService>(
      builder: (context, player, child) {
        final playlist = _playlist!;
        final playableTracks = _playableTracks(playlist);
        final queue = _queueForPlaylist(playlist);
        final isCurrentQueue = _isCurrentQueue(player, queue);
        final activeQueueTrack = isCurrentQueue ? player.currentTrack : null;
        final fallbackTrack = playableTracks.isNotEmpty
            ? playableTracks.first
            : (playlist.tracks.isNotEmpty ? playlist.tracks.first : null);
        final currentTrack = _activeTrackForPlaylist(
          playlist: playlist,
          currentTrackId: isCurrentQueue ? player.currentTrack?.trackId : null,
          fallbackTrack: fallbackTrack,
        );
        final displayTitle = _displayTitle(
          playlist: playlist,
          activeQueueTrack: activeQueueTrack,
          fallbackTrack: fallbackTrack,
        );
        final displaySubtitle = _displaySubtitle(
          playlist: playlist,
          activeQueueTrack: activeQueueTrack,
          fallbackTrack: fallbackTrack,
        );
        final displayArtwork = _displayArtwork(
          playlist: playlist,
          activeQueueTrack: activeQueueTrack,
          fallbackTrack: fallbackTrack,
        );
        final currentTime = isCurrentQueue ? player.currentTime : Duration.zero;
        final duration = isCurrentQueue ? player.duration : Duration.zero;
        final isPlaying = isCurrentQueue && player.playing;
        final hasPlayableTracks = queue.isNotEmpty;
        final canStep = isCurrentQueue && hasPlayableTracks;
        final queueCount = playlist.tracks.length;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Stack(
            children: [
              _PlaylistBackdrop(imageUrl: displayArtwork),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 44,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _GlassActionButton(
                                  icon: Icons.arrow_back_rounded,
                                  label: 'Back',
                                  expanded: true,
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                                const Spacer(),
                                _GlassIconButton(
                                  icon: Icons.refresh_rounded,
                                  onTap: _loadPlaylist,
                                ),
                                const SizedBox(width: 10),
                                _GlassIconButton(
                                  icon: Icons.queue_music_rounded,
                                  onTap: () => _openQueueSheet(
                                      context, playlist, player),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 430),
                                child: _PlaylistPlayerShell(
                                  artworkUrl: displayArtwork,
                                  title: displayTitle,
                                  subtitle: displaySubtitle,
                                  ownerUsername: playlist.ownerUsername,
                                  trackCount: playlist.trackCount,
                                  currentTrack: currentTrack,
                                  currentTime: currentTime,
                                  duration: duration,
                                  hasPlayableTracks: hasPlayableTracks,
                                  isPlaying: isPlaying,
                                  canGoPrevious: canStep && player.hasPrevious,
                                  canGoNext: canStep && player.hasNext,
                                  queueCount: queueCount,
                                  onSeek: (value) {
                                    if (!isCurrentQueue ||
                                        player.duration.inMilliseconds <= 0) {
                                      return;
                                    }
                                    final nextMs =
                                        (player.duration.inMilliseconds * value)
                                            .round();
                                    player.seek(
                                      Duration(milliseconds: nextMs),
                                    );
                                  },
                                  onPlayPause: !hasPlayableTracks
                                      ? null
                                      : () async {
                                          if (isCurrentQueue) {
                                            await player.togglePlaying();
                                            return;
                                          }
                                          await _playPlaylist(
                                              context, playlist);
                                        },
                                  onPrevious: canStep && player.hasPrevious
                                      ? () => player.playRelative(-1)
                                      : null,
                                  onNext: canStep && player.hasNext
                                      ? () => player.playRelative(1)
                                      : null,
                                  onQueueTap: () => _openQueueSheet(
                                      context, playlist, player),
                                ),
                              ),
                            ),
                            if (!hasPlayableTracks) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'No playable audio is available for this playlist yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Track? _activeTrackForPlaylist({
    required Playlist playlist,
    required int? currentTrackId,
    required Track? fallbackTrack,
  }) {
    if (currentTrackId == null) {
      return fallbackTrack;
    }
    for (final track in playlist.tracks) {
      if (track.id == currentTrackId) {
        return track;
      }
    }
    return fallbackTrack;
  }

  String _displayTitle({
    required Playlist playlist,
    required GlobalAudioQueueItem? activeQueueTrack,
    required Track? fallbackTrack,
  }) {
    final activeTitle = activeQueueTrack?.title.trim() ?? '';
    if (activeTitle.isNotEmpty) {
      return activeTitle;
    }
    final fallbackTitle = fallbackTrack?.title.trim() ?? '';
    if (fallbackTitle.isNotEmpty) {
      return fallbackTitle;
    }
    final playlistTitle = playlist.title.trim();
    return playlistTitle.isEmpty ? 'No track' : playlistTitle;
  }

  String _displaySubtitle({
    required Playlist playlist,
    required GlobalAudioQueueItem? activeQueueTrack,
    required Track? fallbackTrack,
  }) {
    final activeArtist = activeQueueTrack?.artist.trim() ?? '';
    if (activeArtist.isNotEmpty) {
      return activeArtist;
    }
    final fallbackArtist = fallbackTrack?.artist.trim() ?? '';
    if (fallbackArtist.isNotEmpty) {
      return fallbackArtist;
    }
    final playlistDescription = playlist.description.trim();
    if (playlistDescription.isNotEmpty) {
      return playlistDescription;
    }
    return playlist.title.trim();
  }

  String _displayArtwork({
    required Playlist playlist,
    required GlobalAudioQueueItem? activeQueueTrack,
    required Track? fallbackTrack,
  }) {
    final activeArtwork = activeQueueTrack?.artworkUrl.trim() ?? '';
    if (activeArtwork.isNotEmpty) {
      return activeArtwork;
    }
    final fallbackArtwork = fallbackTrack?.resolvedArtworkUrl.trim() ?? '';
    if (fallbackArtwork.isNotEmpty) {
      return fallbackArtwork;
    }
    return playlist.resolvedCoverUrl;
  }
}

class _PlaylistPlayerShell extends StatelessWidget {
  const _PlaylistPlayerShell({
    required this.artworkUrl,
    required this.title,
    required this.subtitle,
    required this.ownerUsername,
    required this.trackCount,
    required this.currentTrack,
    required this.currentTime,
    required this.duration,
    required this.hasPlayableTracks,
    required this.isPlaying,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.queueCount,
    required this.onSeek,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onQueueTap,
  });

  final String artworkUrl;
  final String title;
  final String subtitle;
  final String ownerUsername;
  final int trackCount;
  final Track? currentTrack;
  final Duration currentTime;
  final Duration duration;
  final bool hasPlayableTracks;
  final bool isPlaying;
  final bool canGoPrevious;
  final bool canGoNext;
  final int queueCount;
  final ValueChanged<double> onSeek;
  final Future<void> Function()? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onQueueTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PlaylistEyebrow(label: 'Playlist'),
        const SizedBox(height: 14),
        _PlaylistCoverArtwork(imageUrl: artworkUrl),
        const SizedBox(height: 26),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          _metaText(trackCount: trackCount, ownerUsername: ownerUsername),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 18),
        _CurrentTrackSummary(
            track: currentTrack, hasPlayableTracks: hasPlayableTracks),
        const SizedBox(height: 20),
        _PlaylistProgressSection(
          currentTime: currentTime,
          duration: duration,
          enabled: hasPlayableTracks && duration > Duration.zero,
          onSeek: onSeek,
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PlayerGhostControlButton(
              icon: Icons.shuffle_rounded,
              enabled: false,
            ),
            const SizedBox(width: 14),
            _PlayerGhostControlButton(
              icon: Icons.skip_previous_rounded,
              enabled: canGoPrevious,
              onTap: canGoPrevious ? onPrevious : null,
            ),
            const SizedBox(width: 14),
            _PlayerMainControlButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              enabled: hasPlayableTracks,
              onTap: onPlayPause,
            ),
            const SizedBox(width: 14),
            _PlayerGhostControlButton(
              icon: Icons.skip_next_rounded,
              enabled: canGoNext,
              onTap: canGoNext ? onNext : null,
            ),
            const SizedBox(width: 14),
            const _PlayerGhostControlButton(
              icon: Icons.repeat_rounded,
              enabled: false,
            ),
          ],
        ),
        const SizedBox(height: 26),
        _PlaylistSongsButton(
          count: queueCount,
          onTap: onQueueTap,
        ),
      ],
    );
  }

  static String _metaText({
    required int trackCount,
    required String ownerUsername,
  }) {
    final trackLabel = '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}';
    final username = ownerUsername.trim();
    if (username.isEmpty) {
      return trackLabel;
    }
    return '$trackLabel • @$username';
  }
}

class _PlaylistEyebrow extends StatelessWidget {
  const _PlaylistEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CurrentTrackSummary extends StatelessWidget {
  const _CurrentTrackSummary({
    required this.track,
    required this.hasPlayableTracks,
  });

  final Track? track;
  final bool hasPlayableTracks;

  @override
  Widget build(BuildContext context) {
    final title = track?.title.trim() ?? '';
    final artist = track?.artist.trim() ?? '';
    final label = !hasPlayableTracks
        ? 'No playable audio in this playlist yet.'
        : (title.isEmpty ? 'Ready to play this playlist.' : title);
    final detail =
        artist.isEmpty ? 'Tap play to start the current queue.' : artist;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        children: [
          const Text(
            'Now queued',
            style: TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistBackdrop extends StatelessWidget {
  const _PlaylistBackdrop({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF111827),
          ),
        ),
        if (imageUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Transform.scale(
              scale: 1.12,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x660F172A),
                Color(0xB50F172A),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x2EFFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              if (expanded) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x2EFFFFFF)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PlaylistCoverArtwork extends StatelessWidget {
  const _PlaylistCoverArtwork({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0x26FFFFFF)),
          child: imageUrl.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Color(0x99FFFFFF),
                    size: 72,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Color(0x99FFFFFF),
                      size: 72,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PlaylistProgressSection extends StatelessWidget {
  const _PlaylistProgressSection({
    required this.currentTime,
    required this.duration,
    required this.enabled,
    required this.onSeek,
  });

  final Duration currentTime;
  final Duration duration;
  final bool enabled;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (currentTime.inMilliseconds / duration.inMilliseconds)
            .clamp(0, 1)
            .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Colors.white,
            inactiveTrackColor: const Color(0x40FFFFFF),
            thumbColor: Colors.white,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: progress,
            onChanged: enabled ? onSeek : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                _formatDuration(currentTime),
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _PlayerGhostControlButton extends StatelessWidget {
  const _PlayerGhostControlButton({
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: const Color(0x26FFFFFF),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _PlayerMainControlButton extends StatelessWidget {
  const _PlayerMainControlButton({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: 68,
        height: 68,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled && onTap != null ? () => onTap!.call() : null,
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 34),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSongsButton extends StatelessWidget {
  const _PlaylistSongsButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x36FFFFFF)),
          backgroundColor: const Color(0x1FFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.queue_music_rounded, size: 20),
        label: Text(
          'Playlist Songs ($count)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PlaylistQueueSheet extends StatelessWidget {
  const _PlaylistQueueSheet({
    required this.playlist,
    required this.currentTrackId,
    required this.isPlayingCurrentQueue,
    required this.onTrackTap,
  });

  final Playlist playlist;
  final int? currentTrackId;
  final bool isPlayingCurrentQueue;
  final ValueChanged<Track> onTrackTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.76,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Playlist Songs (${playlist.tracks.length})',
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playlist.title.trim().isEmpty
                            ? 'Current queue'
                            : playlist.title.trim(),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (playlist.tracks.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No tracks in this playlist yet.',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: playlist.tracks.length,
                  itemBuilder: (context, index) {
                    final track = playlist.tracks[index];
                    final isActive = currentTrackId == track.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _QueueTrackTile(
                        index: index,
                        track: track,
                        isActive: isActive,
                        isPlaying: isActive && isPlayingCurrentQueue,
                        onTap: () => onTrackTap(track),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  const _QueueTrackTile({
    required this.index,
    required this.track,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
  });

  final int index;
  final Track track;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final playable = track.playableUrl.isNotEmpty;
    final title =
        track.title.trim().isEmpty ? 'Audio track' : track.title.trim();
    final artist = track.artist.trim().isEmpty
        ? (playable ? 'Unknown artist' : 'Unavailable track')
        : track.artist.trim();
    final artworkUrl = track.resolvedArtworkUrl.trim();

    return Material(
      color: isActive ? const Color(0xFFEEF2FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isActive ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFF3F4F6),
                  child: artworkUrl.isEmpty
                      ? Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: artworkUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                !playable
                    ? Icons.lock_outline_rounded
                    : (isActive && isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded),
                color: !playable
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistErrorState extends StatelessWidget {
  const _PlaylistErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_off_rounded,
              size: 44,
              color: Color(0x99FFFFFF),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111827),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
