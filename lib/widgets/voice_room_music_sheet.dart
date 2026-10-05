import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room_music_track.dart';
import '../services/voice_room_controller.dart';
import '../services/voice_room_music_service.dart';

/// Modal bottom sheet for browsing, searching, and streaming Bunny CDN music in Voice Rooms.
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
      backgroundColor: const Color(0xFF14151B),
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
  final TextEditingController _searchController = TextEditingController();
  final VoiceRoomMusicService _musicService = VoiceRoomMusicService();

  List<VoiceRoomMusicTrack> _allTracks = [];
  List<VoiceRoomMusicTrack> _filteredTracks = [];
  List<String> _genres = ['All'];
  String _selectedGenre = 'All';
  bool _isLoading = true;
  String? _loadingTrackId;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final result = await _musicService.getTracks(forceRefresh: forceRefresh);
    if (!mounted) return;

    setState(() {
      _allTracks = result.tracks;
      _genres = result.genres;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredTracks = _allTracks.where((track) {
        final matchesGenre = _selectedGenre == 'All' ||
            track.genre.toLowerCase() == _selectedGenre.toLowerCase();
        final matchesQuery = query.isEmpty ||
            track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query) ||
            track.genre.toLowerCase().contains(query);
        return matchesGenre && matchesQuery;
      }).toList();
    });
  }

  Future<void> _playTrack(VoiceRoomMusicTrack track) async {
    HapticFeedback.lightImpact();
    setState(() => _loadingTrackId = track.id);

    await widget.controller.playCdnMusic(track);

    if (!mounted) return;
    setState(() => _loadingTrackId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1F2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        content: Row(
          children: [
            const Icon(Icons.music_note_rounded, color: Color(0xFFFF7A45)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Now streaming: ${track.title}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isMusicPlaying = widget.controller.isRoomMusicPlaying;
        final currentCdnTrack = widget.controller.roomCdnTrack;

        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),
              // Drag handle
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 18.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice Room Music',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_allTracks.length} high-quality tracks available',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: Colors.white70, size: 20.r),
                    tooltip: 'Refresh library',
                    onPressed: () => _loadTracks(forceRefresh: true),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20.r),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Currently Playing Banner (if active)
              if (widget.controller.roomMusicTitle.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: widget.controller.roomMusicArtwork.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.controller.roomMusicArtwork,
                                    width: 44.r,
                                    height: 44.r,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 44.r,
                                      height: 44.r,
                                      color: Colors.white10,
                                      child: const Icon(Icons.music_note, color: Colors.white38),
                                    ),
                                  )
                                : Container(
                                    width: 44.r,
                                    height: 44.r,
                                    color: Colors.white10,
                                    child: const Icon(Icons.music_note, color: Colors.white38),
                                  ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        isMusicPlaying ? 'STREAMING' : 'PAUSED',
                                        style: TextStyle(
                                          color: isMusicPlaying
                                              ? const Color(0xFF4ADE80)
                                              : Colors.white54,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  widget.controller.roomMusicTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  widget.controller.roomMusicArtist.isNotEmpty
                                      ? widget.controller.roomMusicArtist
                                      : 'KatsKlub Music',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isMusicPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              color: const Color(0xFFFF7A45),
                              size: 32.r,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.controller.togglePauseRoomMusic();
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 26.r),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.controller.stopRoomMusic();
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Volume Slider Row
                      Row(
                        children: [
                          Icon(Icons.volume_down_rounded, color: Colors.white54, size: 16.r),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                          Icon(Icons.volume_up_rounded, color: Colors.white54, size: 16.r),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
              ],

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search songs or artists...',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 13.sp,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 20.r),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: Colors.white38, size: 18.r),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              // Genre Filter Chips
              if (_genres.isNotEmpty)
                SizedBox(
                  height: 32.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _genres.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8.w),
                    itemBuilder: (context, index) {
                      final g = _genres[index];
                      final isSelected = g.toLowerCase() == _selectedGenre.toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedGenre = g;
                            _applyFilter();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                                  )
                                : null,
                            color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            g,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              SizedBox(height: 10.h),

              // Tracks List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF7A45)),
                      )
                    : _filteredTracks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.music_off_rounded, color: Colors.white24, size: 48.r),
                                SizedBox(height: 10.h),
                                Text(
                                  'No songs found matching "${_searchController.text}"',
                                  style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredTracks.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              final track = _filteredTracks[index];
                              final isCurrent = currentCdnTrack?.id == track.id;
                              final isItemLoading = _loadingTrackId == track.id;

                              return Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xFFFF7A45).withValues(alpha: 0.1)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFFFF7A45).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: track.artworkUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: track.artworkUrl,
                                              width: 44.r,
                                              height: 44.r,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Container(
                                                width: 44.r,
                                                height: 44.r,
                                                color: Colors.white10,
                                                child: const Icon(Icons.music_note, color: Colors.white38),
                                              ),
                                            )
                                          : Container(
                                              width: 44.r,
                                              height: 44.r,
                                              color: Colors.white10,
                                              child: const Icon(Icons.music_note, color: Colors.white38),
                                            ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.sp,
                                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Row(
                                            children: [
                                              Text(
                                                track.artist,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11.sp,
                                                ),
                                              ),
                                              if (track.genre.isNotEmpty && track.genre != 'General') ...[
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                                                  child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
                                                ),
                                                Text(
                                                  track.genre,
                                                  style: TextStyle(
                                                    color: const Color(0xFFFF7A45),
                                                    fontSize: 10.5.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    InkWell(
                                      onTap: isItemLoading ? null : () => _playTrack(track),
                                      borderRadius: BorderRadius.circular(16.r),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                        decoration: BoxDecoration(
                                          gradient: isCurrent
                                              ? const LinearGradient(
                                                  colors: [Color(0xFF4ADE80), Color(0xFF10B981)],
                                                )
                                              : const LinearGradient(
                                                  colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                                                ),
                                          borderRadius: BorderRadius.circular(16.r),
                                        ),
                                        child: isItemLoading
                                            ? SizedBox(
                                                width: 14.r,
                                                height: 14.r,
                                                child: const CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isCurrent && isMusicPlaying
                                                        ? Icons.equalizer_rounded
                                                        : Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: 14.sp,
                                                  ),
                                                  SizedBox(width: 3.w),
                                                  Text(
                                                    isCurrent ? 'Playing' : 'Play',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }
}
