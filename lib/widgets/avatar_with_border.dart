import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';

enum AvatarBorderType {
  none,
  unicorn,
  rabbit,
  crown,
  rainbow,
  witch,
  fox,
  butterfly,
  flowers,
  horns,
  moon,
  heart;

  static AvatarBorderType parse(String? value) {
    if (value == null) return AvatarBorderType.none;
    switch (value.toLowerCase().trim()) {
      case 'unicorn':
        return AvatarBorderType.unicorn;
      case 'rabbit':
        return AvatarBorderType.rabbit;
      case 'crown':
        return AvatarBorderType.crown;
      case 'rainbow':
        return AvatarBorderType.rainbow;
      case 'witch':
        return AvatarBorderType.witch;
      case 'fox':
        return AvatarBorderType.fox;
      case 'butterfly':
        return AvatarBorderType.butterfly;
      case 'flowers':
        return AvatarBorderType.flowers;
      case 'horns':
        return AvatarBorderType.horns;
      case 'moon':
        return AvatarBorderType.moon;
      case 'heart':
        return AvatarBorderType.heart;
      default:
        return AvatarBorderType.none;
    }
  }
}

class AvatarWithBorder extends StatelessWidget {
  final String avatarUrl;
  final String initials;
  final AvatarBorderType borderType;
  final double size;
  final VoidCallback? onTap;

  const AvatarWithBorder({
    required this.avatarUrl,
    required this.initials,
    this.borderType = AvatarBorderType.none,
    this.size = 80,
    this.onTap,
    super.key,
  });

  String get _borderAssetPath {
    switch (borderType) {
      case AvatarBorderType.unicorn:
        return 'assets/images/borders/border_unicorn.png';
      case AvatarBorderType.rabbit:
        return 'assets/images/borders/border_rabbit.png';
      case AvatarBorderType.crown:
        return 'assets/images/borders/border_crown.png';
      case AvatarBorderType.rainbow:
        return 'assets/images/borders/border_rainbow.png';
      case AvatarBorderType.witch:
        return 'assets/images/borders/border_witch.png';
      case AvatarBorderType.fox:
        return 'assets/images/borders/border_fox.png';
      case AvatarBorderType.butterfly:
        return 'assets/images/borders/border_butterfly.png';
      case AvatarBorderType.flowers:
        return 'assets/images/borders/border_flowers.png';
      case AvatarBorderType.horns:
        return 'assets/images/borders/border_horns.png';
      case AvatarBorderType.moon:
        return 'assets/images/borders/border_moon.png';
      case AvatarBorderType.heart:
        return 'assets/images/borders/border_heart.png';
      case AvatarBorderType.none:
        return '';
    }
  }

  double get _avatarScaleMultiplier {
    switch (borderType) {
      case AvatarBorderType.flowers:
        return 0.74; // Floral wreath has a larger inside opening
      case AvatarBorderType.rainbow:
        return 0.72; // Rainbow has slightly larger opening
      case AvatarBorderType.unicorn:
        return 0.65; // Horn and hair stick in slightly, needs smaller avatar
      case AvatarBorderType.heart:
        return 0.48; // Heart border has wings and bottom heart, circle is smaller
      default:
        return 0.68; // Standard multiplier for other borders
    }
  }

  @override
  Widget build(BuildContext context) {
    if (borderType == AvatarBorderType.none) {
      // Return simple circular avatar
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: avatarUrl.trim().isEmpty
              ? CircleAvatar(
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      fontSize: size * 0.4,
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: ApiConfig.assetUrl(avatarUrl),
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    backgroundColor: const Color(0xFFE5E7EB),
                    backgroundImage: imageProvider,
                  ),
                  placeholder: (context, url) => const CircleAvatar(
                    backgroundColor: Color(0xFFF3F4F6),
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    backgroundColor: const Color(0xFFE5E7EB),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        fontSize: size * 0.4,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }

    final double avatarMultiplier = borderType == AvatarBorderType.heart ? 0.68 : _avatarScaleMultiplier;
    final double avatarSize = size * avatarMultiplier;
    final double borderSize = size * (avatarMultiplier / _avatarScaleMultiplier);
    final double borderOffset = (size - borderSize) / 2;

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // The Avatar Image (placed behind the frame border)
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipOval(
                  child: avatarUrl.trim().isEmpty
                      ? Container(
                          color: const Color(0xFFE5E7EB),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                              fontSize: avatarSize * 0.4,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: ApiConfig.assetUrl(avatarUrl),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFF3F4F6),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFE5E7EB),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                                fontSize: avatarSize * 0.4,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              // The Border Overlay with a circular cutout in the middle
              // (to remove painted/dark centers in border PNGs that are not
              // designed with a transparent inner hole).
              Positioned(
                left: borderOffset,
                top: borderOffset,
                width: borderSize,
                height: borderSize,
                child: ShaderMask(
                  blendMode: BlendMode.dstOut,
                  shaderCallback: (Rect bounds) {
                    // Cutout radius matches the avatar's radius so the border
                    // touches the avatar edge cleanly without bleed-through.
                    final double cut = _avatarScaleMultiplier; // 0..1 along gradient radius
                    final double feather = 0.02; // small anti-alias edge
                    return RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: const [
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, cut, (cut + feather).clamp(0.0, 1.0)],
                    ).createShader(bounds);
                  },
                  child: Image.asset(
                    _borderAssetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
