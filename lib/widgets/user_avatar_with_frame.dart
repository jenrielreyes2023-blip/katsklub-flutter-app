import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../config/api_config.dart';

final ValueNotifier<String> equippedAdminFrameNotifier = ValueNotifier<String>('assets/frames/bframe.png');

class UserAvatarWithFrame extends StatelessWidget {
  const UserAvatarWithFrame({
    super.key,
    required this.avatarUrl,
    this.radius = 40.0,
    this.framePath,
    this.avatarFrame,
    this.isAdmin = false,
    this.initials = '',
    this.onTap,
    this.preserveLayoutFootprint = true,
  });

  final String avatarUrl;
  final double radius;
  final String? framePath;
  final String? avatarFrame;
  final bool isAdmin;
  final String initials;
  final VoidCallback? onTap;
  final bool preserveLayoutFootprint;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl.trim();
    final size = radius * 2;

    Widget avatarChild;
    if (cleanUrl.isEmpty) {
      avatarChild = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE5E7EB),
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            fontSize: math.max(1.0, (radius * 0.7).sp),
          ),
        ),
      );
    } else if (cleanUrl.startsWith('data:')) {
      Uint8List? memoryBytes;
      try {
        final commaIdx = cleanUrl.indexOf(',');
        final b64Str = commaIdx != -1 ? cleanUrl.substring(commaIdx + 1) : cleanUrl;
        memoryBytes = base64Decode(b64Str);
      } catch (_) {}

      if (memoryBytes != null && memoryBytes.isNotEmpty) {
        avatarChild = CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE5E7EB),
          backgroundImage: MemoryImage(memoryBytes),
        );
      } else {
        avatarChild = CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE5E7EB),
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              fontSize: math.max(1.0, (radius * 0.7).sp),
            ),
          ),
        );
      }
    } else {
      avatarChild = CachedNetworkImage(
        imageUrl: ApiConfig.assetUrl(cleanUrl),
        memCacheWidth: 300,
        maxWidthDiskCache: 300,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE5E7EB),
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFF3F4F6),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE5E7EB),
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              fontSize: math.max(1.0, (radius * 0.7).sp),
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: equippedAdminFrameNotifier,
      builder: (context, globalEquippedFrame, _) {
        final String? rawFrame = (avatarFrame?.trim().isNotEmpty == true ? avatarFrame : framePath) ?? (isAdmin ? globalEquippedFrame : null);
        final cleanRaw = (rawFrame == 'none' || rawFrame == null) ? null : rawFrame.trim();
        final effectiveFrame = cleanRaw != null ? ApiConfig.frameUrl(cleanRaw) : null;
        final hasFrame = effectiveFrame != null && effectiveFrame.isNotEmpty;
        final pathLower = (effectiveFrame ?? '').toLowerCase();

        final isRemote = pathLower.startsWith('http://') || pathLower.startsWith('https://');
        final isLottie = pathLower.endsWith('.json') || pathLower.contains('.json?');
        final isSvga = pathLower.endsWith('.svga') || pathLower.contains('.svga?');
        final isWingFrame = pathLower.contains('wing_frame');
        final isTestFrame = pathLower.contains('test_frame');
        final isNeonFrame = pathLower.contains('neon.json') ||
            pathLower.contains('neon_frame') ||
            pathLower.contains('/neon');
        final isSpringFrame = pathLower.contains('spring_blossom_frame');
        final isBeachFrame =
            pathLower.contains('beach-frame') || pathLower.contains('beach_frame');
        final isKawaiiFrame =
            pathLower.contains('kawaii2') || pathLower.contains('kawaii');
        final isOrnaFrame =
            pathLower.contains('orna');
        final isPurpleFrame =
            pathLower.contains('purpleav') || pathLower.contains('purple_av');
        final isHeartFrame =
            pathLower.contains('heart');
        final isPotionFrame =
            pathLower.contains('potion') || pathLower.contains('magical_potion');

        final double frameSize;
        if (isWingFrame) {
          frameSize = size * 1.85;
        } else if (isTestFrame) {
          frameSize = size * 1.48;
        } else if (isNeonFrame) {
          frameSize = size * 1.70;
        } else if (isBeachFrame || isKawaiiFrame || isOrnaFrame) {
          frameSize = size * 1.50;
        } else if (isPotionFrame) {
          frameSize = size * 1.42;
        } else if (isHeartFrame) {
          frameSize = size * 1.46;
        } else if (isSpringFrame) {
          frameSize = size * 1.35;
        } else if (isPurpleFrame) {
          frameSize = size * 1.38;
        } else if (isSvga) {
          // Default optimal scale for remote/local SVGA avatar frames
          frameSize = size * 1.50;
        } else {
          frameSize = size * 1.30;
        }

        final double xOffset = isBeachFrame ? (10.0 / 480.0) * frameSize : 0.0;
        final double yOffset = isBeachFrame ? (12.5 / 480.0) * frameSize : 0.0;

        final double effectiveWidth = (hasFrame && !preserveLayoutFootprint) ? frameSize : size;
        final double effectiveHeight = (hasFrame && !preserveLayoutFootprint) ? frameSize : size;

        final widgetStack = SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Layer 1 (Bottom): The CircleAvatar displaying the user photo
              avatarChild,

              // Layer 2 (Top): The frame image, Lottie, or SVGA overlay wrapped in IgnorePointer and RepaintBoundary
              if (hasFrame)
                Positioned(
                  left: (effectiveWidth - frameSize) / 2 + xOffset,
                  top: (effectiveHeight - frameSize) / 2 + yOffset,
                  width: frameSize,
                  height: frameSize,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: isLottie
                          ? _LottieFrameOverlay(
                              framePath: effectiveFrame,
                              frameSize: frameSize,
                            )
                          : isSvga
                              ? _SvgaFrameOverlay(
                                  framePath: effectiveFrame,
                                  frameSize: frameSize,
                                )
                              : isRemote
                                  ? CachedNetworkImage(
                                      imageUrl: effectiveFrame,
                                      width: frameSize,
                                      height: frameSize,
                                      fit: BoxFit.contain,
                                      errorWidget: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    )
                                  : Image.asset(
                                      effectiveFrame,
                                      width: frameSize,
                                      height: frameSize,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    ),
                    ),
                  ),
                ),
            ],
          ),
        );

        if (onTap != null) {
          return GestureDetector(
            onTap: onTap,
            child: widgetStack,
          );
        }

        return widgetStack;
      },
    );
  }
}

class _LottieFrameOverlay extends StatefulWidget {
  const _LottieFrameOverlay({
    required this.framePath,
    required this.frameSize,
  });

  final String framePath;
  final double frameSize;

  @override
  State<_LottieFrameOverlay> createState() => _LottieFrameOverlayState();
}

class _LottieFrameOverlayState extends State<_LottieFrameOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    final pathLower = widget.framePath.toLowerCase();
    if (pathLower.contains('wing_frame')) {
      // Wing frame skips initial circle morph state and continuously loops expanded wings segment
      _controller.repeat(min: 0.35, max: 1.0);
    } else {
      // Full uncut animation loop for standard Lottie frames
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = widget.framePath.startsWith('http://') ||
        widget.framePath.startsWith('https://');

    if (isRemote) {
      return Lottie.network(
        widget.framePath,
        width: widget.frameSize,
        height: widget.frameSize,
        fit: BoxFit.contain,
        controller: _controller,
        onLoaded: _onLoaded,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return Lottie.asset(
      widget.framePath,
      width: widget.frameSize,
      height: widget.frameSize,
      fit: BoxFit.contain,
      controller: _controller,
      onLoaded: _onLoaded,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _SvgaFrameOverlay extends StatefulWidget {
  const _SvgaFrameOverlay({
    required this.framePath,
    required this.frameSize,
  });

  final String framePath;
  final double frameSize;

  @override
  State<_SvgaFrameOverlay> createState() => _SvgaFrameOverlayState();
}

class _SvgaFrameOverlayState extends State<_SvgaFrameOverlay>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadSvga();
  }

  @override
  void didUpdateWidget(covariant _SvgaFrameOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.framePath != widget.framePath) {
      _loadSvga();
    }
  }

  Future<void> _loadSvga() async {
    final targetPath = widget.framePath;
    _loadedPath = targetPath;
    try {
      final isRemote = targetPath.startsWith('http://') ||
          targetPath.startsWith('https://');

      Uint8List? bytes;
      if (isRemote) {
        try {
          final file = await DefaultCacheManager().getSingleFile(targetPath);
          bytes = await file.readAsBytes();
        } catch (_) {
          try {
            final res = await http.get(Uri.parse(targetPath));
            if (res.statusCode == 200) bytes = res.bodyBytes;
          } catch (_) {}
        }
      } else {
        try {
          final byteData = await rootBundle.load(targetPath);
          bytes = byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        } catch (_) {
          // If local asset is not yet in bundle (e.g. newly added and user only hot-restarted),
          // fallback gracefully to CDN URL
          final fileName = targetPath.split('/').last;
          try {
            final cdnUrl = 'https://media.katsklub.top/frames/$fileName';
            final file = await DefaultCacheManager().getSingleFile(cdnUrl);
            bytes = await file.readAsBytes();
          } catch (_) {
            try {
              final res = await http.get(Uri.parse(
                  'https://media.katsklub.top/frames/$fileName?t=${DateTime.now().millisecondsSinceEpoch}'));
              if (res.statusCode == 200) bytes = res.bodyBytes;
            } catch (_) {}
          }
        }
      }

      if (_loadedPath != targetPath || bytes == null || bytes.isEmpty) return;

      MovieEntity videoItem;
      try {
        videoItem = await SVGAParser.shared.decodeFromBuffer(bytes);
      } catch (decodeErr) {
        // If decoding failed (e.g. stale/corrupted disk cache from earlier version),
        // bust cache and attempt recovery
        debugPrint(
            'SVGA decode error for $targetPath: $decodeErr. Attempting fresh recovery...');
        if (isRemote) {
          try {
            await DefaultCacheManager().removeFile(targetPath);
          } catch (_) {}
          // Try local asset first
          final fileName = targetPath.split('/').last;
          try {
            final byteData = await rootBundle.load('assets/frames/$fileName');
            bytes = byteData.buffer
                .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
            videoItem = await SVGAParser.shared.decodeFromBuffer(bytes);
          } catch (_) {
            // Fresh download with cache buster
            final freshRes = await http.get(Uri.parse(
                '$targetPath?t=${DateTime.now().millisecondsSinceEpoch}'));
            bytes = freshRes.bodyBytes;
            videoItem = await SVGAParser.shared.decodeFromBuffer(bytes);
          }
        } else {
          // Local decode failed, try fresh CDN
          final fileName = targetPath.split('/').last;
          final freshRes = await http.get(Uri.parse(
              'https://media.katsklub.top/frames/$fileName?t=${DateTime.now().millisecondsSinceEpoch}'));
          bytes = freshRes.bodyBytes;
          videoItem = await SVGAParser.shared.decodeFromBuffer(bytes);
        }
      }

      // Explicitly hide stray or unclipped layers from SVGA
      videoItem.dynamicItem.setHidden(true, 'shim');
      videoItem.dynamicItem.setHidden(true, 'glint');
      videoItem.dynamicItem.setHidden(true, 'spark');
      if (mounted && _loadedPath == targetPath) {
        setState(() {
          _controller?.videoItem = videoItem;
          _controller?.repeat();
        });
      }
    } catch (e) {
      debugPrint('Error loading SVGA frame $targetPath: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller?.videoItem == null) {
      return SizedBox(
        width: widget.frameSize,
        height: widget.frameSize,
      );
    }
    return SizedBox(
      width: widget.frameSize,
      height: widget.frameSize,
      child: SVGAImage(
        _controller!,
        fit: BoxFit.contain,
      ),
    );
  }
}
