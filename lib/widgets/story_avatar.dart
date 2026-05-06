import 'package:flutter/material.dart';

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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(3),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFE5E7EB),
                    backgroundImage: avatarUrl.trim().isEmpty
                        ? null
                        : NetworkImage(ApiConfig.assetUrl(avatarUrl)),
                    child: avatarUrl.trim().isEmpty
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              if (showPlus)
                Positioned(
                  right: -1,
                  bottom: 1,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        ),
      ),
    );
  }
}
