import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    this.isAdmin = false,
    this.initials = '',
    this.onTap,
  });

  final String avatarUrl;
  final double radius;
  final String? framePath;
  final bool isAdmin;
  final String initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl.trim();
    final size = radius * 2;

    final avatarChild = cleanUrl.isEmpty
        ? CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
                fontSize: radius * 0.7,
              ),
            ),
          )
        : CachedNetworkImage(
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
                  fontSize: radius * 0.7,
                ),
              ),
            ),
          );

    return ValueListenableBuilder<String>(
      valueListenable: equippedAdminFrameNotifier,
      builder: (context, globalEquippedFrame, _) {
        final String? effectiveFrame = framePath ?? (isAdmin ? globalEquippedFrame : null);
        final cleanFrame = (effectiveFrame == 'none' || effectiveFrame == null) ? null : effectiveFrame.trim();
        final pathLower = (cleanFrame ?? '').toLowerCase();
        final hasFrame = cleanFrame != null && cleanFrame.isNotEmpty;

        final isLottie = pathLower.endsWith('.json');
        final isSvga = pathLower.endsWith('.svga');
        final isWingFrame = pathLower.contains('wing_frame');
        final isTestFrame = pathLower.contains('test_frame');
        final isSpringFrame = pathLower.contains('spring_blossom_frame');

        final double frameSize;
        if (isWingFrame) {
          frameSize = size * 1.85;
        } else if (isTestFrame) {
          frameSize = size * 1.48;
        } else if (isSpringFrame) {
          frameSize = size * 1.35;
        } else {
          frameSize = size * 1.25;
        }

        final widgetStack = SizedBox(
          width: hasFrame ? frameSize : size,
          height: hasFrame ? frameSize : size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Layer 1 (Bottom): The CircleAvatar displaying the user photo
              avatarChild,

              // Layer 2 (Top): The frame image, Lottie, or SVGA overlay wrapped in IgnorePointer and RepaintBoundary
              if (hasFrame)
                IgnorePointer(
                  child: RepaintBoundary(
                    child: isLottie
                        ? _LottieFrameOverlay(
                            framePath: cleanFrame,
                            frameSize: frameSize,
                          )
                        : isSvga
                            ? _SvgaFrameOverlay(
                                framePath: cleanFrame,
                                frameSize: frameSize,
                              )
                            : Image.asset(
                                cleanFrame,
                                width: frameSize,
                                height: frameSize,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
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

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.framePath,
      width: widget.frameSize,
      height: widget.frameSize,
      fit: BoxFit.contain,
      controller: _controller,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        final pathLower = widget.framePath.toLowerCase();
        if (pathLower.contains('wing_frame')) {
          // Wing frame skips initial circle morph state and continuously loops expanded wings segment
          _controller.repeat(min: 0.35, max: 1.0);
        } else {
          // Full uncut animation loop for standard Lottie frames
          _controller.repeat();
        }
      },
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

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadSvga();
  }

  Future<void> _loadSvga() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromAssets(widget.framePath);
      if (mounted) {
        setState(() {
          _controller?.videoItem = videoItem;
          _controller?.repeat();
        });
      }
    } catch (e) {
      debugPrint('Error loading SVGA frame ${widget.framePath}: $e');
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
