import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/api_config.dart';

class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    required this.label,
    required this.initials,
    this.avatarUrl = '',
    this.isOwnStory = false,
    this.showPlus = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String initials;
  final String avatarUrl;
  final bool isOwnStory;
  final bool showPlus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isOwnStory
                          ? const [Color(0xFF2563EB), Color(0xFF06B6D4)]
                          : const [Color(0xFFF97316), Color(0xFFEC4899)],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: avatarUrl.trim().isEmpty
                            ? ColoredBox(
                                color: const Color(0xFFE5E7EB),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: ApiConfig.assetUrl(avatarUrl),
                                fit: BoxFit.cover,
                                memCacheWidth: 200,
                                maxWidthDiskCache: 200,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholderFadeInDuration: Duration.zero,
                                placeholder: (context, url) => const ColoredBox(
                                  color: Color(0xFFE5E7EB),
                                ),
                                errorWidget: (context, url, error) =>
                                    const ColoredBox(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (showPlus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
