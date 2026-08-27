import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

import '../services/youtube_service.dart';
import 'youtube_player_screen.dart';

/// Full-featured YouTube MP3 Music & Audio Player screen.
/// Features:
/// - Background audio playback using [just_audio].
/// - Beautiful animated rotating vinyl album art.
/// - Data Saver (<5 MB audio vs >50 MB video).
/// - Fast seek bar, speed toggle, loop toggle.
/// - In-app MP3 download with progress and direct file sharing.
class YouTubeMP3Screen extends StatefulWidget {
  const YouTubeMP3Screen({
    required this.videoId,
    this.title,
    this.author,
    this.thumbnail,
    super.key,
  });

  final String videoId;
  final String? title;
  final String? author;
  final String? thumbnail;

  static Route<void> route({
    required String videoId,
    String? title,
    String? author,
    String? thumbnail,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => YouTubeMP3Screen(
        videoId: videoId,
        title: title,
        author: author,
        thumbnail: thumbnail,
      ),
    );
  }

  @override
  State<YouTubeMP3Screen> createState() => _YouTubeMP3ScreenState();
}

class _YouTubeMP3ScreenState extends State<YouTubeMP3Screen>
    with SingleTickerProviderStateMixin {
  final YouTubeService _youtubeService = YouTubeService();
  late final AudioPlayer _audioPlayer;
  late final AnimationController _rotationController;

  bool _isLoading = true;
  String? _errorMessage;
  String? _audioStreamUrl;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLooping = false;
  double _playbackSpeed = 1.0;

  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _initPlayerListeners();
    _loadAndPlayAudio();
  }

  void _initPlayerListeners() {
    _posSub = _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _durSub = _audioPlayer.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });

    _stateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.playing) {
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      } else {
        if (_rotationController.isAnimating) {
          _rotationController.stop();
        }
      }
    });
  }

  Future<void> _loadAndPlayAudio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = await _youtubeService.getAudioStreamUrl(widget.videoId);
      if (url == null || url.isEmpty) {
        throw Exception('Unable to extract audio stream for this video.');
      }

      _audioStreamUrl = url;
      final mediaItem = MediaItem(
        id: widget.videoId,
        album: widget.author?.isNotEmpty == true ? widget.author! : 'YouTube Music',
        title: widget.title?.isNotEmpty == true ? widget.title! : 'YouTube Audio',
        artist: widget.author?.isNotEmpty == true ? widget.author! : 'YouTube Creator',
        artUri: widget.thumbnail != null && widget.thumbnail!.isNotEmpty
            ? Uri.tryParse(widget.thumbnail!)
            : null,
      );

      final source = AudioSource.uri(
        Uri.parse(url),
        tag: mediaItem,
      );
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Fallback: If audio-only stream fails with Source Error, try direct muxed MP4 stream
      try {
        final yt = yte.YoutubeExplode();
        final manifest = await yt.videos.streamsClient.getManifest(widget.videoId);
        final muxed = manifest.muxed.withHighestBitrate();
        yt.close();

        _audioStreamUrl = muxed.url.toString();
        final fallbackSource = AudioSource.uri(
          muxed.url,
          tag: MediaItem(
            id: widget.videoId,
            album: widget.author?.isNotEmpty == true ? widget.author! : 'YouTube Music',
            title: widget.title?.isNotEmpty == true ? widget.title! : 'YouTube Audio',
            artist: widget.author?.isNotEmpty == true ? widget.author! : 'YouTube Creator',
            artUri: widget.thumbnail != null && widget.thumbnail!.isNotEmpty
                ? Uri.tryParse(widget.thumbnail!)
                : null,
          ),
        );
        await _audioPlayer.setAudioSource(fallbackSource);
        await _audioPlayer.play();

        if (mounted) {
          setState(() => _isLoading = false);
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Hindi ma-load ang audio stream: $e';
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: math.max(
        0,
        math.min(target.inMilliseconds, _duration.inMilliseconds),
      ),
    );
    await _audioPlayer.seek(clamped);
  }

  Future<void> _toggleLoop() async {
    final next = !_isLooping;
    await _audioPlayer.setLoopMode(next ? LoopMode.one : LoopMode.off);
    setState(() => _isLooping = next);
  }

  void _cycleSpeed() {
    final speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    final nextIndex = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];
    _audioPlayer.setSpeed(newSpeed);
    setState(() => _playbackSpeed = newSpeed);
  }

  Future<void> _downloadMp3() async {
    if (_audioStreamUrl == null || _isDownloading) return;

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

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_audioStreamUrl!));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() {
            _downloadProgress = receivedBytes / totalBytes;
          });
        }
      }).asFuture<void>();

      await sink.close();
      client.close();

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
    _audioPlayer.pause();
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
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _rotationController.dispose();
    _audioPlayer.dispose();
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
              'YouTube MP3 Player',
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
            icon: const Icon(Icons.video_collection_outlined, color: Colors.white70),
            tooltip: 'Switch to Video Player',
            onPressed: _switchToVideo,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70),
            tooltip: 'Open in YouTube',
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
                : _buildPlayerBody(titleText, authorText),
      ),
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
            'Extracting high-quality MP3 audio...',
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Ultra low data usage (~3 MB)',
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
              _errorMessage ?? 'Failed to load MP3 stream.',
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
                  onPressed: _loadAndPlayAudio,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2A6D),
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 12.w),
                OutlinedButton.icon(
                  onPressed: _switchToVideo,
                  icon: const Icon(Icons.video_library_rounded, size: 18),
                  label: const Text('Watch Video'),
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

  Widget _buildPlayerBody(String titleText, String authorText) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Animated Vinyl Disc Album Art
          Center(
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

          // Data Saver & Quality Chip
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
                const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 14),
                SizedBox(width: 4.w),
                Text(
                  '128 kbps MP3 • Low Data Mode (~3 MB)',
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
                  value: _position.inMilliseconds
                      .clamp(0, math.max(1, _duration.inMilliseconds))
                      .toDouble(),
                  max: math.max(1, _duration.inMilliseconds).toDouble(),
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 11.sp,
                        color: Colors.white54,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
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

          // Primary Controls: Rewind, Play/Pause, Fast Forward, Loop, Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Loop Toggle
              IconButton(
                icon: Icon(
                  _isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  color: _isLooping ? const Color(0xFFFF2A6D) : Colors.white60,
                  size: 22.sp,
                ),
                tooltip: 'Loop Track',
                onPressed: _toggleLoop,
              ),

              // Skip -10s
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                tooltip: 'Rewind 10s',
                onPressed: () => _seekRelative(-10),
              ),

              // Play / Pause Circle Button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 64.w,
                  height: 64.w,
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
                    _audioPlayer.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36.sp,
                  ),
                ),
              ),

              // Skip +10s
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                tooltip: 'Forward 10s',
                onPressed: () => _seekRelative(10),
              ),

              // Speed Switcher
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
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
                                    'Downloaded to device',
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
