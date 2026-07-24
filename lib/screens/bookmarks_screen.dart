import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({required this.user, super.key});
  final User user;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  final FeedService _feedService = FeedService();
  late TabController _tabController;
  List<Post> _allBookmarks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookmarks = await _feedService.getBookmarkedPosts();
      setState(() {
        _allBookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Categories Categorization using Client-side Dart where() filters
  List<Post> get _videos => _allBookmarks
      .where((p) => (p.videoUrl.isNotEmpty || p.youtubeVideoId.isNotEmpty) && !p.isReel)
      .toList();

  List<Post> get _reels => _allBookmarks.where((p) => p.isReel).toList();
  
  List<Post> get _discussions => _allBookmarks.where((p) => p.isDiscussion).toList();

  List<Post> get _photos => _allBookmarks
      .where((p) => p.imageUrls.isNotEmpty || p.isAlbum)
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18191A) : const Color(0xFFF9FAFB);
    final appBarColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final tabLabelColor = isDark ? Colors.white : Colors.black;
    final unselectedLabelColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[500];
    final tabIndicatorColor = isDark ? const Color(0xFFFF7A45) : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        surfaceTintColor: appBarColor,
        iconTheme: IconThemeData(color: titleColor),
        elevation: 0,
        title: Text(
          'Bookmarks',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: titleColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: tabIndicatorColor,
              labelColor: tabLabelColor,
              unselectedLabelColor: unselectedLabelColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Videos'),
                Tab(text: 'Reels'),
                Tab(text: 'Discussions'),
                Tab(text: 'Photos'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? const Color(0xFFFF7A45) : Colors.black))
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookmarksList(_allBookmarks),
                    _buildBookmarksList(_videos),
                    _buildBookmarksList(_reels),
                    _buildBookmarksList(_discussions),
                    _buildBookmarksList(_photos),
                  ],
                ),
    );
  }

  Widget _buildBookmarksList(List<Post> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: isDark ? const Color(0xFFFF7A45) : Colors.black,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final post = posts[index];
          return _BookmarkItemRow(
            key: ValueKey(post.id),
            post: post,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(
                    postId: post.id,
                    currentUser: widget.user,
                  ),
                ),
              );
            },
            onOpenAuthor: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    username: post.authorUsername,
                  ),
                ),
              );
            },
            onRemove: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _feedService.toggleBookmark(post);
                if (!mounted) return;
                setState(() {
                  _allBookmarks.removeWhere((item) => item.id == post.id);
                });
                messenger.showSnackBar(
                  const SnackBar(content: Text('Removed from Bookmarks')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[500];
    final containerColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: containerColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 64,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Bookmarks Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmarked posts will show up here sorted by categories.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Failed to load bookmarks',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookmarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFFF7A45) : Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }
}

class _BookmarkItemRow extends StatelessWidget {
  const _BookmarkItemRow({
    required this.post,
    required this.onTap,
    required this.onOpenAuthor,
    required this.onRemove,
    super.key,
  });

  final Post post;
  final VoidCallback onTap;
  final VoidCallback onOpenAuthor;
  final VoidCallback onRemove;

  String _relativeTimestamp(DateTime? date) {
    if (date == null) {
      return '';
    }

    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) {
      return '${weeks}w';
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) {
      return '${months}mo';
    }
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  String _getTypeLabel() {
    if (post.isReel) return 'Reel';
    if (post.isDiscussion) return 'Discussion';
    if (post.isAlbum || post.imageUrls.isNotEmpty) return 'Photos';
    if (post.videoUrl.isNotEmpty || post.youtubeVideoId.isNotEmpty) return 'Video';
    return 'Post';
  }

  IconData _getTypeIcon() {
    if (post.isReel) return Icons.slideshow_rounded;
    if (post.isDiscussion) return Icons.forum_rounded;
    if (post.isAlbum || post.imageUrls.isNotEmpty) return Icons.photo_library_rounded;
    if (post.videoUrl.isNotEmpty || post.youtubeVideoId.isNotEmpty) return Icons.play_circle_fill_rounded;
    return Icons.notes_rounded;
  }

  String? _getThumbnailUrl() {
    if (post.imageUrls.isNotEmpty) return post.imageUrls.first;
    if (post.videoPosterUrl.isNotEmpty) return post.videoPosterUrl;
    if (post.discussionCoverUrl.isNotEmpty) return post.discussionCoverUrl;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = _getThumbnailUrl();
    final typeLabel = _getTypeLabel();
    final typeIcon = _getTypeIcon();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final itemBgColor = isDark ? const Color(0xFF242526) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[500];
    final snippetColor = isDark ? const Color(0xFFE4E6EB) : Colors.grey[700];
    final activeOrange = const Color(0xFFFF7A45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: itemBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: User Avatar
            GestureDetector(
              onTap: onOpenAuthor,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: isDark ? const Color(0xFF18191A) : const Color(0xFFE5E7EB),
                backgroundImage: post.authorAvatarUrl.isEmpty
                    ? null
                    : NetworkImage(ApiConfig.assetUrl(post.authorAvatarUrl)),
                child: post.authorAvatarUrl.isEmpty
                    ? Text(
                        post.authorFullName.isEmpty
                            ? 'K'
                            : post.authorFullName.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                          ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Center: Info and snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author & relative timestamp row
                  GestureDetector(
                    onTap: onOpenAuthor,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorFullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '@${post.authorUsername}',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '•',
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _relativeTimestamp(post.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Snippet text
                  Text(
                    post.text.isEmpty
                        ? (post.isDiscussion ? 'Shared a discussion' : 'Attached media')
                        : post.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: snippetColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Category label/badge
                  Row(
                    children: [
                      Icon(
                        typeIcon,
                        size: 14,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: Thumbnail & Bookmark Action
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (thumbnailUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(
                        ApiConfig.assetUrl(thumbnailUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? const Color(0xFF18191A) : const Color(0xFFF3F4F6),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_outlined,
                            color: subtitleColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Bookmark Unsave Button
                IconButton(
                  icon: Icon(
                    Icons.bookmark_rounded,
                    color: activeOrange,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                  tooltip: 'Unsave',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
