import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room.dart';
import 'custom_icons.dart';

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
    final isSpeaking = (isAway != true) && !seat.isMuted && seat.soundLevel > 6.0;

    final avatarSize = isHost ? 50.w : 40.w;
    final rippleSize = isHost ? 58.w : 48.w;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar or Empty Slot with sound wave ripple
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Speaking ripple glow animation (subtle ambient ring)
              if (isSpeaking)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: rippleSize,
                  height: rippleSize,
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

              // Main Avatar or Empty Seat
              if (user != null)
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
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
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: isHost && isAway ? 0.35 : 1.0,
                          child: user.avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: user.avatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: const Color(0xFF232428),
                                    child: const Icon(Icons.person, color: Colors.white38, size: 20),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: const Color(0xFF232428),
                                    child: const Icon(Icons.person, color: Colors.white38, size: 20),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF232428),
                                  child: const Icon(Icons.person, color: Colors.white38, size: 20),
                                ),
                        ),
                        if (isHost && isAway) ...[
                          Container(
                            color: Colors.black.withValues(alpha: 0.58),
                          ),
                          Center(
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
                      ],
                    ),
                  ),
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

          SizedBox(height: 4.h),

          // User Name or Seat Number with Mute Sign
          SizedBox(
            width: 62.w,
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
