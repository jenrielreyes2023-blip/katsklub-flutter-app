import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/post.dart';
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
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5.sp,
                                  letterSpacing: -0.2,
                                  height: 1.33,
                                  color: isDarkTheme
                                      ? const Color(0xFFE4E6EB)
                                      : const Color(0xFF050505)),
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
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
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
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Future<void> Function() onTap;
  final bool isDestructive;
}

class PostOptionsSheet extends StatelessWidget {
  const PostOptionsSheet({
    required this.actions,
    super.key,
  });

  final List<PostActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF2D2E30) : Colors.white;

    return SmoothSheetContainer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: cardBgColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                PostOptionsRow(action: actions[index]),
                if (index != actions.length - 1)
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF3E4042)
                        : const Color(0xFFE5E7EB),
                  ),
              ],
            ],
          ),
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
    final color = action.isDestructive
        ? const Color(0xFFDC2626)
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        await action.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(action.icon, color: color, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.33,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (action.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle!,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B3B8)
                            : const Color(0xFF65676B),
                        fontSize: 13.sp,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
