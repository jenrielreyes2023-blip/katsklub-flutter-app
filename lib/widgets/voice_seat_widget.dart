import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room.dart';
import '../services/auth_service.dart';
import 'custom_icons.dart';
import 'user_avatar_with_frame.dart';

/// Compact, interactive microphone seat widget with SVG badges and ambient speaking ring
class VoiceSeatWidget extends StatelessWidget {
  const VoiceSeatWidget({
    super.key,
    required this.seat,
    this.isHost = false,
    this.isAway = false,
    this.onTap,
  });

  final VoiceSeat seat;
  final bool isHost;
  final bool isAway;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final currentUser = AuthService().currentUser;
    final isMe = currentUser != null && currentUser.id.toString() == user?.id.toString();
    final effectiveAvatarFrame = (user?.avatarFrame != null && user!.avatarFrame!.isNotEmpty)
        ? user.avatarFrame
        : (isMe ? currentUser.avatarFrame : null);
    final hasFrame = effectiveAvatarFrame != null && effectiveAvatarFrame.isNotEmpty;

    final isSpeaking = (isAway != true) && !seat.isMuted && seat.soundLevel > 6.0;

    final avatarSize = isHost ? 50.w : 40.w;
    final rippleSize = isHost
        ? (hasFrame ? 66.w : 58.w)
        : (hasFrame ? 52.w : 48.w);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar or Empty Slot with sound wave ripple (Fixed footprint prevents layout shift)
          SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Speaking ripple glow animation (Positioned so it doesn't push the seat or row downward)
                if (isSpeaking)
                  Positioned(
                    left: (avatarSize - rippleSize) / 2,
                    top: (avatarSize - rippleSize) / 2,
                    width: rippleSize,
                    height: rippleSize,
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: const Color(0xFF34D399).withValues(alpha: 0.3),
                              blurRadius: 14,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

              // Main Avatar or Empty Seat
              if (user != null)
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: isHost && isAway ? 0.35 : 1.0,
                      child: UserAvatarWithFrame(
                        avatarUrl: user.avatarUrl,
                        avatarFrame: effectiveAvatarFrame,
                        radius: avatarSize / 2,
                        preserveLayoutFootprint: true,
                        border: Border.all(
                          color: isHost
                              ? (isAway
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : const Color(0xFFFFB800))
                              : (isSpeaking
                                  ? const Color(0xFF10B981)
                                  : Colors.white.withValues(alpha: 0.2)),
                          width: isHost ? (isAway ? 1.2 : 2.0) : 1.5,
                        ),
                        initials: user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : (user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : '?'),
                      ),
                    ),
                    if (isHost && isAway)
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.58),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'OUT',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              else if (seat.isLocked)
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white30,
                      size: 16,
                    ),
                  ),
                )
              else
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                ),

              // Host Crown Badge (Vector SVG instead of emoji)
              if (isHost)
                Positioned(
                  top: -6,
                  child: Opacity(
                    opacity: isAway ? 0.35 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB800), Color(0xFFFF7A00)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomIcons.crown(color: Colors.black, size: 9),
                          const SizedBox(width: 2.5),
                          const Text(
                            'HOST',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Muted Sign Badge (Prominent red circular badge on avatar)
              if (seat.isMuted && user != null)
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    padding: EdgeInsets.all(isHost ? 3.5 : 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F1015), width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.55),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.mic_off_rounded,
                      color: Colors.white,
                      size: isHost ? 12.r : 10.r,
                    ),
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 4.h),

        // User Name or Seat Number with Mute Sign (Fixed height prevents text row vertical shifts)
        SizedBox(
          width: 64.w,
          height: 16.h,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (seat.isMuted && user != null) ...[
                  CustomIcons.micOffParty(color: const Color(0xFFEF4444), size: 10.r),
                  SizedBox(width: 2.w),
                ],
                Flexible(
                  child: Text(
                    user != null
                        ? (user.fullName.isNotEmpty ? user.fullName : user.username)
                        : (seat.isLocked ? 'Locked' : 'Seat ${seat.seatIndex + 1}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: user != null ? FontWeight.w600 : FontWeight.w400,
                      color: user != null
                          ? (isHost && isAway
                              ? Colors.white38
                              : (seat.isMuted ? const Color(0xFFFFA4A4) : Colors.white.withValues(alpha: 0.9)))
                          : Colors.white.withValues(alpha: 0.4),
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
