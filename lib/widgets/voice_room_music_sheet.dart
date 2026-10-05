import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room_music_track.dart';
import '../services/voice_room_controller.dart';
import '../services/voice_room_music_service.dart';
import 'marquee_text.dart';

/// Modal bottom sheet for browsing, searching, favoriting, and queueing Bunny CDN music in Voice Rooms.
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

  int _selectedTabIndex = 0; // 0: Search, 1: Favorites, 2: Queue
  List<VoiceRoomMusicTrack> _allTracks = [];
  List<VoiceRoomMusicTrack> _filteredTracks = [];
  List<VoiceRoomMusicTrack> _favoriteTracks = [];
  Set<String> _favoriteTrackIds = {};
  List<String> _genres = ['All'];
  String _selectedGenre = 'All';
  bool _isLoading = true;
  String? _loadingTrackId;

  final List<String> _quickSuggestions = [
    'Taylor Swift',
    'Lofi',
    'Acoustic',
    'OPM',
    'Anime',
    'Chill',
    'Pop',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadTracks(forceRefresh: forceRefresh),
      _loadFavorites(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTracks({bool forceRefresh = false}) async {
    final result = await _musicService.getTracks(forceRefresh: forceRefresh);
    if (!mounted) return;
    _allTracks = result.tracks;
    _genres = result.genres;
    _applyFilter();
  }

  Future<void> _loadFavorites() async {
    final favs = await _musicService.getFavoriteTracks();
    if (!mounted) return;
    setState(() {
      _favoriteTracks = favs;
      _favoriteTrackIds = favs.map((t) => t.id).toSet();
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

  Future<void> _toggleFavorite(VoiceRoomMusicTrack track) async {
    HapticFeedback.lightImpact();
    final isNowFav = await _musicService.toggleFavorite(track);
    await _loadFavorites();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1F2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        content: Row(
          children: [
            Icon(
              isNowFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isNowFav ? Colors.redAccent : Colors.white70,
              size: 18.r,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                isNowFav ? 'Added to Favorites: ${track.title}' : 'Removed from Favorites',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addToQueue(VoiceRoomMusicTrack track) {
    HapticFeedback.lightImpact();
    widget.controller.addToQueue(track);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1F2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        content: Row(
          children: [
            const Icon(Icons.playlist_add_check_rounded, color: Color(0xFF4ADE80)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Added to Queue: ${track.title}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _playTrack(VoiceRoomMusicTrack track) async {
    HapticFeedback.lightImpact();
    setState(() => _loadingTrackId = track.id);

    await widget.controller.playCdnMusic(track);

    if (!mounted) return;
    setState(() => _loadingTrackId = null);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
        final hasActiveMusic = widget.controller.roomMusicTitle.isNotEmpty;
        final queue = widget.controller.musicQueue;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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

              // Header Row
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
                          'Browse & play music for everyone in the room',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: Colors.white70, size: 20.r),
                    tooltip: 'Refresh library',
                    onPressed: () => _loadInitialData(forceRefresh: true),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20.r),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // 3 Navigation Tabs: [ 🔍 Search ]  [ ❤️ Favorites (N) ]  [ 📋 Queue (N) ]
              Container(
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    _buildTabButton(
                      index: 0,
                      label: 'Search',
                      icon: Icons.search_rounded,
                      badge: null,
                    ),
                    _buildTabButton(
                      index: 1,
                      label: 'Favorites',
                      icon: Icons.favorite_rounded,
                      badge: _favoriteTracks.isNotEmpty ? '${_favoriteTracks.length}' : null,
                    ),
                    _buildTabButton(
                      index: 2,
                      label: 'Queue',
                      icon: Icons.queue_music_rounded,
                      badge: queue.isNotEmpty ? '${queue.length}' : null,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12.h),

              // Tab View Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF7A45)),
                      )
                    : IndexedStack(
                        index: _selectedTabIndex,
                        children: [
                          _buildSearchTab(),
                          _buildFavoritesTab(),
                          _buildQueueTab(queue),
                        ],
                      ),
              ),

              // Persistent Mini Player Banner (if active)
              if (hasActiveMusic) ...[
                SizedBox(height: 8.h),
                _buildMiniPlayerBanner(isMusicPlaying),
                SizedBox(height: 10.h),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedTabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 15.r,
              ),
              SizedBox(width: 5.w),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFFF7A45),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFFF7A45) : Colors.white,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: SEARCH TAB
  // ==========================================
  Widget _buildSearchTab() {
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty || _selectedGenre != 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Field
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
              hintText: 'Search songs, artists, or keywords...',
              hintStyle: TextStyle(
                color: Colors.white38,
                fontSize: 13.sp,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 20.r),
              suffixIcon: query.isNotEmpty
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
            height: 30.h,
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
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
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
                        fontSize: 11.sp,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        SizedBox(height: 10.h),

        // Results or Empty Landing
        Expanded(
          child: !isSearching
              ? _buildSearchLandingView()
              : _filteredTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, color: Colors.white24, size: 48.r),
                          SizedBox(height: 10.h),
                          Text(
                            'No songs found matching "${_searchController.text}"',
                            style: TextStyle(color: Colors.white60, fontSize: 13.sp),
                          ),
                          SizedBox(height: 8.h),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _selectedGenre = 'All');
                              _applyFilter();
                            },
                            child: const Text('Clear Search', style: TextStyle(color: Color(0xFFFF7A45))),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredTracks.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        return _buildTrackTile(_filteredTracks[index]);
                      },
                    ),
        ),
      ],
    );
  }

  /// Empty search landing state with quick suggestions
  Widget _buildSearchLandingView() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
        child: Column(
          children: [
            Container(
              width: 56.r,
              height: 56.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF7A45).withValues(alpha: 0.2),
                    const Color(0xFFEC4899).withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                color: const Color(0xFFFF7A45),
                size: 28.r,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Search Voice Room Music',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Type a song title, artist, or keyword to find music',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Keywords',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _quickSuggestions.map((tag) {
                return ActionChip(
                  label: Text(tag),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _searchController.text = tag;
                    _applyFilter();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: FAVORITES TAB
  // ==========================================
  Widget _buildFavoritesTab() {
    if (_favoriteTracks.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.r,
                height: 60.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 30.r),
              ),
              SizedBox(height: 14.h),
              Text(
                'No Favorite Songs Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Tap the ❤️ heart icon on any song in Search to save it here for instant access without searching!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.sp,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 18.h),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                ),
                onPressed: () {
                  setState(() => _selectedTabIndex = 0);
                },
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 16),
                label: const Text(
                  'Search Songs Now',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_favoriteTracks.length} Saved Songs',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '1-Tap to Play or Queue',
              style: TextStyle(
                color: const Color(0xFFFF7A45),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Expanded(
          child: ListView.separated(
            itemCount: _favoriteTracks.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              return _buildTrackTile(_favoriteTracks[index]);
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: QUEUE TAB
  // ==========================================
  Widget _buildQueueTab(List<VoiceRoomMusicTrack> queue) {
    final currentTitle = widget.controller.roomMusicTitle;
    final currentArtist = widget.controller.roomMusicArtist;
    final currentArtwork = widget.controller.roomMusicArtwork;
    final isPlaying = widget.controller.isRoomMusicPlaying;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Currently Playing Card
          if (currentTitle.isNotEmpty) ...[
            Text(
              'NOW PLAYING',
              style: TextStyle(
                color: const Color(0xFFFF7A45),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF7A45).withValues(alpha: 0.15),
                    const Color(0xFFEC4899).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: currentArtwork.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: currentArtwork,
                                width: 48.r,
                                height: 48.r,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 48.r,
                                  height: 48.r,
                                  color: Colors.white10,
                                  child: const Icon(Icons.music_note, color: Colors.white38),
                                ),
                              )
                            : Container(
                                width: 48.r,
                                height: 48.r,
                                color: Colors.white10,
                                child: const Icon(Icons.music_note, color: Colors.white38),
                              ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarqueeText(
                              text: currentTitle,
                              maxWidth: 165.w,
                              isPlaying: isPlaying,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              currentArtist.isNotEmpty ? currentArtist : 'KatsKlub Music',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                          color: const Color(0xFFFF7A45),
                          size: 34.r,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.controller.togglePauseRoomMusic();
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 28.r),
                        tooltip: 'Skip to next song',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.controller.skipToNextMusic();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
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
            SizedBox(height: 18.h),
          ],

          // Up Next Section Header
          Row(
            children: [
              Text(
                'UP NEXT (${queue.length})',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              if (queue.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.controller.clearQueue();
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 10.h),

          if (queue.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 20.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Icon(Icons.queue_music_rounded, color: Colors.white24, size: 44.r),
                  SizedBox(height: 10.h),
                  Text(
                    'Queue is Empty',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Tap "+ Queue" on any song to queue it for automatic playback',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11.5.sp,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: () {
                      setState(() => _selectedTabIndex = 0);
                    },
                    child: const Text('Find Songs to Queue', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: queue.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final track = queue[index];
                return Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24.r,
                        height: 24.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: const Color(0xFFFF7A45),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: track.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: track.artworkUrl,
                                width: 38.r,
                                height: 38.r,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 38.r,
                                height: 38.r,
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
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF7A45)),
                        tooltip: 'Play this now',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.controller.removeFromQueue(index);
                          _playTrack(track);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                        tooltip: 'Remove from queue',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.controller.removeFromQueue(index);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED TRACK CARD TILE
  // ==========================================
  Widget _buildTrackTile(VoiceRoomMusicTrack track) {
    final currentTitle = widget.controller.roomMusicTitle;
    final isCurrent = currentTitle == track.title;
    final isItemLoading = _loadingTrackId == track.id;
    final isFav = _favoriteTrackIds.contains(track.id);

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
          SizedBox(width: 4.w),

          // Favorite Heart Button
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : Colors.white38,
              size: 20.r,
            ),
            tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
            onPressed: () => _toggleFavorite(track),
          ),

          // Add to Queue Button
          InkWell(
            onTap: () => _addToQueue(track),
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 14.r),
                  SizedBox(width: 3.w),
                  Text(
                    'Queue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 6.w),

          // Play Button
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
                          isCurrent && widget.controller.isRoomMusicPlaying
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
  }

  // ==========================================
  // PERSISTENT MINI PLAYER BANNER
  // ==========================================
  Widget _buildMiniPlayerBanner(bool isMusicPlaying) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
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
                borderRadius: BorderRadius.circular(6.r),
                child: widget.controller.roomMusicArtwork.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.controller.roomMusicArtwork,
                        width: 36.r,
                        height: 36.r,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 36.r,
                          height: 36.r,
                          color: Colors.white10,
                          child: const Icon(Icons.music_note, color: Colors.white38),
                        ),
                      )
                    : Container(
                        width: 36.r,
                        height: 36.r,
                        color: Colors.white10,
                        child: const Icon(Icons.music_note, color: Colors.white38),
                      ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: widget.controller.roomMusicTitle,
                      maxWidth: 150.w,
                      isPlaying: isMusicPlaying,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isMusicPlaying ? 'Streaming in room...' : 'Paused',
                      style: TextStyle(
                        color: isMusicPlaying ? const Color(0xFF4ADE80) : Colors.white38,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
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
                  size: 28.r,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.controller.togglePauseRoomMusic();
                },
              ),
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: Colors.white70, size: 24.r),
                tooltip: 'Next in queue',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.controller.skipToNextMusic();
                },
              ),
              IconButton(
                icon: Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 22.r),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.controller.stopRoomMusic();
                },
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.volume_down_rounded, color: Colors.white54, size: 14.r),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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
              Icon(Icons.volume_up_rounded, color: Colors.white54, size: 14.r),
            ],
          ),
        ],
      ),
    );
  }
}
