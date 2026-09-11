import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'edit_voice_room_screen.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/voice_room_controller.dart';
import '../../services/zego_voice_service.dart';
import '../../widgets/custom_icons.dart';
import '../../widgets/voice_room_gift_sheet.dart';
import '../../widgets/voice_room_set_pin_sheet.dart';
import '../../widgets/voice_seat_widget.dart';

/// Full-Screen WePlay-Style Interactive Voice Room Screen
class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({super.key});

  static Future<void> open(BuildContext context, VoiceRoom room, User user) async {
    final controller = VoiceRoomController();
    await controller.enterRoom(room, user);

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: const VoiceRoomScreen(),
            );
          },
        ),
      );
    }
  }

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _chatTextController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  SVGAAnimationController? _svgaController;
  String? _currentlyPlayingSvgaUrl;

  @override
  void initState() {
    super.initState();
    _svgaController = SVGAAnimationController(vsync: this);
    VoiceRoomController().addListener(_handleControllerUpdate);
  }

  @override
  void dispose() {
    VoiceRoomController().removeListener(_handleControllerUpdate);
    _svgaController?.dispose();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (!mounted) return;
    final controller = VoiceRoomController();

    // Auto-scroll chat to bottom
    if (controller.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    // Play SVGA Gift animation if active
    final activeGift = controller.activePlayingGift;
    if (activeGift != null && activeGift.svgaUrl.isNotEmpty) {
      if (_currentlyPlayingSvgaUrl != activeGift.svgaUrl) {
        _playSvgaGift(activeGift.svgaUrl);
      }
    } else {
      _currentlyPlayingSvgaUrl = null;
    }

    setState(() {});
  }

  Future<void> _playSvgaGift(String url) async {
    try {
      _currentlyPlayingSvgaUrl = url;
      final videoItem = await SVGAParser.shared.decodeFromURL(url);
      if (mounted) {
        _svgaController?.videoItem = videoItem;
        _svgaController?.reset();
        _svgaController?.forward();
      }
    } catch (e) {
      debugPrint('[VoiceRoom] Error playing SVGA gift: $e');
    }
  }

  void _handleSeatTap(VoiceSeat seat) {
    final controller = VoiceRoomController();
    final myId = controller.currentUser?.id;
    final isHost = controller.currentRoom?.host.id.toString() == myId?.toString();

    if (seat.user == null) {
      if (isHost) {
        // Host tapped an empty seat -> Host moderation (Lock / Unlock seat)
        _showHostSeatModeration(seat);
        return;
      }

      // Guest tapped an empty seat -> Take seat
      if (seat.isLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This seat is locked by the host')),
        );
        return;
      }
      controller.takeSeat(seat.seatIndex);
    } else if (seat.user!.id.toString() == myId?.toString()) {
      // My seat (guests seated in 0..7) -> Options (Leave, Mute)
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E2024),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  controller.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: controller.isMuted ? Colors.redAccent : Colors.greenAccent,
                ),
                title: Text(
                  controller.isMuted ? 'Unmute Microphone' : 'Mute Microphone',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.toggleMute();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward_rounded, color: Colors.orangeAccent),
                title: const Text('Leave Microphone', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.leaveSeat();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // Occupied by someone else -> Send Gift or Host / Admin options
      final isAdmin = controller.currentRoom?.admins.any((a) => a.id.toString() == myId?.toString()) ?? false;
      if (isHost || isAdmin) {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E2024),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.card_giftcard_rounded, color: Colors.pinkAccent),
                  title: Text('Send Gift to ${seat.user!.fullName}',
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    VoiceRoomGiftSheet.show(context,
                        room: controller.currentRoom!, initialReceiver: seat.user);
                  },
                ),
                ListTile(
                  leading: Icon(
                    seat.isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: seat.isMuted ? Colors.greenAccent : Colors.redAccent,
                  ),
                  title: Text(
                    seat.isMuted
                        ? 'Unmute ${seat.user!.fullName}'
                        : 'Mute ${seat.user!.fullName}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    seat.isMuted
                        ? 'Allow user to speak on microphone'
                        : 'Mute this user\'s microphone',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.muteSeat(seat.seatIndex, !seat.isMuted);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_rounded, color: Colors.orangeAccent),
                  title: Text('Kick ${seat.user!.fullName} from mic',
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.kickSeat(seat.seatIndex);
                  },
                ),
              ],
            ),
          ),
        );
      } else {
        // Just send gift
        VoiceRoomGiftSheet.show(context,
            room: controller.currentRoom!, initialReceiver: seat.user);
      }
    }
  }

  void _showHostSeatModeration(VoiceSeat seat) {
    final controller = VoiceRoomController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Text(
                'Seat ${seat.seatIndex + 1} Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Icon(
                seat.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: seat.isLocked ? Colors.greenAccent : Colors.orangeAccent,
              ),
              title: Text(
                seat.isLocked ? 'Unlock Seat ${seat.seatIndex + 1}' : 'Lock Seat ${seat.seatIndex + 1}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                seat.isLocked
                    ? 'Allow audience to take this seat'
                    : 'Prevent audience from taking this seat',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                controller.lockSeat(seat.seatIndex, !seat.isLocked);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHostStageOptions(BuildContext context, VoiceRoomController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Text(
                'Host Stage Options',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Icon(
                controller.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: controller.isMuted ? Colors.redAccent : Colors.greenAccent,
              ),
              title: Text(
                controller.isMuted ? 'Unmute Host Microphone' : 'Mute Host Microphone',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                controller.toggleMute();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA78BFA)),
              title: const Text('Voice Effects', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showVoiceEffectsSheet();
              },
            ),
            if (controller.currentRoom != null)
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: Colors.cyanAccent),
                title: const Text('Edit Room Settings', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  EditVoiceRoomScreen.open(context, controller.currentRoom!, controller);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showChatInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2024),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 12.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatTextController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    VoiceRoomController().sendChatMessage(val);
                    _chatTextController.clear();
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
            SizedBox(width: 8.w),
            IconButton(
              onPressed: () {
                final val = _chatTextController.text;
                if (val.trim().isNotEmpty) {
                  VoiceRoomController().sendChatMessage(val);
                  _chatTextController.clear();
                  Navigator.pop(ctx);
                }
              },
              icon: const Icon(Icons.send_rounded, color: Color(0xFFFF7A45)),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceEffectsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18191C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomIcons.sparkles(color: const Color(0xFFA78BFA), size: 18),
                  SizedBox(width: 8.w),
                  Text(
                    'Voice Effects & Audio Filter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _effectChip('Normal Voice', () {
                    ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.None);
                    ZegoVoiceService().setReverb(ZegoReverbPreset.None);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('Chipmunk', () {
                    ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.MenToChild);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('Robot', () {
                    ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.OptimusPrime);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('Concert Hall', () {
                    ZegoVoiceService().setReverb(ZegoReverbPreset.ConcertHall);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('KTV Karaoke', () {
                    ZegoVoiceService().setReverb(ZegoReverbPreset.KTV);
                    Navigator.pop(ctx);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _effectChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _handleExit(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    final isHost = controller.isHost ||
        (controller.currentUser != null &&
            room.host.id.toString() == controller.currentUser!.id.toString());

    if (!isHost) {
      controller.leaveRoom();
      Navigator.of(context).pop();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.picture_in_picture_alt_rounded, color: Color(0xFFFF7A45)),
                title: const Text('Minimize Room',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Keep room playing in background',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.minimize();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded, color: Colors.orangeAccent),
                title: const Text('Leave Room',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Leave without closing room for others',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await controller.leaveRoom();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              if (!room.isPermanent) ...[
                ListTile(
                  leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                  title: const Text('Dissolve Room',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                  subtitle: const Text('End party and disconnect all members',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E2024),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8.w),
                            const Text('Dissolve Room?',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to dissolve "${room.title}"?\n\nAll participants will be disconnected and the room will be closed permanently.',
                          style: const TextStyle(color: Colors.white70, height: 1.3),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Dissolve'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await controller.dissolveRoom(room.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomOptions(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF17181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 14.h),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            room.isPermanent ? 'Permanent Room' : '24-Hour Temporary Room',
                            style: TextStyle(
                              color: room.isPermanent ? const Color(0xFFFFB800) : Colors.white38,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (room.isLocked)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_rounded, color: Colors.white70, size: 10),
                            SizedBox(width: 4.w),
                            Text(
                              'Locked',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              const Divider(color: Colors.white12, height: 1),
              SizedBox(height: 6.h),

              // Edit Room & Icon
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                ),
                title: const Text('Edit Room & Icon',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: Text('Change room name and set room image icon',
                    style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                onTap: () {
                  Navigator.pop(ctx);
                  EditVoiceRoomScreen.open(context, room, controller);
                },
              ),

              // Lock / Unlock Room
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    room.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    color: room.isLocked ? const Color(0xFFFFB800) : Colors.white,
                    size: 18,
                  ),
                ),
                title: Text(room.isLocked ? 'Unlock Room' : 'Lock Room',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: Text(
                  room.isLocked
                      ? 'Room is currently locked. Tap to unlock.'
                      : 'Set a 4-digit PIN to restrict room entry.',
                  style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                ),
                onTap: () async {
                  Navigator.pop(ctx);

                  if (room.isLocked) {
                    // Confirm unlock
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF17181F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        title: const Row(
                          children: [
                            Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Unlock Room?',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        content: const Text(
                          'Anyone will be able to enter your room without a PIN.',
                          style: TextStyle(color: Colors.white70, height: 1.3),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A45),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Unlock'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final ok = await controller.toggleRoomLock(false);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Room is now unlocked.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    }
                  } else {
                    // Open 2-step PIN setup sheet (Enter PIN -> Re-enter PIN to confirm)
                    final didLock = await VoiceRoomSetPinSheet.show(context, room, controller);
                    if (didLock == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room is now locked with PIN protection.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  }
                },
              ),

              // Dissolve Room (Temporary rooms only!)
              if (!room.isPermanent) ...[
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 18),
                  ),
                  title: const Text('Dissolve Room',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('Close room permanently and disconnect all participants',
                      style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF17181F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8.w),
                            const Text('Dissolve Room?',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to dissolve "${room.title}"?\n\nAll participants will be disconnected and the room will be closed permanently.',
                          style: const TextStyle(color: Colors.white70, height: 1.3),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Dissolve'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await controller.dissolveRoom(room.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = VoiceRoomController();
    final room = controller.currentRoom;

    if (room == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1015),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final seats = room.seats;
    final hostSeat = VoiceSeat(
      seatIndex: 99,
      user: room.host,
      isMuted: controller.isHostMuted,
      soundLevel: controller.hostSoundLevel,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: Stack(
        children: [
          // Background Gradient & Atmosphere
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  Color(0xFF26193E),
                  Color(0xFF13111C),
                  Color(0xFF0A090F),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  child: Row(
                    children: [
                      // Minimize button
                      IconButton(
                        onPressed: () {
                          controller.minimize();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 28),
                        tooltip: 'Minimize',
                      ),

                      // Room Info
                      Expanded(
                        child: Row(
                          children: [
                            if (room.coverUrl.isNotEmpty) ...[
                              Container(
                                width: 34.r,
                                height: 34.r,
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1.2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: room.coverUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Row(
                                    children: [
                                      Container(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ID: ${room.id}',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                  decoration: BoxDecoration(
                                    color: room.isPermanent
                                        ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                                        : Colors.cyanAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: room.isPermanent
                                          ? const Color(0xFFFFB800).withValues(alpha: 0.35)
                                          : Colors.cyanAccent.withValues(alpha: 0.35),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (room.isPermanent)
                                        CustomIcons.crown(color: const Color(0xFFFFB800), size: 9)
                                      else
                                        const Icon(Icons.timer_outlined, size: 9, color: Colors.cyanAccent),
                                      SizedBox(width: 3.w),
                                      Text(
                                        room.durationBadgeText,
                                        style: TextStyle(
                                          color: room.isPermanent ? const Color(0xFFFFD54F) : Colors.cyanAccent,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.people_alt_rounded,
                                    color: Colors.white60, size: 13.r),
                                SizedBox(width: 3.w),
                                Text(
                                  '${room.audienceCount}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                      // Room Options button (Host only)
                      if (controller.isHost ||
                          (controller.currentUser != null &&
                              room.host.id.toString() ==
                                  controller.currentUser!.id.toString()))
                        IconButton(
                          onPressed: () =>
                              _showRoomOptions(context, room, controller),
                          icon: const Icon(Icons.tune_rounded,
                              color: Colors.white70, size: 20),
                          tooltip: 'Room Options',
                        ),

                      // Exit button
                      IconButton(
                        onPressed: () => _handleExit(context, room, controller),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 22),
                        tooltip: 'Exit Room',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 4.h),

                // Host Stage Area (Center Top)
                Center(
                  child: VoiceSeatWidget(
                    seat: hostSeat,
                    isHost: true,
                    isAway: controller.isHostInRoom != true,
                    onTap: () {
                      if (controller.isHost) {
                        _showHostStageOptions(context, controller);
                      } else {
                        VoiceRoomGiftSheet.show(context,
                            room: room, initialReceiver: room.host);
                      }
                    },
                  ),
                ),

                SizedBox(height: 10.h),

                // 8 Guest Mic Seats Grid (4x2)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 8,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.96,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final seat = index < seats.length
                          ? seats[index]
                          : VoiceSeat(seatIndex: index);

                      return VoiceSeatWidget(
                        seat: seat,
                        isHost: false,
                        onTap: () => _handleSeatTap(seat),
                      );
                    },
                  ),
                ),

                SizedBox(height: 6.h),

                // Live Floating Chat Stream (Directly under seats 5, 6, 7, 8)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 14.w),
                    child: ListView.builder(
                      controller: _chatScrollController,
                      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        final msg = controller.messages[index];

                        if (msg.isSystem) {
                          final isGift = msg.message.contains('sent');
                          final isNotice = msg.message.startsWith('Notice:') || msg.sender.username == 'Notice';
                          final isRegulations = msg.message.contains('strictly forbidden') || msg.message.contains('Regulations');
                          final isHq = msg.message.contains('high quality mode');

                          Color accentColor = const Color(0xFFFFB800);
                          String badgePrefix = 'System: ';
                          String contentText = msg.message;

                          if (isNotice) {
                            accentColor = const Color(0xFFFF7A45);
                            badgePrefix = 'Notice: ';
                            contentText = msg.message.replaceFirst(RegExp(r'^Notice:\s*'), '');
                          } else if (isRegulations) {
                            accentColor = const Color(0xFF10B981);
                            badgePrefix = 'System: ';
                            contentText = msg.message.replaceFirst(RegExp(r'^System:\s*'), '');
                          } else if (isHq) {
                            accentColor = const Color(0xFF60A5FA);
                            badgePrefix = 'System: ';
                            contentText = msg.message.replaceFirst(RegExp(r'^System:\s*'), '');
                          }

                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 2.5.h),
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.5.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.28),
                                width: 0.8,
                              ),
                            ),
                            child: isGift
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomIcons.giftBox(color: accentColor, size: 12),
                                      SizedBox(width: 5.w),
                                      Flexible(
                                        child: Text(
                                          msg.message,
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: badgePrefix,
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'SF Pro Rounded',
                                          ),
                                        ),
                                        TextSpan(
                                          text: contentText,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.95),
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w400,
                                            height: 1.32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          );
                        }

                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 2.h),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${msg.sender.fullName}: ',
                                  style: TextStyle(
                                    color: const Color(0xFFFF7A45),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: msg.message,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                // Bottom Action Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      // 1. Sleek Compact Message Pill ("kasya lang type message ...")
                      GestureDetector(
                        onTap: _showChatInputSheet,
                        child: Container(
                          height: 30.h,
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(15.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white38,
                                size: 13.r,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'Type message...',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // 2. Microphone SVG (Pure SVG, small & sleek)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!controller.isOnMic) {
                            final empty = seats.firstWhere(
                              (s) => s.user == null && !s.isLocked,
                              orElse: () => VoiceSeat(seatIndex: -1),
                            );
                            if (empty.seatIndex >= 0) {
                              controller.takeSeat(empty.seatIndex);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('All mic seats are occupied')),
                              );
                            }
                          } else {
                            controller.toggleMute();
                            setState(() {});
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                          child: controller.isOnMic && controller.isMuted
                              ? CustomIcons.micOffParty(
                                  color: const Color(0xFFEF4444),
                                  size: 16.r,
                                )
                              : CustomIcons.micParty(
                                  color: controller.isOnMic
                                      ? const Color(0xFF10B981)
                                      : Colors.white60,
                                  size: 16.r,
                                ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 3. Gift SVG Button (Pure SVG, small & sleek)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          VoiceRoomGiftSheet.show(context, room: room);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                          child: CustomIcons.giftBox(
                            color: Colors.white,
                            size: 16.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 4. Voice Effects SVG Button (Pure SVG, small & sleek)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showVoiceEffectsSheet,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                          child: CustomIcons.sparkles(
                            color: const Color(0xFFA78BFA),
                            size: 16.r,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Full Screen SVGA Gift Player Animation Overlay
          if (controller.activePlayingGift != null && _svgaController != null)
            IgnorePointer(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SVGAImage(_svgaController!),
                  ),
                  Positioned(
                    top: 100.h,
                    left: 20.w,
                    right: 20.w,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A45).withValues(alpha: 0.5),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomIcons.giftBox(color: Colors.white, size: 16),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                '${controller.activeGiftSender?.fullName ?? ''} sent ${controller.activePlayingGift?.name ?? ''} to ${controller.activeGiftReceiver?.fullName ?? ''}!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
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
