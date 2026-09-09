import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/voice_room_controller.dart';
import '../../services/zego_voice_service.dart';
import '../../widgets/voice_room_gift_sheet.dart';
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
      // Empty seat -> Take seat
      if (seat.isLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This seat is locked by the host')),
        );
        return;
      }
      controller.takeSeat(seat.seatIndex);
    } else if (seat.user!.id.toString() == myId?.toString()) {
      // My seat -> Options (Leave, Mute)
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
      // Occupied by someone else -> Send Gift or Host options
      if (isHost) {
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
                  leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
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
                  hintText: 'Say something friendly...',
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
              Text(
                'Voice Effects & Magic Filter 🎤',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
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
                  _effectChip('🐿️ Chipmunk', () {
                    ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.MenToChild);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('🤖 Robot', () {
                    ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.OptimusPrime);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('🎙️ Concert Hall', () {
                    ZegoVoiceService().setReverb(ZegoReverbPreset.ConcertHall);
                    Navigator.pop(ctx);
                  }),
                  _effectChip('🎶 KTV Karaoke', () {
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
      soundLevel: seats.isNotEmpty ? seats[0].soundLevel : 0.0,
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

                      // Exit button
                      IconButton(
                        onPressed: () async {
                          await controller.leaveRoom();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 22),
                        tooltip: 'Exit Room',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                // Host Stage Area (Center Top)
                Center(
                  child: VoiceSeatWidget(
                    seat: hostSeat,
                    isHost: true,
                    onTap: () {
                      VoiceRoomGiftSheet.show(context,
                          room: room, initialReceiver: room.host);
                    },
                  ),
                ),

                SizedBox(height: 16.h),

                // 8 Guest Mic Seats Grid (4x2)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 8,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
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

                const Spacer(),

                // Live Floating Chat Stream (Bottom Left)
                Container(
                  height: 140.h,
                  margin: EdgeInsets.symmetric(horizontal: 14.w),
                  child: ListView.builder(
                    controller: _chatScrollController,
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final msg = controller.messages[index];

                      if (msg.isSystem) {
                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 2.h),
                          padding:
                              EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.message,
                            style: TextStyle(
                              color: const Color(0xFFFFB800),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 2.h),
                        padding:
                            EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
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

                SizedBox(height: 10.h),

                // Bottom Action Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      // Chat Button
                      IconButton(
                        onPressed: _showChatInputSheet,
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: Colors.white),
                        tooltip: 'Say Something',
                      ),

                      // Voice Effects / Magic
                      IconButton(
                        onPressed: _showVoiceEffectsSheet,
                        icon: const Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFFA78BFA)),
                        tooltip: 'Voice Effects',
                      ),

                      const Spacer(),

                      // Mic Mute Toggle (If on mic)
                      if (controller.isSeated)
                        IconButton(
                          onPressed: () => controller.toggleMute(),
                          icon: Icon(
                            controller.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            color: controller.isMuted
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                          tooltip: controller.isMuted ? 'Unmute' : 'Mute',
                        ),

                      // Take / Leave Seat Button
                      ElevatedButton.icon(
                        onPressed: () {
                          if (controller.isSeated) {
                            controller.leaveSeat();
                          } else {
                            // Find first empty seat
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
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: controller.isSeated
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(
                          controller.isSeated
                              ? Icons.arrow_downward_rounded
                              : Icons.mic_rounded,
                          size: 16,
                        ),
                        label: Text(
                          controller.isSeated ? 'Leave Mic' : 'Take Mic',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      SizedBox(width: 8.w),

                      // Gift Button
                      ElevatedButton(
                        onPressed: () {
                          VoiceRoomGiftSheet.show(context, room: room);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A45),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          children: [
                            const Text('🎁 ', style: TextStyle(fontSize: 14)),
                            Text(
                              'Gift',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                        child: Text(
                          '🎁 ${controller.activeGiftSender?.fullName ?? ''} sent ${controller.activePlayingGift?.name ?? ''} to ${controller.activeGiftReceiver?.fullName ?? ''}!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                          ),
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
