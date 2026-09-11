import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../screens/top_users_screen.dart';
import '../screens/voice_room/voice_rooms_lobby_screen.dart';
import 'custom_icons.dart';

const String _topOutstandingSvg =
    '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6 3.5H18V9C18 12.31 15.31 15 12 15C8.69 15 6 12.31 6 9V3.5Z" stroke="#292D32" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M6 5H4C2.9 5 2 5.9 2 7C2 8.1 2.9 9 4 9H6" stroke="#292D32" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M18 5H20C21.1 5 22 5.9 22 7C22 8.1 21.1 9 20 9H18" stroke="#292D32" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M12 15V19" stroke="#292D32" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M8 20.5H16" stroke="#292D32" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M12 6.5L12.6 7.7L14 7.9L13 8.9L13.2 10.3L12 9.6L10.8 10.3L11 8.9L10 7.9L11.4 7.7L12 6.5Z" fill="#292D32"/>'
    '</svg>';

const String _notificationBellSvg =
    '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12.0196 2.91016c-3.31.0-6 2.69-6 6V11.8002C6.0196 12.4102 5.7596 13.3402 5.4496 13.8602l-1.15 1.91c-.71 1.18-.22 2.49 1.08 2.93 4.31 1.44 8.96 1.44 13.27.0 1.21-.399999999999999 1.74-1.83 1.08-2.93l-1.15-1.91C18.2796 13.3402 18.0196 12.4102 18.0196 11.8002V8.91016c0-3.3-2.7-6-6-6z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round"/><path d="M13.8699 3.19994C13.5599 3.10994 13.2399 3.03994 12.9099 2.99994 11.9499 2.87994 11.0299 2.94994 10.1699 3.19994c.289999999999999-.74 1.01-1.26 1.85-1.26s1.56.52 1.85 1.26z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M15.0195 19.0601c0 1.65-1.35 3-3 3-.82.0-1.58-.34-2.11997-.879999999999999C9.35953 20.6401 9.01953 19.8801 9.01953 19.0601" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10"/></svg>';

class KatsTopBar extends StatelessWidget {
  const KatsTopBar({
    required this.unreadNotifications,
    required this.isMenuOpen,
    this.onHomeTap,
    this.onNotificationsTap,
    super.key,
  });

  final int unreadNotifications;
  final bool isMenuOpen;
  final VoidCallback? onHomeTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onHomeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Home',
                    style: TextStyle(
                      inherit: false,
                      color: const Color(0xFFFF7A45),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isMenuOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFFF7A45),
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VoiceRoomsLobbyScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomIcons.micParty(
                    color: Colors.white,
                    size: 13,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Party',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            tooltip: 'Voice Party Rooms',
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TopUsersScreen(),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: SvgPicture.string(
              _topOutstandingSvg,
              width: 21,
              height: 21,
              colorFilter: const ColorFilter.mode(
                Color(0xFFFF7A45),
                BlendMode.srcIn,
              ),
            ),
            tooltip: 'Top Outstanding Users',
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/youtube');
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.5.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            tooltip: 'YouTube Search',
          ),
          IconButton(
            onPressed: () {
              themeProvider.toggleTheme(!isDark);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: const Color(0xFFFF7A45),
            ),
            iconSize: 21,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          const SizedBox(width: 2),
          NotificationBellButton(
            unreadNotifications: unreadNotifications,
            onPressed: onNotificationsTap,
          ),
        ],
      ),
    );
  }
}

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    required this.unreadNotifications,
    this.onPressed,
    super.key,
  });

  final int unreadNotifications;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final badgeLabel =
        unreadNotifications > 9 ? '9+' : unreadNotifications.toString();

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: SvgPicture.string(
                _notificationBellSvg,
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFF7A45),
                  BlendMode.srcIn,
                ),
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 2,
                top: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 0.5,
                      ),
                      child: Center(
                        child: Text(
                          badgeLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            inherit: false,
                            color: Colors.white,
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
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
