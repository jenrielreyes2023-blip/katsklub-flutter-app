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

  Future<void> _loadInitialData({bool forceRefresh = true}) async {
    // 1. Instant render if cached tracks exist so user has zero lag
    if (_musicService.hasCachedTracks) {
      final cached = _musicService.cachedResult;
      if (cached != null) {
        _allTracks = cached.tracks;
        _genres = cached.genres;
        _applyFilter();
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Auto-sync immediately from Bunny CDN every time the sheet opens
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
        backgroundColor: const Color(0xFF1E1E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        content: Row(
          children: [
            Icon(
              isNowFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isNowFav ? Colors.redAccent : Colors.white70,
              size: 15.r,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                isNowFav ? 'Added to Favorites: ${track.title}' : 'Removed from Favorites',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
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
        backgroundColor: const Color(0xFF1E1E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        content: Row(
          children: [
            Icon(Icons.playlist_add_check_rounded, color: const Color(0xFF4ADE80), size: 16.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Added to Queue: ${track.title}',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
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
        backgroundColor: const Color(0xFF1E1E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        content: Row(
          children: [
            Icon(Icons.music_note_rounded, color: const Color(0xFFFF7A45), size: 16.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Now streaming: ${track.title}',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
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
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final bottomSafe = MediaQuery.of(context).padding.bottom;

        return Container(
          height: MediaQuery.of(context).size.height * 0.58,
          decoration: BoxDecoration(
            color: const Color(0xFF101012),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.only(
            left: 14.w,
            right: 14.w,
            bottom: bottomInset > 0 ? bottomInset + 8.h : (bottomSafe > 0 ? bottomSafe : 8.h),
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
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 14.r,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice Room Music',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        Text(
                          'Browse & play for everyone in room',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white38,
                            fontSize: 10.sp,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: Colors.white60, size: 17.r),
                    tooltip: 'Refresh library',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16.r,
                    onPressed: () => _loadInitialData(forceRefresh: true),
                  ),
                  SizedBox(width: 12.w),
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

              // 3 Navigation Tabs: [ 🔍 Search ]  [ ❤️ Favorites (N) ]  [ 📋 Queue (N) ]
              Container(
                padding: EdgeInsets.all(2.5.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E20),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 0.5,
                  ),
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

              SizedBox(height: 8.h),

              // Tab View Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF7A45),
                            strokeWidth: 2,
                          ),
                        ),
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
                SizedBox(height: 6.h),
                _buildMiniPlayerBanner(isMusicPlaying),
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
          padding: EdgeInsets.symmetric(vertical: 5.5.h),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 13.5.r,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              if (badge != null) ...[
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFFF7A45),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: isSelected ? const Color(0xFFFF7A45) : Colors.white,
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w600,
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
        // Search Field - Compact & Sleek
        Container(
          height: 34.h,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(9.r),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 0.6,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilter(),
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: Colors.white,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search songs, artists, or keywords...',
              hintStyle: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white38,
                fontSize: 11.5.sp,
                letterSpacing: -0.1,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 16.r),
              prefixIconConstraints: BoxConstraints(minWidth: 32.w),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: Colors.white38, size: 14.r),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 14.r,
                      onPressed: () {
                        _searchController.clear();
                        _applyFilter();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
              isDense: true,
            ),
          ),
        ),

        SizedBox(height: 7.h),

        // Genre Filter Chips
        if (_genres.isNotEmpty)
          SizedBox(
            height: 24.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _genres.length,
              separatorBuilder: (_, __) => SizedBox(width: 6.w),
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
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF1E1E20),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : const Color(0xFF2C2C2E),
                        width: 0.6,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      g,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 10.sp,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        SizedBox(height: 7.h),

        // Results or Empty Landing
        Expanded(
          child: !isSearching
              ? _buildSearchLandingView()
              : _filteredTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, color: Colors.white24, size: 36.r),
                          SizedBox(height: 6.h),
                          Text(
                            'No songs found matching "${_searchController.text}"',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: Colors.white60,
                              fontSize: 11.5.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _selectedGenre = 'All');
                              _applyFilter();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Clear Search',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: const Color(0xFFFF7A45),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      itemCount: _filteredTracks.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.h),
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
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
        child: Column(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF7A45).withValues(alpha: 0.18),
                    const Color(0xFFEC4899).withValues(alpha: 0.18),
                  ],
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                color: const Color(0xFFFF7A45),
                size: 20.r,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Search Voice Room Music',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Type a song title, artist, or keyword to find music',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white38,
                fontSize: 10.5.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Popular Keywords',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white60,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: _quickSuggestions.map((tag) {
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _searchController.text = tag;
                    _applyFilter();
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E20),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white70,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22.r),
              ),
              SizedBox(height: 8.h),
              Text(
                'No Favorite Songs Yet',
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
                'Tap the ❤️ heart on any song to save it here for instant access without searching.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white38,
                  fontSize: 10.5.sp,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 12.h),
              InkWell(
                onTap: () => setState(() => _selectedTabIndex = 0),
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded, color: Colors.white, size: 14.r),
                      SizedBox(width: 5.w),
                      Text(
                        'Search Songs Now',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
                fontFamily: 'SF Pro Rounded',
                color: Colors.white60,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
            const Spacer(),
            Text(
              '1-Tap to Play or Queue',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: const Color(0xFFFF7A45),
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 2.h),
            itemCount: _favoriteTracks.length,
            separatorBuilder: (_, __) => SizedBox(height: 6.h),
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
    final currentTrackId = widget.controller.roomCdnTrack?.id;
    final isPlaying = widget.controller.isRoomMusicPlaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Playlist Queue Header with Loop Badge
        Row(
          children: [
            Text(
              'PLAYLIST QUEUE (${queue.length})',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, color: const Color(0xFF4ADE80), size: 10.r),
                  SizedBox(width: 3.w),
                  Text(
                    'Auto-loops to start',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: const Color(0xFF4ADE80),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
                    fontFamily: 'SF Pro Rounded',
                    color: const Color(0xFFED4956),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),

        SizedBox(height: 6.h),

        if (queue.isEmpty)
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E20),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music_rounded, color: Colors.white24, size: 30.r),
                    SizedBox(height: 6.h),
                    Text(
                      'Queue is Empty',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Tap "+ Queue" on any song to add it. Songs stay in queue and loop automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white38,
                        fontSize: 10.5.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      borderRadius: BorderRadius.circular(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'Find Songs to Queue',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              itemCount: queue.length,
              separatorBuilder: (_, __) => SizedBox(height: 6.h),
              itemBuilder: (context, index) {
                final track = queue[index];
                final isThisPlaying = track.id == currentTrackId;

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: isThisPlaying
                        ? const Color(0xFFFF7A45).withValues(alpha: 0.12)
                        : const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isThisPlaying
                          ? const Color(0xFFFF7A45).withValues(alpha: 0.5)
                          : const Color(0xFF2C2C2E),
                      width: isThisPlaying ? 0.9 : 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
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
                          color: isThisPlaying
                              ? null
                              : const Color(0xFFFF7A45).withValues(alpha: 0.15),
                        ),
                        alignment: Alignment.center,
                        child: isThisPlaying
                            ? Icon(
                                isPlaying
                                    ? Icons.equalizer_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 11.r,
                              )
                            : Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  color: const Color(0xFFFF7A45),
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      SizedBox(width: 7.w),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: track.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: track.artworkUrl,
                                width: 32.r,
                                height: 32.r,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 32.r,
                                height: 32.r,
                                color: Colors.white10,
                                child: Icon(Icons.music_note, color: Colors.white38, size: 16.r),
                              ),
                      ),
                      SizedBox(width: 8.w),
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
                                      isPlaying ? 'PLAYING' : 'PAUSED',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Rounded',
                                        color: const Color(0xFFFF7A45),
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white38,
                                fontSize: 9.5.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==========================================
  // SHARED TRACK CARD TILE (THREADS-STYLE INSET ISLAND)
  // ==========================================
  Widget _buildTrackTile(VoiceRoomMusicTrack track) {
    final currentTitle = widget.controller.roomMusicTitle;
    final isCurrent = currentTitle == track.title;
    final isItemLoading = _loadingTrackId == track.id;
    final isFav = _favoriteTrackIds.contains(track.id);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFFF7A45).withValues(alpha: 0.1)
            : const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFF7A45).withValues(alpha: 0.4)
              : const Color(0xFF2C2C2E),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: track.artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl,
                    width: 34.r,
                    height: 34.r,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 34.r,
                      height: 34.r,
                      color: Colors.white10,
                      child: Icon(Icons.music_note, color: Colors.white38, size: 16.r),
                    ),
                  )
                : Container(
                    width: 34.r,
                    height: 34.r,
                    color: Colors.white10,
                    child: Icon(Icons.music_note, color: Colors.white38, size: 16.r),
                  ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 11.5.sp,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Colors.white38,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                    if (track.genre.isNotEmpty && track.genre != 'General') ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
                      ),
                      Text(
                        track.genre,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: const Color(0xFFFF7A45),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w500,
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
              size: 16.r,
            ),
            tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 14.r,
            onPressed: () => _toggleFavorite(track),
          ),

          SizedBox(width: 6.w),

          // Add to Queue Button
          InkWell(
            onTap: () => _addToQueue(track),
            borderRadius: BorderRadius.circular(6.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.5.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: const Color(0xFF2C2C2E),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 12.r),
                  SizedBox(width: 2.w),
                  Text(
                    'Queue',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Colors.white70,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 5.w),

          // Play Button
          InkWell(
            onTap: isItemLoading ? null : () => _playTrack(track),
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
              decoration: BoxDecoration(
                gradient: isCurrent
                    ? const LinearGradient(
                        colors: [Color(0xFF4ADE80), Color(0xFF10B981)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                      ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: isItemLoading
                  ? SizedBox(
                      width: 12.r,
                      height: 12.r,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.5,
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
                          size: 12.r,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          isCurrent ? 'Playing' : 'Play',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
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
  // PERSISTENT MINI PLAYER BANNER (SLEEK)
  // ==========================================
  Widget _buildMiniPlayerBanner(bool isMusicPlaying) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5.r),
                child: widget.controller.roomMusicArtwork.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.controller.roomMusicArtwork,
                        width: 28.r,
                        height: 28.r,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 28.r,
                          height: 28.r,
                          color: Colors.white10,
                          child: Icon(Icons.music_note, color: Colors.white38, size: 14.r),
                        ),
                      )
                    : Container(
                        width: 28.r,
                        height: 28.r,
                        color: Colors.white10,
                        child: Icon(Icons.music_note, color: Colors.white38, size: 14.r),
                      ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: widget.controller.roomMusicTitle,
                      maxWidth: 130.w,
                      isPlaying: isMusicPlaying,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    Text(
                      isMusicPlaying ? 'Streaming in room...' : 'Paused',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isMusicPlaying ? const Color(0xFF4ADE80) : Colors.white38,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 18.r),
                tooltip: 'Previous in queue',
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
                  size: 22.r,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 14.r,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.controller.togglePauseRoomMusic();
                },
              ),
              SizedBox(width: 4.w),
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: Colors.white70, size: 18.r),
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
                icon: Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 17.r),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 14.r,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.controller.stopRoomMusic();
                },
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Icon(Icons.volume_down_rounded, color: Colors.white38, size: 12.r),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 1.5,
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
}
