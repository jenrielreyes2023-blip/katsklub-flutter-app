import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/global_audio_player_service.dart';
import '../services/youtube_music_service.dart';
import '../services/youtube_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;
import 'youtube_player_screen.dart';

/// Full-featured YouTube MP3 Music & Audio Player screen.
/// Integrated directly with [GlobalAudioPlayerService]:
/// - Continues playing seamlessly when navigating to any other screen.
/// - Synced with the floating vinyl mini-player in AppShell.
/// - Background audio playback on Android lock screen.
/// - Data Saver (<5 MB audio vs >50 MB video).
/// - In-app MP3 download with progress and direct file sharing.
class YouTubeMP3Screen extends StatefulWidget {
  const YouTubeMP3Screen({
    required this.videoId,
    this.title,
    this.author,
    this.thumbnail,
    this.audioUrl,
    super.key,
  });

  final String videoId;
  final String? title;
  final String? author;
  final String? thumbnail;
  final String? audioUrl;

  static Route<void> route({
    required String videoId,
    String? title,
    String? author,
    String? thumbnail,
    String? audioUrl,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => YouTubeMP3Screen(
        videoId: videoId,
        title: title,
        author: author,
        thumbnail: thumbnail,
        audioUrl: audioUrl,
      ),
    );
  }

  @override
  State<YouTubeMP3Screen> createState() => _YouTubeMP3ScreenState();
}

class _YouTubeMP3ScreenState extends State<YouTubeMP3Screen>
    with SingleTickerProviderStateMixin {
  final YouTubeService _youtubeService = YouTubeService();
  final YouTubeMusicService _musicService = YouTubeMusicService();
  late final AnimationController _rotationController;

  bool _isLoading = false;
  String? _errorMessage;

  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;

  // Lyrics state
  bool _showLyrics = false;
  bool _loadingLyrics = false;
  String? _lyrics;

  Future<void> _toggleLyrics() async {
    if (_showLyrics) {
      setState(() => _showLyrics = false);
      return;
    }

    if (_lyrics != null) {
      setState(() => _showLyrics = true);
      return;
    }

    setState(() {
      _loadingLyrics = true;
      _showLyrics = true;
    });

    final text = await _musicService.getLyrics(widget.videoId);
    if (mounted) {
      setState(() {
        _loadingLyrics = false;
        _lyrics = text ?? 'Walang lyrics na available para sa kantang ito.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initOrSwitchPlayback();
    });
  }

  Future<void> _initOrSwitchPlayback() async {
    final playerService = context.read<GlobalAudioPlayerService>();
    final targetTrackId = 'yt_${widget.videoId}';

    // If this YouTube track is already active and playing or has duration, don't restart it
    if (playerService.currentTrack?.id == targetTrackId &&
        (playerService.playing || playerService.duration > Duration.zero)) {
      if (playerService.playing && !_rotationController.isAnimating) {
        _rotationController.repeat();
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String cleanVideoId = widget.videoId;

      // 1. Resolve MPREb album/playlist ID if passed
      if (cleanVideoId.startsWith('MPREb_') || cleanVideoId.length != 11) {
        try {
          final query = widget.title?.isNotEmpty == true
              ? '${widget.title} ${widget.author ?? ''}'.trim()
              : cleanVideoId;
          final searchSongs = await _musicService.searchSongs(query);
          if (searchSongs.isNotEmpty) {
            cleanVideoId = searchSongs.first.id;
          }
        } catch (_) {}
      }

      String? streamUrl;

      // 2. Client-side extraction via youtube_explode_dart FIRST (prefers AAC itag 140)
      try {
        final yt = yte.YoutubeExplode();
        final manifest = await yt.videos.streamsClient.getManifest(cleanVideoId);
        final mp4Streams = manifest.audioOnly
            .where((a) => a.container.name == 'mp4' || a.audioCodec.contains('mp4a'))
            .toList();
        final streamInfo = mp4Streams.isNotEmpty
            ? mp4Streams.first
            : (manifest.audioOnly.isNotEmpty
                ? manifest.audioOnly.withHighestBitrate()
                : (manifest.muxed.isNotEmpty ? manifest.muxed.first : null));
        if (streamInfo != null) {
          streamUrl = streamInfo.url.toString();
        }
        yt.close();
      } catch (err) {
        debugPrint('Direct client explode failed for $cleanVideoId: $err');
      }

      // 3. Fallback: Search alternative audio track if original video is restricted (e.g. MV or unavailable)
      if (streamUrl == null || streamUrl.isEmpty) {
        try {
          final searchTitle = '${widget.title ?? ''} ${widget.author ?? ''}'.trim();
          if (searchTitle.isNotEmpty) {
            final yt = yte.YoutubeExplode();
            final results = await yt.search.search('$searchTitle audio');
            for (final alt in results.take(4)) {
              if (alt.id.value != cleanVideoId) {
                try {
                  final m = await yt.videos.streamsClient.getManifest(alt.id.value);
                  final mp4s = m.audioOnly
                      .where((a) => a.container.name == 'mp4' || a.audioCodec.contains('mp4a'))
                      .toList();
                  final s = mp4s.isNotEmpty
                      ? mp4s.first
                      : (m.audioOnly.isNotEmpty
                          ? m.audioOnly.withHighestBitrate()
                          : (m.muxed.isNotEmpty ? m.muxed.first : null));
                  if (s != null) {
                    streamUrl = s.url.toString();
                    cleanVideoId = alt.id.value;
                    break;
                  }
                } catch (_) {}
              }
            }
            yt.close();
          }
        } catch (_) {}
      }

      // 4. Last fallback: backend decipher endpoint
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await _youtubeService.getAudioStreamUrl(cleanVideoId);
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Walang available na audio stream para sa kantang ito.');
      }

      final track = GlobalAudioQueueItem(
        id: targetTrackId,
        src: streamUrl,
        title: widget.title?.isNotEmpty == true ? widget.title! : 'YouTube Audio',
        artist: widget.author?.isNotEmpty == true ? widget.author! : 'YouTube Creator',
        artworkUrl: widget.thumbnail ?? '',
        source: 'youtube',
      );

      await playerService.setPlaylist([track], autoPlay: true);

      if (mounted) {
        setState(() => _isLoading = false);
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  void _syncRotation(bool isPlaying) {
    if (isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final playerService = context.read<GlobalAudioPlayerService>();
    final newPosition = playerService.currentTime + delta;
    final maxDuration = playerService.duration;
    final clamped = Duration(
      milliseconds: math.max(
        0,
        math.min(newPosition.inMilliseconds, maxDuration.inMilliseconds),
      ),
    );
    await playerService.seek(clamped);
  }

  Future<void> _downloadMp3() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final safeTitle = (widget.title ?? 'youtube_audio')
          .replaceAll(RegExp(r'[^\w\s\.-]'), '_')
          .trim();
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$safeTitle.mp3';

      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/yt_audio_${widget.videoId}.m4a');

      if (cacheFile.existsSync() && cacheFile.lengthSync() > 50000) {
        await cacheFile.copy(savePath);
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 1.0;
            _downloadedFilePath = savePath;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('MP3 saved: $safeTitle.mp3'),
              backgroundColor: const Color(0xFF10B981),
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: _shareDownloadedFile,
              ),
            ),
          );
        }
        return;
      }

      // If not cached yet, download via getCachedOrDownloadAudio
      await _youtubeService.getCachedOrDownloadAudio(
        widget.videoId,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );

      if (cacheFile.existsSync() && cacheFile.lengthSync() > 50000) {
        await cacheFile.copy(savePath);
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadedFilePath = savePath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MP3 downloaded successfully: $safeTitle.mp3'),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: _shareDownloadedFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _shareDownloadedFile() {
    if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
      Share.shareXFiles(
        [XFile(_downloadedFilePath!)],
        text: widget.title ?? 'YouTube MP3 Track',
      );
    }
  }

  void _switchToVideo() {
    final playerService = context.read<GlobalAudioPlayerService>();
    playerService.setPlaying(false);

    Navigator.of(context).pushReplacement(
      YouTubePlayerScreen.route(
        videoId: widget.videoId,
        title: widget.title,
        author: widget.author,
        thumbnail: widget.thumbnail,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // IMPORTANT: DO NOT STOP AUDIO IN GlobalAudioPlayerService!
    // This allows audio to continue playing across all screens!
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : 'YouTube Audio';
    final authorText = widget.author?.trim().isNotEmpty == true
        ? widget.author!.trim()
        : 'YouTube Creator';

    return Consumer<GlobalAudioPlayerService>(
      builder: (context, player, child) {
        _syncRotation(player.playing);

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F12),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note_rounded, color: Color(0xFFFF2A6D), size: 20),
                SizedBox(width: 6.w),
                Text(
                  'KatsKlub YouTube Music',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showLyrics ? Icons.album_rounded : Icons.lyrics_rounded,
                  color: _showLyrics ? const Color(0xFFFF2A6D) : Colors.white70,
                ),
                tooltip: _showLyrics ? 'Ipakita ang Vinyl' : 'Ipakita ang Lyrics',
                onPressed: _toggleLyrics,
              ),
              IconButton(
                icon: const Icon(Icons.video_collection_outlined, color: Colors.white70),
                tooltip: 'Panoorin ang Video',
                onPressed: _switchToVideo,
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Colors.white70),
                tooltip: 'Buksan sa YouTube App',
                onPressed: () async {
                  final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildPlayerBody(titleText, authorText, player),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A6D)),
          ),
          SizedBox(height: 16.h),
          Text(
            'Inilalagay sa Music Player...',
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Hindi mamamatay ang audio kahit lumipat ng screens 🎵',
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 11.sp,
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            SizedBox(height: 12.h),
            Text(
              _errorMessage ?? 'Hindi ma-load ang audio stream.',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.sp,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initOrSwitchPlayback,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Subukan Muli'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2A6D),
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 12.w),
                OutlinedButton.icon(
                  onPressed: _switchToVideo,
                  icon: const Icon(Icons.video_library_rounded, size: 18),
                  label: const Text('Panoorin ang Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsCard() {
    return Container(
      width: double.infinity,
      height: 250.h,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFFF2A6D).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2A6D).withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lyrics_rounded, color: Color(0xFFFF2A6D), size: 18),
                  SizedBox(width: 6.w),
                  Text(
                    'YouTube Music Lyrics',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _showLyrics = false),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          Expanded(
            child: _loadingLyrics
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A6D)),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      _lyrics ?? 'Walang lyrics.',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.sp,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBody(
    String titleText,
    String authorText,
    GlobalAudioPlayerService player,
  ) {
    final position = player.currentTime;
    final duration = player.duration;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Either Animated Vinyl Disc or Lyrics View
          _showLyrics
              ? _buildLyricsCard()
              : Center(
                  child: AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 240.w,
                      height: 240.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E1E24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                            blurRadius: 36,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF111115),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(18.r),
                            child: ClipOval(
                              child: widget.thumbnail != null && widget.thumbnail!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.thumbnail!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.black45),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.music_note, color: Colors.white38, size: 50),
                                    )
                                  : Container(
                                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.2),
                                      child: const Icon(Icons.music_note, color: Colors.white, size: 50),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

          const Spacer(flex: 1),

          // Song Title and Artist
          Text(
            titleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            authorText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF2A6D),
            ),
          ),
          SizedBox(height: 8.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Background Floating Notice Chip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0x4410B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.album_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4.w),
                    Text(
                      'Background Audio Active',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // View Lyrics Pill Button
              GestureDetector(
                onTap: _toggleLyrics,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _showLyrics
                        ? const Color(0xFFFF2A6D).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: _showLyrics ? const Color(0xFFFF2A6D) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lyrics_rounded,
                        color: _showLyrics ? const Color(0xFFFF2A6D) : Colors.white70,
                        size: 14,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _showLyrics ? 'Vinyl' : 'Lyrics',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _showLyrics ? const Color(0xFFFF2A6D) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 18.h),

          // Progress Slider
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: const Color(0xFFFF2A6D),
                  activeTrackColor: const Color(0xFFFF2A6D),
                  inactiveTrackColor: Colors.white12,
                  trackHeight: 3.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
                ),
                child: Slider(
                  value: position.inMilliseconds
                      .clamp(0, math.max(1, duration.inMilliseconds))
                      .toDouble(),
                  max: math.max(1, duration.inMilliseconds).toDouble(),
                  onChanged: (val) {
                    player.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 11.sp,
                        color: Colors.white54,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 11.sp,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Primary Controls: Rewind 10s, Play/Pause, Fast Forward 10s
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip -10s
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 30),
                tooltip: 'I-rewind nang 10 segundo',
                onPressed: () => _seekRelative(const Duration(seconds: -10)),
              ),

              // Play / Pause Circle Button
              GestureDetector(
                onTap: () async {
                  final targetTrackId = 'yt_${widget.videoId}';
                  if (player.currentTrack?.id != targetTrackId || player.duration == Duration.zero) {
                    await _initOrSwitchPlayback();
                  } else {
                    await player.togglePlaying();
                  }
                },
                child: Container(
                  width: 68.w,
                  height: 68.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A6D), Color(0xFF9B51E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.4),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38.sp,
                  ),
                ),
              ),

              // Skip +10s
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 30),
                tooltip: 'I-forward nang 10 segundo',
                onPressed: () => _seekRelative(const Duration(seconds: 10)),
              ),
            ],
          ),

          const Spacer(flex: 1),

          // Download MP3 & Share Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isDownloading
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Downloading MP3...',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    fontSize: 11.sp,
                                    color: const Color(0xFFFF2A6D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A6D)),
                            ),
                          ],
                        )
                      : _downloadedFilePath != null
                          ? Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    'Downloaded sa device',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _shareDownloadedFile,
                                  icon: const Icon(Icons.share_rounded, size: 16),
                                  label: const Text('Share MP3'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.download_rounded, color: Color(0xFFFF2A6D), size: 22),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    'Download MP3 for Offline Listening',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _downloadMp3,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF2A6D),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                  child: const Text('Download'),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
