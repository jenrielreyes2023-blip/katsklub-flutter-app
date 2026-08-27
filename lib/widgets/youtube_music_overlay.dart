import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/youtube_music_controller.dart';

/// Persistent YouTube Music Player Overlay.
/// Designed specifically like the official YouTube Music mobile app:
/// - Re-uses a single GlobalKey for WebViewWidget to ensure audio never stops.
/// - Fixed-height 64.h mini-player bar positioned perfectly above the bottom nav bar.
/// - Full touch target and comfortable controls in both full-screen and mini modes.
class YouTubeMusicOverlay extends StatefulWidget {
  const YouTubeMusicOverlay({super.key});

  @override
  State<YouTubeMusicOverlay> createState() => _YouTubeMusicOverlayState();
}

class _YouTubeMusicOverlayState extends State<YouTubeMusicOverlay> {
  final YouTubeMusicController _controller = youTubeMusicController;
  final GlobalKey _webViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isOpen || _controller.currentTrack == null) {
      return const SizedBox.shrink();
    }

    final isMin = _controller.isMinimized;
    final track = _controller.currentTrack!;

    return PopScope(
      canPop: isMin,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isMin) {
          _controller.minimize();
        }
      },
      child: isMin
          ? Positioned(
              left: 12.w,
              right: 12.w,
              bottom: 10.h,
              height: 64.h,
              child: _buildMiniBar(track),
            )
          : Positioned.fill(
              child: _buildFullScreenPlayer(track),
            ),
    );
  }

  /// Sleek YouTube Music Bottom Mini-Player Bar
  Widget _buildMiniBar(dynamic track) {
    return Material(
      color: Colors.transparent,
      elevation: 16,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: const Color(0xFF181924),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFFF2A6D), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Active Mini Video Window (68x44)
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                width: 68.w,
                height: 44.h,
                color: Colors.black,
                child: _controller.webViewController != null
                    ? WebViewWidget(
                        key: _webViewKey,
                        controller: _controller.webViewController!,
                      )
                    : CachedNetworkImage(
                        imageUrl: track.thumbnail,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            SizedBox(width: 10.w),

            // Tap on title/channel to expand to full screen!
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _controller.expand,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded,
                            color: Color(0xFFFF2A6D), size: 13),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            track.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 11.5.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Play / Pause Button
            IconButton(
              icon: Icon(
                _controller.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: const Color(0xFFFF2A6D),
                size: 36.sp,
              ),
              tooltip: _controller.isPlaying ? 'I-pause' : 'I-play',
              onPressed: _controller.togglePlayPause,
            ),

            // Close (X) Button
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
              tooltip: 'Isara',
              onPressed: _controller.close,
            ),
          ],
        ),
      ),
    );
  }

  /// Full-Screen YouTube Music Player View
  Widget _buildFullScreenPlayer(dynamic track) {
    return Material(
      color: const Color(0xFF0D0E15),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar with Minimize Down Arrow
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 36),
                    tooltip: 'I-minimize ang Player',
                    onPressed: _controller.minimize,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PLAYING FROM YOUTUBE MUSIC',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: const Color(0xFFFF2A6D),
                          ),
                        ),
                        Text(
                          track.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: Colors.white70, size: 22),
                    tooltip: 'Buksan sa YouTube App',
                    onPressed: () async {
                      final uri =
                          Uri.parse('https://www.youtube.com/watch?v=${track.id}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Video/Audio Player Area
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                height: 220.h,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: _controller.webViewController != null
                      ? WebViewWidget(
                          key: _webViewKey,
                          controller: _controller.webViewController!,
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFFFF2A6D)),
                          ),
                        ),
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Title & Channel Metadata
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 16.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    track.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF2A6D),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  // Continuous Background Play Chip
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0x4410B981)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Color(0xFF10B981), size: 15),
                        SizedBox(width: 4.w),
                        Text(
                          'Continuous Playback • Tap ∨ to browse app',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Controls: Rewind 10s, Play/Pause, Forward 10s
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded,
                      color: Colors.white, size: 36),
                  tooltip: 'Rewind 10s',
                  onPressed: () => _controller.seekRelative(-10),
                ),

                // Large Circular Gradient Play / Pause Button
                GestureDetector(
                  onTap: _controller.togglePlayPause,
                  child: Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2A6D), Color(0xFF9B51E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A6D).withValues(alpha: 0.45),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 42.sp,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.forward_10_rounded,
                      color: Colors.white, size: 36),
                  tooltip: 'Forward 10s',
                  onPressed: () => _controller.seekRelative(10),
                ),
              ],
            ),

            const Spacer(flex: 1),

            // Minimize Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: ElevatedButton.icon(
                onPressed: _controller.minimize,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                label: const Text('I-minimize at Makinig Habang Nagba-browse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E28),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),

            SizedBox(height: 18.h),
          ],
        ),
      ),
    );
  }
}
