import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import '../config/api_config.dart';

class UserAvatarWithFrame extends StatelessWidget {
  const UserAvatarWithFrame({
    super.key,
    required this.avatarUrl,
    this.radius = 40.0,
    this.framePath,
    this.initials = '',
    this.onTap,
  });

  final String avatarUrl;
  final double radius;
  final String? framePath;
  final String initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl.trim();
    final size = radius * 2;
    final isLottie = framePath != null && framePath!.trim().toLowerCase().endsWith('.json');
    final frameSize = isLottie ? size * 1.85 : size * 1.25;

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

    final widgetStack = SizedBox(
      width: framePath != null ? frameSize : size,
      height: framePath != null ? frameSize : size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Layer 1 (Bottom): The CircleAvatar displaying the user photo
          avatarChild,

          // Layer 2 (Top): The frame image or Lottie overlay wrapped in IgnorePointer and RepaintBoundary
          if (framePath != null && framePath!.trim().isNotEmpty)
            IgnorePointer(
              child: RepaintBoundary(
                child: isLottie
                    ? _LottieFrameOverlay(
                        framePath: framePath!.trim(),
                        frameSize: frameSize,
                      )
                    : Image.asset(
                        framePath!.trim(),
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
        // Skips the initial circle morph state and continuously loops ONLY on the fully expanded wings segment
        _controller.repeat(min: 0.35, max: 1.0);
      },
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
