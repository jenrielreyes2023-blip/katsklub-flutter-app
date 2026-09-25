import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'user_avatar_with_frame.dart';

class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    required this.label,
    required this.initials,
    this.avatarUrl = '',
    this.avatarFrame,
    this.isAdmin = false,
    this.isOwnStory = false,
    this.showPlus = false,
    this.onTap,
    this.onPlusTap,
    super.key,
  });

  final String label;
  final String initials;
  final String avatarUrl;
  final String? avatarFrame;
  final bool isAdmin;
  final bool isOwnStory;
  final bool showPlus;
  final VoidCallback? onTap;
  final VoidCallback? onPlusTap;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: isOwnStory
          ? const [Color(0xFF2563EB), Color(0xFF06B6D4)]
          : const [Color(0xFFF97316), Color(0xFFEC4899)],
    );

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 62.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatarWithFrame(
                  avatarUrl: avatarUrl,
                  initials: initials,
                  radius: 26.w,
                  avatarFrame: avatarFrame,
                  isAdmin: isOwnStory && isAdmin,
                  storyRingGradient: gradient,
                ),
                if (showPlus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onPlusTap ?? onTap,
                      child: Container(
                        width: 17.w,
                        height: 17.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2.w),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 12.r,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 10.5.sp,
                height: 1.1,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
