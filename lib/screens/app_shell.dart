import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../services/normal_video_overlay_controller.dart';
import '../services/normal_video_playback_session.dart';
import '../services/normal_video_inline_controls.dart';
import '../widgets/global_audio_mini_player.dart';
import '../widgets/normal_video_overlay.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import '../services/push_notification_service.dart';
import '../services/webrtc_call_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.user,
    required this.onLogout,
    super.key,
  });

  final User user;
  final Future<void> Function() onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  LocalHistoryEntry? _normalVideoOverlayHistoryEntry;

  late User _currentUser;
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;
  int _previousIndex = 0;
  int _feedRefreshToken = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationClickSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    normalVideoOverlayController.addListener(_syncNormalVideoOverlayHistory);
    FeedService.ensureRealtimeSync();

    PushNotificationService().initialize();
    _notificationClickSubscription =
        PushNotificationService().clickStream.listen(_handleNotificationClick);
    WebRTCCallService().initSocketListeners();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      setState(() {
        _currentUser = widget.user;
        _feedRefreshToken++;
      });
      FeedService.clearUserFeedCache();
    }
  }

  @override
  void dispose() {
    normalVideoOverlayController.removeListener(_syncNormalVideoOverlayHistory);
    _normalVideoOverlayHistoryEntry?.remove();
    _normalVideoOverlayHistoryEntry = null;
    _notificationClickSubscription?.cancel();
    super.dispose();
  }

  void _handleNotificationClick(Map<String, dynamic> data) async {
    debugPrint('[DM-DBG] notif tap data=$data');
    unawaited(FeedService.ensureRealtimeSync());
    final type = data['type']?.toString();
    if (type == null) {
      _openNotifications();
      return;
    }

    switch (type) {
      case 'message':
        final threadIdStr = data['threadId']?.toString();
        if (threadIdStr != null) {
          final threadId = int.tryParse(threadIdStr);
          if (threadId != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessagesScreen(
                  initialThreadId: threadId,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            );
            return;
          }
        }
        _selectTab(3);
        break;

      case 'post_like':
      case 'post_comment':
      case 'comment_reply':
      case 'mention':
        final postId = data['postId']?.toString() ??
            data['targetPostId']?.toString() ??
            data['entityId']?.toString();
        if (postId != null && postId.isNotEmpty) {
          final commentIdRaw = data['commentId']?.toString() ??
              data['targetCommentId']?.toString();
          final targetCommentId =
              commentIdRaw == null ? null : int.tryParse(commentIdRaw);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                postId: postId,
                currentUser: _currentUser,
                onOpenCurrentUserProfile: _openProfileTab,
                onOpenUserProfile: _openUserProfile,
                targetCommentId: targetCommentId,
              ),
            ),
          );
          return;
        }
        _openNotifications();
        break;

      case 'follow':
        final username = data['username']?.toString();
        if (username != null && username.isNotEmpty) {
          _openUserProfile(username);
          return;
        }
        _openNotifications();
        break;

      default:
        _openNotifications();
        break;
    }
  }

  void _syncNormalVideoOverlayHistory() {
    final route = ModalRoute.of(context);
    final isCurrentRoute = route?.isCurrent ?? true;

    if (!isCurrentRoute) {
      final entry = _normalVideoOverlayHistoryEntry;
      _normalVideoOverlayHistoryEntry = null;
      entry?.remove();
      return;
    }

    if (normalVideoOverlayController.isOpen &&
        _normalVideoOverlayHistoryEntry == null) {
      _normalVideoOverlayHistoryEntry = LocalHistoryEntry(
        onRemove: () {
          final video = normalVideoOverlayController.video;
          _normalVideoOverlayHistoryEntry = null;

          normalVideoPlaybackSession.setViewerOpen(false);

          if (video != null) {
            resumeNormalVideoInline(video.id);
            normalVideoPlaybackSession.play(muted: normalVideoMuted());
          }

          if (normalVideoOverlayController.isOpen) {
            normalVideoOverlayController.close();
          }
        },
      );

      ModalRoute.of(context)?.addLocalHistoryEntry(
        _normalVideoOverlayHistoryEntry!,
      );
      return;
    }

    if (!normalVideoOverlayController.isOpen &&
        _normalVideoOverlayHistoryEntry != null) {
      final entry = _normalVideoOverlayHistoryEntry;
      _normalVideoOverlayHistoryEntry = null;
      entry?.remove();
    }
  }

  void _selectTab(int index) {
    if (index == 2) {
      _showCreateMenu();
      return;
    }

    if (index == _selectedIndex) {
      return;
    }

    _pauseNormalVideoForTabChange();
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  void _showCreateMenu() {
    final shellContext = context;

    showModalBottomSheet(
      context: shellContext,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.paddingOf(sheetContext).bottom;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(sheetContext).colorScheme.surface : const Color(0xFFF3F4F6),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(14, 10, 14, 18 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3E4042) : const Color(0xFF9CA3AF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242526) : Colors.white,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CreateMenuItem(
                        title: 'Create post',
                        icon: Icons.edit_outlined,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _navigateToCreatePost();
                        },
                      ),
                      const _CreateMenuDivider(),
                      _CreateMenuItem(
                        title: 'Create story',
                        icon: Icons.auto_stories_outlined,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _navigateToCreateStory();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToCreatePost() {
    _pauseNormalVideoForTabChange();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          user: _currentUser,
          onPostCreated: () {
            _pauseNormalVideoForTabChange();
            setState(() {
              _selectedIndex = 0;
              _feedRefreshToken++;
            });
          },
        ),
      ),
    );
  }

  Future<void> _navigateToCreateStory() async {
    _pauseNormalVideoForTabChange();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(user: _currentUser),
      ),
    );
    if (created == true) {
      setState(() {
        _feedRefreshToken++;
      });
    }
  }

  void _closeMessagesTab() {
    _selectTab(_previousIndex == 3 ? 0 : _previousIndex);
  }

  void _openProfileTab() {
    _selectTab(4);
  }

  void _openUserProfile(String username) {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      return;
    }

    final currentUsername = _currentUser.username?.trim().toLowerCase() ?? '';
    if (currentUsername.isNotEmpty &&
        cleanUsername.toLowerCase() == currentUsername) {
      _openProfileTab();
      return;
    }

    _pauseNormalVideoForTabChange();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: cleanUsername,
          onOpenCurrentUserProfile: _openProfileTab,
          onOpenUserProfile: _openUserProfile,
          onOpenNotifications: _openNotifications,
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _pauseNormalVideoForTabChange() {
    pauseAllNormalVideoInline();
    normalVideoPlaybackSession.setViewerOpen(false);
    normalVideoPlaybackSession.pause();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        key: const PageStorageKey<String>('home-tab'),
        user: _currentUser,
        refreshToken: _feedRefreshToken,
        onLogout: widget.onLogout,
        onOpenCurrentUserProfile: _openProfileTab,
        onOpenUserProfile: _openUserProfile,
      ),
      FeedScreen(
        key: const PageStorageKey<String>('feed-tab'),
        user: _currentUser,
        refreshToken: _feedRefreshToken,
        onOpenCurrentUserProfile: _openProfileTab,
        onOpenUserProfile: _openUserProfile,
      ),
      CreatePostScreen(
        user: _currentUser,
        onPostCreated: () {
          _pauseNormalVideoForTabChange();
          setState(() {
            _selectedIndex = 0;
            _feedRefreshToken++;
          });
        },
      ),
      MessagesScreen(onBack: _closeMessagesTab),
      ProfileScreen(
        user: _currentUser,
        refreshToken: _feedRefreshToken,
        onLogout: widget.onLogout,
        onOpenCurrentUserProfile: _openProfileTab,
        onOpenUserProfile: _openUserProfile,
        onOpenNotifications: _openNotifications,
        onUserUpdated: (updatedUser) {
          setState(() {
            _currentUser = updatedUser;
          });
        },
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiStyle = normalVideoOverlayController.isOpen
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle(
            statusBarColor: isDark ? const Color(0xFF18191A) : Colors.white,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isDark ? const Color(0xFF18191A) : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: isDark ? const Color(0xFF18191A) : Colors.white,
          );

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        // Only handle back if AppShell is the current route
        if (!isCurrentRoute) {
          return;
        }

        // 1. Video overlay open - close it
        if (normalVideoOverlayController.isOpen) {
          final video = normalVideoOverlayController.video;
          normalVideoPlaybackSession.setViewerOpen(false);

          if (video != null) {
            resumeNormalVideoInline(video.id);
            normalVideoPlaybackSession.play(muted: normalVideoMuted());
          }

          normalVideoOverlayController.close();
          return;
        }

        // 2. Not on Home tab - switch to Home tab
        if (_selectedIndex != 0) {
          _selectTab(0);
          return;
        }

        // 3. On Home tab - show "press again to exit" or exit
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // 4. Second back within 2 seconds - exit app
        SystemNavigator.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemUiStyle,
        child: Scaffold(
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              SafeArea(
                child: PageStorage(
                  bucket: _pageStorageBucket,
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      for (int i = 0; i < screens.length; i++)
                        HeroMode(
                          enabled: i == _selectedIndex,
                          child: screens[i],
                        ),
                    ],
                  ),
                ),
              ),
              if (isCurrentRoute) const GlobalAudioMiniPlayer(),
              const NormalVideoOverlay(),
            ],
          ),
          bottomNavigationBar:
              (isCurrentRoute && normalVideoOverlayController.isOpen)
                  ? null
                  : BottomNavigationBar(
                      currentIndex: _selectedIndex,
                      onTap: _selectTab,
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      elevation: 0,
                      selectedItemColor: const Color(0xFFFF7A45),
                      unselectedItemColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      showSelectedLabels: false,
                      showUnselectedLabels: false,
                      items: [
                        const BottomNavigationBarItem(
                          icon: _HomeNavIcon(),
                          activeIcon: _HomeNavIcon(isSelected: true),
                          label: 'Home',
                        ),
                        const BottomNavigationBarItem(
                          icon: _FeedNavIcon(),
                          activeIcon: _FeedNavIcon(isSelected: true),
                          label: 'Feed',
                        ),
                        const BottomNavigationBarItem(
                          icon: _PostNavIcon(),
                          activeIcon: _PostNavIcon(isSelected: true),
                          label: 'Post',
                        ),
                        const BottomNavigationBarItem(
                          icon: _MessagesNavIcon(),
                          activeIcon: _MessagesNavIcon(isSelected: true),
                          label: 'Messages',
                        ),
                        BottomNavigationBarItem(
                          icon: _ProfileNavIcon(user: _currentUser),
                          activeIcon: _ProfileNavIcon(
                            user: _currentUser,
                            isSelected: true,
                          ),
                          label: 'Profile',
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _HomeNavIcon extends StatelessWidget {
  const _HomeNavIcon({this.isSelected = false});

  final bool isSelected;

  static const String _svg =
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path d="M10.0693 2.81984L3.13929 8.36983c-.78.62-1.28 1.93007-1.11 2.91007l1.33 7.9599c.24 1.42 1.59999 2.57 3.03999 2.57H17.5993c1.43 0 2.8-1.16 3.04-2.57l1.33-7.9599c.16-.98-.34-2.29007-1.11-2.91007l-6.93-5.53998c-1.07-.86-2.8-.86001-3.86-.01001z" stroke="#292d32" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M12 15.5c1.3807 0 2.5-1.1193 2.5-2.5s-1.1193-2.5-2.5-2.5S9.5 11.6193 9.5 13s1.1193 2.5 2.5 2.5z" stroke="#292d32" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round"/></svg>''';

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);

    return SvgPicture.string(
      _svg,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? const Color(0xFF6B7280),
        BlendMode.srcIn,
      ),
    );
  }
}

class _FeedNavIcon extends StatelessWidget {
  const _FeedNavIcon({this.isSelected = false});

  final bool isSelected;

  static const String _svg =
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path d="M11.5 21c5.2467 0 9.5-4.2533 9.5-9.5C21 6.25329 16.7467 2 11.5 2 6.25329 2 2 6.25329 2 11.5 2 16.7467 6.25329 21 11.5 21z" stroke="#292d32" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M22 22l-2-2" stroke="#292d32" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round"/></svg>''';

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);

    return SvgPicture.string(
      _svg,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? const Color(0xFF6B7280),
        BlendMode.srcIn,
      ),
    );
  }
}

class _MessagesNavIcon extends StatelessWidget {
  const _MessagesNavIcon({this.isSelected = false});

  final bool isSelected;

  static const String _svg =
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path opacity=".4" d="M18.4698 16.83L18.8598 19.99C18.9598 20.82 18.0698 21.4 17.3598 20.97l-4.19-2.49C12.7098 18.48 12.2599 18.45 11.8199 18.39 12.5599 17.52 12.9998 16.42 12.9998 15.23c0-2.84-2.46-5.14-5.49995-5.14-1.16 0-2.23.33-3.12.91C4.34985 10.75 4.33984 10.5 4.33984 10.24 4.33984 5.68999 8.28985 2 13.1698 2c4.88 0 8.83 3.68999 8.83 8.24 0 2.7-1.39 5.09-3.53 6.59z" stroke="#292d32" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/><path d="M13 15.2298c0 1.19-.44 2.29-1.18 3.16-.99 1.2-2.56 1.97-4.32 1.97l-2.61 1.55C4.45 22.1798 3.89 21.8098 3.95 21.2998l.25-1.97c-1.34-.93-2.2-2.42-2.2-4.1 0-1.76.94-3.31 2.38-4.23.89-.58 1.96-.91 3.12-.91 3.04 0 5.5 2.3 5.5 5.14z" stroke="#292d32" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>''';

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);

    final icon = SvgPicture.string(
      _svg,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? const Color(0xFF6B7280),
        BlendMode.srcIn,
      ),
    );

    return ValueListenableBuilder<int>(
      valueListenable: FeedService.unreadMessagesNotifier,
      builder: (context, count, _) {
        if (count <= 0) return icon;
        final label = count > 99 ? '+99' : count.toString();
        return SizedBox(
          width: 34,
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(alignment: Alignment.bottomLeft, child: icon),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostNavIcon extends StatelessWidget {
  const _PostNavIcon({this.isSelected = false});

  final bool isSelected;

  static const String _svg =
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><g opacity=".4" stroke="#292d32" stroke-width="2.35" stroke-linejoin="round" stroke-linecap="round"><path d="M8 12h8"/><path d="M12 16V8"/></g><path d="M9 22h6c5 0 7-2 7-7V9c0-5-2-7-7-7H9C4 2 2 4 2 9v6c0 5 2 7 7 7z" stroke="#292d32" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round"/></svg>''';

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);

    return SvgPicture.string(
      _svg,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? const Color(0xFF6B7280),
        BlendMode.srcIn,
      ),
    );
  }
}

class _CreateMenuItem extends StatelessWidget {
  const _CreateMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBg = isDark ? const Color(0xFF242526) : Colors.white;
    final itemFg = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827);
    final activeIconColor = isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827);

    return Material(
      color: itemBg,
      child: InkWell(
        onTap: onTap,
        splashColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
        highlightColor: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: itemFg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  icon,
                  color: activeIconColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateMenuDivider extends StatelessWidget {
  const _CreateMenuDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? const Color(0xFF3E4042) : const Color(0xFFE5E7EB),
      ),
    );
  }
}

class _ProfileNavIcon extends StatelessWidget {
  const _ProfileNavIcon({
    required this.user,
    this.isSelected = false,
  });

  final User user;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim() ?? '';
    final borderColor = isSelected ? Colors.black : const Color(0xFFD1D5DB);

    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
      ),
      child: ClipOval(
        child: avatarUrl.isEmpty
            ? ColoredBox(
                color: const Color(0xFFE5E7EB),
                child: Center(
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: ApiConfig.assetUrl(avatarUrl),
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                placeholder: (context, url) => const ColoredBox(
                  color: Color(0xFFE5E7EB),
                ),
                errorWidget: (context, url, error) => ColoredBox(
                  color: const Color(0xFFE5E7EB),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
