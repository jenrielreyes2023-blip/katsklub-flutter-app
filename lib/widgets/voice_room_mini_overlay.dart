import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/voice_room_controller.dart';
import '../services/auth_service.dart';
import '../screens/voice_room/voice_room_screen.dart';
import '../utils/update_checker.dart';

/// Global floating mini-player overlay for Voice Rooms (PIP)
class VoiceRoomMiniOverlay extends StatefulWidget {
  const VoiceRoomMiniOverlay({super.key});

  @override
  State<VoiceRoomMiniOverlay> createState() => _VoiceRoomMiniOverlayState();
}

class _VoiceRoomMiniOverlayState extends State<VoiceRoomMiniOverlay> {
  Offset? _position;
  bool _isDragging = false;
  bool _hasDragged = false;
  bool _isOpening = false;
  bool _wasMinimized = false;

  static const String _powerOffSvg =
      '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 2V10" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      '<path d="M18.36 6.64A9 9 0 1 1 5.64 6.64" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>';

  @override
  void initState() {
    super.initState();
    VoiceRoomController().addListener(_onControllerChange);
  }

  @override
  void dispose() {
    VoiceRoomController().removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) {
      final isMin = VoiceRoomController().isMinimized;
      if (isMin && !_wasMinimized) {
        // Reset position to dock at the side when newly minimized
        _position = null;
      }
      _wasMinimized = isMin;
      setState(() {});
    }
  }

  void _maximizeAndOpenRoom() {
    if (_isOpening) return;
    _isOpening = true;
    HapticFeedback.lightImpact();

    final nav = UpdateChecker.navigatorKey.currentState;
    final controller = VoiceRoomController();

    if (nav != null) {
      controller.maximize();
      nav.push(
        PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const VoiceRoomScreen(),
          ),
        ),
      ).then((_) {
        _isOpening = false;
      });
    } else {
      final ctx = UpdateChecker.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        controller.maximize();
        Navigator.of(ctx).push(
          PageRouteBuilder<void>(
            opaque: true,
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: const VoiceRoomScreen(),
            ),
          ),
        ).then((_) {
          _isOpening = false;
        });
      } else {
        _isOpening = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VoiceRoomController();
    final room = controller.currentRoom;
    final authUser = AuthService().currentUser;

    if (authUser == null || !controller.isMinimized || room == null) {
      return const SizedBox.shrink();
    }

    // Safety check: Never show another user's active room if account switched
    if (controller.currentUser != null &&
        authUser.id != null &&
        controller.currentUser!.id.toString() != authUser.id.toString()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.leaveRoom();
      });
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final pillWidth = 155.w;
    final defaultX = screenSize.width - pillWidth - 10.w; // Docked at right side edge
    final defaultY = 130.h;

    final currentPos = _position ?? Offset(defaultX, defaultY);
    final clampedX = currentPos.dx.clamp(8.0, (screenSize.width - pillWidth - 8.0).clamp(8.0, double.infinity));
    final clampedY = currentPos.dy.clamp(60.0, (screenSize.height - 100.0).clamp(60.0, double.infinity));

    final coverUrl = room.coverUrl.trim().isNotEmpty
        ? room.coverUrl.trim()
        : room.host.avatarUrl.trim();
    final hasImage = coverUrl.isNotEmpty;

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
            _hasDragged = false;
          });
        },
        onPanUpdate: (details) {
          if (details.delta.dx.abs() > 0.5 || details.delta.dy.abs() > 0.5) {
            _hasDragged = true;
          }
          setState(() {
            final activePos = _position ?? Offset(defaultX, defaultY);
            _position = Offset(
              activePos.dx + details.delta.dx,
              activePos.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (_) {
          if (!_hasDragged) {
            // It was a tap that triggered pan
            setState(() {
              _isDragging = false;
            });
            _maximizeAndOpenRoom();
            return;
          }

          final midX = screenSize.width / 2;
          final activeX = (_position ?? Offset(defaultX, defaultY)).dx;
          final activeY = (_position ?? Offset(defaultX, defaultY)).dy;
          // Magnetically snap to the nearest side edge (left or right)
          final targetX = (activeX + pillWidth / 2 < midX)
              ? 8.w
              : (screenSize.width - pillWidth - 8.w);
          final targetY = activeY.clamp(60.h, screenSize.height - 110.h);
          setState(() {
            _isDragging = false;
            _position = Offset(targetX, targetY);
          });
        },
        onPanCancel: () {
          setState(() {
            _isDragging = false;
          });
        },
        onTap: _maximizeAndOpenRoom,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.transparent,
          child: Container(
            width: pillWidth,
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF26193E), Color(0xFF13111C)],
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: const Color(0xFFFF7A45).withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Room Cover / Room Icon
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.7),
                      width: 1.0,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 12.r,
                    backgroundColor: const Color(0xFF26193E),
                    backgroundImage: hasImage
                        ? CachedNetworkImageProvider(coverUrl)
                        : null,
                    child: !hasImage
                        ? Icon(
                            Icons.graphic_eq_rounded,
                            size: 13.r,
                            color: const Color(0xFFFF7A45),
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 6.w),

                // 2. Room Title
                Expanded(
                  child: Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                SizedBox(width: 5.w),

                // 3. Power Off SVG button (Easy leave room)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.leaveRoom();
                  },
                  child: Container(
                    width: 24.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.string(
                      _powerOffSvg,
                      width: 13.r,
                      height: 13.r,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFFF4D4F),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
