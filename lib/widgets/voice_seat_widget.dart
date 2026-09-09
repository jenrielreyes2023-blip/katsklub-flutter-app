import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room.dart';

/// Interactive WePlay-style Microphone Seat Widget with speaking soundwave ripple effect
class VoiceSeatWidget extends StatelessWidget {
  const VoiceSeatWidget({
    super.key,
    required this.seat,
    this.isHost = false,
    this.onTap,
  });

  final VoiceSeat seat;
  final bool isHost;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final isSpeaking = seat.soundLevel > 6.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar or Empty Slot with sound wave ripple
          Stack(
            alignment: Alignment.center,
            children: [
              // Speaking ripple glow animation
              if (isSpeaking)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isHost ? 72.w : 58.w,
                  height: isHost ? 72.w : 58.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        blurRadius: 14,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.4),
                        blurRadius: 22,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),

              // Main Avatar or Empty Seat
              if (user != null)
                Container(
                  width: isHost ? 58.w : 48.w,
                  height: isHost ? 58.w : 48.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isHost
                          ? const Color(0xFFFFB800)
                          : (isSpeaking
                              ? const Color(0xFF10B981)
                              : Colors.white.withValues(alpha: 0.2)),
                      width: isHost ? 2.5 : 2.0,
                    ),
                  ),
                  child: ClipOval(
                    child: user.avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF2C2D30),
                              child: const Icon(Icons.person, color: Colors.white54),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF2C2D30),
                              child: const Icon(Icons.person, color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF2C2D30),
                            child: const Icon(Icons.person, color: Colors.white54),
                          ),
                  ),
                )
              else if (seat.isLocked)
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                )
              else
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                ),

              // Host Crown Badge
              if (isHost)
                Positioned(
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB800), Color(0xFFFF7A00)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      '👑 HOST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              // Muted Badge
              if (seat.isMuted && user != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_off_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          // User Name or Seat Number
          SizedBox(
            width: 64.w,
            child: Text(
              user != null
                  ? (user.fullName.isNotEmpty ? user.fullName : user.username)
                  : (seat.isLocked ? 'Locked' : 'Seat ${seat.seatIndex + 1}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: user != null ? FontWeight.w600 : FontWeight.w400,
                color: user != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
