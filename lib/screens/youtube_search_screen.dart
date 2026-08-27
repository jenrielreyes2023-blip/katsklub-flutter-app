import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/youtube_music_service.dart';
import '../services/youtube_service.dart';
import 'youtube_player_screen.dart';
import 'youtube_mp3_screen.dart';

/// Screen allowing users to search, browse, and play YouTube videos directly.
class YouTubeSearchScreen extends StatefulWidget {
  const YouTubeSearchScreen({
    this.initialQuery,
    this.onVideoSelected,
    super.key,
  });

  final String? initialQuery;
  final ValueChanged<YouTubeVideoItem>? onVideoSelected;

  static Route<YouTubeVideoItem?> route({
    String? initialQuery,
    ValueChanged<YouTubeVideoItem>? onVideoSelected,
  }) {
    return MaterialPageRoute<YouTubeVideoItem?>(
      builder: (_) => YouTubeSearchScreen(
        initialQuery: initialQuery,
        onVideoSelected: onVideoSelected,
      ),
    );
  }

  @override
  State<YouTubeSearchScreen> createState() => _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends State<YouTubeSearchScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  final YouTubeMusicService _musicService = YouTubeMusicService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<YouTubeVideoItem> _videos = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String? _currentlyLoadingVideoId;

  // Music vs Video mode
  bool _musicMode = true;
  YouTubeMusicChartsResult? _chartsResult;
  bool _isLoadingCharts = false;

  // Curated quick search suggestions
  final List<String> _suggestions = const [
    'OPM Hits',
    'Lofi Beats',
    'Acoustic Covers',
    'Live Music',
    'Podcasts',
    'Trending',
    'Flutter Tutorial',
    'Gaming',
  ];

  @override
  void initState() {
    super.initState();
    _loadCharts();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _performSearch(widget.initialQuery!.trim());
    }
  }

  Future<void> _loadCharts() async {
    setState(() => _isLoadingCharts = true);
    final res = await _musicService.getCharts();
    if (mounted) {
      setState(() {
        _chartsResult = res;
        _isLoadingCharts = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      if (_musicMode) {
        final songs = await _musicService.searchSongs(trimmed, type: 'song');
        final results = songs
            .map((s) => YouTubeVideoItem(
                  id: s.id,
                  title: s.title,
                  author: s.artist,
                  duration: s.duration,
                  thumbnail: s.thumbnail,
                  viewCount: s.album.isNotEmpty ? s.album : 'YouTube Music',
                ))
            .toList();
        if (mounted) {
          setState(() {
            _videos = results;
            _isLoading = false;
          });
        }
      } else {
        final results = await _youtubeService.searchVideos(trimmed);
        if (mounted) {
          setState(() {
            _videos = results;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to search YouTube. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playVideo(YouTubeVideoItem video) async {
    if (widget.onVideoSelected != null) {
      widget.onVideoSelected!(video);
      Navigator.of(context).pop(video);
      return;
    }

    if (_musicMode) {
      Navigator.of(context).push(
        YouTubeMP3Screen.route(
          videoId: video.id,
          title: video.title,
          author: video.author,
          thumbnail: video.thumbnail,
        ),
      );
      return;
    }

    setState(() {
      _currentlyLoadingVideoId = video.id;
    });

    try {
      // Prefetch stream URL
      final streamUrl = await _youtubeService.getStreamUrl(video.id);

      if (!mounted) return;
      setState(() {
        _currentlyLoadingVideoId = null;
      });

      // Launch full player screen
      Navigator.of(context).push(
        YouTubePlayerScreen.route(
          videoId: video.id,
          title: video.title,
          author: video.author,
          thumbnail: video.thumbnail,
          streamUrl: streamUrl,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentlyLoadingVideoId = null;
        });
        // Still navigate to player screen where webview fallback will handle playback
        Navigator.of(context).push(
          YouTubePlayerScreen.route(
            videoId: video.id,
            title: video.title,
            author: video.author,
            thumbnail: video.thumbnail,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1C1E21),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 16,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'YouTube Search',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1C1E21),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _performSearch,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : const Color(0xFF1C1E21),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search YouTube videos, songs...',
                        hintStyle: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 13.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          size: 20.sp,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                color: const Color(0xFF9CA3AF),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Search Action Button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    onPressed: () => _performSearch(_searchController.text),
                    tooltip: 'Search',
                  ),
                ),
              ],
            ),
          ),

          // Mode Selector: YouTube Music vs Video
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_musicMode) {
                        setState(() {
                          _musicMode = true;
                          _videos.clear();
                          _hasSearched = false;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 7.h),
                      decoration: BoxDecoration(
                        color: _musicMode
                            ? const Color(0xFFFF2A6D).withValues(alpha: 0.18)
                            : (isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: _musicMode ? const Color(0xFFFF2A6D) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 15.sp,
                            color: _musicMode ? const Color(0xFFFF2A6D) : Colors.white60,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            'YouTube Music',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: _musicMode ? const Color(0xFFFF2A6D) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_musicMode) {
                        setState(() {
                          _musicMode = false;
                          _videos.clear();
                          _hasSearched = false;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 7.h),
                      decoration: BoxDecoration(
                        color: !_musicMode
                            ? const Color(0xFFFF0000).withValues(alpha: 0.18)
                            : (isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: !_musicMode ? const Color(0xFFFF0000) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_rounded,
                            size: 15.sp,
                            color: !_musicMode ? const Color(0xFFFF0000) : Colors.white60,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            'YouTube Videos',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: !_musicMode ? const Color(0xFFFF0000) : Colors.white70,
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
          SizedBox(height: 6.h),

          // Suggestion Chips (Horizontal Carousel)
          SizedBox(
            height: 36.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final isSelected =
                    _searchController.text.trim().toLowerCase() ==
                    suggestion.toLowerCase();

                return ActionChip(
                  label: Text(
                    suggestion,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 11.5.sp,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                    ),
                  ),
                  backgroundColor: isSelected
                      ? const Color(0xFFFF0000)
                      : (isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0),
                  onPressed: () {
                    _searchController.text = suggestion;
                    _performSearch(suggestion);
                  },
                );
              },
            ),
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Color(0x1F9CA3AF)),

          // Content Body (List / States)
          Expanded(
            child: _buildBody(isDark, primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
            ),
            SizedBox(height: 14.h),
            Text(
              'Searching YouTube...',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 54.sp, color: Colors.grey),
              SizedBox(height: 12.h),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 14.sp,
                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: () => _performSearch(_searchController.text),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      if (_musicMode) {
        return _buildMusicChartsView(isDark);
      }
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.r,
                  height: 72.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFFFF0000),
                    size: 44,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Explore YouTube Media',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1C1E21),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Search music, podcast episodes, tutorials, and videos to stream directly with zero server buffering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 12.5.sp,
                    color: const Color(0xFF9CA3AF),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 54.sp, color: Colors.grey),
              SizedBox(height: 12.h),
              Text(
                'No videos found',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1C1E21),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Try searching for different keywords or checking for spelling errors.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 12.5.sp,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _performSearch(_searchController.text),
      color: const Color(0xFFFF0000),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        itemCount: _videos.length,
        separatorBuilder: (_, __) => SizedBox(height: 14.h),
        itemBuilder: (context, index) {
          final video = _videos[index];
          final isItemLoading = _currentlyLoadingVideoId == video.id;

          return _VideoCard(
            video: video,
            isLoading: isItemLoading,
            isDark: isDark,
            onTap: () => _playVideo(video),
          );
        },
      ),
    );
  }

  Widget _buildMusicChartsView(bool isDark) {
    if (_isLoadingCharts) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2A6D)),
            ),
            SizedBox(height: 12.h),
            Text(
              'Loading YouTube Music Charts...',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.sp,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final charts = _chartsResult?.charts ?? [];
    final newReleases = _chartsResult?.newReleases ?? [];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 14.h),
      children: [
        if (charts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF2A6D), size: 20),
                SizedBox(width: 6.w),
                Text(
                  'Trending on YouTube Music',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: math.min(10, charts.length),
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final item = charts[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                tileColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF3F4F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: CachedNetworkImage(
                    imageUrl: item.thumbnail,
                    width: 48.w,
                    height: 48.w,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 48.w,
                      height: 48.w,
                      color: const Color(0xFFFF2A6D).withValues(alpha: 0.2),
                      child: const Icon(Icons.music_note, color: Colors.white70),
                    ),
                  ),
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  item.artist.isNotEmpty ? item.artist : 'Trending Song',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 11.5.sp,
                    color: const Color(0xFFFF2A6D),
                  ),
                ),
                trailing: Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF2A6D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    YouTubeMP3Screen.route(
                      videoId: item.id,
                      title: item.title,
                      author: item.artist,
                      thumbnail: item.thumbnail,
                    ),
                  );
                },
              );
            },
          ),
        ],
        if (newReleases.isNotEmpty) ...[
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                const Icon(Icons.new_releases_rounded, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 6.w),
                Text(
                  'New Music Releases',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: 160.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: newReleases.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final item = newReleases[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      YouTubeMP3Screen.route(
                        videoId: item.id,
                        title: item.title,
                        author: item.artist,
                        thumbnail: item.thumbnail,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 110.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: CachedNetworkImage(
                            imageUrl: item.thumbnail,
                            width: 110.w,
                            height: 110.w,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 110.w,
                              height: 110.w,
                              color: Colors.white12,
                              child: const Icon(Icons.music_note, color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 10.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Card item representing an individual YouTube search result.
class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.isLoading,
    required this.isDark,
    required this.onTap,
  });

  final YouTubeVideoItem video;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242526) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 16:9 Thumbnail with Duration Overlay & Play Badge
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: video.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnail,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? const Color(0xFF3A3B3C)
                                  : const Color(0xFFE5E7EB),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF0000),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF3A3B3C)
                                  : const Color(0xFFE5E7EB),
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.black12,
                            child: const Icon(Icons.video_library, color: Colors.grey),
                          ),
                  ),

                  // Duration Badge (Bottom-Right)
                  if (video.duration.isNotEmpty)
                    Positioned(
                      bottom: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          video.duration,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                  // Center Play Button / Loading Indicator Overlay
                  Positioned.fill(
                    child: Center(
                      child: isLoading
                          ? Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF0000),
                                ),
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Title & Channel Info
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16.r,
                    backgroundColor:
                        const Color(0xFFFF0000).withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Color(0xFFFF0000),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1C1E21),
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 4.h),

                        // Channel & View Count
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                video.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            if (video.viewCount.isNotEmpty) ...[
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                              Text(
                                video.viewCount,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 11.sp,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Quick MP3 Button
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        YouTubeMP3Screen.route(
                          videoId: video.id,
                          title: video.title,
                          author: video.author,
                          thumbnail: video.thumbnail,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0x33FF2A6D)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: Color(0xFFFF2A6D), size: 14),
                          SizedBox(width: 3.w),
                          Text(
                            'MP3',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF2A6D),
                            ),
                          ),
                        ],
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
