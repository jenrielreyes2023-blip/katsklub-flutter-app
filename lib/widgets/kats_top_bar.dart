import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onHomeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isMenuOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF111827),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onNotificationsTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SvgPicture.string(
                      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12.0196 2.91016c-3.31.0-6 2.69-6 6V11.8002C6.0196 12.4102 5.7596 13.3402 5.4496 13.8602l-1.15 1.91c-.71 1.18-.22 2.49 1.08 2.93 4.31 1.44 8.96 1.44 13.27.0 1.21-.399999999999999 1.74-1.83 1.08-2.93l-1.15-1.91C18.2796 13.3402 18.0196 12.4102 18.0196 11.8002V8.91016c0-3.3-2.7-6-6-6z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round"/><path d="M13.8699 3.19994C13.5599 3.10994 13.2399 3.03994 12.9099 2.99994 11.9499 2.87994 11.0299 2.94994 10.1699 3.19994c.289999999999999-.74 1.01-1.26 1.85-1.26s1.56.52 1.85 1.26z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M15.0195 19.0601c0 1.65-1.35 3-3 3-.82.0-1.58-.34-2.11997-.879999999999999C9.35953 20.6401 9.01953 19.8801 9.01953 19.0601" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10"/></svg>',
                      width: 29,
                      height: 29,
                    ),
                  ),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadNotifications > 99
                            ? '99+'
                            : unreadNotifications.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
