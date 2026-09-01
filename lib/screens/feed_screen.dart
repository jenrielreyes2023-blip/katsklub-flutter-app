import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_text_styles.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/loading_skeletons.dart';
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
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    super.key,
  });

  final User user;
  final int refreshToken;
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
  Timer? _peopleHydrateDebounce;
  Set<String> _followedUsernames = <String>{};
  Set<String> _followPendingUsernames = <String>{};
  Set<String> _profileLoadingUsernames = <String>{};
  Set<String> _resolvedProfileUsernames = <String>{};
  Set<String> _invalidProfileUsernames = <String>{};
  Map<String, User> _peopleProfileDetails = <String, User>{};
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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _mediaSnapCoordinator.dispose();
    _peopleSearchDebounce?.cancel();
    _peopleHydrateDebounce?.cancel();
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
      offset = page.offset + page.posts.length;
      hasMore = page.hasMore;

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
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
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
    await _loadInitialFeed();
    _loadFollowedUsers();
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
    final people = _visiblePeople();
    final hashtags = _visibleHashtags();
    final searchEntries = _buildSearchEntries(people, hashtags);
    final headerHeight = _activeTab == 'people' ? 114.0 : 54.0;

    if (_activeTab == 'people') {
      _scheduleHydrateVisiblePeople(people);
    }

    return Stack(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: RefreshIndicator(
            onRefresh: _refresh,
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
                          setState(() {
                            _activeTab = tab;
                          });
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _activeTab == 'people'
                            ? _buildSearchItem(index, searchEntries, people)
                            : _buildFeedItem(context, index, posts),
                        childCount: _activeTab == 'people'
                            ? _searchItemCount(searchEntries)
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
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Follow people to fill your feed with their posts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'SF Pro Rounded',
                fontSize: 13.5.sp,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => setState(() => _activeTab = 'people'),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text('Discover people'),
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
    return _activeTab == 'people' ? 114.0 : 54.0;
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
        : _discoverPeople(_posts);
    final seen = <String>{};
    final visible = <User>[];

    for (final user in sourcePeople) {
      final username = _normalizeUsername(user.username);
      if (username.isEmpty ||
          username == _normalizeUsername(widget.user.username) ||
          (!isSearching && _followedUsernames.contains(username)) ||
          _invalidProfileUsernames.contains(username) ||
          !seen.add(username)) {
        continue;
      }
      visible.add(user);
    }

    return visible;
  }

  List<HashtagResult> _visibleHashtags() {
    if (!_peopleSearchQuery.trim().startsWith('#')) {
      return const [];
    }

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
        entries.add(const _SearchEntry.section('People'));
      }
      entries.addAll(
        people.map(_SearchEntry.person),
      );
    }

    return entries;
  }

  List<User> _discoverPeople(List<Post> posts) {
    final people = <User>[];
    final seen = <String>{};

    for (final post in posts) {
      if (post.isReel ||
          _isOwnPost(post) ||
          post.isFollowingAuthor ||
          _isFollowedUsername(post.authorUsername)) {
        continue;
      }

      final username = _normalizeUsername(post.authorUsername);
      if (username.isEmpty || !seen.add(username)) {
        continue;
      }

      people.add(
        User(
          fullName: post.authorFullName,
          username: username,
          avatarUrl: post.authorAvatarUrl.trim().isEmpty
              ? null
              : post.authorAvatarUrl.trim(),
          isVerified: post.authorIsVerified,
          isAuthor: post.authorIsAuthor,
          raw: const <String, dynamic>{},
        ),
      );
    }

    return people;
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
        final baseUser = entry.user!;
        final user =
            _peopleProfileDetails[_normalizeUsername(baseUser.username)] ??
                baseUser;
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
      final updatedUser = await _feedService.unfollowUser(username);
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

  void _scheduleHydrateVisiblePeople(List<User> people) {
    _peopleHydrateDebounce?.cancel();
    _peopleHydrateDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _activeTab != 'people') return;
      _hydrateVisiblePeople(people);
    });
  }

  Future<void> _hydrateVisiblePeople(List<User> people) async {
    final usernamesToLoad = people
        .map((user) => _normalizeUsername(user.username))
        .where((username) => username.isNotEmpty)
        .where(
          (username) =>
              !_profileLoadingUsernames.contains(username) &&
              !_resolvedProfileUsernames.contains(username) &&
              !_invalidProfileUsernames.contains(username),
        )
        .take(8)
        .toList();

    if (usernamesToLoad.isEmpty) {
      return;
    }

    setState(() {
      _profileLoadingUsernames = {
        ..._profileLoadingUsernames,
        ...usernamesToLoad,
      };
    });

    final loadedEntries = <String, User>{};
    final invalidUsernames = <String>{};

    await Future.wait(
      usernamesToLoad.map((username) async {
        try {
          final user = await _feedService.loadUserProfile(username);
          if (user != null) {
            loadedEntries[username] = user;
          } else {
            invalidUsernames.add(username);
          }
        } catch (_) {
          invalidUsernames.add(username);
        }
      }),
    );

    if (!mounted) return;

    setState(() {
      final nextLoading = Set<String>.from(_profileLoadingUsernames)
        ..removeAll(usernamesToLoad);
      _profileLoadingUsernames = nextLoading;
      _resolvedProfileUsernames = {
        ..._resolvedProfileUsernames,
        ...usernamesToLoad
            .where((username) => !invalidUsernames.contains(username)),
      };
      _invalidProfileUsernames = {
        ..._invalidProfileUsernames,
        ...invalidUsernames,
      };
      _peopleProfileDetails = {
        ..._peopleProfileDetails,
        ...loadedEntries,
      };
    });
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

  Future<void> _openPerson(User user) async {
    final username = user.username?.trim() ?? '';
    if (username.isEmpty) {
      return;
    }

    final normalizedUsername = _normalizeUsername(username);
    if (_invalidProfileUsernames.contains(normalizedUsername)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile unavailable.')),
      );
      return;
    }

    if (!_resolvedProfileUsernames.contains(normalizedUsername)) {
      final profile = await _feedService.loadUserProfile(username);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _invalidProfileUsernames = {
            ..._invalidProfileUsernames,
            normalizedUsername,
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile unavailable.')),
        );
        return;
      }

      setState(() {
        _resolvedProfileUsernames = {
          ..._resolvedProfileUsernames,
          normalizedUsername,
        };
        _peopleProfileDetails = {
          ..._peopleProfileDetails,
          normalizedUsername: profile,
        };
      });
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
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
  });

  final List<Post> reels;
  final Function(Post reel, int index) onReelTap;

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.38).clamp(145.0, 165.0);
    final cardHeight = cardWidth * 1.65;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Reels',
            style: TextStyle(fontFamily: 'SF Pro Rounded',
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        SizedBox(height: 12),
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

class _ReelPreviewCard extends StatelessWidget {
  const _ReelPreviewCard({
    super.key,
    required this.reel,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Post reel;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final posterUrl = _railPosterUrl(reel);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[300],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (posterUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: ApiConfig.assetUrl(posterUrl),
                  memCacheWidth: 400,
                  maxWidthDiskCache: 400,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.video_library, color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.video_library, color: Colors.white),
                  ),
                )
              else
                Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.video_library, color: Colors.white),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  reel.authorFullName,
                  style: TextStyle(fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 40,
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
    final showSearch = activeTab == 'people';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontFamily: 'SF Pro Rounded',
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12.sp,
                ),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(fontFamily: 'SF Pro Rounded', fontSize: 12.sp, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF242526) : const Color(0xFFF2F2F2),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                      color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827),
                      width: 1,
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
      height: 54,
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: Row(
        children: [
          _FeedTabButton(
            label: 'Posts',
            isActive: activeTab == 'posts',
            onTap: () => onChanged('posts'),
          ),
          _FeedTabButton(
            label: 'People',
            isActive: activeTab == 'people',
            onTap: () => onChanged('people'),
          ),
        ],
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
              backgroundImage: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? null
                  : NetworkImage(ApiConfig.assetUrl(user.avatarUrl!)),
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(
                      user.initials,
                      style: TextStyle(fontFamily: 'SF Pro Rounded',
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'SF Pro Rounded',
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    user.handle ?? '',
                    style: TextStyle(fontFamily: 'SF Pro Rounded',
                      color: Color(0xFF6B7280),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  for (final line in extras) ...[
                    SizedBox(height: 2),
                    Text(
                      line,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'SF Pro Rounded',
                        color: Color(0xFF6B7280),
                        fontSize: 12.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 12),
            TextButton(
              onPressed: isFollowPending ? null : onFollow,
              style: TextButton.styleFrom(
                backgroundColor: isFollowing
                    ? (isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB))
                    : (isDark ? const Color(0xFFFF7A45) : const Color(0xFFF2F2F2)),
                foregroundColor: isFollowing
                    ? (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563))
                    : (isDark ? Colors.white : const Color(0xFF111111)),
                minimumSize: const Size(84, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                shape: const StadiumBorder(),
                textStyle: TextStyle(fontFamily: 'SF Pro Rounded',
                  fontSize: 11.sp,
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
    );
  }

  List<String> _extraLines(User user) {
    final candidates = [
      user.bio,
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#',
                style: TextStyle(fontFamily: 'SF Pro Rounded',
                  color: Color(0xFF111827),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${hashtag.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'SF Pro Rounded',
                      color: Color(0xFF111111),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    countLabel,
                    style: TextStyle(fontFamily: 'SF Pro Rounded',
                      color: Color(0xFF6B7280),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
        ),
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
    final activeColor = isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827);
    final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF9CA3AF);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? activeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(fontFamily: 'SF Pro Rounded',
              color: isActive ? activeColor : inactiveColor,
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
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
