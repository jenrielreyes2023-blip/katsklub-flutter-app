import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import 'avatar_with_border.dart';

class UserAvatarWithFrame extends StatelessWidget {
  const UserAvatarWithFrame({
    super.key,
    required this.avatarUrl,
    required this.initials,
    this.frameAsset = 'assets/frames/aframe.png',
    this.borderType = AvatarBorderType.none,
    this.size = 56.0,
    this.frameScale = 1.25,
    this.showFrame = true,
    this.onTap,
  });

  final String avatarUrl;
  final String initials;
  final String? frameAsset;
  final AvatarBorderType borderType;
  final double size;
  final double frameScale;
  final bool showFrame;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cleanAvatarUrl = avatarUrl.trim();
    final hasFrame = showFrame && frameAsset != null && frameAsset!.trim().isNotEmpty;

    final avatarWidget = ClipOval(
      child: cleanAvatarUrl.isEmpty
          ? Container(
              width: size,
              height: size,
              color: const Color(0xFFE5E7EB),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                  fontSize: size * 0.38,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: ApiConfig.assetUrl(cleanAvatarUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              maxWidthDiskCache: 300,
              placeholder: (context, url) => Container(
                width: size,
                height: size,
                color: const Color(0xFFF3F4F6),
              ),
              errorWidget: (context, url, error) => Container(
                width: size,
                height: size,
                color: const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    fontSize: size * 0.38,
                  ),
                ),
              ),
            ),
    );

    // If borderType is specified (e.g. unicorn, rabbit, crown, etc.), delegate to AvatarWithBorder
    if (borderType != AvatarBorderType.none) {
      return AvatarWithBorder(
        avatarUrl: avatarUrl,
        initials: initials,
        borderType: borderType,
        size: size,
        onTap: onTap,
      );
    }

    final frameSize = size * frameScale;

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: SizedBox(
          width: hasFrame ? frameSize : size,
          height: hasFrame ? frameSize : size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Base User Avatar
              avatarWidget,

              // Overlay Animated/PNG Frame
              if (hasFrame)
                Positioned.fill(
                  child: Image.asset(
                    frameAsset!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
