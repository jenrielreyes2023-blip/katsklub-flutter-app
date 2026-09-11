import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/voice_room_controller.dart';
import '../screens/voice_room/voice_room_screen.dart';

/// Global floating mini-player overlay for Voice Rooms (PIP)
class VoiceRoomMiniOverlay extends StatefulWidget {
  const VoiceRoomMiniOverlay({super.key});

  @override
  State<VoiceRoomMiniOverlay> createState() => _VoiceRoomMiniOverlayState();
}

class _VoiceRoomMiniOverlayState extends State<VoiceRoomMiniOverlay> {
  Offset _position = const Offset(16, 120);

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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VoiceRoomController();
    final room = controller.currentRoom;

    if (!controller.isMinimized || room == null) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx.clamp(10.0, screenSize.width - 230.0),
      top: _position.dy.clamp(60.0, screenSize.height - 100.0),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onTap: () {
          controller.maximize();
          Navigator.of(context, rootNavigator: true).push(
            PageRouteBuilder<void>(
              opaque: true,
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (_, __, ___) => const VoiceRoomScreen(),
            ),
          );
        },
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(28),
          color: Colors.transparent,
          child: Container(
            width: 220.w,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF26193E), Color(0xFF13111C)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFF7A45).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Host avatar or room cover
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor: const Color(0xFFFF7A45),
                  backgroundImage: room.host.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(room.host.avatarUrl)
                      : null,
                  child: room.host.avatarUrl.isEmpty
                      ? const Icon(Icons.mic, size: 16, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 8.w),

                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            controller.isOnMic ? 'On Mic' : 'Listening',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mic Mute (if on mic)
                if (controller.isOnMic)
                  GestureDetector(
                    onTap: () => controller.toggleMute(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Icon(
                        controller.isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        color: controller.isMuted
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        size: 18.r,
                      ),
                    ),
                  ),

                // Close / Leave button
                GestureDetector(
                  onTap: () => controller.leaveRoom(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 18.r,
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
