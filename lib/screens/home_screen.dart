import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_text_styles.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/kats_top_bar.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/feed_momentum_scroll_physics.dart';
import '../widgets/media_post_snap_coordinator.dart';
import '../widgets/post_card.dart';
import '../widgets/share_post_sheet.dart';
import '../widgets/story_avatar.dart';
import 'create_story_screen.dart';
import 'image_viewer_screen.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import 'repost_post_screen.dart';
import 'story_viewer_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';
import 'settings_screen.dart';
import 'bookmarks_screen.dart';
import 'game_room_screen.dart';
import 'wallet_screen.dart';
import '../widgets/top_users_home_card.dart';
import '../services/promotions_service.dart';


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
  List<Post> _promotions = [];
  List<Post> _pendingNewPosts = [];
  List<List<Story>> _storyGroups = [];
  List<Story> _ownStories = [];
  int _unreadNotifications = 0;
  bool _isInitialLoading = true;
  bool _hasLoadedInitialContent = false;
  bool _hasLoadedNetworkFeed = false;
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  late final MediaPostSnapCoordinator _mediaSnapCoordinator;
  StreamSubscription<String>? _postDeletedSubscription;
  StreamSubscription<String>? _postHiddenSubscription;
  StreamSubscription<Post>? _postCreatedSubscription;
  StreamSubscription<Post>? _postUpdatedSubscription;
  StreamSubscription<CommentCountChange>? _commentCountSubscription;
  StreamSubscription<ProfileStatsChange>? _profileStatsSubscription;
  StreamSubscription<void>? _postcardThemesResetSubscription;
  StreamSubscription<void>? _storyCreatedSubscription;

  bool _isHomeMenuOpen = false;
  bool _isHeaderVisible = true;
  bool _isMediaClamping = false;
  final Set<String> _prefetchedPostImages = <String>{};

  List<User> _suggestions = const [];
  final Set<String> _followingUsernames = <String>{};
  final Set<String> _followingInFlight = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _mediaSnapCoordinator = MediaPostSnapCoordinator(
      controller: _scrollController,
      topInsetBuilder: () => _homeHeaderHeight,
      hardClampEnabled: true,
      onClampStateChanged: _handleClampStateChanged,
    );
    _bindFeedEvents();
    // Restore cache first so posts appear instantly, then refresh from network.
    _restoreCachedHomePostsThenLoad();
    _loadSuggestions();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    final promos = await PromotionsService().getActivePromotionPosts();
    if (mounted) {
      setState(() {
        _promotions = promos;
      });
    }
  }

  /// Shows cached posts immediately, then kicks off the network refresh in
  /// background so the user never stares at a skeleton loader on repeat visits.
  Future<void> _restoreCachedHomePostsThenLoad() async {
    await _restoreCachedHomePosts();
    _loadHomeFeed();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userChanged = oldWidget.user.id != widget.user.id;
    final tokenChanged = oldWidget.refreshToken != widget.refreshToken;

    if (userChanged || tokenChanged) {
      if (userChanged) {
        _resetForUserSwitch();
      } else {
        _loadHomeFeed();
      }
    }
  }

  void _resetForUserSwitch() {
    setState(() {
      _posts = [];
      _promotions = [];
      _pendingNewPosts = [];
      _storyGroups = [];
      _ownStories = [];
      _suggestions = [];
      _followingUsernames.clear();
      _isInitialLoading = true;
      _hasLoadedInitialContent = false;
      _hasLoadedNetworkFeed = false;
      _nextOffset = 0;
      _hasMore = true;
      _isLoadingMore = false;
    });

    _loadHomeFeed();
    _loadSuggestions();
    _loadPromotions();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _mediaSnapCoordinator.dispose();
    _postDeletedSubscription?.cancel();
    _postHiddenSubscription?.cancel();
    _postCreatedSubscription?.cancel();
    _postUpdatedSubscription?.cancel();
    _commentCountSubscription?.cancel();
    _profileStatsSubscription?.cancel();
    _postcardThemesResetSubscription?.cancel();
    _storyCreatedSubscription?.cancel();
    FeedService.unreadNotificationsNotifier
        .removeListener(_handleUnreadNotificationsChanged);
    super.dispose();
  }

  void _bindFeedEvents() {
    _postDeletedSubscription =
        FeedService.postDeletedStream.listen(_removePostById);
    _postHiddenSubscription =
        FeedService.postHiddenStream.listen(_removePostById);
    _postCreatedSubscription =
        FeedService.postCreatedStream.listen(_handleCreatedPost);
    _postUpdatedSubscription =
        FeedService.postUpdatedStream.listen(_replacePost);
    _commentCountSubscription =
        FeedService.commentCountChangedStream.listen(_applyCommentCountChange);
    _profileStatsSubscription =
        FeedService.profileStatsChangedStream.listen(_applyProfileStatsChange);
    _postcardThemesResetSubscription = FeedService.postcardThemesResetStream
        .listen((_) => _clearAllPostcardThemes());
    _storyCreatedSubscription = FeedService.storyCreatedStream
        .listen((_) => _loadHomeFeed());
    FeedService.unreadNotificationsNotifier
        .addListener(_handleUnreadNotificationsChanged);
  }

  void _handleUnreadNotificationsChanged() {
    if (!mounted) {
      return;
    }

    final unreadCount = FeedService.unreadNotificationsNotifier.value;
    if (_unreadNotifications == unreadCount) {
      return;
    }

    setState(() {
      _unreadNotifications = unreadCount;
    });
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _loadHomeFeed(),
      _loadSuggestions(),
    ]);
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _feedService.loadFollowSuggestions();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
      });
    } catch (_) {
      // Silently ignore — suggestions are non-critical.
    }
  }

  Future<void> _toggleFollow(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || _followingInFlight.contains(cleanUsername)) {
      return;
    }

    final wasFollowing = _followingUsernames.contains(cleanUsername);
    setState(() {
      _followingInFlight.add(cleanUsername);
      if (wasFollowing) {
        _followingUsernames.remove(cleanUsername);
      } else {
        _followingUsernames.add(cleanUsername);
      }
    });

    try {
      if (wasFollowing) {
        await _feedService.unfollowUser(cleanUsername);
      } else {
        await _feedService.followUser(cleanUsername);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFollowing) {
          _followingUsernames.add(cleanUsername);
        } else {
          _followingUsernames.remove(cleanUsername);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update follow status.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _followingInFlight.remove(cleanUsername);
        });
      }
    }
  }

  void _openSuggestionProfile(String username) {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return;

    if (_isCurrentUser(cleanUsername)) {
      widget.onOpenCurrentUserProfile?.call();
      return;
    }

    final onOpenUserProfile = widget.onOpenUserProfile;
    if (onOpenUserProfile != null) {
      onOpenUserProfile(cleanUsername);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: cleanUsername),
      ),
    );
  }

  Future<void> _restoreCachedHomePosts() async {
    final cachedPosts = await _feedService.loadCachedHomePosts();
    final cachedStories = await _feedService.loadCachedStories();

    if (!mounted) return;
    if (cachedPosts.isEmpty && cachedStories.isEmpty) {
      return;
    }

    setState(() {
      if (cachedPosts.isNotEmpty) {
        _posts = cachedPosts;
        _isInitialLoading = false;
        _hasLoadedInitialContent = true;
      }
      if (cachedStories.isNotEmpty) {
        _storyGroups = _buildStoryGroups(cachedStories);
        _ownStories = _getOwnStories(cachedStories);
        _hasLoadedNetworkFeed = true;
      }
    });
  }

  void _removePostById(String postId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts.where((item) => item.id != postId).toList();
    });
  }

  void _handleCreatedPost(Post createdPost) {
    if (!mounted) {
      return;
    }

    final shouldInclude = createdPost.ownedByMe ||
        createdPost.isFollowingAuthor ||
        createdPost.authorIsAuthor ||
        createdPost.authorIsAdmin;
    if (!shouldInclude) {
      return;
    }

    final alreadyInFeed = _posts.any((item) => item.id == createdPost.id);
    final alreadyPending =
        _pendingNewPosts.any((item) => item.id == createdPost.id);
    if (alreadyInFeed || alreadyPending) return;

    final atTop =
        !_scrollController.hasClients || _scrollController.position.pixels < 80;
    if (atTop || createdPost.ownedByMe) {
      setState(() {
        _posts = [createdPost, ..._posts];
      });
      return;
    }

    setState(() {
      _pendingNewPosts = [createdPost, ..._pendingNewPosts];
    });
  }

  void _showPendingNewPosts() {
    if (_pendingNewPosts.isEmpty) return;
    final pending = _pendingNewPosts;
    setState(() {
      final seen = _posts.map((post) => post.id).toSet();
      final merged = <Post>[
        ...pending.where((post) => seen.add(post.id)),
        ..._posts,
      ];
      _posts = merged;
      _pendingNewPosts = [];
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _applyCommentCountChange(CommentCountChange event) {
    if (!mounted) {
      return;
    }

    final index = _posts.indexWhere((item) => item.id == event.postId);
    if (index < 0 || _posts[index].commentCount == event.commentCount) return;
    final next = List<Post>.from(_posts);
    next[index] = next[index].copyWith(commentCount: event.commentCount);
    setState(() {
      _posts = next;
    });
  }

  void _applyProfileStatsChange(ProfileStatsChange event) {
    final nextTheme = event.user?.postcardTheme ?? '';
    final username = event.username.trim().toLowerCase();
    if (!mounted || username.isEmpty) {
      return;
    }

    List<Post>? nextPosts;
    for (var i = 0; i < _posts.length; i++) {
      final item = _posts[i];
      if (item.authorUsername.trim().toLowerCase() != username ||
          (item.authorPostcardTheme ?? '') == nextTheme) {
        continue;
      }
      nextPosts ??= List<Post>.from(_posts);
      nextPosts[i] = item.copyWith(authorPostcardTheme: nextTheme);
    }

    if (nextPosts == null) return;
    setState(() {
      _posts = nextPosts!;
    });
  }

  Future<void> _loadHomeFeed() async {
    final shouldShowSkeleton = !_hasLoadedInitialContent && _posts.isEmpty;
    setState(() {
      _isInitialLoading = shouldShowSkeleton;
      _isLoadingMore = false;
      _nextOffset = 0;
      _hasMore = true;
    });

    final data = await _feedService.loadHomeFeed();
    if (!mounted) return;

    final uniquePosts = <Post>[];
    final seenIds = <String>{};
    for (final p in data.posts) {
      if (seenIds.add(p.id)) {
        uniquePosts.add(p);
      }
    }

    setState(() {
      _posts = uniquePosts;
      _storyGroups = _buildStoryGroups(data.stories);
      _ownStories = _getOwnStories(data.stories);
      _unreadNotifications = data.unreadNotifications;
      _isInitialLoading = false;
      _hasLoadedInitialContent = true;
      _nextOffset = data.postsOffset + data.posts.length;
      _hasMore = data.postsHasMore;
      _hasLoadedNetworkFeed = true;
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (_isLoadingMore || _isInitialLoading || !_hasMore) return;
    if (position.extentAfter < 1200) {
      _loadMoreHomePosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts = _homePosts(_posts);

    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFF7F8FA),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _handleHomeScrollNotification(notification, posts),
              child: CustomScrollView(
                controller: _scrollController,
                key: const PageStorageKey<String>('home-post-list'),
                cacheExtent: 1500,
                physics: const FeedMomentumScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: _homeHeaderHeight.h),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildHomeItem(context, index, posts),
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
                  color: Theme.of(context).colorScheme.surface,
                  child: SizedBox(
                    height: _homeHeaderHeight.h,
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
          if (_pendingNewPosts.isNotEmpty)
            Positioned(
              top: _homeHeaderHeight.h + 8.h,
              left: 0,
              right: 0,
              child: Center(
                child: _NewPostsBadge(
                  count: _pendingNewPosts.length,
                  onTap: _showPendingNewPosts,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24.h,
            child: Center(
              child: MediaLoadingChip(visible: _isMediaClamping),
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

    final metrics = notification.metrics;
    final extentAfter = metrics.maxScrollExtent - metrics.pixels;
    if (!_isLoadingMore && !_isInitialLoading && _hasMore && extentAfter < 1200) {
      _loadMoreHomePosts();
    }

    if (metrics.pixels <= 4) {
      _setHeaderVisible(true);
      return false;
    }

    final hasReachedFirstPost =
        metrics.pixels >= _storiesRowHeight;

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

  void _handleClampStateChanged(bool isClamping) {
    if (!mounted || _isMediaClamping == isClamping) return;
    setState(() {
      _isMediaClamping = isClamping;
    });
  }

  static const int _kSuggestionsInlineAfter = 5;

  bool _hasInlineSuggestions(List<Post> posts) {
    return !_isInitialLoading &&
        _suggestions.isNotEmpty &&
        posts.length > _kSuggestionsInlineAfter;
  }

  bool _hasEmptyStateSuggestions(List<Post> posts) {
    return !_isInitialLoading && _suggestions.isNotEmpty && posts.isEmpty;
  }

  int _homeItemCount(List<Post> posts) {
    const fixedHeaderCount = 3;
    final contentCount = _isInitialLoading || posts.isEmpty ? 1 : posts.length;
    final inlineSuggestions = _hasInlineSuggestions(posts) ? 1 : 0;
    return fixedHeaderCount +
        contentCount +
        inlineSuggestions +
        (_isLoadingMore ? 3 : 0) +
        1;
  }

  void _prefetchUpcomingPostImages(
      BuildContext context, List<Post> posts, int currentIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final end = (currentIndex + 3).clamp(0, posts.length - 1).toInt();
      for (var i = currentIndex + 1; i <= end; i++) {
        final post = posts[i];
        if (!_prefetchedPostImages.add(post.id)) continue;
        final urls = <String>[];
        if (post.imageUrls.isNotEmpty) urls.add(post.imageUrls.first);
        if (post.videoPosterUrl.trim().isNotEmpty) {
          urls.add(post.videoPosterUrl);
        }
        for (final url in urls) {
          final resolved = ApiConfig.assetUrl(url);
          if (resolved.isEmpty) continue;
          precacheImage(CachedNetworkImageProvider(resolved), context)
              .catchError((_) {});
        }
      }
    });
  }

  Widget _buildHomeItem(BuildContext context, int index, List<Post> posts) {
    if (index == 0) {
      final surfaceColor = Theme.of(context).colorScheme.surface;
      if (!_hasLoadedNetworkFeed && _storyGroups.isEmpty) {
        return ColoredBox(
          color: surfaceColor,
          child: const StorySkeletonRow(),
        );
      }

      return ColoredBox(
        color: surfaceColor,
        child: _StoriesRow(
          key: ValueKey<String>(
            'home-stories-row-${_storyGroups.map((g) => g.first.id).join('-')}',
          ),
          user: widget.user,
          ownStories: _ownStories,
          storyGroups: _storyGroups,
          onStoryTap: _openStoryViewer,
          onCreateStory: _openCreateStory,
        ),
      );
    }

    if (index == 1) {
      return const TopUsersHomeCard();
    }

    if (index == 2) {
      if (_hasEmptyStateSuggestions(posts)) {
        return _buildSuggestionsRail();
      }
      return const SizedBox.shrink();
    }

    final hasInlineRail = _hasInlineSuggestions(posts);
    final inlineRailIndex = 3 + _kSuggestionsInlineAfter;

    if (index == _homeItemCount(posts) - 1) {
      return SizedBox(height: 18.h);
    }

    if (_isLoadingMore && index >= _homeItemCount(posts) - 4) {
      return PostSkeletonCard(variant: index % 4);
    }

    if (hasInlineRail && index == inlineRailIndex) {
      return _buildSuggestionsRail();
    }

    var contentIndex = index - 3;
    if (hasInlineRail && index > inlineRailIndex) {
      contentIndex -= 1;
    }
    if (_isInitialLoading) {
      return Column(
        children: [
          PostSkeletonCard(variant: 0),
          PostSkeletonCard(variant: 1),
        ],
      );
    }

    if (posts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
        child: Column(
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E3),
                borderRadius: BorderRadius.circular(32.r),
              ),
              child: Icon(
                Icons.dynamic_feed_outlined,
                size: 30.r,
                color: Color(0xFFEE8F3F),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Nothing here yet',
              style: TextStyle(fontFamily: 'SF Pro Rounded',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: Color(0xFF1C1E21),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Follow people from the Feed tab and their posts will land here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'SF Pro Rounded',
                fontSize: 13.5.sp,
                color: Color(0xFF65676B),
              ),
            ),
            SizedBox(height: 14.h),
            FilledButton.icon(
              onPressed: _refresh,
              icon: Icon(Icons.refresh, size: 18.r),
              label: Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEE8F3F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
                padding:
                    EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              ),
            ),
          ],
        ),
      );
    }

    _prefetchUpcomingPostImages(context, posts, contentIndex);
    return _buildSnappablePostCard(posts[contentIndex]);
  }

  bool _handleHomeScrollNotification(
    ScrollNotification notification,
    List<Post> posts,
  ) {
    _mediaSnapCoordinator.handleNotification(
      notification,
      posts: posts,
      enabled: posts.isNotEmpty,
      isMediaPost: hasSnappableMedia,
    );
    return _handleHomeScroll(notification);
  }

  Widget _buildSnappablePostCard(Post post) {
    return KeyedSubtree(
      key: _mediaSnapCoordinator.keyForPost(post),
      child: _postCard(post),
    );
  }

  Future<void> _loadMoreHomePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _feedService.loadHomePosts(
        offset: _nextOffset,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        final existingIds = _posts.map((p) => p.id).toSet();
        final newUniquePosts = page.posts.where((p) => !existingIds.contains(p.id)).toList();
        _posts = [..._posts, ...newUniquePosts];
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  List<List<Story>> _buildStoryGroups(List<Story> stories) {
    final groups = <String, List<Story>>{};

    for (final story in stories) {
      if (story.ownedByMe) {
        continue;
      }

      final key = story.authorUsername.trim().toLowerCase().isNotEmpty
          ? story.authorUsername.trim().toLowerCase()
          : story.authorFullName.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }

      groups.putIfAbsent(key, () => []).add(story);
    }

    return groups.values.toList();
  }

  List<Story> _getOwnStories(List<Story> stories) {
    return stories.where((s) => s.ownedByMe).toList();
  }

  List<Post> _homePosts(List<Post> posts) {
    final filtered = posts
        .where(
          (post) =>
              post.ownedByMe ||
              post.isFollowingAuthor ||
              post.authorIsAuthor ||
              post.authorIsAdmin,
        )
        .toList();

    if (filtered.isEmpty || _promotions.isEmpty) {
      return filtered;
    }

    final result = <Post>[];
    int promoIndex = 0;

    for (int i = 0; i < filtered.length; i++) {
      result.add(filtered[i]);
      // Inject promotion every 15 posts
      if ((i + 1) % 15 == 0) {
        final promo = _promotions[promoIndex % _promotions.length];
        result.add(promo);
        promoIndex++;
      }
    }
    return result;
  }

  Widget _postCard(Post post) {
    return PostCard(
      post: post,
      onOpenPost: _openPost,
      onOpenImages: _openImages,
      onOpenAuthor: _openAuthor,
      onLike: _feedService.toggleLike,
      onPollVote: _feedService.votePoll,
      onDelete: _deletePost,
      onHide: _hidePost,
      onUpdate: _replacePost,
      onComment: _openComments,
      onRepost: _openRepostComposer,
      onShare: _showSharePlaceholder,
      onBookmark: _toggleBookmark,
    );
  }

  Future<void> _openRepostComposer(Post post) async {
    final repostedPost = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => RepostPostScreen(originalPost: post),
      ),
    );

    if (!mounted || repostedPost == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post reposted.')),
    );
  }

  void _replacePost(Post updatedPost) {
    if (!mounted) {
      return;
    }

    final index = _posts.indexWhere((item) => item.id == updatedPost.id);
    if (index < 0) return;
    final next = List<Post>.from(_posts);
    next[index] = updatedPost;
    setState(() {
      _posts = next;
    });
  }

  void _clearAllPostcardThemes() {
    if (!mounted) {
      return;
    }

    var changed = false;
    final nextPosts = List<Post>.from(_posts);
    for (var i = 0; i < nextPosts.length; i++) {
      final item = nextPosts[i];
      final hasOwnTheme = (item.authorPostcardTheme ?? '').isNotEmpty;
      final hasInnerTheme =
          (item.originalPost?.authorPostcardTheme ?? '').isNotEmpty;
      if (!hasOwnTheme && !hasInnerTheme) continue;
      changed = true;
      nextPosts[i] = item.copyWith(
        authorPostcardTheme: '',
        originalPost: hasInnerTheme
            ? item.originalPost!.copyWith(authorPostcardTheme: '')
            : item.originalPost,
      );
    }

    if (!changed) return;
    setState(() {
      _posts = nextPosts;
    });
  }

  Future<void> _openComments(Post post) async {
    final commentCount = await showCommentsModal(context: context, post: post);
    if (!mounted || commentCount == null) {
      return;
    }

    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index < 0 || _posts[index].commentCount == commentCount) return;
    final next = List<Post>.from(_posts);
    next[index] = next[index].copyWith(commentCount: commentCount);
    setState(() {
      _posts = next;
    });
  }

  Future<void> _deletePost(Post post) async {
    await _feedService.deletePost(post.id);
    if (!mounted) return;
    setState(() {
      _posts = _posts.where((item) => item.id != post.id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post successfully deleted.')),
    );
  }

  Future<void> _hidePost(Post post) async {
    final previousPosts = List<Post>.from(_posts);

    setState(() {
      _posts = _posts.where((item) => item.id != post.id).toList();
    });

    try {
      await _feedService.hidePost(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post hidden')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = previousPosts;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to hide post.')),
      );
    }
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
            post: post,
            currentUser: widget.user,
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
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          opaque: true,
          barrierColor: Colors.black,
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
          post: post,
          currentUser: widget.user,
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
        user: widget.user,
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
    SharePostSheet.show(
      context,
      post: post,
      currentUser: widget.user,
    );
  }

  Future<void> _toggleBookmark(Post post) async {
    try {
      final updatedPost = await _feedService.toggleBookmark(post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedPost.bookmarkedByMe
              ? 'Added to Bookmarks'
              : 'Removed from Bookmarks'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to bookmark: $e')),
      );
    }
  }

  void _openStoryViewer(int groupIndex, int storyIndex) {
    final groups = _buildViewerGroups();

    if (groups.isEmpty || groupIndex < 0 || groupIndex >= groups.length) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          storyGroups: groups,
          initialGroupIndex: groupIndex,
          initialStoryIndex: storyIndex,
        ),
      ),
    );
  }

  List<List<Story>> _buildViewerGroups() {
    final groups = <List<Story>>[];

    // Add own stories as first group if available
    if (_ownStories.isNotEmpty) {
      groups.add(_ownStories);
    }

    // Add other users' story groups
    groups.addAll(_storyGroups);

    return groups;
  }

  Future<void> _openCreateStory() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(user: widget.user),
      ),
    );
    if (created == true) {
      _loadHomeFeed();
    }
  }

  Widget _buildSuggestionsRail() {
    final visible = _suggestions
        .where((user) => (user.username ?? '').trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SuggestionsRail(
      key: const PageStorageKey<String>('home-suggestions-rail-root'),
      users: visible,
      followingUsernames: _followingUsernames,
      followingInFlight: _followingInFlight,
      onFollowTap: _toggleFollow,
      onOpenProfile: _openSuggestionProfile,
    );
  }
}

class _HomeMenuSheet extends StatelessWidget {
  const _HomeMenuSheet({
    required this.user,
    required this.onLogout,
    required this.onPlaceholder,
  });

  final User user;
  final Future<void> Function() onLogout;
  final ValueChanged<String> onPlaceholder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isDark ? const Color(0xFF1C1E21) : const Color(0xFFF7F7F7);
    final cardBgColor = isDark ? const Color(0xFF242526) : Colors.white;
    final dragHandleColor = isDark ? const Color(0xFF4E4F51) : const Color(0xFFD1D5DB);
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    final footerColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: dragHandleColor,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            SizedBox(height: 16.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: cardBgColor,
                child: Column(
                  children: [
                    _HomeMenuItem(
                      label: 'Bookmarks',
                      icon: Icons.bookmark_border_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookmarksScreen(user: user),
                          ),
                        );
                      },
                    ),
                    _HomeMenuItem(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WalletScreen(user: user),
                          ),
                        );
                      },
                    ),
                    _HomeMenuItem(
                      label: 'Play Mini-Games',
                      icon: Icons.videogame_asset_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameRoomScreen(user: user),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: dividerColor),
                    _HomeMenuItem(
                      label: 'Account settings',
                      icon: Icons.settings_outlined,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsScreen(
                              user: user,
                              onLogout: onLogout,
                            ),
                          ),
                        );
                      },
                    ),
                    _HomeMenuItem(
                      label: 'Logout',
                      icon: Icons.logout_rounded,
                      color: const Color(0xFFE53935),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await onLogout();
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18.h),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontFamily: 'SF Pro Rounded',
                  color: footerColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
                children: const [
                  TextSpan(text: 'Katsklub © 2026 - '),
                  TextSpan(
                    text: 'Created by Riel Seyer',
                    style: TextStyle(fontFamily: 'SF Pro Rounded',decoration: TextDecoration.underline),
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
    this.color = const Color(0xFF1C1E21),
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = color == const Color(0xFF1C1E21)
        ? (isDark ? Colors.white : const Color(0xFF1C1E21))
        : color;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontFamily: 'SF Pro Rounded',
                  color: resolvedColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(icon, color: resolvedColor, size: 23.r),
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
    required this.ownStories,
    required this.storyGroups,
    required this.onStoryTap,
    required this.onCreateStory,
  });

  final User user;
  final List<Story> ownStories;
  final List<List<Story>> storyGroups;
  final void Function(int groupIndex, int storyIndex) onStoryTap;
  final VoidCallback onCreateStory;

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

    final hasOwnStories = widget.ownStories.isNotEmpty;

    return SizedBox(
      height: 102.h,
      child: ListView.separated(
        key: PageStorageKey<String>(
          'home-stories-row-${widget.storyGroups.map((g) => g.first.id).join('-')}',
        ),
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        scrollDirection: Axis.horizontal,
        itemCount: widget.storyGroups.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 4.w),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _OwnStoryAvatar(
              key: ValueKey<String>('home-story-own-${widget.user.id ?? 'me'}'),
              user: widget.user,
              hasStories: hasOwnStories,
              onOpenViewer:
                  hasOwnStories ? () => widget.onStoryTap(0, 0) : null,
              onCreateStory: widget.onCreateStory,
            );
          }

          final group = widget.storyGroups[index - 1];
          final firstStory = group.first;
          // Group index in viewer: if own stories exist, they're at index 0,
          // so other users start at index 1
          final viewerGroupIndex = hasOwnStories ? index : index - 1;
          return StoryAvatar(
            key: ValueKey<String>('home-story-${firstStory.id}'),
            label: firstStory.authorFullName,
            initials: firstStory.initials,
            avatarUrl: firstStory.authorAvatarUrl,
            onTap: () => widget.onStoryTap(viewerGroupIndex, 0),
          );
        },
      ),
    );
  }
}

class _OwnStoryAvatar extends StatelessWidget {
  const _OwnStoryAvatar({
    super.key,
    required this.user,
    required this.hasStories,
    this.onOpenViewer,
    required this.onCreateStory,
  });

  final User user;
  final bool hasStories;
  final VoidCallback? onOpenViewer;
  final VoidCallback onCreateStory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onOpenViewer ?? onCreateStory,
                child: Container(
                  width: 72.w,
                  height: 72.w,
                  padding: EdgeInsets.all(2.5.r),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: user.avatarUrl?.trim().isEmpty ?? true
                            ? ColoredBox(
                                color: const Color(0xFFE5E7EB),
                                child: Center(
                                  child: Text(
                                    user.initials,
                                    style: TextStyle(fontFamily: 'SF Pro Rounded',
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1C1E21),
                                    ),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: ApiConfig.assetUrl(user.avatarUrl!),
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholderFadeInDuration: Duration.zero,
                                placeholder: (context, url) => const ColoredBox(
                                  color: Color(0xFFE5E7EB),
                                ),
                                errorWidget: (context, url, error) =>
                                    const ColoredBox(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onCreateStory,
                  child: Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5.w),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 14.r,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          Text(
            hasStories ? 'Your Story' : 'Add Story',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'SF Pro Rounded',
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPostsBadge extends StatelessWidget {
  const _NewPostsBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 new post' : '$count new posts';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFFEE8F3F),
            borderRadius: BorderRadius.circular(999.r),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10.r,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_upward_rounded,
                  size: 16.r, color: Colors.white),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(fontFamily: 'SF Pro Rounded',
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionsRail extends StatefulWidget {
  const _SuggestionsRail({
    super.key,
    required this.users,
    required this.followingUsernames,
    required this.followingInFlight,
    required this.onFollowTap,
    required this.onOpenProfile,
  });

  final List<User> users;
  final Set<String> followingUsernames;
  final Set<String> followingInFlight;
  final ValueChanged<String> onFollowTap;
  final ValueChanged<String> onOpenProfile;

  @override
  State<_SuggestionsRail> createState() => _SuggestionsRailState();
}

class _SuggestionsRailState extends State<_SuggestionsRail>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
            child: Text(
              'Suggested for you',
              style: TextStyle(fontFamily: 'SF Pro Rounded',
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
          ),
          SizedBox(
            height: 260.h,
            child: ListView.separated(
              key: const PageStorageKey<String>('home-suggestions-rail'),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: widget.users.length,
              separatorBuilder: (_, __) => SizedBox(width: 10.w),
              itemBuilder: (context, index) {
                final user = widget.users[index];
                final username = (user.username ?? '').trim();
                final normalized = username.toLowerCase();
                return RepaintBoundary(
                  child: _SuggestionCard(
                    user: user,
                    isFollowing: widget.followingUsernames.contains(normalized),
                    isLoading: widget.followingInFlight.contains(normalized),
                    onFollowTap: () => widget.onFollowTap(normalized),
                    onTap: () => widget.onOpenProfile(username),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.user,
    required this.isFollowing,
    required this.isLoading,
    required this.onFollowTap,
    required this.onTap,
  });

  final User user;
  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onFollowTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Aim for ~2 cards visible on first screen with a peek of the third.
    // Rail has 12px horizontal padding + 10px gap between cards.
    final cardWidth = ((mediaWidth - 12 * 2 - 10) / 2.2).clamp(160.0, 220.0);
    final displayName = user.displayName;
    final avatarUrl = (user.avatarUrl ?? '').trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242526) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: avatarUrl.isEmpty
                  ? ColoredBox(
                      color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                      child: Center(
                        child: Text(
                          user.initials,
                          style: TextStyle(fontFamily: 'SF Pro Rounded',
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF1C1E21),
                            fontSize: 44.sp,
                          ),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: ApiConfig.assetUrl(avatarUrl),
                      memCacheWidth: 300,
                      maxWidthDiskCache: 300,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ColoredBox(
                        color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: TextStyle(fontFamily: 'SF Pro Rounded',
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF1C1E21),
                              fontSize: 44.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'SF Pro Rounded',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox(
                    height: 32.h,
                    child: FilledButton(
                      onPressed: isLoading ? null : onFollowTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: isFollowing
                            ? (isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB))
                            : const Color(0xFFFF7A45),
                        foregroundColor: isFollowing
                            ? (isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151))
                            : Colors.white,
                        disabledBackgroundColor: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                        padding:
                            EdgeInsets.symmetric(horizontal: 14.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        textStyle: TextStyle(fontFamily: 'SF Pro Rounded',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isFollowing
                                    ? (isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151))
                                    : Colors.white,
                              ),
                            )
                          : Text(isFollowing ? 'Following' : 'Follow'),
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
