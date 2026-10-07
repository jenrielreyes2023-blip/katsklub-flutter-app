import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'edit_voice_room_screen.dart';
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/auth_service.dart';
import '../../services/voice_room_controller.dart';
import '../../services/zego_voice_service.dart';
import '../../widgets/custom_icons.dart';
import '../../widgets/gif_picker_modal.dart';
import '../../widgets/marquee_text.dart';
import '../../widgets/smooth_bottom_sheet.dart';
import '../../widgets/user_avatar_with_frame.dart';
import '../../widgets/voice_room_gift_sheet.dart';
import '../../widgets/voice_room_music_sheet.dart';
import '../../widgets/voice_room_set_pin_sheet.dart';
import '../../widgets/voice_seat_widget.dart';

/// Full-Screen WePlay-Style Interactive Voice Room Screen
class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({super.key});

  /// Tracks whether the full-screen VoiceRoomScreen is currently mounted
  static bool isScreenOpen = false;

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
  int _lastHandledGiftToken = -1;
  bool _isSpeakerMuted = false;

  @override
  void initState() {
    super.initState();
    VoiceRoomScreen.isScreenOpen = true;
    _svgaController = SVGAAnimationController(vsync: this);
    VoiceRoomController().addListener(_handleControllerUpdate);
  }

  @override
  void dispose() {
    VoiceRoomScreen.isScreenOpen = false;
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

    // Play SVGA Gift animation whenever a new gift token is emitted
    final activeGift = controller.activePlayingGift;
    if (activeGift != null && activeGift.svgaUrl.isNotEmpty) {
      if (_lastHandledGiftToken != controller.giftPlayToken) {
        _lastHandledGiftToken = controller.giftPlayToken;
        _playSvgaGift(activeGift.svgaUrl);
      }
    }

    setState(() {});
  }

  Future<void> _playSvgaGift(String url) async {
    try {
      final videoItem = url.startsWith('assets/')
          ? await SVGAParser.shared.decodeFromAssets(url)
          : await SVGAParser.shared.decodeFromURL(url);
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
      KatsBottomSheet.showMenu(
        context,
        title: 'Microphone Controls',
        items: [
          KatsSheetItem(
            title: controller.isMuted ? 'Unmute Microphone' : 'Mute Microphone',
            subtitle: controller.isMuted
                ? 'Turn on your microphone to speak'
                : 'Turn off your microphone',
            icon: controller.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            iconColor: controller.isMuted
                ? const Color(0xFFED4956)
                : const Color(0xFF22C55E),
            onTap: () {
              Navigator.pop(context);
              controller.toggleMute();
            },
          ),
          KatsSheetItem(
            title: 'Leave Microphone',
            subtitle: 'Return to audience section',
            icon: Icons.arrow_downward_rounded,
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              controller.leaveSeat();
            },
          ),
        ],
      );
    } else {
      // Occupied by someone else -> Send Gift or Host / Admin options
      final isAdmin = controller.currentRoom?.admins.any((a) => a.id.toString() == myId?.toString()) ?? false;
      if (isHost || isAdmin) {
        KatsBottomSheet.showMenu(
          context,
          title: 'Manage ${seat.user!.fullName}',
          items: [
            KatsSheetItem(
              title: 'Send Gift',
              subtitle: 'Send virtual gifts to speaker',
              icon: Icons.card_giftcard_rounded,
              iconColor: const Color(0xFFEC4899),
              onTap: () {
                Navigator.pop(context);
                VoiceRoomGiftSheet.show(context,
                    room: controller.currentRoom!, initialReceiver: seat.user);
              },
            ),
            KatsSheetItem(
              title: seat.isMuted
                  ? 'Unmute Microphone'
                  : 'Mute Microphone',
              subtitle: seat.isMuted
                  ? 'Allow speaker to unmute & talk'
                  : 'Mute this speaker\'s microphone',
              icon: seat.isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
              iconColor: seat.isMuted
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFED4956),
              onTap: () {
                Navigator.pop(context);
                controller.muteSeat(seat.seatIndex, !seat.isMuted);
              },
            ),
            KatsSheetItem(
              title: 'Remove from Microphone',
              subtitle: 'Move user back to audience section',
              icon: Icons.person_remove_rounded,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                controller.kickSeat(seat.seatIndex);
              },
            ),
          ],
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
    KatsBottomSheet.showMenu(
      context,
      title: 'Seat ${seat.seatIndex + 1} Management',
      items: [
        KatsSheetItem(
          title: seat.isLocked
              ? 'Unlock Seat ${seat.seatIndex + 1}'
              : 'Lock Seat ${seat.seatIndex + 1}',
          subtitle: seat.isLocked
              ? 'Allow audience to take this seat'
              : 'Prevent audience from taking this seat',
          icon: seat.isLocked
              ? Icons.lock_open_rounded
              : Icons.lock_outline_rounded,
          iconColor: seat.isLocked
              ? const Color(0xFF22C55E)
              : const Color(0xFFFFB800),
          onTap: () {
            Navigator.pop(context);
            controller.lockSeat(seat.seatIndex, !seat.isLocked);
          },
        ),
      ],
    );
  }

  void _showHostStageOptions(BuildContext context, VoiceRoomController controller) {
    KatsBottomSheet.showMenu(
      context,
      title: 'Host Stage Options',
      items: [
        KatsSheetItem(
          title: controller.isMuted
              ? 'Unmute Host Microphone'
              : 'Mute Host Microphone',
          subtitle: controller.isMuted
              ? 'Turn on host mic'
              : 'Mute host mic',
          icon: controller.isMuted
              ? Icons.mic_off_rounded
              : Icons.mic_rounded,
          iconColor: controller.isMuted
              ? const Color(0xFFED4956)
              : const Color(0xFF22C55E),
          onTap: () {
            Navigator.pop(context);
            controller.toggleMute();
          },
        ),
        KatsSheetItem(
          title: 'Voice Effects',
          subtitle: 'Apply voice changer or audio reverb filter',
          icon: Icons.auto_awesome_rounded,
          iconColor: const Color(0xFFA78BFA),
          onTap: () {
            Navigator.pop(context);
            _showVoiceEffectsSheet();
          },
        ),
        if (controller.currentRoom != null && controller.isHost)
          KatsSheetItem(
            title: 'Edit Room Settings',
            subtitle: 'Manage room name, admins, and permissions',
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFF06B6D4),
            onTap: () {
              Navigator.pop(context);
              EditVoiceRoomScreen.open(context, controller.currentRoom!, controller);
            },
          ),
      ],
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _uploadAndSendImage(File(picked.path));
    } catch (e) {
      debugPrint('[VoiceRoom] Error picking image: $e');
    }
  }

  Future<void> _uploadAndSendImage(File file) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending photo...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      final token = await AuthService().getToken();
      final request = http.MultipartRequest('POST', ApiConfig.uri('/api/upload/image'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = data['url'] ?? data['fileUrl'];
        if (url != null && url.toString().isNotEmpty) {
          VoiceRoomController().sendChatMessage(url.toString());
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
      }
    } catch (e) {
      debugPrint('[VoiceRoom] Image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendGif() async {
    try {
      final gif = await showGifPickerModal(context);
      if (gif != null && gif.url.isNotEmpty) {
        VoiceRoomController().sendChatMessage(gif.url);
      }
    } catch (e) {
      debugPrint('[VoiceRoom] Error picking GIF: $e');
    }
  }

  void _showChatInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        bool hasText = _chatTextController.text.trim().isNotEmpty;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 10.w,
                right: 10.w,
                top: 10.h,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 10.h,
              ),
              child: Row(
                children: [
                  // Left 1: Picture attachment icon
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      _pickAndSendImage();
                    },
                    child: Container(
                      width: 32.r,
                      height: 32.r,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),

                  // Left 2: GIF icon
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                      _pickAndSendGif();
                    },
                    child: Container(
                      width: 32.r,
                      height: 32.r,
                      alignment: Alignment.center,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54, width: 1.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'GIF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),

                  // Center: Input TextField
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E20),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFF2C2C2E),
                          width: 0.8,
                        ),
                      ),
                      child: TextField(
                        controller: _chatTextController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (val) {
                          final currentHasText = val.trim().isNotEmpty;
                          if (currentHasText != hasText) {
                            setSheetState(() {
                              hasText = currentHasText;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Type message...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          border: InputBorder.none,
                          isDense: true,
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
                  ),

                  // Right: Send icon ONLY when text is typed ("sa labas lalabas yung send icon pag may tinaype kanang words")
                  if (hasText) ...[
                    SizedBox(width: 8.w),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final val = _chatTextController.text;
                        if (val.trim().isNotEmpty) {
                          VoiceRoomController().sendChatMessage(val);
                          _chatTextController.clear();
                          Navigator.pop(ctx);
                        }
                      },
                      child: Container(
                        width: 32.r,
                        height: 32.r,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF8A50), Color(0xFFFF5722)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerMuted = !_isSpeakerMuted;
    });
    try {
      ZegoExpressEngine.instance.muteSpeaker(_isSpeakerMuted);
    } catch (e) {
      debugPrint('[VoiceRoom] Error toggling speaker: $e');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSpeakerMuted ? 'Room audio muted' : 'Room audio unmuted'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQuickEmojiSheet() {
    final emojis = ['❤️', '🔥', '👏', '😂', '🎉', '✨', '💯', '👍', '😍', '🤩', '🌸', '🍕'];
    KatsBottomSheet.showCustom(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
            child: Text(
              'Quick Reactions',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E20),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                child: Center(
                  child: Wrap(
                    spacing: 12.w,
                    runSpacing: 12.h,
                    children: emojis.map((e) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          VoiceRoomController().sendChatMessage(e);
                        },
                        child: Container(
                          width: 44.r,
                          height: 44.r,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(22.r),
                            border: Border.all(
                              color: const Color(0xFF2C2C2E),
                              width: 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            e,
                            style: TextStyle(fontSize: 22.sp),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAudienceListSheet(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    final speakingSeats = room.seats.where((s) => s.user != null).toList();

    KatsBottomSheet.showCustom(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Color(0xFFFFB800), size: 18),
                SizedBox(width: 8.w),
                Text(
                  'Audience & Participants (${room.participantCount})',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // Host Island Card
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Container(
              padding: EdgeInsets.all(12.r),
              color: const Color(0xFF1E1E20),
              child: Row(
                children: [
                  UserAvatarWithFrame(
                    avatarUrl: room.host.avatarUrl,
                    avatarFrame: room.host.avatarFrame,
                    radius: 18.r,
                    preserveLayoutFootprint: true,
                    initials: room.host.fullName.isNotEmpty
                        ? room.host.fullName[0].toUpperCase()
                        : '?',
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                room.host.fullName.isNotEmpty ? room.host.fullName : room.host.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  color: Colors.white,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB800).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'HOST',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  color: const Color(0xFFFFB800),
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          '@${room.host.username}',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: const Color(0xFF8E8E93),
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.currentUser?.id.toString() != room.host.id.toString())
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        VoiceRoomGiftSheet.show(context, room: room, initialReceiver: room.host);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A45), Color(0xFFFF4D4F)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Text(
                          'Send Gift',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12.h),

          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
            child: Text(
              'SEATS & SPEAKING GUESTS',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: const Color(0xFF8E8E93),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Speaking Guests Island Card
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Container(
              color: const Color(0xFF1E1E20),
              child: speakingSeats.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < speakingSeats.length; i++) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            child: Row(
                              children: [
                                UserAvatarWithFrame(
                                  avatarUrl: speakingSeats[i].user!.avatarUrl,
                                  avatarFrame: speakingSeats[i].user!.avatarFrame,
                                  radius: 15.r,
                                  preserveLayoutFootprint: true,
                                  initials: speakingSeats[i].user!.fullName.isNotEmpty
                                      ? speakingSeats[i].user!.fullName[0].toUpperCase()
                                      : '?',
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    speakingSeats[i].user!.fullName.isNotEmpty
                                        ? speakingSeats[i].user!.fullName
                                        : speakingSeats[i].user!.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(
                                      color: const Color(0xFF2C2C2E),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Mic ${speakingSeats[i].seatIndex + 1}',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: const Color(0xFF8E8E93),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i != speakingSeats.length - 1)
                            Padding(
                              padding: EdgeInsets.only(left: 14.w),
                              child: const Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Color(0xFF2C2C2E),
                              ),
                            ),
                        ],
                      ],
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 14.w),
                      child: Center(
                        child: Text(
                          'No other guests currently on microphone',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: const Color(0xFF8E8E93),
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatCluster(VoiceSeat seatA, VoiceSeat seatB) {
    return SizedBox(
      width: 146.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceSeatWidget(
            key: ValueKey('voice_seat_${seatA.seatIndex}'),
            seat: seatA,
            isHost: false,
            onTap: () => _handleSeatTap(seatA),
          ),
          SizedBox(
            width: 38.w,
            height: 46.w,
            child: Center(
              child: SizedBox(
                width: 28.w,
                height: 18.h,
                child: CustomPaint(
                  painter: SoundWavePainter(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
          VoiceSeatWidget(
            key: ValueKey('voice_seat_${seatB.seatIndex}'),
            seat: seatB,
            isHost: false,
            onTap: () => _handleSeatTap(seatB),
          ),
        ],
      ),
    );
  }

  void _showVoiceEffectsSheet() {
    KatsBottomSheet.showCustom(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
            child: Row(
              children: [
                CustomIcons.sparkles(color: const Color(0xFFA78BFA), size: 18),
                SizedBox(width: 8.w),
                Text(
                  'Voice Effects & Audio Filter',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E20),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _effectChip('Normal Voice', () {
                      ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.None);
                      ZegoVoiceService().setReverb(ZegoReverbPreset.None);
                      Navigator.pop(context);
                    }),
                    _effectChip('Chipmunk', () {
                      ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.MenToChild);
                      Navigator.pop(context);
                    }),
                    _effectChip('Robot', () {
                      ZegoVoiceService().setVoiceChanger(ZegoVoiceChangerPreset.OptimusPrime);
                      Navigator.pop(context);
                    }),
                    _effectChip('Concert Hall', () {
                      ZegoVoiceService().setReverb(ZegoReverbPreset.ConcertHall);
                      Navigator.pop(context);
                    }),
                    _effectChip('KTV Karaoke', () {
                      ZegoVoiceService().setReverb(ZegoReverbPreset.KTV);
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            color: Colors.white,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _handleExit(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    final isHost = controller.isHost;

    if (!isHost) {
      KatsBottomSheet.showMenu(
        context,
        title: 'Exit Voice Room',
        items: [
          KatsSheetItem(
            title: 'Minimize Room',
            subtitle: 'Keep listening in background',
            icon: Icons.picture_in_picture_alt_rounded,
            iconColor: const Color(0xFFFF7A45),
            onTap: () {
              Navigator.pop(context);
              controller.minimize();
              Navigator.of(context).pop();
            },
          ),
          KatsSheetItem(
            title: 'Leave Room',
            subtitle: 'Disconnect and exit voice room',
            icon: Icons.exit_to_app_rounded,
            isDestructive: true,
            onTap: () async {
              Navigator.pop(context);
              await controller.leaveRoom();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
      return;
    }

    final groups = <KatsSheetGroup>[
      KatsSheetGroup(
        title: 'ROOM OPTIONS',
        items: [
          KatsSheetItem(
            title: 'Minimize Room',
            subtitle: 'Keep room playing in background',
            icon: Icons.picture_in_picture_alt_rounded,
            iconColor: const Color(0xFFFF7A45),
            onTap: () {
              Navigator.pop(context);
              controller.minimize();
              Navigator.of(context).pop();
            },
          ),
          KatsSheetItem(
            title: 'Leave Room',
            subtitle: 'Leave without closing room for others',
            icon: Icons.exit_to_app_rounded,
            isDestructive: true,
            onTap: () async {
              Navigator.pop(context);
              await controller.leaveRoom();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      if (!room.isPermanent)
        KatsSheetGroup(
          title: 'HOST DISSOLVE',
          items: [
            KatsSheetItem(
              title: 'Dissolve Room',
              subtitle: 'End party and disconnect all members',
              icon: Icons.delete_sweep_rounded,
              isDestructive: true,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: const Color(0xFF101012),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      side: const BorderSide(color: Color(0xFF2C2C2E)),
                    ),
                    title: Row(
                      children: [
                        const Icon(Icons.delete_sweep_rounded, color: Color(0xFFED4956), size: 20),
                        SizedBox(width: 8.w),
                        const Text(
                          'Dissolve Room?',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      'Are you sure you want to dissolve "${room.title}"?\n\nAll participants will be disconnected and the room will be closed permanently.',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Color(0xFF8E8E93),
                        height: 1.3,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFED4956),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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
        ),
    ];

    KatsBottomSheet.showGroupedMenu(
      context,
      title: 'Exit Voice Room',
      groups: groups,
    );
  }

  void _openRoomMusicPicker(VoiceRoomController controller) {
    HapticFeedback.lightImpact();
    VoiceRoomMusicSheet.show(context, controller);
  }

  void _showRoomToolsSheet(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    KatsBottomSheet.showCustom(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final isMusicOn = controller.isMusicEnabled;
          final hasPlayingMusic = controller.roomMusicTitle.isNotEmpty;
          final musicTitle = controller.roomMusicTitle;
          final musicArtist = controller.roomMusicArtist;
          final musicArtwork = controller.roomMusicArtwork;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: const Color(0xFFFF7A45),
                        size: 18.r,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'Room Tools & Applications',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Background Music Toggle Card
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  color: const Color(0xFF1E1E20),
                  child: Row(
                    children: [
                      Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 20.r,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Background Music',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              controller.isHost
                                  ? (isMusicOn
                                      ? (hasPlayingMusic
                                          ? 'Now playing: $musicTitle'
                                          : 'Enabled: Tap below to browse library')
                                      : 'Enable music playback in the room')
                                  : (isMusicOn
                                      ? (hasPlayingMusic
                                          ? 'Now playing: $musicTitle'
                                          : 'Music active (controlled by host)')
                                      : 'Disabled by room owner'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: isMusicOn ? const Color(0xFFFFB800) : const Color(0xFF8E8E93),
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (controller.isHost)
                        Switch.adaptive(
                          value: isMusicOn,
                          activeThumbColor: const Color(0xFFFF7A45),
                          activeTrackColor: const Color(0xFFFF7A45).withValues(alpha: 0.45),
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            controller.toggleMusicEnabled(val);
                            setSheetState(() {});
                            setState(() {});
                          },
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isMusicOn ? const Color(0xFF4ADE80).withValues(alpha: 0.15) : Colors.white10,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: isMusicOn ? const Color(0xFF4ADE80).withValues(alpha: 0.3) : Colors.white12,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            isMusicOn ? 'ACTIVE' : 'HOST ONLY',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: isMusicOn ? const Color(0xFF4ADE80) : Colors.white38,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // If Music is enabled: Show Now Playing Controls or Shortcut Button to pick
              if (isMusicOn) ...[
                SizedBox(height: 10.h),
                if (hasPlayingMusic)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      color: const Color(0xFF1E1E20),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: musicArtwork.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: musicArtwork,
                                    width: 38.r,
                                    height: 38.r,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 38.r,
                                    height: 38.r,
                                    color: Colors.white10,
                                    child: const Icon(Icons.music_note, color: Colors.white54),
                                  ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  musicTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: Colors.white,
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  controller.isRoomMusicPlaying
                                      ? (musicArtist.isNotEmpty ? musicArtist : 'Streaming...')
                                      : 'Paused',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: controller.isRoomMusicPlaying
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF8E8E93),
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (controller.isHost)
                            IconButton(
                              icon: Icon(
                                controller.isRoomMusicPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: const Color(0xFFFF7A45),
                                size: 28.r,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                controller.togglePauseRoomMusic();
                                setSheetState(() {});
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.tune_rounded,
                              color: Colors.white70,
                              size: 20.r,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              VoiceRoomMusicSheet.show(context, controller);
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: Material(
                      color: const Color(0xFF1E1E20),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _openRoomMusicPicker(controller);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.library_music_rounded, color: const Color(0xFFFF7A45), size: 18.r),
                              SizedBox(width: 8.w),
                              Text(
                                'Search & Add Music from Library',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  color: const Color(0xFFFF7A45),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],

              SizedBox(height: 10.h),

              // 2. Sound Effects / Voice FX Shortcut Card
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: Material(
                  color: const Color(0xFF1E1E20),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showVoiceEffectsSheet();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voice Changer & Effects',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: Colors.white,
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Apply sound filters or voice pitch changer',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: const Color(0xFF8E8E93),
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomIcons.sparkles(
                            color: const Color(0xFFA78BFA),
                            size: 18.5.r,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRoomOptions(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    final isHost = controller.isHost ||
        (controller.currentUser != null &&
            room.host.id.toString() == controller.currentUser!.id.toString());

    final headerWidget = Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
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
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  room.isPermanent ? 'Permanent Room' : '24-Hour Temporary Room',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: room.isPermanent ? const Color(0xFFFFB800) : const Color(0xFF8E8E93),
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
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.white70, size: 10),
                  SizedBox(width: 4.w),
                  Text(
                    'Locked',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
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
    );

    final groups = <KatsSheetGroup>[];

    if (isHost) {
      groups.add(
        KatsSheetGroup(
          title: 'HOST CONTROLS',
          items: [
            KatsSheetItem(
              title: 'Edit Room & Icon',
              subtitle: 'Change room name and set room image icon',
              icon: Icons.edit_note_rounded,
              onTap: () {
                Navigator.pop(context);
                EditVoiceRoomScreen.open(context, room, controller);
              },
            ),
            KatsSheetItem(
              title: room.isLocked ? 'Unlock Room' : 'Lock Room',
              subtitle: room.isLocked
                  ? 'Room is currently locked. Tap to unlock.'
                  : 'Set a 4-digit PIN to restrict room entry.',
              icon: room.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              iconColor: room.isLocked ? const Color(0xFFFFB800) : null,
              onTap: () async {
                Navigator.pop(context);
                if (room.isLocked) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF101012),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        side: const BorderSide(color: Color(0xFF2C2C2E)),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Unlock Room?',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      content: const Text(
                        'Anyone will be able to enter your room without a PIN.',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Color(0xFF8E8E93),
                          height: 1.3,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A45),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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
            if (!room.isPermanent)
              KatsSheetItem(
                title: 'Dissolve Room',
                subtitle: 'Close room permanently and disconnect all participants',
                icon: Icons.delete_sweep_rounded,
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF101012),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        side: const BorderSide(color: Color(0xFF2C2C2E)),
                      ),
                      title: Row(
                        children: [
                          const Icon(Icons.delete_sweep_rounded, color: Color(0xFFED4956), size: 20),
                          SizedBox(width: 8.w),
                          const Text(
                            'Dissolve Room?',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        'Are you sure you want to dissolve "${room.title}"?\n\nAll participants will be disconnected and the room will be closed permanently.',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Color(0xFF8E8E93),
                          height: 1.3,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED4956),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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
        ),
      );
    }

    groups.add(
      KatsSheetGroup(
        title: isHost ? 'ROOM DETAILS' : 'ROOM ACTIONS',
        items: [
          KatsSheetItem(
            title: 'Copy Room ID',
            subtitle: 'Room ID: ${room.roomCode.isNotEmpty ? room.roomCode : room.id}',
            icon: Icons.copy_rounded,
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: room.roomCode.isNotEmpty ? room.roomCode : room.id.toString()));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Room ID copied: ${room.roomCode.isNotEmpty ? room.roomCode : room.id}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          if (!isHost) ...[
            KatsSheetItem(
              title: 'Report Room',
              subtitle: 'Report inappropriate content or violation',
              icon: Icons.flag_outlined,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you. Room report submitted for review.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            KatsSheetItem(
              title: 'Leave Room',
              subtitle: 'Exit this voice room',
              icon: Icons.logout_rounded,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _handleExit(context, room, controller);
              },
            ),
          ],
        ],
      ),
    );

    KatsBottomSheet.showGroupedMenu(
      context,
      header: headerWidget,
      groups: groups,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.minimize();
        Navigator.of(context).pop();
      },
      child: Scaffold(
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
                    Color(0xFF1E2028),
                    Color(0xFF14151B),
                    Color(0xFF0D0E12),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // WePlay-Style Top Header Bar (Ultra-Compact, Top-Aligned)
                  Padding(
                    padding: EdgeInsets.only(left: 10.w, right: 10.w, top: 2.h, bottom: 4.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Arrow (<) at the very top (20.r) - Minimizes room to floating pill
                        Padding(
                          padding: EdgeInsets.only(top: 1.h),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              controller.minimize();
                              Navigator.of(context).pop();
                            },
                          child: Container(
                            width: 20.r,
                            height: 20.r,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // Room Info Capsule (Delicate small words: Title 9sp, ID 7sp)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.38),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Cyan Diamond Level Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                      ),
                                      borderRadius: BorderRadius.circular(3.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.hexagon_rounded, size: 6.5, color: Colors.white),
                                        SizedBox(width: 1.5.w),
                                        Text(
                                          '3',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 6.5.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Flexible(
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
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            Clipboard.setData(ClipboardData(text: '${room.id}'));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Room ID ${room.id} copied!'),
                                                duration: const Duration(seconds: 1),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: Text(
                                            '${room.category.isNotEmpty ? room.category : "Music"} P${room.id} Rooms',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.6),
                                              fontSize: 7.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(top: 2.h, left: 2.w),
                              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(5.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bar_chart_rounded, size: 8, color: Color(0xFFFFB800)),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Hourly Ranking',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 7.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 5.w),

                      // Right Controls: [-] Minimize, [ 1 ] Participant, [...] Options (Nasa pinakataas at size 20)
                      Padding(
                        padding: EdgeInsets.only(top: 1.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Minimize pill [-] (20.r)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                controller.minimize();
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: 20.r,
                                height: 20.r,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 7.w,
                                    height: 1.4.h,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.w),

                            // 2. Audience / Participant Pill [ 1 ] (20.r)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showAudienceListSheet(context, room, controller);
                              },
                              child: Container(
                                height: 20.r,
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${room.participantCount}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 6.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.w),

                            // 3. More options [...] (Unwrapped clean icon)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showRoomOptions(context, room, controller);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 4.h),

                // Host Stage Area (Center Top)
                Center(
                  child: VoiceSeatWidget(
                    key: const ValueKey('voice_seat_host'),
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

                SizedBox(height: 14.h),

                // WePlay 8 Guest Seats in Two 2x2 Clusters with Wave Connectors
                RepaintBoundary(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Column(
                      children: [
                        // Row 1: Left Pair (0, 1) & Right Pair (2, 3)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSeatCluster(
                              seats.isNotEmpty ? seats[0] : VoiceSeat(seatIndex: 0),
                              seats.length > 1 ? seats[1] : VoiceSeat(seatIndex: 1),
                            ),
                            SizedBox(width: 26.w),
                            _buildSeatCluster(
                              seats.length > 2 ? seats[2] : VoiceSeat(seatIndex: 2),
                              seats.length > 3 ? seats[3] : VoiceSeat(seatIndex: 3),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        // Row 2: Left Pair (4, 5) & Right Pair (6, 7)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSeatCluster(
                              seats.length > 4 ? seats[4] : VoiceSeat(seatIndex: 4),
                              seats.length > 5 ? seats[5] : VoiceSeat(seatIndex: 5),
                            ),
                            SizedBox(width: 26.w),
                            _buildSeatCluster(
                              seats.length > 6 ? seats[6] : VoiceSeat(seatIndex: 6),
                              seats.length > 7 ? seats[7] : VoiceSeat(seatIndex: 7),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 6.h),

                // Live Floating Chat Stream (Directly under seats 5, 6, 7, 8)
                Expanded(
                  child: RepaintBoundary(
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

                        final isMedia = msg.message.startsWith('http') &&
                            (msg.message.contains('.gif') ||
                             msg.message.contains('giphy.com') ||
                             msg.message.contains('tenor.com') ||
                             msg.message.contains('/attachments/') ||
                             msg.message.contains('.webp') ||
                             msg.message.contains('.png') ||
                             msg.message.contains('.jpg') ||
                             msg.message.contains('.jpeg'));

                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 2.5.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. User Header: Avatar (same size as font) + Name (reduced weight) + Charm Badge
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 14.r,
                                      height: 14.r,
                                      child: msg.sender.avatarUrl.trim().isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: msg.sender.avatarUrl.trim(),
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: Colors.white12,
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                color: const Color(0xFFFF7A45),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  msg.sender.fullName.isNotEmpty
                                                      ? msg.sender.fullName[0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 7.5.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: const Color(0xFFFF7A45),
                                              alignment: Alignment.center,
                                              child: Text(
                                                msg.sender.fullName.isNotEmpty
                                                    ? msg.sender.fullName[0].toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 7.5.sp,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: 4.5.w),
                                  Flexible(
                                    child: Text(
                                      msg.sender.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFFFF8A50),
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Image.asset(
                                    msg.sender.charmBadgeAsset,
                                    height: 11.5.h,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                              SizedBox(height: 3.h),

                              // 2. Message Bubble (Yung message lang ang nakabalot sa pill!)
                              Container(
                                padding: isMedia
                                    ? EdgeInsets.all(3.r)
                                    : EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.5.h),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 0.7,
                                  ),
                                ),
                                child: isMedia
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(9.r),
                                        child: CachedNetworkImage(
                                          imageUrl: msg.message,
                                          height: 95.h,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            width: 95.w,
                                            height: 95.h,
                                            color: Colors.white10,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFFFF7A45),
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => const Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.white38,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        msg.message,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.28,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                ),

                SizedBox(height: 10.h),

                // WePlay Bottom Action Bar (All Icons Wrapped in Glassmorphic Pills)
                Container(
                  padding: EdgeInsets.only(
                    left: 8.w,
                    right: 8.w,
                    top: 6.h,
                    bottom: 6.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // 1. Speaker Pill Button (Audio Output)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _toggleSpeaker();
                        },
                        child: Container(
                          width: 28.r,
                          height: 28.r,
                          decoration: BoxDecoration(
                            color: _isSpeakerMuted
                                ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isSpeakerMuted
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.14),
                              width: 0.7,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _isSpeakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: _isSpeakerMuted ? const Color(0xFFEF4444) : Colors.white,
                            size: 17.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 2. Microphone Pill Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (!controller.isOnMic) {
                            final empty = seats.firstWhere(
                              (s) => s.user == null && !s.isLocked,
                              orElse: () => VoiceSeat(seatIndex: -1),
                            );
                            if (empty.seatIndex >= 0) {
                              controller.takeSeat(empty.seatIndex);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('All mic seats are occupied')),
                              );
                            }
                          } else {
                            controller.toggleMute();
                            setState(() {});
                          }
                        },
                        child: Container(
                          width: 28.r,
                          height: 28.r,
                          decoration: BoxDecoration(
                            color: controller.isOnMic && controller.isMuted
                                ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                                : (controller.isOnMic
                                    ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.1)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: controller.isOnMic && controller.isMuted
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                  : (controller.isOnMic
                                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.14)),
                              width: 0.7,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: controller.isOnMic && controller.isMuted
                              ? CustomIcons.micOffParty(
                                  color: const Color(0xFFEF4444),
                                  size: 17.r,
                                )
                              : CustomIcons.micParty(
                                  color: controller.isOnMic
                                      ? const Color(0xFF10B981)
                                      : Colors.white,
                                  size: 17.r,
                                ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 3. Type message... Pill Input (Takes flex)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showChatInputSheet();
                          },
                          child: Container(
                            height: 28.r,
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                                width: 0.7,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  'Type...',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 4. Emoji Reaction Pill Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showQuickEmojiSheet();
                        },
                        child: Container(
                          width: 28.r,
                          height: 28.r,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                              width: 0.7,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.sentiment_satisfied_alt_rounded,
                            color: Colors.white,
                            size: 17.5.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 5. Gift Pill Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          VoiceRoomGiftSheet.show(context, room: room);
                        },
                        child: Container(
                          width: 28.r,
                          height: 28.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A45).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                              width: 0.7,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: CustomIcons.giftBox(
                            color: const Color(0xFFFF7A45),
                            size: 17.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 6. Voice Effects Pill Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showVoiceEffectsSheet();
                        },
                        child: Container(
                          width: 28.r,
                          height: 28.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA78BFA).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                              width: 0.7,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: CustomIcons.sparkles(
                            color: const Color(0xFFA78BFA),
                            size: 17.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),

                      // 7. Grid / Tools Pill Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showRoomToolsSheet(context, room, controller);
                        },
                        child: Container(
                          width: 28.r,
                          height: 28.r,
                          decoration: BoxDecoration(
                            color: controller.isMusicEnabled
                                ? const Color(0xFFFF7A45).withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: controller.isMusicEnabled
                                  ? const Color(0xFFFF7A45).withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.14),
                              width: 0.7,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: controller.isMusicEnabled ? const Color(0xFFFF7A45) : Colors.white,
                            size: 16.5.r,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating "Add Music / Now Playing" Overlay Pill (Top Right, directly below more options [...])
          if (controller.isMusicEnabled || controller.roomMusicTitle.isNotEmpty || controller.musicQueue.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 34.h,
              right: 10.w,
              child: Builder(
                builder: (context) {
                  final effectiveTrack = controller.roomCdnTrack ??
                      (controller.musicQueue.isNotEmpty
                          ? (controller.currentQueueIndex >= 0 && controller.currentQueueIndex < controller.musicQueue.length
                              ? controller.musicQueue[controller.currentQueueIndex]
                              : controller.musicQueue.first)
                          : null);
                  final musicTitle = controller.roomMusicTitle.isNotEmpty
                      ? controller.roomMusicTitle
                      : (effectiveTrack?.title ?? '');
                  final musicArtwork = controller.roomMusicArtwork.isNotEmpty
                      ? controller.roomMusicArtwork
                      : (effectiveTrack?.artworkUrl ?? '');
                  final hasMusic = musicTitle.isNotEmpty;
                  final isLoading = controller.isRoomMusicLoading;

                  // 1. If we have track info (loading or playing), show artwork + title + state
                  if (hasMusic) {
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        VoiceRoomMusicSheet.show(context, controller);
                      },
                      child: Container(
                        height: 22.h,
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141522).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFFFF7A45).withValues(alpha: 0.75),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A45).withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: musicArtwork.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: musicArtwork,
                                      width: 14.r,
                                      height: 14.r,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 14.r,
                                        height: 14.r,
                                        color: const Color(0xFFFF7A45),
                                        child: Icon(Icons.music_note_rounded, size: 9.r, color: Colors.white),
                                      ),
                                    )
                                  : Container(
                                      width: 14.r,
                                      height: 14.r,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.music_note_rounded, size: 9.r, color: Colors.white),
                                    ),
                            ),
                            SizedBox(width: 4.w),
                            MarqueeText(
                              text: musicTitle,
                              maxWidth: 72.w,
                              isPlaying: controller.isRoomMusicPlaying && !isLoading,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            if (isLoading)
                              SizedBox(
                                width: 11.r,
                                height: 11.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A45)),
                                ),
                              )
                            else
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  controller.togglePauseRoomMusic();
                                },
                                child: Icon(
                                  controller.isRoomMusicPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 13.r,
                                  color: const Color(0xFFFF7A45),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 2. If loading with no track info yet, show compact loading pill
                  if (isLoading) {
                    return Container(
                      height: 22.h,
                      padding: EdgeInsets.symmetric(horizontal: 7.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141522).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFFF7A45).withValues(alpha: 0.7),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10.r,
                            height: 10.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A45)),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // No track playing yet: Show compact "Add Music +"
                  return GestureDetector(
                    onTap: () => _openRoomMusicPicker(controller),
                    child: Container(
                      height: 22.h,
                      padding: EdgeInsets.symmetric(horizontal: 7.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141522).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFFF7A45).withValues(alpha: 0.7),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A45).withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14.r,
                            height: 14.r,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 9.r,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Add Music',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Icon(
                            Icons.add_rounded,
                            size: 11.r,
                            color: const Color(0xFFFF7A45),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                    top: 80.h,
                    left: 20.w,
                    right: 20.w,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E1065), Color(0xFF701A75), Color(0xFF9D174D)],
                          ),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sender Avatar
                            UserAvatarWithFrame(
                              avatarUrl: controller.activeGiftSender?.avatarUrl ?? '',
                              avatarFrame: controller.activeGiftSender?.avatarFrame,
                              radius: 13.r,
                              preserveLayoutFootprint: true,
                              initials: (controller.activeGiftSender?.fullName.isNotEmpty ?? false)
                                  ? controller.activeGiftSender!.fullName[0].toUpperCase()
                                  : '?',
                            ),
                            SizedBox(width: 8.w),
                            // Details
                            Flexible(
                              child: RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: controller.activeGiftSender?.fullName ?? '',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' sent ',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5.sp,
                                      ),
                                    ),
                                    TextSpan(
                                      text: controller.activePlayingGift?.name ?? '',
                                      style: TextStyle(
                                        color: const Color(0xFFFFD54F),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' to ',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5.sp,
                                      ),
                                    ),
                                    TextSpan(
                                      text: controller.activeGiftReceiver?.fullName ?? '',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            // Gift Emoji
                            Text(
                              controller.activePlayingGift?.emoji ?? '🎁',
                              style: TextStyle(fontSize: 20.sp),
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
    ),
  );
}
}

/// ECG / Sound Wave waveform painter connecting horizontal voice seat pairs (WePlay style)
class SoundWavePainter extends CustomPainter {
  final Color color;
  const SoundWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    final path = Path();
    path.moveTo(0, cy);
    path.lineTo(w * 0.28, cy);
    path.lineTo(w * 0.38, cy + 4);
    path.lineTo(w * 0.48, cy - 7);
    path.lineTo(w * 0.58, cy + 7);
    path.lineTo(w * 0.68, cy - 3);
    path.lineTo(w * 0.74, cy);
    path.lineTo(w, cy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SoundWavePainter oldDelegate) => oldDelegate.color != color;
}
