import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/post.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/kats_top_bar.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/post_card.dart';
import '../widgets/story_avatar.dart';
import 'image_viewer_screen.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.user,
    required this.refreshToken,
    required this.onLogout,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    super.key,
  });

  final User user;
  final int refreshToken;
  final Future<void> Function() onLogout;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  static const double _homeHeaderHeight = 58;
  static const double _storiesRowHeight = 124;
  static const Duration _homeHeaderAnimationDuration =
      Duration(milliseconds: 180);

  final FeedService _feedService = FeedService();

  List<Post> _posts = [];
  List<Story> _groupedStories = [];
  int _unreadNotifications = 0;
  bool _isInitialLoading = true;
  bool _isHomeMenuOpen = false;
  bool _isHeaderVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _restoreCachedHomePosts();
    _loadHomeFeed();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadHomeFeed();
    }
  }

  Future<void> _refresh() async {
    await _loadHomeFeed();
  }

  Future<void> _restoreCachedHomePosts() async {
    final cachedPosts = await _feedService.loadCachedHomePosts();
    if (!mounted || cachedPosts.isEmpty) {
      return;
    }

    setState(() {
      _posts = cachedPosts;
      _isInitialLoading = false;
    });
  }

  Future<void> _loadHomeFeed() async {
    final shouldShowSkeleton = _posts.isEmpty;
    setState(() {
      _isInitialLoading = shouldShowSkeleton;
    });

    final data = await _feedService.loadHomeFeed();
    if (!mounted) return;

    setState(() {
      _posts = data.posts;
      _groupedStories = _groupStories(data.stories);
      _unreadNotifications = data.unreadNotifications;
      _isInitialLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts = _homePosts(_posts);
    final stories = _groupedStories;

    return ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleHomeScroll,
              child: CustomScrollView(
                key: const PageStorageKey<String>('home-post-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(height: _homeHeaderHeight),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildHomeItem(index, posts, stories),
                      childCount: _homeItemCount(posts),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: _isHeaderVisible ? Offset.zero : const Offset(0, -1),
              duration: _homeHeaderAnimationDuration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _isHeaderVisible ? 1 : 0,
                duration: _homeHeaderAnimationDuration,
                curve: Curves.easeOutCubic,
                child: Material(
                  color: Colors.white,
                  child: SizedBox(
                    height: _homeHeaderHeight,
                    child: KatsTopBar(
                      unreadNotifications: _unreadNotifications,
                      isMenuOpen: _isHomeMenuOpen,
                      onHomeTap: _showHomeMenu,
                      onNotificationsTap: _openNotifications,
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

  bool _handleHomeScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification.metrics.pixels <= 4) {
      _setHeaderVisible(true);
      return false;
    }

    final hasReachedFirstPost =
        notification.metrics.pixels >= _storiesRowHeight;

    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta ?? 0;
      if (scrollDelta > 0 && hasReachedFirstPost) {
        _setHeaderVisible(false);
      } else if (scrollDelta < 0) {
        _setHeaderVisible(true);
      }
    }

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse &&
          hasReachedFirstPost) {
        _setHeaderVisible(false);
      } else if (notification.direction == ScrollDirection.forward) {
        _setHeaderVisible(true);
      }
    }

    return false;
  }

  void _setHeaderVisible(bool visible) {
    if (_isHeaderVisible == visible || !mounted) {
      return;
    }

    setState(() {
      _isHeaderVisible = visible;
    });
  }

  int _homeItemCount(List<Post> posts) {
    const fixedHeaderCount = 2;
    final contentCount = _isInitialLoading || posts.isEmpty ? 1 : posts.length;
    return fixedHeaderCount + contentCount + 1;
  }

  Widget _buildHomeItem(int index, List<Post> posts, List<Story> stories) {
    if (index == 0) {
      if (_isInitialLoading && stories.isEmpty) {
        return const ColoredBox(
          color: Colors.white,
          child: StorySkeletonRow(),
        );
      }

      return ColoredBox(
        color: Colors.white,
        child: _StoriesRow(
          key: ValueKey<String>(
            'home-stories-row-${stories.map((story) => story.id).join('-')}',
          ),
          user: widget.user,
          stories: stories,
          onStoryTap: _showStoryPlaceholder,
        ),
      );
    }

    if (index == 1) {
      return const SizedBox.shrink();
    }

    if (index == _homeItemCount(posts) - 1) {
      return const SizedBox(height: 18);
    }

    final contentIndex = index - 2;
    if (_isInitialLoading) {
      return const Column(
        children: [
          PostSkeletonCard(),
          PostSkeletonCard(),
        ],
      );
    }

    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            Text(
              'No posts yet.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Pull to refresh.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return _postCard(posts[contentIndex]);
  }

  List<Story> _groupStories(List<Story> stories) {
    final seen = <String>{};
    final grouped = <Story>[];

    for (final story in stories) {
      if (story.ownedByMe) {
        continue;
      }

      final key = story.authorUsername.trim().toLowerCase().isNotEmpty
          ? story.authorUsername.trim().toLowerCase()
          : story.authorFullName.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      grouped.add(story);
    }

    return grouped;
  }

  List<Post> _homePosts(List<Post> posts) {
    return posts
        .where(
          (post) =>
              !post.isReel &&
              (post.ownedByMe ||
                  post.isFollowingAuthor ||
                  post.authorIsAuthor ||
                  post.authorIsAdmin),
        )
        .toList();
  }

  Widget _postCard(Post post) {
    return PostCard(
      post: post,
      onOpenPost: _openPost,
      onOpenImages: _openImages,
      onOpenAuthor: _openAuthor,
      onLike: FeedService().toggleLike,
      onDelete: _deletePost,
      onComment: _openComments,
      onShare: _showSharePlaceholder,
      onBookmark: _showBookmarkPlaceholder,
    );
  }

  Future<void> _openComments(Post post) async {
    final commentCount = await showCommentsModal(context: context, post: post);
    if (!mounted || commentCount == null) {
      return;
    }

    setState(() {
      _posts = _posts
          .map(
            (item) => item.id == post.id
                ? item.copyWith(commentCount: commentCount)
                : item,
          )
          .toList();
    });
  }

  Future<void> _deletePost(Post post) async {
    await _feedService.deletePost(post.id);
    if (!mounted) return;
    setState(() {
      _posts = _posts.where((item) => item.id != post.id).toList();
    });
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: post.id,
          initialPost: post,
          currentUser: widget.user,
          onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
          onOpenUserProfile: widget.onOpenUserProfile,
        ),
      ),
    );
  }

  void _openImages(Post post, int index) {
    // Single image: go directly to lightbox
    if (post.imageUrls.length == 1) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ImageViewerScreen(
            imageUrls: post.imageUrls,
            initialIndex: index,
            postId: post.id,
            uploaderName: post.authorFullName,
            createdAt: post.createdAt,
            privacyLabel: post.privacyLabel,
            caption: post.text,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fade transition for background
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.5),
        ),
      );
      return;
    }

    // Multiple images: go to vertical gallery first
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerticalGalleryScreen(
          imageUrls: post.imageUrls,
          initialIndex: index,
          postId: post.id,
          uploaderName: post.authorFullName,
          createdAt: post.createdAt,
          privacyLabel: post.privacyLabel,
          caption: post.text,
          likeCount: post.likeCount,
          commentCount: post.commentCount,
        ),
      ),
    );
  }

  void _openAuthor(Post post) {
    final authorUsername = post.authorUsername.trim();
    if (authorUsername.isEmpty) return;

    if (_isCurrentUser(authorUsername)) {
      widget.onOpenCurrentUserProfile?.call();
      return;
    }

    final onOpenUserProfile = widget.onOpenUserProfile;
    if (onOpenUserProfile != null) {
      onOpenUserProfile(authorUsername);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: authorUsername),
      ),
    );
  }

  bool _isCurrentUser(String username) {
    final currentUsername = widget.user.username?.trim().toLowerCase() ?? '';
    return currentUsername.isNotEmpty &&
        username.trim().toLowerCase() == currentUsername;
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _showHomeMenu() async {
    if (_isHomeMenuOpen) {
      return;
    }

    setState(() {
      _isHomeMenuOpen = true;
      _isHeaderVisible = true;
    });

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (context) => _HomeMenuSheet(
        onLogout: widget.onLogout,
        onPlaceholder: _showMenuPlaceholder,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isHomeMenuOpen = false;
    });
  }

  void _showMenuPlaceholder(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is not available yet.')),
    );
  }

  void _showSharePlaceholder(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share placeholder: ${post.id}')),
    );
  }

  void _showBookmarkPlaceholder(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save/bookmark is not available yet.')),
    );
  }

  void _showStoryPlaceholder(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Story viewer coming soon: $label')),
    );
  }
}

class _HomeMenuSheet extends StatelessWidget {
  const _HomeMenuSheet({
    required this.onLogout,
    required this.onPlaceholder,
  });

  final Future<void> Function() onLogout;
  final ValueChanged<String> onPlaceholder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: Colors.white,
                child: Column(
                  children: [
                    _HomeMenuItem(
                      label: 'Bookmarks',
                      icon: Icons.bookmark_border_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        onPlaceholder('Bookmarks');
                      },
                    ),
                    _HomeMenuItem(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        onPlaceholder('Wallet');
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    _HomeMenuItem(
                      label: 'Account settings',
                      icon: Icons.settings_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        onPlaceholder('Account settings');
                      },
                    ),
                    _HomeMenuItem(
                      label: 'Logout',
                      icon: Icons.logout_rounded,
                      color: Color(0xFFE53935),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await onLogout();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(text: 'Katsklub © 2026 - '),
                  TextSpan(
                    text: 'Created by Riel Seyer',
                    style: TextStyle(decoration: TextDecoration.underline),
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

class _HomeMenuItem extends StatelessWidget {
  const _HomeMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF111827),
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(icon, color: color, size: 23),
          ],
        ),
      ),
    );
  }
}

class _StoriesRow extends StatefulWidget {
  const _StoriesRow({
    super.key,
    required this.user,
    required this.stories,
    required this.onStoryTap,
  });

  final User user;
  final List<Story> stories;
  final ValueChanged<String> onStoryTap;

  @override
  State<_StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<_StoriesRow>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SizedBox(
      height: 124,
      child: ListView.separated(
        key: PageStorageKey<String>(
          'home-stories-row-${widget.stories.map((story) => story.id).join('-')}',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: widget.stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return StoryAvatar(
              key: ValueKey<String>('home-story-own-${widget.user.id ?? 'me'}'),
              label: 'Your Story',
              initials: widget.user.initials,
              avatarUrl: widget.user.avatarUrl ?? '',
              isOwnStory: true,
              showPlus: true,
              onTap: () => widget.onStoryTap('Your Story'),
            );
          }

          final story = widget.stories[index - 1];
          return StoryAvatar(
            key: ValueKey<String>('home-story-${story.id}'),
            label: story.authorFullName,
            initials: story.initials,
            avatarUrl: story.authorAvatarUrl,
            onTap: () => widget.onStoryTap(story.authorFullName),
          );
        },
      ),
    );
  }
}
