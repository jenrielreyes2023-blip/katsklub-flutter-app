import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/youtube_service.dart';

/// Full-featured YouTube Player Screen supporting direct Google CDN stream playback
/// via [video_player] and [chewie], with automatic fallback to Webview for restricted media.
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
      if (stream == null || stream.isEmpty) {
        stream = await _youtubeService.getStreamUrl(widget.videoId);
      }

      if (stream != null && stream.isNotEmpty) {
        await _initializeChewiePlayer(stream);
      } else {
        // Fallback to webview player if direct stream is restricted
        _initWebviewFallback();
      }
    } catch (e) {
      _initWebviewFallback();
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
                  onPressed: _initWebviewFallback,
                  icon: const Icon(Icons.web, size: 18),
                  label: const Text('Switch to Web Player'),
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
        _initWebviewFallback();
      }
    }
  }

  void _initWebviewFallback() {
    const userAgent =
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.119 Mobile Safari/537.36';

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000000; overflow: hidden; }
    .video-container { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <div class="video-container">
    <iframe
      src="https://www.youtube-nocookie.com/embed/${widget.videoId}?autoplay=1&playsinline=1&enablejsapi=1&rel=0&modestbranding=1"
      title="YouTube Video Player"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen>
    </iframe>
  </div>
</body>
</html>
''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(userAgent)
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
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: 'https://www.youtube.com');

    if (mounted) {
      setState(() {
        _webViewController = controller;
        _useWebviewFallback = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _disposeControllers() async {
    _chewieController?.dispose();
    _chewieController = null;
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  void dispose() {
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
                              _initWebviewFallback();
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
                                ? Icons.language
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
                                  ? 'Streaming via YouTube Webview Player'
                                  : 'Direct Google CDN Native Stream Active',
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
                'Extracting stream URL...',
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
