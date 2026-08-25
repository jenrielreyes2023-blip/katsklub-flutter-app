import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import 'profile_screen.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/normal_video_overlay_host.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.username,
    this.seedFullName,
    this.seedAvatarUrl,
    this.seedIsVerified = false,
    this.seedIsAdmin = false,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    this.onOpenNotifications,
    this.onBack,
    super.key,
  });

  final String username;
  final String? seedFullName;
  final String? seedAvatarUrl;
  final bool seedIsVerified;
  final bool seedIsAdmin;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onBack;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<User?> _profileFuture;
  String? _currentUsername;
  late User _seedUser;

  @override
  void initState() {
    super.initState();
    _seedUser = User(
      username: widget.username,
      fullName: widget.seedFullName,
      avatarUrl: widget.seedAvatarUrl,
      isVerified: widget.seedIsVerified,
      isAdmin: widget.seedIsAdmin,
      raw: const {},
    );
    _profileFuture = FeedService().loadUserProfile(widget.username);
    _loadCurrentUsername();
  }

  @override
  void didUpdateWidget(UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _profileFuture = FeedService().loadUserProfile(widget.username);
    }
  }

  Future<void> _loadCurrentUsername() async {
    final currentUser = await AuthService().getSavedUser();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUsername = currentUser?.username?.trim().toLowerCase();
    });
  }

  bool _isOtherUser(User user) {
    final profileUsername = user.username?.trim().toLowerCase() ?? '';
    final currentUsername = _currentUsername?.trim().toLowerCase() ?? '';
    if (profileUsername.isEmpty) {
      return false;
    }

    if (currentUsername.isEmpty) {
      return true;
    }

    return profileUsername != currentUsername;
  }

  void _openProfileOptions(User user) {
    final username = user.username?.trim();
    if (username == null || username.isEmpty) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ProfileOptionsSheet(
          username: username,
          isMuted: user.isMuted,
          onMention: () {
            Navigator.of(sheetContext).pop();
            _copyMention(username);
          },
          onCopyLink: () {
            Navigator.of(sheetContext).pop();
            _copyProfileLink(username);
          },
          onReport: () {
            Navigator.of(sheetContext).pop();
            _showReportUserDialog(user);
          },
          onBlock: () {
            Navigator.of(sheetContext).pop();
            _confirmAndBlockUser(user);
          },
          onMute: () {
            Navigator.of(sheetContext).pop();
            _confirmAndMuteUser(user);
          },
          onAbout: () {
            Navigator.of(sheetContext).pop();
            showProfileAboutSheet(
              context,
              user: user,
              showPrivateFields: false,
            );
          },
        );
      },
    );
  }

  Future<void> _copyMention(String username) async {
    await Clipboard.setData(ClipboardData(text: '@$username'));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mention copied.')),
    );
  }

  Future<void> _copyProfileLink(String username) async {
    final profileLink = '${ApiConfig.apiBaseUrl}/u/$username';
    await Clipboard.setData(ClipboardData(text: profileLink));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile link copied.')),
    );
  }



  Future<void> _confirmAndBlockUser(User user) async {
    final username = user.username?.trim();
    if (username == null || username.isEmpty) {
      return;
    }

    final displayName = (user.fullName?.trim().isNotEmpty ?? false)
        ? user.fullName!.trim()
        : '@$username';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Block $displayName?'),
          content: Text(
            'They will no longer be able to see your profile or posts, and you will stop seeing theirs. You will also unfollow each other.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final ok = await FeedService().blockUser(username);
    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not block this user. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Blocked $displayName.')),
    );

    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmAndMuteUser(User user) async {
    final username = user.username ?? '';
    final displayName = user.displayName;
    if (username.isEmpty) return;

    final isMuted = user.isMuted;
    final titleText = isMuted ? 'Unmute $displayName?' : 'Mute $displayName?';
    final contentText = isMuted
        ? 'You will start seeing their posts in your feed again.'
        : 'KatsKlub won\'t let them know you muted them. You will stop seeing their posts in your feed.';
    final actionText = isMuted ? 'Unmute' : 'Mute';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titleText),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(actionText),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final ok = isMuted
        ? await FeedService().unmuteUser(username)
        : await FeedService().muteUser(username);
    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not $actionText this user. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${isMuted ? "Unmuted" : "Muted"} $displayName.')),
    );

    setState(() {
      _profileFuture = FeedService().loadUserProfile(username);
    });
  }

  Future<void> _showReportUserDialog(User user) async {
    final username = user.username ?? '';
    final displayName = user.displayName;
    if (username.isEmpty) return;

    final reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Nudity or sexual content',
      'Violence or dangerous content',
      'Something else',
    ];

    String? selectedReason = reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Report $displayName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedReason == null || !mounted) {
      return;
    }

    final ok = await FeedService().reportUser(username, selectedReason!);
    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit report. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Thank you for reporting $displayName. We will review it shortly.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NormalVideoOverlayHost(
      child: FutureBuilder<User?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final loadedUser = snapshot.data;
          final isDone = snapshot.connectionState == ConnectionState.done;

          if (isDone && loadedUser == null) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : Colors.black;
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: textColor,
                  onPressed: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Profile Unavailable',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load profile. Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _profileFuture = FeedService().loadUserProfile(widget.username);
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (loadedUser == null) {
            return ProfileSkeleton(
              hasBackButton: widget.onBack != null || Navigator.of(context).canPop(),
              hasActions: _isOtherUser(_seedUser),
            );
          }

          final user = loadedUser;

          return ProfileScreen(
            user: user,
            refreshToken: 1,
            onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
            onOpenUserProfile: widget.onOpenUserProfile,
            onOpenNotifications: widget.onOpenNotifications,
            onBack: widget.onBack,
            extraHeaderAction: _isOtherUser(user)
                ? _UserProfileMoreButton(
                    onPressed: () => _openProfileOptions(user),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _UserProfileMoreButton extends StatelessWidget {
  const _UserProfileMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(
        Icons.more_horiz,
        color: Color(0xFFFF7A45),
        size: 24,
      ),
      splashRadius: 22,
    );
  }
}

class _ProfileOptionsSheet extends StatelessWidget {
  const _ProfileOptionsSheet({
    required this.username,
    required this.onMention,
    required this.onCopyLink,
    required this.onReport,
    required this.onBlock,
    required this.onMute,
    required this.onAbout,
    required this.isMuted,
  });

  final String username;
  final VoidCallback onMention;
  final VoidCallback onCopyLink;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onMute;
  final VoidCallback onAbout;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827);
    const destructiveColor = Color(0xFFDC2626);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF3F4F6),
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
                color: isDark ? const Color(0xFF3E4042) : const Color(0xFF9CA3AF),
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            SizedBox(height: 10.h),
            _ProfileOptionGroup(
              children: [
                _ProfileOptionRow(
                  label: 'Mention @$username',
                  icon: Icons.alternate_email,
                  iconColor: normalColor,
                  textColor: normalColor,
                  onTap: onMention,
                ),
                const _ProfileOptionDivider(),
                _ProfileOptionRow(
                  label: 'Copy profile link',
                  icon: Icons.link,
                  iconColor: normalColor,
                  textColor: normalColor,
                  onTap: onCopyLink,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            _ProfileOptionGroup(
              children: [
                _ProfileOptionRow(
                  label: 'Report @$username',
                  icon: Icons.report_outlined,
                  iconColor: destructiveColor,
                  textColor: destructiveColor,
                  onTap: onReport,
                ),
                const _ProfileOptionDivider(),
                _ProfileOptionRow(
                  label: 'Block @$username',
                  icon: Icons.block,
                  iconColor: destructiveColor,
                  textColor: destructiveColor,
                  onTap: onBlock,
                ),
                const _ProfileOptionDivider(),
                _ProfileOptionRow(
                  label: isMuted ? 'Unmute @$username' : 'Mute @$username',
                  icon: isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                  iconColor: destructiveColor,
                  textColor: destructiveColor,
                  onTap: onMute,
                ),
                const _ProfileOptionDivider(),
                _ProfileOptionRow(
                  label: 'About account',
                  icon: Icons.info_outline,
                  iconColor: normalColor,
                  textColor: normalColor,
                  onTap: onAbout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOptionGroup extends StatelessWidget {
  const _ProfileOptionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: ColoredBox(
        color: isDark ? const Color(0xFF242526) : Colors.white,
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileOptionRow extends StatelessWidget {
  const _ProfileOptionRow({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF242526) : Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
        highlightColor: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
        child: Container(
          constraints: BoxConstraints(minHeight: 46.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20.r, color: iconColor),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.1,
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

class _ProfileOptionDivider extends StatelessWidget {
  const _ProfileOptionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.w),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3E4042)
            : const Color(0xFFE5E7EB),
      ),
    );
  }
}
