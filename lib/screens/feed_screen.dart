import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/custom_icons.dart';
import '../widgets/feed_momentum_scroll_physics.dart';
import '../widgets/media_post_snap_coordinator.dart';
import '../widgets/post_card.dart';
import '../widgets/share_post_sheet.dart';
import 'hashtag_screen.dart';
import 'image_viewer_screen.dart';
import 'post_detail_screen.dart';
import 'reels_viewer_screen.dart';
import 'repost_post_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    required this.user,
    required this.refreshToken,
    this.isTabActive = true,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    super.key,
  });

  final User user;
  final int refreshToken;
  final bool isTabActive;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 10;
  static const int _maxInitialSeedPages = 4;
  static const int _maxRailReels = 4;

  final ScrollController _scrollController = ScrollController();
  late final MediaPostSnapCoordinator _mediaSnapCoordinator;
  final FeedService _feedService = FeedService();
  final TextEditingController _peopleSearchController = TextEditingController();

  String _activeTab = 'posts';
  Timer? _peopleSearchDebounce;
  Set<String> _followedUsernames = <String>{};
  Set<String> _followPendingUsernames = <String>{};
  List<User> _suggestedCreators = [];
  bool _isLoadingSuggestions = false;
  List<User> _searchPeopleResults = [];
  List<HashtagResult> _searchHashtagResults = [];
  String _peopleSearchQuery = '';
  List<Post> _posts = [];
  List<Post> _railReels = [];
  bool _isInitialLoading = true;
  bool _hasLoadedInitialContent = false;
  bool _isSearchingPeople = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _railReelsLocked = false;
  int _nextOffset = 0;
  double _lastScrollPixels = 0;
  StreamSubscription<String>? _postDeletedSubscription;
  StreamSubscription<String>? _postHiddenSubscription;
  StreamSubscription<Post>? _postUpdatedSubscription;
  StreamSubscription<CommentCountChange>? _commentCountSubscription;
  StreamSubscription<ProfileStatsChange>? _profileStatsSubscription;
  StreamSubscription<void>? _postcardThemesResetSubscription;
  final Set<String> _prefetchedPostImages = <String>{};
  bool _isMediaClamping = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _mediaSnapCoordinator = MediaPostSnapCoordinator(
      controller: _scrollController,
      topInsetBuilder: _feedSnapTopInset,
      hardClampEnabled: true,
      onClampStateChanged: _handleClampStateChanged,
    );
    _bindFeedEvents();
    _loadInitialFeed();
    _loadFollowedUsers();
    _loadSuggestedCreators();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _mediaSnapCoordinator.dispose();
    _peopleSearchDebounce?.cancel();
    _peopleSearchController.dispose();
    _postDeletedSubscription?.cancel();
    _postHiddenSubscription?.cancel();
    _postUpdatedSubscription?.cancel();
    _commentCountSubscription?.cancel();
    _profileStatsSubscription?.cancel();
    _postcardThemesResetSubscription?.cancel();
    super.dispose();
  }

  void _bindFeedEvents() {
    _postDeletedSubscription =
        FeedService.postDeletedStream.listen(_removePostById);
    _postHiddenSubscription =
        FeedService.postHiddenStream.listen(_removePostById);
    _postUpdatedSubscription =
        FeedService.postUpdatedStream.listen(_replacePost);
    _commentCountSubscription =
        FeedService.commentCountChangedStream.listen(_applyCommentCountChange);
    _profileStatsSubscription =
        FeedService.profileStatsChangedStream.listen(_applyProfileStatsChange);
    _postcardThemesResetSubscription = FeedService.postcardThemesResetStream
        .listen((_) => _clearAllPostcardThemes());
  }

  void _removePostById(String postId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts.where((item) => item.id != postId).toList();
      _railReels = _railReels.where((item) => item.id != postId).toList();
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

  void _applyCommentCountChange(CommentCountChange event) {
    if (!mounted) {
      return;
    }

    final postIndex = _posts.indexWhere((item) => item.id == event.postId);
    final reelIndex = _railReels.indexWhere((item) => item.id == event.postId);
    if (postIndex < 0 && reelIndex < 0) return;

    List<Post>? nextPosts;
    List<Post>? nextReels;
    if (postIndex >= 0 &&
        _posts[postIndex].commentCount != event.commentCount) {
      nextPosts = List<Post>.from(_posts);
      nextPosts[postIndex] =
          nextPosts[postIndex].copyWith(commentCount: event.commentCount);
    }
    if (reelIndex >= 0 &&
        _railReels[reelIndex].commentCount != event.commentCount) {
      nextReels = List<Post>.from(_railReels);
      nextReels[reelIndex] =
          nextReels[reelIndex].copyWith(commentCount: event.commentCount);
    }

    if (nextPosts == null && nextReels == null) return;
    setState(() {
      if (nextPosts != null) _posts = nextPosts;
      if (nextReels != null) _railReels = nextReels;
    });
  }

  void _applyProfileStatsChange(ProfileStatsChange event) {
    final nextTheme = event.user?.postcardTheme ?? '';
    final username = event.username.trim().toLowerCase();
    if (!mounted || username.isEmpty) {
      return;
    }

    List<Post>? nextPosts;
    List<Post>? nextRailReels;
    for (var i = 0; i < _posts.length; i++) {
      final item = _posts[i];
      if (item.authorUsername.trim().toLowerCase() != username ||
          (item.authorPostcardTheme ?? '') == nextTheme) {
        continue;
      }
      nextPosts ??= List<Post>.from(_posts);
      nextPosts[i] = item.copyWith(authorPostcardTheme: nextTheme);
    }
    for (var i = 0; i < _railReels.length; i++) {
      final item = _railReels[i];
      if (item.authorUsername.trim().toLowerCase() != username ||
          (item.authorPostcardTheme ?? '') == nextTheme) {
        continue;
      }
      nextRailReels ??= List<Post>.from(_railReels);
      nextRailReels[i] = item.copyWith(authorPostcardTheme: nextTheme);
    }

    if (nextPosts == null && nextRailReels == null) return;
    setState(() {
      if (nextPosts != null) _posts = nextPosts;
      if (nextRailReels != null) _railReels = nextRailReels;
    });
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userChanged = oldWidget.user.id != widget.user.id;
    final tokenChanged = oldWidget.refreshToken != widget.refreshToken;

    if (userChanged || tokenChanged) {
      if (userChanged) {
        setState(() {
          _posts = [];
          _railReels = [];
          _isInitialLoading = true;
          _hasLoadedInitialContent = false;
          _nextOffset = 0;
          _hasMore = true;
          _isLoadingMore = false;
        });
      }
      _loadInitialFeed();
      _loadFollowedUsers();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final currentPixels = position.pixels;
    final isScrollingDown = currentPixels > _lastScrollPixels;
    _lastScrollPixels = currentPixels;

    if (!isScrollingDown ||
        _isLoadingMore ||
        _isInitialLoading ||
        !_hasMore ||
        position.maxScrollExtent <= 0) {
      return;
    }

    // Load older posts only when scrolling downward near the bottom.
    if (position.extentAfter < 700) {
      _loadMoreFeed();
    }
  }

  Future<void> _loadInitialFeed() async {
    final shouldShowSkeleton = !_hasLoadedInitialContent && _posts.isEmpty;
    setState(() {
      _isInitialLoading = shouldShowSkeleton;
      _isLoadingMore = false;
      _hasMore = true;
      _railReels = [];
      _railReelsLocked = false;
      _nextOffset = 0;
      if (shouldShowSkeleton) {
        _posts = [];
      }
    });

    try {
      final seed = await _loadInitialFeedSeed();
      final railReels = await _loadRailReelsSeed();
      if (!mounted) return;
      setState(() {
        _posts = seed.posts;
        _railReels = railReels;
        _railReelsLocked = true;
        _nextOffset = seed.nextOffset;
        _hasMore = seed.hasMore;
        _isInitialLoading = false;
        _hasLoadedInitialContent = true;
      });
    } catch (e, stack) {
      print('DEBUG: _loadInitialFeed caught error: $e');
      print(stack);
      if (!mounted) return;
      setState(() {
        _posts = [];
        _railReels = [];
        _railReelsLocked = true;
        _hasMore = false;
        _isInitialLoading = false;
        _hasLoadedInitialContent = true;
      });
    }
  }

  Future<_FeedSeedResult> _loadInitialFeedSeed() async {
    var loadedPosts = <Post>[];
    var offset = 0;
    var hasMore = true;

    for (var pageIndex = 0; pageIndex < _maxInitialSeedPages; pageIndex++) {
      final page =
          await _feedService.loadFeed(offset: offset, limit: _pageSize);
      loadedPosts = _mergePosts(loadedPosts, page.posts);
      final advanced = offset + page.posts.length;
      offset = (page.offset > offset)
          ? (page.offset + page.posts.length)
          : advanced;
      hasMore = page.hasMore && page.posts.length >= _pageSize;

      if (!hasMore || page.posts.isEmpty) {
        break;
      }
    }

    return _FeedSeedResult(
      posts: loadedPosts,
      nextOffset: offset,
      hasMore: hasMore,
    );
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _feedService.loadFeed(
        offset: _nextOffset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        final mergedPosts = _mergePosts(_posts, page.posts);
        _posts = mergedPosts;
        final advanced = _nextOffset + page.posts.length;
        _nextOffset = (page.offset > _nextOffset)
            ? (page.offset + page.posts.length)
            : advanced;
        _hasMore = page.hasMore && page.posts.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e, stack) {
      print('DEBUG: _loadMoreFeed caught error: $e');
      print(stack);
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_activeTab == 'explore') {
      await Future.wait([
        _loadSuggestedCreators(forceRefresh: true),
        _loadFollowedUsers(),
      ]);
    } else {
      await Future.wait([
        _loadInitialFeed(),
        _loadFollowedUsers(),
      ]);
    }
  }

  Future<List<Post>> _loadRailReelsSeed() async {
    if (_railReelsLocked) {
      return _railReels;
    }

    final page = await _feedService.loadReels(limit: 20);
    final reels = _eligibleReels(page.posts);
    reels.shuffle(math.Random());
    return reels.take(_maxRailReels).toList(growable: false);
  }

  List<Post> _eligibleReels(List<Post> posts) {
    return posts
        .where((post) =>
            post.isReel &&
            (post.videoUrl.trim().isNotEmpty || post.imageUrls.isNotEmpty))
        .toList();
  }

  Future<void> _loadFollowedUsers() async {
    final followedUsernames = await _feedService.loadFriendUsernames();
    if (!mounted) return;
    setState(() {
      _followedUsernames = followedUsernames;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final posts = _visiblePosts(_posts);
    final exploreMediaPosts = _getExploreMediaPosts(posts);
    final people = _visiblePeople();
    final hashtags = _visibleHashtags();
    final searchEntries = _buildSearchEntries(people, hashtags);
    final headerHeight = _activeTab == 'explore' ? 104.0 : 48.0;

    return Stack(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: RefreshIndicator(
            onRefresh: _refresh,
            edgeOffset: headerHeight,
            displacement: 24.h,
            color: const Color(0xFFFF7A45),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF222224)
                : Colors.white,
            strokeWidth: 2.8,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _handleFeedScrollNotification(notification, posts),
              child: CustomScrollView(
                key: const PageStorageKey<String>('feed-post-list'),
                controller: _scrollController,
                cacheExtent: 1500,
                physics: const FeedMomentumScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabDelegate(
                      extent: headerHeight,
                      child: _FeedHeader(
                        activeTab: _activeTab,
                        searchController: _peopleSearchController,
                        onSearchChanged: _handlePeopleSearchChanged,
                        onChanged: (tab) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _activeTab = tab;
                          });
                          if (_scrollController.hasClients &&
                              _scrollController.offset > 0) {
                            _scrollController.jumpTo(0);
                          }
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _activeTab == 'explore'
                            ? _buildExploreItem(
                                context,
                                index,
                                exploreMediaPosts,
                                searchEntries,
                                people,
                              )
                            : _buildFeedItem(context, index, posts),
                        childCount: _activeTab == 'explore'
                            ? _exploreItemCount(exploreMediaPosts)
                            : _feedItemCount(posts),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: MediaLoadingChip(visible: _isMediaClamping),
          ),
        ),
      ],
    );
  }

  int _feedItemCount(List<Post> posts) {
    if (!_isInitialLoading && posts.isNotEmpty && _railReels.isNotEmpty) {
      return posts.length + 1 + (_isLoadingMore ? 3 : 0);
    }

    if (_isInitialLoading || posts.isEmpty) {
      return 1;
    }

    return posts.length + (_isLoadingMore ? 3 : 0);
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

  Widget _buildFeedItem(BuildContext context, int index, List<Post> posts) {
    if (_isInitialLoading) {
      return Column(
        children: [
          PostSkeletonCard(variant: 0),
          PostSkeletonCard(variant: 1),
          PostSkeletonCard(variant: 2),
        ],
      );
    }

    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E3),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.people_alt_outlined,
                size: 30,
                color: Color(0xFFEE8F3F),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Your feed is quiet',
              style: TextStyle(fontFamily: 'SF Pro Rounded',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFE4E6EB)
                    : const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Follow people to fill your feed with their posts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'SF Pro Rounded',
                fontSize: 13.5.sp,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B3B8)
                    : const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => setState(() => _activeTab = 'explore'),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explore KatsKlub'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEE8F3F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    final reelsInsertOffset = math.min(7, posts.length);
    final reelsItemIndex = _railReels.isNotEmpty ? reelsInsertOffset : null;

    if (reelsItemIndex != null && index == reelsItemIndex) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _ReelsRail(
          key: ValueKey<String>(
            'feed-reels-rail-${_railReels.map((reel) => reel.id).join('-')}',
          ),
          reels: _railReels,
          isTabActive: widget.isTabActive,
          onReelTap: _openRailReel,
        ),
      );
    }

    final contentIndex =
        index - (reelsItemIndex != null && index > reelsItemIndex ? 1 : 0);
    if (contentIndex >= 0 && contentIndex < posts.length) {
      _prefetchUpcomingPostImages(context, posts, contentIndex);
      return _buildSnappablePostCard(posts[contentIndex]);
    }

    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: PostSkeletonCard(variant: index % 4),
    );
  }

  double _feedSnapTopInset() {
    return _activeTab == 'explore' ? 104.0 : 48.0;
  }

  void _handleClampStateChanged(bool isClamping) {
    if (!mounted || _isMediaClamping == isClamping) return;
    setState(() {
      _isMediaClamping = isClamping;
    });
  }

  bool _handleFeedScrollNotification(
    ScrollNotification notification,
    List<Post> posts,
  ) {
    _mediaSnapCoordinator.handleNotification(
      notification,
      posts: posts,
      enabled: _activeTab == 'posts' && posts.isNotEmpty,
      isMediaPost: hasSnappableMedia,
    );
    return false;
  }

  Widget _buildSnappablePostCard(Post post) {
    return RepaintBoundary(
      child: KeyedSubtree(
        key: _mediaSnapCoordinator.keyForPost(post),
        child: _postCard(post),
      ),
    );
  }

  List<Post> _mergePosts(List<Post> existing, List<Post> incoming) {
    final merged = <Post>[
      ...existing,
    ];
    final seen = existing.map((post) => post.id).toSet();
    for (final post in incoming) {
      if (seen.add(post.id)) {
        merged.add(post);
      }
    }
    return merged;
  }

  List<Post> _visiblePosts(List<Post> posts) {
    return posts
        .where(
          (post) =>
              !_isOwnPost(post) &&
              !post.isFollowingAuthor &&
              !_isFollowedUsername(post.authorUsername),
        )
        .toList();
  }

  List<User> _visiblePeople() {
    final isSearching = _peopleSearchQuery.trim().length >= 2;
    final sourcePeople = isSearching
        ? _searchPeopleResults
        : _suggestedCreators;
    final seen = <String>{};
    final visible = <User>[];

    for (final user in sourcePeople) {
      final username = _normalizeUsername(user.username);
      if (username.isEmpty ||
          username == _normalizeUsername(widget.user.username) ||
          (!isSearching && _followedUsernames.contains(username)) ||
          !seen.add(username)) {
        continue;
      }
      visible.add(user);
    }

    return visible;
  }

  List<HashtagResult> _visibleHashtags() {
    final visible = <HashtagResult>[];
    final seen = <String>{};

    for (final hashtag in _searchHashtagResults) {
      final name = hashtag.name.trim().toLowerCase();
      if (name.isEmpty || !seen.add(name)) {
        continue;
      }
      visible.add(hashtag);
    }

    return visible;
  }

  List<_SearchEntry> _buildSearchEntries(
    List<User> people,
    List<HashtagResult> hashtags,
  ) {
    if (_isSearchingPeople) {
      return const <_SearchEntry>[];
    }

    final entries = <_SearchEntry>[];

    if (hashtags.isNotEmpty) {
      entries.add(const _SearchEntry.section('Hashtags'));
      entries.addAll(
        hashtags.map(_SearchEntry.hashtag),
      );
    }

    if (people.isNotEmpty) {
      if (entries.isNotEmpty) {
        entries.add(const _SearchEntry.section('Creators'));
      }
      entries.addAll(
        people.map(_SearchEntry.person),
      );
    }

    return entries;
  }

  bool _isOwnPost(Post post) {
    if (post.ownedByMe) {
      return true;
    }

    final currentUsername = (widget.user.username ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    if (currentUsername.isEmpty) {
      return false;
    }

    final postUsername = post.authorUsername
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    return postUsername == currentUsername;
  }

  bool _isFollowedUsername(String? username) {
    return _followedUsernames.contains(_normalizeUsername(username));
  }

  String _normalizeUsername(String? username) {
    return (username ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
  }

  void _handlePeopleSearchChanged(String value) {
    final nextQuery = value.trim();
    _peopleSearchDebounce?.cancel();

    setState(() {
      _peopleSearchQuery = nextQuery;
      if (nextQuery.length < 2) {
        _searchPeopleResults = [];
        _searchHashtagResults = [];
        _isSearchingPeople = false;
      }
    });

    if (nextQuery.length < 2) {
      return;
    }

    _peopleSearchDebounce = Timer(
      const Duration(milliseconds: 250),
      () async {
        if (!mounted) return;
        setState(() {
          _isSearchingPeople = true;
        });

        try {
          final results = await _feedService.search(nextQuery);
          if (!mounted || _peopleSearchQuery != nextQuery) {
            return;
          }

          setState(() {
            _searchPeopleResults = results.people;
            _searchHashtagResults = results.hashtags;
            _isSearchingPeople = false;
          });
        } catch (_) {
          if (!mounted || _peopleSearchQuery != nextQuery) {
            return;
          }

          setState(() {
            _searchPeopleResults = [];
            _searchHashtagResults = [];
            _isSearchingPeople = false;
          });
        }
      },
    );
  }

  int _searchItemCount(List<_SearchEntry> entries) {
    if (_isSearchingPeople || entries.isEmpty) {
      return 1;
    }

    return entries.length;
  }

  Widget _buildSearchItem(
    int index,
    List<_SearchEntry> entries,
    List<User> people,
  ) {
    if (_isSearchingPeople) {
      return Padding(
        padding: EdgeInsets.only(top: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (entries.isEmpty) {
      final message = _peopleSearchQuery.trim().length >= 2
          ? (_peopleSearchQuery.trim().startsWith('#')
              ? 'No hashtags found.'
              : 'No people found.')
          : 'No people to show right now.';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Text(
          message,
          style: TextStyle(fontFamily: 'SF Pro Rounded',
            color: Color(0xFF6B7280),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final entry = entries[index];
    switch (entry.type) {
      case _SearchEntryType.section:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            entry.label!,
            style: TextStyle(fontFamily: 'SF Pro Rounded',
              color: Color(0xFF6B7280),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case _SearchEntryType.person:
        final user = entry.user!;
        final isFollowing = _followedUsernames.contains(_normalizeUsername(user.username));
        return _PeopleListRow(
          user: user,
          isFollowing: isFollowing,
          isFollowPending: _followPendingUsernames
              .contains(_normalizeUsername(user.username)),
          onTap: () => _openPerson(user),
          onFollow: () => isFollowing ? _unfollowPerson(user) : _followPerson(user),
        );
      case _SearchEntryType.hashtag:
        return _HashtagListRow(
          hashtag: entry.hashtag!,
          onTap: () => _openHashtag(entry.hashtag!.name),
        );
    }
  }

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagScreen(
          tag: tag,
          currentUser: widget.user,
          onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
          onOpenUserProfile: widget.onOpenUserProfile,
        ),
      ),
    );
  }

  Future<void> _followPerson(User user) async {
    final username = _normalizeUsername(user.username);
    if (username.isEmpty || _followPendingUsernames.contains(username)) {
      return;
    }

    setState(() {
      _followPendingUsernames = {
        ..._followPendingUsernames,
        username,
      };
    });

    try {
      final updatedUser = await _feedService.followUser(username);
      if (!mounted) return;

      setState(() {
        _followPendingUsernames = Set<String>.from(_followPendingUsernames)
          ..remove(username);
        _followedUsernames = {
          ..._followedUsernames,
          _normalizeUsername(updatedUser?.username ?? username),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followPendingUsernames = Set<String>.from(_followPendingUsernames)
          ..remove(username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to follow user.')),
      );
    }
  }

  Future<void> _unfollowPerson(User user) async {
    final username = _normalizeUsername(user.username);
    if (username.isEmpty || _followPendingUsernames.contains(username)) {
      return;
    }

    setState(() {
      _followPendingUsernames = {
        ..._followPendingUsernames,
        username,
      };
    });

    try {
      await _feedService.unfollowUser(username);
      if (!mounted) return;

      setState(() {
        _followPendingUsernames = Set<String>.from(_followPendingUsernames)
          ..remove(username);
        _followedUsernames = Set<String>.from(_followedUsernames)
          ..remove(username);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followPendingUsernames = Set<String>.from(_followPendingUsernames)
          ..remove(username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unfollow user.')),
      );
    }
  }

  Future<void> _followAuthorFromPost(Post post) async {
    final username = _normalizeUsername(post.authorUsername);
    if (username.isEmpty || _followPendingUsernames.contains(username)) {
      return;
    }

    setState(() {
      _followPendingUsernames = {
        ..._followPendingUsernames,
        username,
      };
    });

    try {
      final updatedUser = await _feedService.followUser(username);
      if (!mounted) {
        return;
      }

      final resolvedUsername =
          _normalizeUsername(updatedUser?.username ?? username);
      setState(() {
        _followPendingUsernames = Set<String>.from(_followPendingUsernames)
          ..remove(username);
        _followedUsernames = {
          ..._followedUsernames,
          resolvedUsername,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'You followed @${updatedUser?.username ?? post.authorUsername}.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _followPendingUsernames = Set<String>.from(_followPendingUsernames)
          ..remove(username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to follow user.')),
      );
    }
  }

  Future<void> _loadSuggestedCreators({bool forceRefresh = false}) async {
    if (_suggestedCreators.isNotEmpty && !forceRefresh) return;
    setState(() => _isLoadingSuggestions = true);
    try {
      final suggestions = await _feedService.loadFollowSuggestions(limit: 15);
      if (!mounted) return;
      setState(() {
        _suggestedCreators = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = false);
    }
  }

  static const List<TrendingTopic> _defaultTrendingTopics = [
    TrendingTopic(
      tag: 'AnimeGirls',
      category: 'Community · Trending',
      postCountLabel: '29 posts',
    ),
    TrendingTopic(
      tag: 'KatsKlub',
      category: 'Official · Hub',
      postCountLabel: '50+ posts',
    ),
    TrendingTopic(
      tag: 'MusicVibes',
      category: 'Music & Audio · Trending',
      postCountLabel: '38 posts',
    ),
    TrendingTopic(
      tag: 'LateNightTalks',
      category: 'Voice Rooms · Hanging out',
      postCountLabel: '24 posts',
    ),
    TrendingTopic(
      tag: 'CozyVibes',
      category: 'Lifestyle · Aesthetic',
      postCountLabel: '19 posts',
    ),
    TrendingTopic(
      tag: 'ManilaWeather',
      category: 'Philippines · News & Life',
      postCountLabel: '15 posts',
    ),
    TrendingTopic(
      tag: 'PinoyMemes',
      category: 'Humor · Viral',
      postCountLabel: '31 posts',
    ),
  ];

  List<TrendingTopic> _getTrendingTopics() {
    final Map<String, int> tagCounts = {};
    final regex = RegExp(r'#([A-Za-z0-9_]+)');

    for (final post in _posts) {
      final matches = regex.allMatches(post.text);
      for (final match in matches) {
        final tag = match.group(1);
        if (tag != null && tag.isNotEmpty) {
          final normalized = tag.toLowerCase();
          tagCounts[normalized] = (tagCounts[normalized] ?? 0) + 1;
        }
      }
    }

    final dynamicTopics = tagCounts.entries.map((entry) {
      return TrendingTopic(
        tag: entry.key,
        category: 'Community · Trending',
        postCountLabel: '${entry.value + 3} posts',
      );
    }).toList();

    final seen = <String>{};
    final merged = <TrendingTopic>[];

    for (final t in dynamicTopics) {
      if (seen.add(t.tag.toLowerCase())) {
        merged.add(t);
      }
    }
    for (final t in _defaultTrendingTopics) {
      if (seen.add(t.tag.toLowerCase())) {
        merged.add(t);
      }
    }

    return merged;
  }

  List<Post> _getExploreMediaPosts(List<Post> allPosts) {
    return allPosts.where((p) {
      final hasImages = p.imageUrls.any((u) => u.trim().isNotEmpty);
      final hasThumbnails = p.thumbnailUrls.any((u) => u.trim().isNotEmpty);
      final hasVideo = p.hasVideo || p.videoUrl.trim().isNotEmpty;
      final hasPoster = p.videoPosterUrl.trim().isNotEmpty;
      final hasDiscussionCover = p.discussionCoverUrl.trim().isNotEmpty;
      return hasImages || hasThumbnails || hasVideo || hasPoster || hasDiscussionCover;
    }).toList();
  }

  int _exploreItemCount(List<Post> mediaPosts) {
    final isSearching = _peopleSearchQuery.trim().length >= 2;
    if (isSearching) {
      final people = _visiblePeople();
      final hashtags = _visibleHashtags();
      final searchEntries = _buildSearchEntries(people, hashtags);
      return _searchItemCount(searchEntries);
    }

    var count = 2; // Creators (0) + Trending (1)
    if (mediaPosts.isNotEmpty) {
      final rowCount = (mediaPosts.length / 3).ceil();
      count += 1 + rowCount; // Header (2) + media grid rows
    }
    return count;
  }

  Widget _buildExploreItem(
    BuildContext context,
    int index,
    List<Post> mediaPosts,
    List<_SearchEntry> searchEntries,
    List<User> people,
  ) {
    final isSearching = _peopleSearchQuery.trim().length >= 2;
    if (isSearching) {
      return _buildSearchItem(index, searchEntries, people);
    }

    if (index == 0) {
      return _SuggestedCreatorsCarousel(
        creators: _suggestedCreators,
        isLoading: _isLoadingSuggestions,
        followedUsernames: _followedUsernames,
        followPendingUsernames: _followPendingUsernames,
        onTapUser: _openPerson,
        onFollowUser: (user) {
          final username = _normalizeUsername(user.username);
          if (_followedUsernames.contains(username)) {
            _unfollowPerson(user);
          } else {
            _followPerson(user);
          }
        },
      );
    }

    if (index == 1) {
      final trendingTopics = _getTrendingTopics();
      return _TrendingSection(
        topics: trendingTopics,
        onTapTopic: _openHashtag,
      );
    }

    if (index == 2 && mediaPosts.isNotEmpty) {
      return const _ExplorePostsHeader();
    }

    final rowIndex = index - 3;
    final startIndex = rowIndex * 3;
    if (startIndex >= 0 && startIndex < mediaPosts.length) {
      final endIndex = (startIndex + 3 <= mediaPosts.length)
          ? startIndex + 3
          : mediaPosts.length;
      final rowPosts = mediaPosts.sublist(startIndex, endIndex);
      return _ExploreMediaGridRow(
        key: ValueKey<String>(
          'explore-media-row-$rowIndex-${rowPosts.first.id}',
        ),
        posts: rowPosts,
        onTapPost: _openPost,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _postCard(Post post) {
    final authorUsername = _normalizeUsername(post.authorUsername);
    final showFollowButton = authorUsername.isNotEmpty &&
        !_isOwnPost(post) &&
        !post.isFollowingAuthor &&
        !_isFollowedUsername(authorUsername);

    return PostCard(
      key: ValueKey<String>('feed-post-card-${post.id}'),
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
      showAuthorFollowButton: showFollowButton,
      isAuthorFollowPending: _followPendingUsernames.contains(authorUsername),
      onAuthorFollow:
          showFollowButton ? () => _followAuthorFromPost(post) : null,
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

    final postIndex = _posts.indexWhere((item) => item.id == updatedPost.id);
    final reelIndex =
        _railReels.indexWhere((item) => item.id == updatedPost.id);
    if (postIndex < 0 && reelIndex < 0) return;

    List<Post>? nextPosts;
    List<Post>? nextReels;
    if (postIndex >= 0) {
      nextPosts = List<Post>.from(_posts);
      nextPosts[postIndex] = updatedPost;
    }
    if (reelIndex >= 0) {
      nextReels = List<Post>.from(_railReels);
      nextReels[reelIndex] = updatedPost;
    }

    setState(() {
      if (nextPosts != null) _posts = nextPosts;
      if (nextReels != null) _railReels = nextReels;
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
      _railReels = _railReels.where((item) => item.id != post.id).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post successfully deleted.')),
    );
  }

  Future<void> _hidePost(Post post) async {
    final previousPosts = List<Post>.from(_posts);
    final previousRailReels = List<Post>.from(_railReels);

    setState(() {
      _posts = _posts.where((item) => item.id != post.id).toList();
      _railReels = _railReels.where((item) => item.id != post.id).toList();
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
        _railReels = previousRailReels;
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

    _openUsername(authorUsername);
  }

  bool _isCurrentUser(String username) {
    final currentUsername = widget.user.username?.trim().toLowerCase() ?? '';
    return currentUsername.isNotEmpty &&
        username.trim().toLowerCase() == currentUsername;
  }

  void _openPerson(User user) {
    final username = user.username?.trim() ?? '';
    if (username.isEmpty) return;
    _openUsername(username);
  }

  void _openUsername(String username) {
    if (_isCurrentUser(username)) {
      widget.onOpenCurrentUserProfile?.call();
      return;
    }

    final onOpenUserProfile = widget.onOpenUserProfile;
    if (onOpenUserProfile != null) {
      onOpenUserProfile(username);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
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

  void _openRailReel(Post reel, int fallbackIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelsViewerScreen(
          initialReel: reel,
          initialReelId: reel.id,
        ),
      ),
    );
  }
}

class _FeedSeedResult {
  const _FeedSeedResult({
    required this.posts,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<Post> posts;
  final int nextOffset;
  final bool hasMore;
}

class _ReelsRail extends StatefulWidget {
  const _ReelsRail({
    super.key,
    required this.reels,
    required this.onReelTap,
    this.isTabActive = true,
  });

  final List<Post> reels;
  final Function(Post reel, int index) onReelTap;
  final bool isTabActive;

  @override
  State<_ReelsRail> createState() => _ReelsRailState();
}

class _ReelsRailState extends State<_ReelsRail>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.50).clamp(185.0, 220.0);
    final cardHeight = cardWidth * 1.70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CustomIcons.reels(
                color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Reels',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            key: PageStorageKey<String>(
              'feed-reels-rail-list-${widget.reels.map((reel) => reel.id).join('-')}',
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.reels.length,
            itemBuilder: (context, index) {
              final reel = widget.reels[index];
              return RepaintBoundary(
                child: _ReelPreviewCard(
                  key: ValueKey<String>('feed-reel-preview-${reel.id}'),
                  reel: reel,
                  width: cardWidth,
                  height: cardHeight,
                  isFirstCard: index == 0 && widget.isTabActive,
                  onTap: () => widget.onReelTap(reel, index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReelPreviewCard extends StatefulWidget {
  const _ReelPreviewCard({
    super.key,
    required this.reel,
    required this.width,
    required this.height,
    required this.onTap,
    this.isFirstCard = false,
  });

  final Post reel;
  final double width;
  final double height;
  final VoidCallback onTap;
  final bool isFirstCard;

  @override
  State<_ReelPreviewCard> createState() => _ReelPreviewCardState();
}

class _ReelPreviewCardState extends State<_ReelPreviewCard> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isFirstCard && widget.reel.videoUrl.trim().isNotEmpty) {
      _initPreviewLoop();
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFirstCard != oldWidget.isFirstCard ||
        widget.reel.videoUrl != oldWidget.reel.videoUrl) {
      _disposeVideo();
      if (widget.isFirstCard && widget.reel.videoUrl.trim().isNotEmpty) {
        _initPreviewLoop();
      }
    }
  }

  void _initPreviewLoop() {
    final videoUrl = ApiConfig.assetUrl(widget.reel.videoUrl.trim());
    if (videoUrl.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    controller.initialize().then((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setVolume(0.0);
      controller.setLooping(false);
      controller.play();
      controller.addListener(_loopListener);
      setState(() {
        _videoController = controller;
        _isInitialized = true;
      });
    }).catchError((_) {});
  }

  void _loopListener() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.position >= const Duration(seconds: 3)) {
      c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _disposeVideo() {
    _videoController?.removeListener(_loopListener);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posterUrl = _railPosterUrl(widget.reel);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF242526) : Colors.grey[300],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isInitialized && _videoController != null)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width > 0
                        ? _videoController!.value.size.width
                        : widget.width,
                    height: _videoController!.value.size.height > 0
                        ? _videoController!.value.size.height
                        : widget.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              else if (posterUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: ApiConfig.assetUrl(posterUrl),
                  memCacheWidth: 400,
                  maxWidthDiskCache: 400,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: isDark ? const Color(0xFF242526) : Colors.grey[800],
                    child: const Icon(Icons.video_library, color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? const Color(0xFF242526) : Colors.grey[800],
                    child: const Icon(Icons.video_library, color: Colors.white),
                  ),
                )
              else
                Container(
                  color: isDark ? const Color(0xFF242526) : Colors.grey[800],
                  child: const Icon(Icons.video_library, color: Colors.white),
                ),
              // Subtle gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
              // Author at bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  widget.reel.authorFullName,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _railPosterUrl(Post reel) {
    final videoPosterUrl = reel.videoPosterUrl.trim();
    if (videoPosterUrl.isNotEmpty) {
      return videoPosterUrl;
    }

    if (reel.thumbnailUrls.isNotEmpty) {
      return reel.thumbnailUrls.first.trim();
    }

    if (reel.imageUrls.isNotEmpty) {
      return reel.imageUrls.first.trim();
    }

    return '';
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.activeTab,
    required this.searchController,
    required this.onSearchChanged,
    required this.onChanged,
  });

  final String activeTab;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final showSearch = activeTab == 'explore';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: ColoredBox(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search creators, #topics...',
                      hintStyle: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.sp,
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: const Color(0xFF9CA3AF),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF242526)
                          : const Color(0xFFF2F2F2),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFFFF7A45)
                              : const Color(0xFF111827),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            _FeedTabs(
              activeTab: activeTab,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTabs extends StatelessWidget {
  const _FeedTabs({
    required this.activeTab,
    required this.onChanged,
  });

  final String activeTab;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: Row(
        children: [
          _FeedTabButton(
            label: 'Posts',
            isActive: activeTab == 'posts',
            onTap: () => onChanged('posts'),
          ),
          _FeedTabButton(
            label: 'Explore',
            isActive: activeTab == 'explore',
            onTap: () => onChanged('explore'),
          ),
        ],
      ),
    );
  }
}

class _FeedTabButton extends StatelessWidget {
  const _FeedTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827);
    final inactiveColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF9CA3AF);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFFF7A45) : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14.5.sp,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeopleListRow extends StatelessWidget {
  const _PeopleListRow({
    required this.user,
    required this.isFollowing,
    required this.isFollowPending,
    required this.onTap,
    required this.onFollow,
  });

  final User user;
  final bool isFollowing;
  final bool isFollowPending;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final extras = _extraLines(user);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = user.avatarUrl?.trim() ?? '';

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isDark
                    ? const Color(0xFF2D2E30)
                    : const Color(0xFFE5E7EB),
                backgroundImage: avatarUrl.isEmpty
                    ? null
                    : CachedNetworkImageProvider(
                        ApiConfig.assetUrl(avatarUrl),
                        maxWidth: 88,
                        maxHeight: 88,
                      ),
                child: avatarUrl.isEmpty
                    ? Text(
                        user.initials,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF0095F6),
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.handle ?? '@${user.username}',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: const Color(0xFF6B7280),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                    for (final line in extras) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6B7280),
                          fontSize: 11.5.sp,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: isFollowPending
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onFollow();
                      },
                style: TextButton.styleFrom(
                  backgroundColor: isFollowing
                      ? (isDark
                          ? const Color(0xFF2D2E30)
                          : const Color(0xFFE5E7EB))
                      : const Color(0xFFFF7A45),
                  foregroundColor: isFollowing
                      ? (isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF4B5563))
                      : Colors.white,
                  minimumSize: const Size(82, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: const StadiumBorder(),
                  textStyle: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  isFollowPending
                      ? '...'
                      : (isFollowing ? 'Following' : 'Follow'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _extraLines(User user) {
    final candidates = [
      user.bio,
      user.location,
      user.roleTitle,
      user.raw['website']?.toString(),
      user.raw['linkUrl']?.toString(),
      user.raw['externalUrl']?.toString(),
    ];

    final seen = <String>{};
    final lines = <String>[];
    for (final candidate in candidates) {
      final text = candidate?.trim() ?? '';
      if (text.isEmpty || !seen.add(text)) {
        continue;
      }
      lines.add(text);
    }
    return lines.take(2).toList(growable: false);
  }
}

enum _SearchEntryType {
  section,
  person,
  hashtag,
}

class _SearchEntry {
  const _SearchEntry._({
    required this.type,
    this.label,
    this.user,
    this.hashtag,
  });

  const _SearchEntry.section(String label)
      : this._(
          type: _SearchEntryType.section,
          label: label,
        );

  const _SearchEntry.person(User user)
      : this._(
          type: _SearchEntryType.person,
          user: user,
        );

  const _SearchEntry.hashtag(HashtagResult hashtag)
      : this._(
          type: _SearchEntryType.hashtag,
          hashtag: hashtag,
        );

  final _SearchEntryType type;
  final String? label;
  final User? user;
  final HashtagResult? hashtag;
}

class _HashtagListRow extends StatelessWidget {
  const _HashtagListRow({
    required this.hashtag,
    required this.onTap,
  });

  final HashtagResult hashtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel =
        hashtag.postCount == 1 ? '1 post' : '${hashtag.postCount} posts';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242526)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: isDark
                        ? const Color(0xFFE4E6EB)
                        : const Color(0xFF111827),
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${hashtag.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark
                            ? const Color(0xFFE4E6EB)
                            : const Color(0xFF111111),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      countLabel,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark
                            ? const Color(0xFFB0B3B8)
                            : const Color(0xFF6B7280),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrendingTopic {
  const TrendingTopic({
    required this.tag,
    required this.category,
    required this.postCountLabel,
  });

  final String tag;
  final String category;
  final String postCountLabel;
}

class _TrendingTopicRow extends StatelessWidget {
  const _TrendingTopicRow({
    required this.topic,
    required this.rank,
    required this.onTap,
  });

  final TrendingTopic topic;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$rank · ${topic.category}',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF6B7280),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${topic.tag}',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark
                            ? const Color(0xFFF3F4F6)
                            : const Color(0xFF111827),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      topic.postCountLabel,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF6B7280),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedCreatorsCarousel extends StatelessWidget {
  const _SuggestedCreatorsCarousel({
    required this.creators,
    required this.isLoading,
    required this.followedUsernames,
    required this.followPendingUsernames,
    required this.onTapUser,
    required this.onFollowUser,
  });

  final List<User> creators;
  final bool isLoading;
  final Set<String> followedUsernames;
  final Set<String> followPendingUsernames;
  final ValueChanged<User> onTapUser;
  final ValueChanged<User> onFollowUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading && creators.isEmpty) {
      return SizedBox(
        height: 195,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, _) => Container(
            width: 142,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1E21) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (creators.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFFF7A45),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Suggested Creators',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 195,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: creators.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final user = creators[index];
                final username = (user.username ?? '')
                    .trim()
                    .replaceFirst(RegExp(r'^@'), '')
                    .toLowerCase();
                final isFollowing = followedUsernames.contains(username);
                final isPending = followPendingUsernames.contains(username);

                return _CreatorCard(
                  user: user,
                  isFollowing: isFollowing,
                  isFollowPending: isPending,
                  onTap: () => onTapUser(user),
                  onFollow: () => onFollowUser(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({
    required this.user,
    required this.isFollowing,
    required this.isFollowPending,
    required this.onTap,
    required this.onFollow,
  });

  final User user;
  final bool isFollowing;
  final bool isFollowPending;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2C2D30) : const Color(0xFFE5E7EB);
    final avatarUrl = user.avatarUrl?.trim() ?? '';
    final bio = user.bio?.trim() ?? '';

    return RepaintBoundary(
      child: Container(
        width: 142,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(30),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: isDark
                    ? const Color(0xFF2D2E30)
                    : const Color(0xFFE5E7EB),
                backgroundImage: avatarUrl.isEmpty
                    ? null
                    : CachedNetworkImageProvider(
                        ApiConfig.assetUrl(avatarUrl),
                        maxWidth: 104,
                        maxHeight: 104,
                      ),
                child: avatarUrl.isEmpty
                    ? Text(
                        user.initials,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF0095F6),
                          size: 13,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.handle ?? '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: const Color(0xFF9CA3AF),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                bio.isEmpty ? 'KatsKlub member' : bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6B7280),
                  fontSize: 10.5.sp,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: FilledButton(
                onPressed: isFollowPending
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onFollow();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: isFollowing
                      ? (isDark
                          ? const Color(0xFF2C2D30)
                          : const Color(0xFFE5E7EB))
                      : const Color(0xFFFF7A45),
                  foregroundColor: isFollowing
                      ? (isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF4B5563))
                      : Colors.white,
                  padding: EdgeInsets.zero,
                  shape: const StadiumBorder(),
                  textStyle: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  isFollowPending
                      ? '...'
                      : (isFollowing ? 'Following' : 'Follow'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({
    required this.topics,
    required this.onTapTopic,
  });

  final List<TrendingTopic> topics;
  final ValueChanged<String> onTapTopic;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2C2D30) : const Color(0xFFE5E7EB);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF7A45),
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  'Trending Topics',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    for (int i = 0; i < topics.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: borderColor,
                          indent: 16,
                        ),
                      _TrendingTopicRow(
                        topic: topics[i],
                        rank: i + 1,
                        onTap: () => onTapTopic(topics[i].tag),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorePostsHeader extends StatelessWidget {
  const _ExplorePostsHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            const Icon(
              Icons.grid_view_rounded,
              color: Color(0xFFFF7A45),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Explore Media',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreMediaGridRow extends StatelessWidget {
  const _ExploreMediaGridRow({
    super.key,
    required this.posts,
    required this.onTapPost,
  });

  final List<Post> posts;
  final ValueChanged<Post> onTapPost;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 3),
        child: Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: i < posts.length
                    ? _ExploreMediaTile(
                        key: ValueKey<String>('explore-tile-${posts[i].id}'),
                        post: posts[i],
                        onTap: () => onTapPost(posts[i]),
                      )
                    : const AspectRatio(
                        aspectRatio: 1.0,
                        child: SizedBox.shrink(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExploreMediaTile extends StatelessWidget {
  const _ExploreMediaTile({
    super.key,
    required this.post,
    required this.onTap,
  });

  final Post post;
  final VoidCallback onTap;

  String _resolveMediaUrl() {
    for (final thumb in post.thumbnailUrls) {
      if (thumb.trim().isNotEmpty) return thumb.trim();
    }
    for (final img in post.imageUrls) {
      if (img.trim().isNotEmpty) return img.trim();
    }
    if (post.videoPosterUrl.trim().isNotEmpty) {
      return post.videoPosterUrl.trim();
    }
    if (post.discussionCoverUrl.trim().isNotEmpty) {
      return post.discussionCoverUrl.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaUrl = _resolveMediaUrl();
    final isVideo =
        post.hasVideo || post.isReel || post.videoUrl.trim().isNotEmpty;
    final isMultiImage = post.imageUrls.length > 1;

    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Material(
          color: isDark ? const Color(0xFF1E1F23) : const Color(0xFFF3F4F6),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (mediaUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: ApiConfig.assetUrl(mediaUrl),
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    maxWidthDiskCache: 600,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      color: isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFEEEEEE),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  )
                else
                  Center(
                    child: Icon(
                      isVideo
                          ? Icons.play_circle_outline_rounded
                          : Icons.photo_outlined,
                      size: 24,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),

                // Video or Carousel Badge at top-right
                if (isVideo)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  )
                else if (isMultiImage)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.collections_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabDelegate({
    required this.child,
    required this.extent,
  });

  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabDelegate oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}
