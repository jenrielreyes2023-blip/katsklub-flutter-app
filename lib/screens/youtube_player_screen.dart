import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

import '../services/youtube_service.dart';

/// Full-featured YouTube Player Screen supporting:
/// 1. Direct device-side stream extraction (via youtube_explode_dart) for native Chewie playback.
/// 2. Backend deciphered CDN stream fallback.
/// 3. Clean mobile web watch player (injects CSS to isolate player, eliminating Error 152/153).
class YouTubePlayerScreen extends StatefulWidget {
  const YouTubePlayerScreen({
    required this.videoId,
    this.title,
    this.author,
    this.thumbnail,
    this.streamUrl,
    super.key,
  });

  final String videoId;
  final String? title;
  final String? author;
  final String? thumbnail;
  final String? streamUrl;

  static Route<void> route({
    required String videoId,
    String? title,
    String? author,
    String? thumbnail,
    String? streamUrl,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => YouTubePlayerScreen(
        videoId: videoId,
        title: title,
        author: author,
        thumbnail: thumbnail,
        streamUrl: streamUrl,
      ),
    );
  }

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  final YouTubeService _youtubeService = YouTubeService();

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool _isLoading = true;
  bool _useWebviewFallback = false;
  String? _errorMessage;

  WebViewController? _webViewController;
  bool _isWebviewLoading = false;
  Timer? _cleanPlayerTimer;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  Future<void> _startPlayback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _useWebviewFallback = false;
    });

    try {
      String? stream = widget.streamUrl;

      // Strategy 1: Client-side direct stream extraction on user's device
      if (stream == null || stream.isEmpty) {
        stream = await _extractStreamClientSide(widget.videoId);
      }

      // Strategy 2: Backend direct stream extraction
      if (stream == null || stream.isEmpty) {
        stream = await _youtubeService.getStreamUrl(widget.videoId);
      }

      if (stream != null && stream.isNotEmpty) {
        await _initializeChewiePlayer(stream);
      } else {
        // Strategy 3: Clean mobile web watch player (avoids Error 152/153)
        _initCleanMobileWebPlayer();
      }
    } catch (e) {
      _initCleanMobileWebPlayer();
    }
  }

  Future<String?> _extractStreamClientSide(String videoId) async {
    final yt = yte.YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final muxed = manifest.muxed.withHighestBitrate();
      return muxed.url.toString();
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }

  Future<void> _initializeChewiePlayer(String url) async {
    try {
      await _disposeControllers();

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      await controller.initialize();

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFFF0000),
          handleColor: const Color(0xFFFF0000),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 42),
                SizedBox(height: 10.h),
                Text(
                  'Playback Error: $errorMessage',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                ElevatedButton.icon(
                  onPressed: _initCleanMobileWebPlayer,
                  icon: const Icon(Icons.web, size: 18),
                  label: const Text('Switch to Clean Web Player'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _videoPlayerController = controller;
          _chewieController = chewie;
          _isLoading = false;
          _useWebviewFallback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _initCleanMobileWebPlayer();
      }
    }
  }

  void _initCleanMobileWebPlayer() {
    _cleanPlayerTimer?.cancel();

    final watchUrl =
        'https://m.youtube.com/watch?v=${widget.videoId}&autoplay=1';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isWebviewLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isWebviewLoading = false);
            }
            _injectCleanPlayerStyles();
          },
        ),
      )
      ..loadRequest(Uri.parse(watchUrl));

    if (mounted) {
      setState(() {
        _webViewController = controller;
        _useWebviewFallback = true;
        _isLoading = false;
      });
    }

    // Periodically enforce clean UI as dynamic elements load
    _cleanPlayerTimer =
        Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (timer.tick > 12) {
        timer.cancel();
      }
      _injectCleanPlayerStyles();
    });
  }

  void _injectCleanPlayerStyles() {
    const script = r"""
      (function() {
        var style = document.getElementById('kk-clean-player-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'kk-clean-player-style';
          style.innerHTML = `
            ytm-header, header, ytm-mobile-topbar-renderer, ytm-pivot-bar-renderer,
            ytm-single-column-watch-next-results-renderer, ytm-item-section-renderer,
            ytm-comments-entry-point-header-renderer, .watch-below-the-player,
            #related, ytm-engagement-panel-section-list-renderer, ytm-paid-content-overlay-renderer,
            .yt-spec-bottom-sheet-layout__bottom-sheet-renderer-container,
            .slim-video-metadata-header, ytm-slim-video-metadata-section-renderer,
            .mobile-topbar-header, .ytp-cards-teaser, .ytp-watermark,
            .ytp-pause-overlay-container, ytm-autonav-toggle,
            #app-banner, ytm-promoted-sparkles-web-renderer {
              display: none !important;
            }
            html, body {
              margin: 0 !important;
              padding: 0 !important;
              background-color: #000000 !important;
              overflow: hidden !important;
              width: 100vw !important;
              height: 100vh !important;
            }
            #player-container-id, .player-container, #player {
              position: fixed !important;
              top: 0 !important;
              left: 0 !important;
              width: 100vw !important;
              height: 100vh !important;
              z-index: 999999 !important;
              background-color: #000000 !important;
            }
            video {
              width: 100% !important;
              height: 100% !important;
              object-fit: contain !important;
            }
          `;
          document.head.appendChild(style);
        }
        var video = document.querySelector('video');
        if (video && video.paused) {
          video.play().catch(function(){});
        }
        var playBtn = document.querySelector('.ytp-large-play-button, .player-placeholder-wrapper');
        if (playBtn) {
          playBtn.click();
        }
      })();
    """;
    _webViewController?.runJavaScript(script).catchError((_) {});
  }

  Future<void> _disposeControllers() async {
    _chewieController?.dispose();
    _chewieController = null;
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _cleanPlayerTimer?.cancel();
    _disposeControllers();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _openInYouTube() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareVideo() {
    final title = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : 'YouTube Video';
    Share.share(
      '$title\nhttps://www.youtube.com/watch?v=${widget.videoId}',
      subject: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleText = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : 'YouTube Video';
    final authorText = widget.author?.trim().isNotEmpty == true
        ? widget.author!.trim()
        : 'YouTube Channel';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          titleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white70, size: 20),
            tooltip: 'Share',
            onPressed: _shareVideo,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
            tooltip: 'Open in YouTube',
            onPressed: _openInYouTube,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Player Container (16:9 Aspect Ratio)
            Container(
              color: Colors.black,
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildPlayerContent(),
              ),
            ),

            // Video Details and Metadata Area
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF18191A) : Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: ListView(
                  children: [
                    // Video Title
                    Text(
                      titleText,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1C1E21),
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Author / Channel Details
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18.r,
                          backgroundColor:
                              const Color(0xFFFF0000).withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFFFF0000),
                            size: 22,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF1C1E21),
                                ),
                              ),
                              Text(
                                'YouTube Creator',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 11.sp,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    const Divider(height: 1, color: Color(0x229CA3AF)),
                    SizedBox(height: 16.h),

                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: _shareVideo,
                          isDark: isDark,
                        ),
                        _buildActionButton(
                          icon: Icons.launch_rounded,
                          label: 'YouTube App',
                          onTap: _openInYouTube,
                          isDark: isDark,
                        ),
                        _buildActionButton(
                          icon: _useWebviewFallback
                              ? Icons.smart_display_outlined
                              : Icons.language_outlined,
                          label: _useWebviewFallback ? 'CDN Player' : 'Web Player',
                          onTap: () {
                            if (_useWebviewFallback) {
                              _startPlayback();
                            } else {
                              _initCleanMobileWebPlayer();
                            }
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    const Divider(height: 1, color: Color(0x229CA3AF)),
                    SizedBox(height: 16.h),

                    // Watch in YouTube App Button
                    InkWell(
                      onTap: _openInYouTube,
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                            SizedBox(width: 8.w),
                            Text(
                              'Open in YouTube App',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Playback Status Indicator
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _useWebviewFallback
                                ? Icons.smart_display_rounded
                                : Icons.bolt_rounded,
                            size: 18.sp,
                            color: _useWebviewFallback
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF10B981),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _useWebviewFallback
                                  ? 'Clean Web Player Active (No Embed Errors)'
                                  : 'Direct Native Stream Active',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_isLoading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.thumbnail!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          Container(color: Colors.black54),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              ),
              SizedBox(height: 12.h),
              Text(
                'Loading video stream...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_useWebviewFallback && _webViewController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _webViewController!),
          if (_isWebviewLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              ),
            ),
        ],
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Chewie(controller: _chewieController!);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white60, size: 36),
          SizedBox(height: 8.h),
          Text(
            _errorMessage ?? 'Unable to initialize video stream',
            style: const TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: _startPlayback,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22.sp,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
