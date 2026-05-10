import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/normal_video_overlay_controller.dart';
import '../services/normal_video_playback_session.dart';
import '../widgets/post_card.dart';
import '../widgets/normal_video_overlay.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';
import 'notifications_screen.dart';

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

  int _selectedIndex = 0;
  int _previousIndex = 0;
  int _feedRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    normalVideoOverlayController.addListener(_syncNormalVideoOverlayHistory);
  }

  @override
  void dispose() {
    normalVideoOverlayController.removeListener(_syncNormalVideoOverlayHistory);
    _normalVideoOverlayHistoryEntry?.remove();
    _normalVideoOverlayHistoryEntry = null;
    super.dispose();
  }

  void _syncNormalVideoOverlayHistory() {
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
    if (index == _selectedIndex) {
      return;
    }

    _pauseNormalVideoForTabChange();
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
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

    final currentUsername = widget.user.username?.trim().toLowerCase() ?? '';
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
        user: widget.user,
        refreshToken: _feedRefreshToken,
        onLogout: widget.onLogout,
        onOpenCurrentUserProfile: _openProfileTab,
        onOpenUserProfile: _openUserProfile,
      ),
      FeedScreen(
        key: const PageStorageKey<String>('feed-tab'),
        user: widget.user,
        refreshToken: _feedRefreshToken,
        onOpenCurrentUserProfile: _openProfileTab,
        onOpenUserProfile: _openUserProfile,
      ),
      CreatePostScreen(
        user: widget.user,
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
        user: widget.user,
        refreshToken: _feedRefreshToken,
        onLogout: widget.onLogout,
        onOpenCurrentUserProfile: _openProfileTab,
        onOpenUserProfile: _openUserProfile,
        onOpenNotifications: _openNotifications,
      ),
    ];

    final systemUiStyle = normalVideoOverlayController.isOpen
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.white,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: PageStorage(
                bucket: _pageStorageBucket,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: screens,
                ),
              ),
            ),
            const NormalVideoOverlay(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _selectTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Colors.black,
          unselectedItemColor: const Color(0xFF6B7280),
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
              icon: _ProfileNavIcon(user: widget.user),
              activeIcon: _ProfileNavIcon(user: widget.user, isSelected: true),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeNavIcon extends StatelessWidget {
  const _HomeNavIcon({this.isSelected = false});

  final bool isSelected;

  static const String _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 511 512" fill="currentColor"><path d="M498.7 222.695c-.016-.011-.028-.027-.04-.039L289.805 13.81C280.902 4.902 269.066 0 256.477 0c-12.59 0-24.426 4.902-33.332 13.809L14.398 222.55c-.07.07-.144.144-.21.215-18.282 18.386-18.25 48.218.09 66.558 8.378 8.383 19.44 13.235 31.273 13.746.484.047.969.07 1.457.07h8.32v153.696c0 30.418 24.75 55.164 55.168 55.164h81.711c8.285 0 15-6.719 15-15V376.5c0-13.879 11.293-25.168 25.172-25.168h48.195c13.88 0 25.168 11.29 25.168 25.168V497c0 8.281 6.715 15 15 15h81.711c30.422 0 55.168-24.746 55.168-55.164V303.14h7.719c12.586 0 24.422-4.903 33.332-13.813 18.36-18.367 18.367-48.254.027-66.633zm-21.243 45.422a17.03 17.03 0 0 1-12.117 5.024H442.62c-8.285 0-15 6.714-15 15v168.695c0 13.875-11.289 25.164-25.168 25.164h-66.71V376.5c0-30.418-24.747-55.168-55.169-55.168H232.38c-30.422 0-55.172 24.75-55.172 55.168V482h-66.71c-13.876 0-25.169-11.29-25.169-25.164V288.14c0-8.286-6.715-15-15-15H48a13.9 13.9 0 0 0-.703-.032c-4.469-.078-8.66-1.851-11.8-4.996-6.68-6.68-6.68-17.55 0-24.234.003 0 .003-.004.007-.008l.012-.012L244.363 35.02A17.003 17.003 0 0 1 256.477 30c4.574 0 8.875 1.781 12.113 5.02l208.8 208.796.098.094c6.645 6.692 6.633 17.54-.031 24.207zm0 0"/></svg>';

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
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 442 442" fill="currentColor"><path d="M171 336H70c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.523 0 10-4.477 10-10s-4.477-10-10-10zM322 336H221c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.522 0 10-4.477 10-10s-4.478-10-10-10zM322 86H70c-5.523 0-10 4.477-10 10s4.477 10 10 10h252c5.522 0 10-4.477 10-10s-4.478-10-10-10zM322 136H221c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.522 0 10-4.477 10-10s-4.478-10-10-10zM322 186H221c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.522 0 10-4.477 10-10s-4.478-10-10-10zM322 236H221c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.522 0 10-4.477 10-10s-4.478-10-10-10zM322 286H221c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.522 0 10-4.477 10-10s-4.478-10-10-10zM171 286H70c-5.523 0-10 4.477-10 10s4.477 10 10 10h101c5.523 0 10-4.477 10-10s-4.477-10-10-10zM171 136H70c-5.523 0-10 4.477-10 10v101c0 5.523 4.477 10 10 10h101c5.523 0 10-4.477 10-10V146c0-5.523-4.477-10-10-10zm-10 101H80v-81h81v81z"/><path d="M422 76h-30V46c0-11.028-8.972-20-20-20H20C8.972 26 0 34.972 0 46v320c0 27.57 22.43 50 50 50h342c27.57 0 50-22.43 50-50V96c0-11.028-8.972-20-20-20zm0 290c0 16.542-13.458 30-30 30H50c-16.542 0-30-13.458-30-30V46h352v305c0 13.785 11.215 25 25 25 5.522 0 10-4.477 10-10s-4.478-10-10-10c-2.757 0-5-2.243-5-5V96h30v270z"/></svg>';

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
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="currentColor"><path d="M304,96H112c-8.832,0-16,7.168-16,16c0,8.832,7.168,16,16,16h192c8.832,0,16-7.168,16-16C320,103.168,312.832,96,304,96z"/><path d="M240,160H112c-8.832,0-16,7.168-16,16c0,8.832,7.168,16,16,16h128c8.832,0,16-7.168,16-16 C256,167.168,248.832,160,240,160z"/><path d="M352,0H64C28.704,0,0,28.704,0,64v320c0,6.208,3.584,11.872,9.216,14.496C11.36,399.488,13.696,400,16,400 c3.68,0,7.328-1.28,10.24-3.712L117.792,320H352c35.296,0,64-28.704,64-64V64C416,28.704,387.296,0,352,0z M384,256 c0,17.632-14.336,32-32,32H112c-3.744,0-7.36,1.312-10.24,3.712L32,349.856V64c0-17.632,14.336-32,32-32h288 c17.664,0,32,14.368,32,32V256z"/><path d="M448,128c-8.832,0-16,7.168-16,16c0,8.832,7.168,16,16,16c17.664,0,32,14.368,32,32v270.688l-54.016-43.2 c-2.816-2.24-6.368-3.488-9.984-3.488H192c-17.664,0-32-14.368-32-32v-16c0-8.832-7.168-16-16-16c-8.832,0-16,7.168-16,16v16 c0,35.296,28.704,64,64,64h218.368l75.616,60.512C488.896,510.816,492.448,512,496,512c2.336,0,4.704-0.512,6.944-1.568 C508.48,507.744,512,502.144,512,496V192C512,156.704,483.296,128,448,128z"/></svg>';

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

class _PostNavIcon extends StatelessWidget {
  const _PostNavIcon({this.isSelected = false});

  final bool isSelected;

  static const String _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="currentColor"><path d="M156,256c0,11.046,8.954,20,20,20h60v60c0,11.046,8.954,20,20,20s20-8.954,20-20v-60h60c11.046,0,20-8.954,20-20 c0-11.046-8.954-20-20-20h-60v-60c0-11.046-8.954-20-20-20s-20,8.954-20,20v60h-60C164.954,236,156,244.954,156,256z"/><path d="M256,40c119.378,0,216,96.608,216,216c0,119.378-96.608,216-216,216c-119.378,0-216-96.608-216-216" fill="none" stroke="currentColor" stroke-width="40" stroke-linecap="round"/><circle cx="80" cy="256" r="12" fill="currentColor"/><circle cx="50" cy="256" r="12" fill="currentColor"/><circle cx="20" cy="256" r="12" fill="currentColor"/></svg>';

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
