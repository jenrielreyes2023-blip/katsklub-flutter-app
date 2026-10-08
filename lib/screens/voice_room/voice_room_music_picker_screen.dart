import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/voice_room_music_track.dart';
import '../../services/voice_room_controller.dart';
import '../../services/voice_room_music_service.dart';

/// Full-Page Song Picker Screen (Threads-Style Inset Grouped Island Architecture)
/// Features Top Search Bar, Trending Top 20, Favorites, Recent, and All Genres tabs.
class VoiceRoomMusicPickerScreen extends StatefulWidget {
  final VoiceRoomController controller;

  const VoiceRoomMusicPickerScreen({
    super.key,
    required this.controller,
  });

  static Future<void> open(BuildContext context, VoiceRoomController controller) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: VoiceRoomMusicPickerScreen(controller: controller),
          );
        },
      ),
    );
  }

  @override
  State<VoiceRoomMusicPickerScreen> createState() => _VoiceRoomMusicPickerScreenState();
}

class _VoiceRoomMusicPickerScreenState extends State<VoiceRoomMusicPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final VoiceRoomMusicService _musicService = VoiceRoomMusicService();

  // 0: Top 20 Trending, 1: Favorites, 2: Recent, 3: All Tracks
  int _selectedTabIndex = 0;
  String _selectedGenre = 'All';

  bool _isLoading = true;
  List<VoiceRoomMusicTrack> _allTracks = [];
  List<VoiceRoomMusicTrack> _filteredTracks = [];
  List<VoiceRoomMusicTrack> _trendingTracks = [];
  List<VoiceRoomMusicTrack> _favoriteTracks = [];
  List<VoiceRoomMusicTrack> _recentTracks = [];
  Set<String> _favoriteTrackIds = {};
  List<String> _genres = ['All'];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);

    // Load in parallel
    final results = await Future.wait([
      _musicService.getTracks(forceRefresh: forceRefresh),
      _musicService.getTrendingTracks(),
      _musicService.getFavoriteTracks(),
      _musicService.getRecentTracks(),
      _musicService.getFavoriteTrackIds(),
    ]);

    if (!mounted) return;

    final musicResult = results[0] as VoiceRoomMusicResult;
    final trending = results[1] as List<VoiceRoomMusicTrack>;
    final favs = results[2] as List<VoiceRoomMusicTrack>;
    final recent = results[3] as List<VoiceRoomMusicTrack>;
    final favIds = results[4] as Set<String>;

    setState(() {
      _allTracks = musicResult.tracks;
      _genres = musicResult.genres;
      _trendingTracks = trending;
      _favoriteTracks = favs;
      _recentTracks = recent;
      _favoriteTrackIds = favIds;
      _applySearch();
      _isLoading = false;
    });
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredTracks = _allTracks;
      return;
    }

    _filteredTracks = _allTracks.where((track) {
      final matchesQuery = track.title.toLowerCase().contains(query) ||
          track.artist.toLowerCase().contains(query) ||
          track.genre.toLowerCase().contains(query);
      final matchesGenre = _selectedGenre == 'All' ||
          track.genre.toLowerCase() == _selectedGenre.toLowerCase();
      return matchesQuery && matchesGenre;
    }).toList();
  }

  Future<void> _toggleFavorite(VoiceRoomMusicTrack track) async {
    HapticFeedback.lightImpact();
    final isNowFav = await _musicService.toggleFavorite(track);
    final favs = await _musicService.getFavoriteTracks();
    final favIds = await _musicService.getFavoriteTrackIds();

    if (!mounted) return;
    setState(() {
      _favoriteTracks = favs;
      _favoriteTrackIds = favIds;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E20),
        duration: const Duration(seconds: 2),
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
                isNowFav ? 'Saved to Favorites: ${track.title}' : 'Removed from Favorites',
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
      ),
    );
  }

  void _handleQueueTrack(VoiceRoomMusicTrack track) {
    HapticFeedback.lightImpact();
    widget.controller.addToQueue(track);

    // Refresh recents dynamically
    _musicService.getRecentTracks().then((recents) {
      if (mounted) setState(() => _recentTracks = recents);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E20),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        content: Row(
          children: [
            Icon(Icons.playlist_add_check_rounded, color: const Color(0xFF4ADE80), size: 16.r),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Added to room queue: ${track.title}',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF101012),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(),

            // Search Bar & Filter Header
            _buildSearchSection(),

            // Tab Selector (Top 20, Favorites, Recent, All)
            if (!isSearching) _buildTabSelector(),

            // Genre Chips (visible when 'All' tab is selected and not searching)
            if (!isSearching && _selectedTabIndex == 3 && _genres.isNotEmpty)
              _buildGenreChips(),

            SizedBox(height: 6.h),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7A45),
                        strokeWidth: 2,
                      ),
                    )
                  : isSearching
                      ? _buildSearchResultsView()
                      : _buildActiveTabContent(),
            ),

            // Persistent Floating Active Queue Bottom Pill
            _buildBottomQueueBar(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP BAR
  // ==========================================
  Widget _buildTopAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              padding: EdgeInsets.all(7.r),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E20),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2C2C2E), width: 0.6),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 14.r,
              ),
            ),
          ),

          SizedBox(width: 10.w),

          // Header Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick Song',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Choose songs to stream in Voice Room #${widget.controller.currentRoom?.id ?? ""}',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white38,
                    fontSize: 9.5.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Queue Counter Pill
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final queueCount = widget.controller.musicQueue.length;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music_rounded, color: const Color(0xFFFF7A45), size: 12.r),
                    SizedBox(width: 4.w),
                    Text(
                      '$queueCount queued',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: const Color(0xFFFF7A45),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
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
  // SEARCH BAR SECTION
  // ==========================================
  Widget _buildSearchSection() {
    final query = _searchController.text.trim();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      child: Container(
        height: 38.h,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E20),
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(
            color: const Color(0xFF2C2C2E),
            width: 0.6,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) {
            setState(() => _applySearch());
          },
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search music title, singer, artist, or genre...',
            hintStyle: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: Colors.white38,
              fontSize: 11.5.sp,
              letterSpacing: -0.1,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 16.r),
            prefixIconConstraints: BoxConstraints(minWidth: 34.w),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Colors.white38, size: 14.r),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 14.r,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _applySearch());
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            isDense: true,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // THREADS-STYLE TAB SELECTOR
  // ==========================================
  Widget _buildTabSelector() {
    final tabs = [
      {'label': '🔥 Top 20', 'index': 0},
      {'label': '❤️ Favorites', 'index': 1},
      {'label': '🕒 Recent', 'index': 2},
      {'label': '🎧 All Songs', 'index': 3},
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF262628), width: 0.6),
      ),
      child: Row(
        children: tabs.map((tab) {
          final idx = tab['index'] as int;
          final isSelected = _selectedTabIndex == idx;
          final label = tab['label'] as String;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTabIndex = idx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(vertical: 6.h),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2C2C2E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9.r),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 10.5.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // GENRE CHIPS (FOR ALL TAB)
  // ==========================================
  Widget _buildGenreChips() {
    return Container(
      height: 26.h,
      margin: EdgeInsets.only(top: 4.h),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
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
                _applySearch();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF7A45).withValues(alpha: 0.2)
                    : const Color(0xFF1E1E20),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF7A45)
                      : const Color(0xFF2C2C2E),
                  width: 0.6,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                g,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: isSelected ? const Color(0xFFFF7A45) : Colors.white70,
                  fontSize: 10.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // ACTIVE TAB CONTENT
  // ==========================================
  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTrendingTab();
      case 1:
        return _buildFavoritesTab();
      case 2:
        return _buildRecentTab();
      case 3:
      default:
        return _buildAllTracksTab();
    }
  }

  // TAB 1: TOP 20 TRENDING
  Widget _buildTrendingTab() {
    if (_trendingTracks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No Trending Songs Yet',
        subtitle: 'Songs played frequently in voice rooms will appear here.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      itemCount: _trendingTracks.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, index) {
        return _buildTrackCard(_trendingTracks[index], rank: index + 1);
      },
    );
  }

  // TAB 2: FAVORITES
  Widget _buildFavoritesTab() {
    if (_favoriteTracks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No Favorite Songs Saved',
        subtitle: 'Tap the ❤️ heart icon on any song to save it here for 1-tap queueing.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      itemCount: _favoriteTracks.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, index) {
        return _buildTrackCard(_favoriteTracks[index]);
      },
    );
  }

  // TAB 3: RECENT
  Widget _buildRecentTab() {
    if (_recentTracks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No Recently Queued Songs',
        subtitle: 'Songs that you queue in this or past rooms will appear here.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      itemCount: _recentTracks.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, index) {
        return _buildTrackCard(_recentTracks[index]);
      },
    );
  }

  // TAB 4: ALL TRACKS
  Widget _buildAllTracksTab() {
    final list = _selectedGenre == 'All'
        ? _allTracks
        : _allTracks
            .where((t) => t.genre.toLowerCase() == _selectedGenre.toLowerCase())
            .toList();

    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.music_off_rounded,
        title: 'No Songs in this Genre',
        subtitle: 'Try selecting another genre chip above.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, index) {
        return _buildTrackCard(list[index]);
      },
    );
  }

  // SEARCH RESULTS
  Widget _buildSearchResultsView() {
    if (_filteredTracks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No Matching Songs',
        subtitle: 'Try searching by a different artist or keyword.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      itemCount: _filteredTracks.length,
      separatorBuilder: (_, __) => SizedBox(height: 6.h),
      itemBuilder: (context, index) {
        return _buildTrackCard(_filteredTracks[index]);
      },
    );
  }

  // ==========================================
  // SHARED TRACK CARD (THREADS-STYLE INSET ISLAND)
  // ==========================================
  Widget _buildTrackCard(VoiceRoomMusicTrack track, {int? rank}) {
    final isInQueue = widget.controller.musicQueue.any((t) => t.id == track.id);
    final isFav = _favoriteTrackIds.contains(track.id);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          // Optional Top Rank Badge (Gold for #1, Silver for #2, Bronze for #3)
          if (rank != null) ...[
            Container(
              width: 22.w,
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: rank == 1
                      ? const Color(0xFFFFB800)
                      : rank == 2
                          ? const Color(0xFFE2E8F0)
                          : rank == 3
                              ? const Color(0xFFF97316)
                              : Colors.white38,
                  fontSize: 11.sp,
                  fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 6.w),
          ],

          // Album Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(7.r),
            child: track.artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl,
                    width: 38.r,
                    height: 38.r,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 38.r,
                      height: 38.r,
                      color: Colors.white10,
                      child: Icon(Icons.music_note, color: Colors.white38, size: 18.r),
                    ),
                  )
                : Container(
                    width: 38.r,
                    height: 38.r,
                    color: Colors.white10,
                    child: Icon(Icons.music_note, color: Colors.white38, size: 18.r),
                  ),
          ),

          SizedBox(width: 9.w),

          // Title & Artist
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

          SizedBox(width: 6.w),

          // Favorite Heart Button
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : Colors.white38,
              size: 16.r,
            ),
            tooltip: isFav ? 'Remove from favorites' : 'Save to favorites',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 14.r,
            onPressed: () => _toggleFavorite(track),
          ),

          SizedBox(width: 8.w),

          // Pick / Queue Button
          InkWell(
            onTap: isInQueue ? null : () => _handleQueueTrack(track),
            borderRadius: BorderRadius.circular(8.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                gradient: isInQueue
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF7A45), Color(0xFFEC4899)],
                      ),
                color: isInQueue ? const Color(0xFF4ADE80).withValues(alpha: 0.15) : null,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isInQueue
                      ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isInQueue ? Icons.check_circle_rounded : Icons.playlist_add_rounded,
                    color: isInQueue ? const Color(0xFF4ADE80) : Colors.white,
                    size: 13.r,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    isInQueue ? 'Queued' : 'Pick',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: isInQueue ? const Color(0xFF4ADE80) : Colors.white,
                      fontSize: 10.5.sp,
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
  // EMPTY STATE HELPER
  // ==========================================
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: Icon(icon, color: Colors.white30, size: 24.r),
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
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
  // BOTTOM ACTIVE QUEUE BAR
  // ==========================================
  Widget _buildBottomQueueBar() {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final queue = widget.controller.musicQueue;
        if (queue.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 8.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
              width: 0.6,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, color: const Color(0xFFFF7A45), size: 16.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${queue.length} song(s) queued in room',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'View Queue',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: const Color(0xFFFF7A45),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
