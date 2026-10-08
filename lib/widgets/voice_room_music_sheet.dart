import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room_music_track.dart';
import '../screens/voice_room/voice_room_music_picker_screen.dart';
import '../services/voice_room_controller.dart';
import 'marquee_text.dart';

/// Threads-Style Dedicated Voice Room Music Queue Bottom Sheet.
/// Displays Currently Playing track, playlist queue list, and a prominent
/// "Pick" button with a microphone icon that navigates to the full-page Music Picker.
class VoiceRoomMusicSheet extends StatefulWidget {
  final VoiceRoomController controller;

  const VoiceRoomMusicSheet({
    super.key,
    required this.controller,
  });

  static void show(BuildContext context, VoiceRoomController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      barrierColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => VoiceRoomMusicSheet(controller: controller),
    );
  }

  @override
  State<VoiceRoomMusicSheet> createState() => _VoiceRoomMusicSheetState();
}

class _VoiceRoomMusicSheetState extends State<VoiceRoomMusicSheet> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isMusicPlaying = widget.controller.isRoomMusicPlaying;
        final hasActiveMusic = widget.controller.roomMusicTitle.isNotEmpty;
        final queue = widget.controller.musicQueue;
        final bottomSafe = MediaQuery.of(context).padding.bottom;

        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: const Color(0xFF101012),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.only(
            left: 14.w,
            right: 14.w,
            bottom: bottomSafe > 0 ? bottomSafe + 6.h : 12.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              // Drag handle per Muse standard: 36.w x 3.5.h, #38383A
              Center(
                child: Container(
                  width: 36.w,
                  height: 3.5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38383A),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              // Header Row: Sleek & Compact
              Row(
                children: [
                  Container(
                    width: 26.r,
                    height: 26.r,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: Colors.white,
                      size: 14.r,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Room Music Queue',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '${queue.length}',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  color: const Color(0xFFFF7A45),
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Plays continuously • Auto-loops in room',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white38,
                            fontSize: 9.5.sp,
                            letterSpacing: -0.1,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (queue.isNotEmpty && widget.controller.isHost)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.controller.clearQueue();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFED4956).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: const Color(0xFFED4956),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white60, size: 17.r),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16.r,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              SizedBox(height: 10.h),

              // Currently Playing Hero Card (if active)
              if (hasActiveMusic) ...[
                _buildNowPlayingHeroCard(isMusicPlaying),
                SizedBox(height: 10.h),
              ],

              // Queue List Header
              Row(
                children: [
                  Text(
                    'UP NEXT IN QUEUE',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Colors.white60,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat_rounded, color: const Color(0xFF4ADE80), size: 9.r),
                        SizedBox(width: 2.5.w),
                        Text(
                          'Looping',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: const Color(0xFF4ADE80),
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${queue.length} track${queue.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Colors.white38,
                      fontSize: 9.5.sp,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6.h),

              // Scrollable Queue Content
              Expanded(
                child: queue.isEmpty
                    ? _buildEmptyQueueView()
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        itemCount: queue.length,
                        separatorBuilder: (_, __) => SizedBox(height: 6.h),
                        itemBuilder: (context, index) {
                          return _buildQueueItem(queue[index], index);
                        },
                      ),
              ),

              SizedBox(height: 8.h),

              // Sticky Bottom "Pick" Action Button with Microphone Icon
              _buildPickMusicButton(),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // NOW PLAYING HERO CARD (INSET GROUPED ISLAND)
  // ==========================================
  Widget _buildNowPlayingHeroCard(bool isMusicPlaying) {
    final track = widget.controller.roomCdnTrack;
    final canControl = widget.controller.canControlCurrentTrack;

    return Container(
      padding: EdgeInsets.all(9.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: widget.controller.roomMusicArtwork.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.controller.roomMusicArtwork,
                        width: 40.r,
                        height: 40.r,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 40.r,
                          height: 40.r,
                          color: Colors.white10,
                          child: Icon(Icons.music_note, color: Colors.white38, size: 18.r),
                        ),
                      )
                    : Container(
                        width: 40.r,
                        height: 40.r,
                        color: Colors.white10,
                        child: Icon(Icons.music_note, color: Colors.white38, size: 18.r),
                      ),
              ),
              SizedBox(width: 9.w),
              // Title & Artist & DJ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: widget.controller.roomMusicTitle,
                      maxWidth: 150.w,
                      isPlaying: isMusicPlaying,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMusicPlaying ? 'Streaming in room' : 'Paused',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: isMusicPlaying ? const Color(0xFF4ADE80) : Colors.white38,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (track?.addedByUsername != null && track!.addedByUsername!.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 8.sp)),
                          ),
                          Flexible(
                            child: Text(
                              'DJ: @${track.addedByUsername}',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: const Color(0xFFFF7A45),
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Playback Controls
              if (canControl) ...[
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 19.r),
                  tooltip: 'Previous song',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 14.r,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.controller.skipToPreviousMusic();
                  },
                ),
                SizedBox(width: 4.w),
                IconButton(
                  icon: Icon(
                    isMusicPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: const Color(0xFFFF7A45),
                    size: 24.r,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16.r,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.controller.togglePauseRoomMusic();
                  },
                ),
                SizedBox(width: 4.w),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded, color: Colors.white70, size: 19.r),
                  tooltip: 'Next in queue',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 14.r,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.controller.skipToNextMusic();
                  },
                ),
                SizedBox(width: 6.w),
                IconButton(
                  icon: Icon(Icons.stop_circle_outlined, color: const Color(0xFFED4956), size: 18.r),
                  tooltip: 'Stop playback',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 14.r,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.controller.stopRoomMusic();
                  },
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.equalizer_rounded, color: const Color(0xFFFF7A45), size: 11.r),
                      SizedBox(width: 3.w),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: const Color(0xFFFF7A45),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Volume Slider (Available to everyone)
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.volume_down_rounded, color: Colors.white38, size: 12.r),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 1.8,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3.5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                  ),
                  child: Slider(
                    value: widget.controller.roomMusicVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: const Color(0xFFFF7A45),
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      widget.controller.setRoomMusicVolume(val);
                    },
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded, color: Colors.white38, size: 12.r),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY QUEUE VIEW (THREADS-STYLE ISLAND)
  // ==========================================
  Widget _buildEmptyQueueView() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E20),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 0.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF7A45).withValues(alpha: 0.15),
                    const Color(0xFFEC4899).withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: Icon(Icons.queue_music_rounded, color: const Color(0xFFFF7A45), size: 22.r),
            ),
            SizedBox(height: 8.h),
            Text(
              'Room Queue is Empty',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'No songs lined up yet.\nTap "Pick" below to browse Top 20 Trending, Favorites, or search songs to play!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white38,
                fontSize: 10.5.sp,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // QUEUE ITEM TILE (THREADS-STYLE INSET ISLAND)
  // ==========================================
  Widget _buildQueueItem(VoiceRoomMusicTrack track, int index) {
    final currentTrackId = widget.controller.roomCdnTrack?.id;
    final isThisPlaying = track.id == currentTrackId;
    final isPlaying = widget.controller.isRoomMusicPlaying;
    final isMyTrack = track.addedByUserId != null &&
        track.addedByUserId.toString() == widget.controller.currentUser?.id?.toString();
    final canControlThis = widget.controller.isHost ||
        isMyTrack ||
        (isThisPlaying && widget.controller.canControlCurrentTrack);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isThisPlaying
            ? const Color(0xFFFF7A45).withValues(alpha: 0.12)
            : const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(11.r),
        border: Border.all(
          color: isThisPlaying
              ? const Color(0xFFFF7A45).withValues(alpha: 0.5)
              : const Color(0xFF2C2C2E),
          width: isThisPlaying ? 0.9 : 0.6,
        ),
      ),
      child: Row(
        children: [
          // Index Badge or Playing Indicator
          Container(
            width: 20.r,
            height: 20.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isThisPlaying
                  ? const LinearGradient(
                      colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                    )
                  : null,
              color: isThisPlaying ? null : const Color(0xFFFF7A45).withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: isThisPlaying
                ? Icon(
                    isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 11.r,
                  )
                : Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: const Color(0xFFFF7A45),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          SizedBox(width: 7.w),

          // Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: track.artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl,
                    width: 32.r,
                    height: 32.r,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 32.r,
                      height: 32.r,
                      color: Colors.white10,
                      child: Icon(Icons.music_note, color: Colors.white38, size: 16.r),
                    ),
                  )
                : Container(
                    width: 32.r,
                    height: 32.r,
                    color: Colors.white10,
                    child: Icon(Icons.music_note, color: Colors.white38, size: 16.r),
                  ),
          ),
          SizedBox(width: 8.w),

          // Title & Artist & Adder info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Colors.white,
                          fontSize: 11.5.sp,
                          fontWeight: isThisPlaying ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (isThisPlaying) ...[
                      SizedBox(width: 5.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A45).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          isPlaying ? 'NOW PLAYING' : 'PAUSED',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: const Color(0xFFFF7A45),
                            fontSize: 7.5.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Colors.white38,
                          fontSize: 9.5.sp,
                        ),
                      ),
                    ),
                    if (track.addedByUsername != null && track.addedByUsername!.isNotEmpty)
                      Text(
                        'by @${track.addedByUsername}',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: const Color(0xFFFF7A45).withValues(alpha: 0.8),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Action Controls: Play Now
          if (canControlThis)
            IconButton(
              icon: Icon(
                isThisPlaying
                    ? (isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded)
                    : Icons.play_arrow_rounded,
                color: const Color(0xFFFF7A45),
                size: 20.r,
              ),
              tooltip: isThisPlaying
                  ? (isPlaying ? 'Pause' : 'Resume')
                  : 'Play this now',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 14.r,
              onPressed: () {
                HapticFeedback.lightImpact();
                if (isThisPlaying) {
                  widget.controller.togglePauseRoomMusic();
                } else {
                  widget.controller.playQueueIndex(index);
                }
              },
            ),

          // Delete from Queue (Host or Adder)
          if (widget.controller.isHost || isMyTrack) ...[
            SizedBox(width: 8.w),
            IconButton(
              icon: Icon(Icons.close_rounded, color: Colors.white38, size: 15.r),
              tooltip: 'Remove from queue',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 14.r,
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.controller.removeFromQueue(index);
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // STICKY BOTTOM "PICK" BUTTON WITH MIC ICON
  // ==========================================
  Widget _buildPickMusicButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        VoiceRoomMusicPickerScreen.open(context, widget.controller);
      },
      child: Container(
        width: double.infinity,
        height: 46.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(13.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 16.r,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Pick',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Top 20 • Favorites • Search',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 6.w),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 11.r,
            ),
          ],
        ),
      ),
    );
  }
}
