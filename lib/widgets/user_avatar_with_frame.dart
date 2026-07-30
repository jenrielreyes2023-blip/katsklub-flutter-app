import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';

class UserAvatarWithFrame extends StatelessWidget {
  const UserAvatarWithFrame({
    super.key,
    required this.avatarUrl,
    this.radius = 40.0,
    this.framePath = 'assets/frames/bframe.png',
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
    final frameSize = size * 1.25;

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

          // Layer 2 (Top): The frame image overlay wrapped in IgnorePointer and RepaintBoundary
          if (framePath != null && framePath!.trim().isNotEmpty)
            IgnorePointer(
              child: RepaintBoundary(
                child: Image.asset(
                  framePath!,
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
