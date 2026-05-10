import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/post_card.dart';
import 'image_viewer_screen.dart';
import 'post_detail_screen.dart';
import 'reels_viewer_screen.dart';
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
  final FeedService _feedService = FeedService();
  final TextEditingController _peopleSearchController =
      TextEditingController();

  String _activeTab = 'posts';
  Timer? _peopleSearchDebounce;
  Set<String> _followedUsernames = <String>{};
  Set<String> _followPendingUsernames = <String>{};
  Set<String> _profileLoadingUsernames = <String>{};
  Set<String> _resolvedProfileUsernames = <String>{};
  Set<String> _invalidProfileUsernames = <String>{};
  Map<String, User> _peopleProfileDetails = <String, User>{};
  List<User> _searchPeopleResults = [];
  String _peopleSearchQuery = '';
  List<Post> _posts = [];
  List<Post> _railReels = [];
  bool _isInitialLoading = true;
  bool _isSearchingPeople = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _railReelsLocked = false;
  int _nextOffset = 0;
  double _lastScrollPixels = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitialFeed();
    _loadFollowedUsers();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _peopleSearchDebounce?.cancel();
    _peopleSearchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
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
    final shouldShowSkeleton = _posts.isEmpty;
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [];
        _railReels = [];
        _railReelsLocked = true;
        _hasMore = false;
        _isInitialLoading = false;
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
    } catch (_) {
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
        .where((post) => post.isReel && post.videoUrl.trim().isNotEmpty)
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
    final headerHeight = _activeTab == 'people' ? 114.0 : 54.0;

    if (_activeTab == 'people') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hydrateVisiblePeople(people);
      });
    }

    return Container(
      color: const Color(0xFFF7F8FA),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const PageStorageKey<String>('feed-post-list'),
          controller: _scrollController,
          cacheExtent: 1500,
          physics: const ClampingScrollPhysics(
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
                      ? _buildPeopleItem(index, people)
                      : _buildFeedItem(index, posts),
                  childCount: _activeTab == 'people'
                      ? _peopleItemCount(people)
                      : _feedItemCount(posts) - 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _feedItemCount(List<Post> posts) {
    if (!_isInitialLoading && posts.isNotEmpty && _railReels.isNotEmpty) {
      return posts.length + 1 + (_isLoadingMore ? 1 : 0);
    }

    if (_isInitialLoading || posts.isEmpty) {
      return 1;
    }

    return posts.length + (_isLoadingMore ? 1 : 0);
  }

  Widget _buildFeedItem(int index, List<Post> posts) {
    if (_isInitialLoading) {
      return const Column(
        children: [
          PostSkeletonCard(),
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

    final contentIndex = index - (reelsItemIndex != null && index > reelsItemIndex ? 1 : 0);
    if (contentIndex >= 0 && contentIndex < posts.length) {
      return _postCard(posts[contentIndex]);
    }

    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: PostSkeletonCard(),
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
    final nonReelPosts = posts.where((post) => !post.isReel);

    return nonReelPosts
        .where(
          (post) =>
              !_isOwnPost(post) &&
              !post.isFollowingAuthor &&
              !_isFollowedUsername(post.authorUsername),
        )
        .toList();
  }

  List<User> _visiblePeople() {
    final sourcePeople = _peopleSearchQuery.trim().length >= 2
        ? _searchPeopleResults
        : _discoverPeople(_posts);
    final seen = <String>{};
    final visible = <User>[];

    for (final user in sourcePeople) {
      final username = _normalizeUsername(user.username);
      if (username.isEmpty ||
          username == _normalizeUsername(widget.user.username) ||
          _followedUsernames.contains(username) ||
          _invalidProfileUsernames.contains(username) ||
          !seen.add(username)) {
        continue;
      }
      visible.add(user);
    }

    return visible;
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
            _isSearchingPeople = false;
          });
        } catch (_) {
          if (!mounted || _peopleSearchQuery != nextQuery) {
            return;
          }

          setState(() {
            _searchPeopleResults = [];
            _isSearchingPeople = false;
          });
        }
      },
    );
  }

  int _peopleItemCount(List<User> people) {
    if (_isSearchingPeople || people.isEmpty) {
      return 1;
    }

    return people.length;
  }

  Widget _buildPeopleItem(int index, List<User> people) {
    if (_isSearchingPeople) {
      return const Padding(
        padding: EdgeInsets.only(top: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (people.isEmpty) {
      final message = _peopleSearchQuery.trim().length >= 2
          ? 'No people found.'
          : 'No people to show right now.';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final baseUser = people[index];
    final user = _peopleProfileDetails[_normalizeUsername(baseUser.username)] ??
        baseUser;
    return _PeopleListRow(
      user: user,
      isFollowPending:
          _followPendingUsernames.contains(_normalizeUsername(user.username)),
      onTap: () => _openPerson(user),
      onFollow: () => _followPerson(user),
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
        ...usernamesToLoad.where((username) => !invalidUsernames.contains(username)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share placeholder: ${post.id}')),
    );
  }

  void _showBookmarkPlaceholder(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save/bookmark is not available yet.')),
    );
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Reels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.reels.length,
            itemBuilder: (context, index) {
              final reel = widget.reels[index];
              return _ReelPreviewCard(
                key: ValueKey<String>('feed-reel-preview-${reel.id}'),
                reel: reel,
                width: cardWidth,
                height: cardHeight,
                onTap: () => widget.onReelTap(reel, index),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Center(
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

    return ColoredBox(
      color: Colors.white,
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
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F2),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF111827),
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
    return Container(
      height: 54,
      color: Colors.white,
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
    required this.isFollowPending,
    required this.onTap,
    required this.onFollow,
  });

  final User user;
  final bool isFollowPending;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final extras = _extraLines(user);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFFE5E7EB),
              backgroundImage: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? null
                  : NetworkImage(ApiConfig.assetUrl(user.avatarUrl!)),
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(
                      user.initials,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.handle ?? '',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  for (final line in extras) ...[
                    const SizedBox(height: 2),
                    Text(
                      line,
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: isFollowPending ? null : onFollow,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF2F2F2),
                foregroundColor: const Color(0xFF111111),
                minimumSize: const Size(84, 36),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(isFollowPending ? '...' : 'Follow'),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF111827) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w800,
              fontSize: 15,
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabDelegate oldDelegate) => true;
}
