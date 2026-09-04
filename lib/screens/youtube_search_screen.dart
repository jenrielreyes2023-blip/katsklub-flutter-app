import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/auth_service.dart';
import '../services/youtube_service.dart';
import 'create_post_screen.dart';
import 'youtube_player_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<YouTubeVideoItem> _videos = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String? _currentlyLoadingVideoId;

  // Curated quick search suggestions
  final List<String> _suggestions = const [
    'Trending',
    'OPM Hits',
    'Lofi Beats',
    'Acoustic Covers',
    'Live Music',
    'Podcasts',
    'Flutter Tutorial',
    'Gaming',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _performSearch(widget.initialQuery!.trim());
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
      final results = await _youtubeService.searchVideos(trimmed);
      if (mounted) {
        setState(() {
          _videos = results;
          _isLoading = false;
        });
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

  Future<void> _postVideoToFeed(YouTubeVideoItem video) async {
    final authService = AuthService();
    final user = await authService.getSavedUser();
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post to feed.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          user: user,
          initialYouTubeVideo: video,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        hintText: 'Search YouTube videos...',
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
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
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                  backgroundColor:
                      isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  onPressed: () {
                    _searchController.text = suggestion;
                    _performSearch(suggestion);
                  },
                );
              },
            ),
          ),
          SizedBox(height: 8.h),

          // Main Body
          Expanded(
            child: _buildBody(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
            ),
            SizedBox(height: 16.h),
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
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              SizedBox(height: 12.h),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 13.5.sp,
                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => _performSearch(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
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
                  'Explore YouTube Videos',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1C1E21),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Search tutorials, podcasts, music videos, and clips to watch directly in KatsKlub.',
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
                'Try checking for typos or use different keywords.',
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

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
          onPostToFeed: widget.onVideoSelected == null
              ? () => _postVideoToFeed(video)
              : null,
        );
      },
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
    this.onPostToFeed,
  });

  final YouTubeVideoItem video;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onPostToFeed;

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
                            if (onPostToFeed != null) ...[
                              const Spacer(),
                              InkWell(
                                onTap: onPostToFeed,
                                borderRadius: BorderRadius.circular(8.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF7A45)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.post_add_rounded,
                                        color: const Color(0xFFFF7A45),
                                        size: 14.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Post',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Rounded',
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFFF7A45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
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
    );
  }
}
