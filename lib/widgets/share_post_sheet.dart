import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../screens/create_story_screen.dart';
import '../screens/messages_screen.dart';

import 'smooth_bottom_sheet.dart';

class SharePostSheet {
  static Future<void> show(
    BuildContext context, {
    required Post post,
    User? currentUser,
  }) async {
    await SmoothBottomSheetRoute.show<void>(
      context,
      builder: (sheetContext) => _SharePostSheetBody(
        hostContext: context,
        post: post,
        currentUser: currentUser,
      ),
    );
  }
}

class _SharePostSheetBody extends StatelessWidget {
  const _SharePostSheetBody({
    required this.hostContext,
    required this.post,
    required this.currentUser,
  });

  final BuildContext hostContext;
  final Post post;
  final User? currentUser;

  String get _postLink {
    final baseUrl = ApiConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$baseUrl/post/${post.id}';
  }

  String get _shareText {
    final title = post.displayTitle.trim();
    final text = post.text.trim();
    final parts = <String>[];
    if (title.isNotEmpty) {
      parts.add(title);
    }
    if (text.isNotEmpty) {
      parts.add(text);
    }
    parts.add(_postLink);
    return parts.join('\n\n');
  }

  Future<void> _systemShare(BuildContext context) async {
    Navigator.of(context).pop();
    await Share.share(
      _shareText,
      subject: post.displayTitle.trim().isNotEmpty ? post.displayTitle.trim() : 'KatsKlub post',
    );
  }

  void _copyLink(BuildContext context) {
    Navigator.of(context).pop();
    Clipboard.setData(ClipboardData(text: _postLink));
    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  void _sendInMessage(BuildContext context) {
    Navigator.of(context).pop();
    Clipboard.setData(ClipboardData(text: _postLink));
    Navigator.of(hostContext).push(
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );
    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Link copied. Open a chat to paste it.')),
    );
  }

  void _addToStory(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(hostContext).showSnackBar(
        const SnackBar(content: Text('Story sharing is unavailable right now.')),
      );
      return;
    }

    Navigator.of(context).pop();
    Clipboard.setData(ClipboardData(text: _postLink));
    Navigator.of(hostContext).push(
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(user: user),
      ),
    );
    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Link copied. Add it to your story.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
    final handleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final cardColor = isDark ? const Color(0xFF2D2E30) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

    final author = post.authorFullName.trim().isNotEmpty
        ? post.authorFullName.trim()
        : '@${post.authorUsername.trim()}';
    final subtitle = post.displayTitle.trim().isNotEmpty
        ? post.displayTitle.trim()
        : (post.text.trim().isNotEmpty ? post.text.trim() : 'Share this post');

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: ColoredBox(
                  color: cardColor,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Share post',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 11.sp,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _ShareActionButton(
                                icon: Icons.share_outlined,
                                label: 'Share',
                                onTap: () => _systemShare(context),
                              ),
                              SizedBox(width: 14.w),
                              _ShareActionButton(
                                icon: Icons.content_copy_rounded,
                                label: 'Copy link',
                                onTap: () => _copyLink(context),
                              ),
                              SizedBox(width: 14.w),
                              _ShareActionButton(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Message',
                                onTap: () => _sendInMessage(context),
                              ),
                              SizedBox(width: 14.w),
                              _ShareActionButton(
                                icon: Icons.auto_stories_outlined,
                                label: 'Story',
                                onTap: () => _addToStory(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF3F4F6);
    final iconColor = isDark ? Colors.white : const Color(0xFF111827);
    final textColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: buttonBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22.r,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
