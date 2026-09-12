import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/post.dart';
import '../theme/app_text_styles.dart';
import '../screens/user_profile_screen.dart';
import 'custom_icons.dart';
import 'post_with_users_line.dart';
import 'smooth_bottom_sheet.dart';
import 'special_name_text.dart';
import 'user_avatar_with_frame.dart';

class PostHeader extends StatelessWidget {
  const PostHeader({
    required this.post,
    required this.onOpenAuthor,
    required this.onMore,
    this.showFollowButton = false,
    this.isFollowPending = false,
    this.onFollow,
    this.onHide,
    this.isHiding = false,
    super.key,
  });

  final Post post;
  final VoidCallback onOpenAuthor;
  final VoidCallback onMore;
  final bool showFollowButton;
  final bool isFollowPending;
  final VoidCallback? onFollow;
  final VoidCallback? onHide;
  final bool isHiding;

  @override
  Widget build(BuildContext context) {
    final themeKey = (post.authorPostcardTheme ?? '').trim().toLowerCase();

    // Determine if the applied theme is a dark background theme.
    final isDarkTheme = themeKey == 'ocean' ||
        (Theme.of(context).brightness == Brightness.dark && themeKey.isEmpty);

    // Text and icon colors
    final nameColor = isDarkTheme ? Colors.white : const Color(0xFF1C1E21);
    final metaColor = isDarkTheme
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF65676B);
    final verifiedIconColor = const Color(0xFF1D9BF0);
    final followColor = const Color(0xFFFF7A45);
    final actionIconColor =
        isDarkTheme ? Colors.white : const Color(0xFF374151);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatarWithFrame(
          avatarUrl: post.authorAvatarUrl,
          initials: post.authorInitials,
          radius: 20,
          isAdmin: post.authorIsAdmin,
          onTap: onOpenAuthor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: onOpenAuthor,
                            child: SpecialNameText(
                              username: post.authorUsername,
                              displayName: post.authorFullName,
                              style: KatsText.postAuthor(context,
                                  themeKey: themeKey),
                            ),
                          ),
                        ),
                        if (post.feeling.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            'is feeling',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: metaColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.feeling,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                              color: nameColor,
                            ),
                          ),
                        ],
                        if (post.authorIsVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            color: verifiedIconColor,
                            size: 16,
                          ),
                        ],
                        if (showFollowButton && onFollow != null) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: isFollowPending ? null : onFollow,
                            child: SizedBox(
                              height: 16,
                              child: Center(
                                child: isFollowPending
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: followColor,
                                        ),
                                      )
                                    : Text(
                                        'Follow',
                                        style: TextStyle(
                                          color: followColor,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                          height: 1.0,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (post.withUsers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      PostWithUsersLine(
                        users: post.withUsers,
                        prefix: 'is — with ',
                        prefixHighlight: '— with',
                        prefixHighlightStyle: TextStyle(
                          color: nameColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        linkStyle: TextStyle(
                          color: nameColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        onUserTap: (username) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(username: username),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _formatTimestamp(post.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KatsText.timestamp(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '·',
                            style: KatsText.timestamp(context),
                          ),
                        ),
                        Icon(
                          _privacyIcon(post.visibility),
                          color: metaColor,
                          size: 13,
                        ),

                        if (post.location.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: Colors.red.shade400,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              post.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (post.hasMusicPreview &&
                            post.musicTitle.trim().isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.music_note_rounded,
                            color: metaColor,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              post.musicTitle.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (post.originalPost != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          CustomIcons.repost(size: 12, color: metaColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: SpecialNameText(
                              username: post.originalPost!.authorUsername,
                              displayName: post.originalPost!.authorFullName,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          if (post.originalPost!.authorIsVerified) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.verified,
                              color: verifiedIconColor,
                              size: 13,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onHide != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: isHiding ? null : onHide,
                        iconSize: 18,
                        color: actionIconColor,
                        icon: isHiding
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: actionIconColor,
                                ),
                              )
                            : const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onMore,
                      iconSize: 18,
                      color: actionIconColor,
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Now';
    }

    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthLabel = monthNames[createdAt.month - 1];
    final sameYear = createdAt.year == DateTime.now().year;

    if (sameYear) {
      return '$monthLabel ${createdAt.day}';
    }

    return '$monthLabel ${createdAt.day}, ${createdAt.year}';
  }

  IconData _privacyIcon(String visibility) {
    switch (visibility) {
      case 'friends':
        return Icons.people_alt_rounded;
      case 'only_me':
        return Icons.lock_rounded;
      default:
        return Icons.public_rounded;
    }
  }
}

class PostActionItem {
  const PostActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
    this.badgeText,
    this.badgeColor,
    this.trailing,
    this.isHero = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Future<void> Function() onTap;
  final bool isDestructive;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailing;
  final bool isHero;
}

class PostActionGroup {
  const PostActionGroup({
    required this.actions,
    this.title,
  });

  final List<PostActionItem> actions;
  final String? title;
}

class PostOptionsSheet extends StatelessWidget {
  const PostOptionsSheet({
    this.actions,
    this.groups,
    super.key,
  }) : assert(actions != null || groups != null, 'Provide either actions or groups');

  final List<PostActionItem>? actions;
  final List<PostActionGroup>? groups;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E1E20) : Colors.white;

    final effectiveGroups = groups ?? [PostActionGroup(actions: actions ?? [])];

    return SmoothSheetContainer(
      maxHeightFraction: 0.90,
      backgroundColor: isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7),
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 14.h),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var g = 0; g < effectiveGroups.length; g++) ...[
              if (effectiveGroups[g].title != null &&
                  effectiveGroups[g].title!.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 5.h),
                  child: Text(
                    effectiveGroups[g].title!,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6B7280),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: ColoredBox(
                  color: cardBgColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0;
                          i < effectiveGroups[g].actions.length;
                          i++) ...[
                        PostOptionsRow(action: effectiveGroups[g].actions[i]),
                        if (i != effectiveGroups[g].actions.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 14.w,
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFE5E5EA),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (g != effectiveGroups.length - 1) SizedBox(height: 7.h),
            ],
          ],
        ),
      ),
    );
  }
}

class PostOptionsRow extends StatelessWidget {
  const PostOptionsRow({
    required this.action,
    super.key,
  });

  final PostActionItem action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = action.isDestructive
        ? const Color(0xFFED4956)
        : (isDark ? Colors.white : const Color(0xFF111827));
    final iconColor = action.isDestructive
        ? const Color(0xFFED4956)
        : (isDark ? Colors.white : const Color(0xFF1C1C1E));

    final verticalPadding = action.subtitle != null ? 9.h : 8.5.h;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Navigator.of(context).pop();
          await action.onTap();
        },
        splashColor:
            isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE5E5EA),
        highlightColor:
            isDark ? const Color(0xFF242426) : const Color(0xFFF2F2F7),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: verticalPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            action.label,
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: color,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (action.badgeText != null &&
                            action.badgeText!.isNotEmpty) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: action.badgeColor ??
                                  const Color(0xFF0095F6),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              action.badgeText!,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white,
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (action.subtitle != null &&
                        action.subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        action.subtitle!,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF8E8E93),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              if (action.trailing != null)
                action.trailing!
              else
                Icon(
                  action.icon,
                  color: iconColor,
                  size: 18.5.r,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeletePostSheet extends StatelessWidget {
  const DeletePostSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final innerBg = isDark ? const Color(0xFF2D2E30) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final bodyColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);
    final cancelFg = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF1C1E21);
    final cancelBorder = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);

    return SmoothSheetContainer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: innerBg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Delete post?',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This post will be permanently deleted. This can\'t be undone.',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cancelFg,
                          side: BorderSide(color: cancelBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
