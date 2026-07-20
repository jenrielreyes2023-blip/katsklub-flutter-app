import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math' as math;

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../models/story.dart';
import 'story_viewer_screen.dart';
import '../services/feed_service.dart';
import '../services/auth_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/kats_top_bar.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/post_card.dart';
import '../widgets/share_post_sheet.dart';
import '../widgets/avatar_with_border.dart';
import '../widgets/profile_music_panel.dart';
import '../widgets/presence_avatar_dot.dart';
import '../widgets/featured_photos_section.dart';
import '../widgets/feed_momentum_scroll_physics.dart';
import '../widgets/media_post_snap_coordinator.dart';
import '../widgets/special_name_text.dart';
import 'image_viewer_screen.dart';
import 'post_detail_screen.dart';
import 'repost_post_screen.dart';
import 'reels_viewer_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';
import 'notifications_screen.dart';
import 'shop_screen.dart';
import 'messages_screen.dart';
import 'admin_dashboard_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'webview_screen.dart';
import 'user_relations_screen.dart';
import 'visitors_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.refreshToken,
    this.onLogout,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    this.onOpenNotifications,
    this.onBack,
    this.extraHeaderAction,
    this.onUserUpdated,
    super.key,
  });

  final User user;
  final int refreshToken;
  final Future<void> Function()? onLogout;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onBack;
  final Widget? extraHeaderAction;
  final ValueChanged<User>? onUserUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FeedService _feedService = FeedService();
  late TabController _tabController;
  List<Post> _profilePosts = [];
  List<Story> _stories = [];
  bool _isLoadingProfilePosts = true;
  bool _hasLoadedInitialContent = false;
  late User _profileUser;
  bool _isUpdatingFollow = false;
  bool _isOpeningMessage = false;
  int _unreadNotifications = 0;
  int? _profilePostCount;
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
  int _featuredPhotosVersion = 0;
  List<User> _followSuggestions = [];
  final Set<String> _loadingSuggestedUsernames = {};
  List<Post> _reelsSuggestions = [];

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _feedService.loadFollowSuggestions();
      if (mounted) {
        setState(() {
          _followSuggestions = suggestions;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReelsSuggestions() async {
    try {
      final result = await _feedService.loadReels(limit: 6);
      if (mounted) {
        setState(() {
          _reelsSuggestions = result.posts;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _profileUser = widget.user;
    _profilePostCount =
        widget.user.postCount > 0 ? widget.user.postCount : null;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _scrollController.addListener(_handleScroll);
    _mediaSnapCoordinator = MediaPostSnapCoordinator(
      controller: _scrollController,
      topInsetBuilder: () => 72,
    );
    _unreadNotifications = FeedService.unreadNotificationsNotifier.value;
    _bindFeedEvents();
    _loadProfilePosts();
    _loadStories();
    _loadSuggestions();
    _loadReelsSuggestions();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.user.username != widget.user.username) {
      _profileUser = widget.user;
      _profilePostCount =
          widget.user.postCount > 0 ? widget.user.postCount : null;
      if (oldWidget.user.username != widget.user.username) {
        _hasLoadedInitialContent = false;
      }
      _loadProfilePosts();
      _loadStories();
      _loadSuggestions();
      _loadReelsSuggestions();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _postDeletedSubscription?.cancel();
    _postHiddenSubscription?.cancel();
    _postCreatedSubscription?.cancel();
    _postUpdatedSubscription?.cancel();
    _commentCountSubscription?.cancel();
    _profileStatsSubscription?.cancel();
    _postcardThemesResetSubscription?.cancel();
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
    FeedService.unreadNotificationsNotifier
        .addListener(_handleUnreadNotificationsChanged);
  }

  void _applyProfileStatsChange(ProfileStatsChange event) {
    if (!mounted) {
      return;
    }

    final profileUsername = _profileUser.username?.trim().toLowerCase() ?? '';
    final eventUsername = event.username.trim().toLowerCase();
    if (profileUsername.isEmpty || profileUsername != eventUsername) {
      return;
    }

    final nextUser = event.user ??
        _profileUser.copyWith(
          followersCount: event.followersCount,
          followingCount: event.followingCount,
          isFollowing: event.isFollowing,
        );
    final nextTheme = nextUser.postcardTheme ?? '';

    setState(() {
      _profileUser = nextUser;
      _profilePosts = _profilePosts
          .map(
            (item) => item.authorUsername.trim().toLowerCase() == eventUsername
                ? item.copyWith(authorPostcardTheme: nextTheme)
                : item,
          )
          .toList();
    });
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

  void _removePostById(String postId) {
    if (!mounted) {
      return;
    }

    var removedCount = 0;
    final nextPosts = _profilePosts.where((item) {
      final shouldKeep = item.id != postId;
      if (!shouldKeep) {
        removedCount++;
      }
      return shouldKeep;
    }).toList();

    if (removedCount == 0) {
      return;
    }

    setState(() {
      _profilePosts = nextPosts;
      if (_profilePostCount != null && _profilePostCount! > 0) {
        _profilePostCount =
            (_profilePostCount! - removedCount).clamp(0, 1 << 31);
      }
    });
  }

  void _handleCreatedPost(Post createdPost) {
    if (!mounted || createdPost.isReel) {
      return;
    }

    final profileUsername = _profileUser.username?.trim().toLowerCase() ?? '';
    final authorUsername = createdPost.authorUsername.trim().toLowerCase();
    if (profileUsername.isEmpty || profileUsername != authorUsername) {
      return;
    }

    final alreadyExists =
        _profilePosts.any((item) => item.id == createdPost.id);
    setState(() {
      _profilePosts = [
        createdPost,
        ..._profilePosts.where((item) => item.id != createdPost.id),
      ];
      if (!alreadyExists) {
        _profilePostCount = (_profilePostCount ?? 0) + 1;
      }
    });
  }

  void _applyCommentCountChange(CommentCountChange event) {
    if (!mounted) {
      return;
    }

    setState(() {
      _profilePosts = _profilePosts
          .map(
            (item) => item.id == event.postId
                ? item.copyWith(commentCount: event.commentCount)
                : item,
          )
          .toList();
    });
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_isLoadingProfilePosts || _isLoadingMore || !_hasMore) {
      return;
    }

    if (_scrollController.position.extentAfter < 1200) {
      _loadMoreProfilePosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.onLogout != null;
    final profilePosts = _profilePosts
        .where((post) => !post.isReel && !post.isDiscussion)
        .toList();
    final profileReels = _profilePosts.where((post) => post.isReel).toList();
    final discussionPosts =
        _profilePosts.where((post) => post.isDiscussion).toList();
    final displayedPostCount = _profilePostCount ??
        (_isLoadingProfilePosts && _profilePosts.isEmpty
            ? null
            : _profilePosts.length);
    final canGoBack = widget.onBack != null || Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadProfilePosts();
            _loadStories();
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: NotificationListener<ScrollNotification>(
          onNotification: (notification) => _handleProfileScrollNotification(
            notification,
            _snapCandidatePosts(
              profilePosts: profilePosts,
              discussionPosts: discussionPosts,
            ),
          ),
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 1500,
            physics: const FeedMomentumScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                pinned: false,
                automaticallyImplyLeading: false,
                title: Row(
                  children: [
                    if (canGoBack) ...[
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _goBack,
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: Center(
                            child: SvgPicture.string(
                              '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 22h6c5 0 7-2 7-7V9c0-5-2-7-7-7H9C4 2 2 4 2 9v6c0 5 2 7 7 7z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M13.2602 15.5302l-3.51997-3.53L13.2602 8.47021" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
                              width: 28,
                              height: 28,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFFF7A45),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        _profileUser.username ?? _profileUser.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShopScreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: SvgPicture.string(
                          '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12.0005 12c1.83.0 3.18-1.49 3-3.32L14.3405 2H9.67048l-.67 6.68C8.82048 10.51 10.1705 12 12.0005 12z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M18.3108 12c2.02.0 3.5-1.64 3.3-3.65L21.3308 5.6C20.9708 3 19.9708 2 17.3508 2h-3.05L15.0008 9.01c.17 1.65 1.66 2.99 3.31 2.99z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M5.64037 12c1.65.0 3.14-1.34 3.3-2.99L9.16037 6.8l.48-4.8h-3.05c-2.62.0-3.62 1-3.98 3.6l-.27 2.75c-.2 2.01 1.28 3.65 3.3 3.65z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><g opacity=".4"><path d="M3.00977 11.2197v4.49c0 4.49 1.8 6.29 6.29 6.29H14.6898c4.49.0 6.29-1.8 6.29-6.29v-4.49" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 17C10.33 17 9.5 17.83 9.5 19.5V22h5V19.5c0-1.67-.83-2.5-2.5-2.5z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></g></svg>',
                          width: 26,
                          height: 26,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFFF7A45),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  NotificationBellButton(
                    unreadNotifications: _unreadNotifications,
                    onPressed: _openNotifications,
                  ),
                  if (widget.extraHeaderAction != null)
                    widget.extraHeaderAction!,
                  if (widget.onLogout != null)
                    IconButton(
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Color(0xFFFF7A45),
                        size: 24,
                      ),
                      onPressed: () => _showMenu(context),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(
                      user: _profileUser,
                      stories: _stories,
                      isOwnProfile: isOwnProfile,
                      onTapStory: () => _openUserStories(_profileUser.username ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _ProfileBio(
                      user: _profileUser,
                      isOwnProfile: isOwnProfile,
                    ),
                    const SizedBox(height: 10),
                    _ProfileMetadataRow(user: _profileUser),
                    const SizedBox(height: 10),
                    _ProfileInlineCounters(
                      user: _profileUser,
                      postCount: displayedPostCount,
                      onTapFollowing: () => _openUserList(false),
                      onTapFollowers: () => _openUserList(true),
                      isOwnProfile: isOwnProfile,
                    ),
                    const SizedBox(height: 14),
                    _ProfileActionRow(
                      user: _profileUser,
                      isOwnProfile: isOwnProfile,
                      isUpdatingFollow: _isUpdatingFollow,
                      onToggleFollow: _toggleFollow,
                      isOpeningMessage: _isOpeningMessage,
                      onMessage: _openMessage,
                    ),
                    const SizedBox(height: 20),
                    FeaturedPhotosSection(
                      key: ValueKey(
                          'featured_photos_${_profileUser.username}_$_featuredPhotosVersion'),
                      user: _profileUser,
                      isOwnProfile: isOwnProfile,
                      onUpdated: (updatedUser) {
                        if (!mounted) return;
                        setState(() {
                          _profileUser = updatedUser;
                          _featuredPhotosVersion++;
                        });
                        widget.onUserUpdated?.call(updatedUser);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileTabBarHeaderDelegate(
                  child: _ProfileTabBar(controller: _tabController),
                ),
              ),
              _buildSelectedTabSliver(
                profilePosts: profilePosts,
                profileReels: profileReels,
                discussionPosts: discussionPosts,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _goBack() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }

    Navigator.of(context).maybePop();
  }

  Widget _buildSelectedTabSliver({
    required List<Post> profilePosts,
    required List<Post> profileReels,
    required List<Post> discussionPosts,
  }) {
    final isOwnProfile = widget.onLogout != null;
    final isLockedPrivate =
        _profileUser.isPrivate && !isOwnProfile && !_profileUser.isFollowing;
    if (isLockedPrivate) {
      return _buildPrivateLockedSliver();
    }

    if (_isLoadingProfilePosts) {
      return SliverList(
        delegate: SliverChildListDelegate.fixed(
          const [
            PostSkeletonCard(variant: 0),
            PostSkeletonCard(variant: 1),
          ],
        ),
      );
    }

    switch (_tabController.index) {
      case 1:
        return _buildReelsGridSliver(profileReels);
      case 2:
        return SliverToBoxAdapter(
          child: ProfileMusicPanel(
            username: _profileUser.username?.trim() ?? '',
            canManagePlaylists: widget.onLogout != null,
          ),
        );
      case 3:
        return _buildPostListSliver(
          posts: discussionPosts,
          emptyMessage: 'No discussions yet',
        );
      default:
        return _buildPostListSliver(
          posts: profilePosts,
          emptyMessage: 'No posts yet',
        );
    }
  }

  Widget _buildPrivateLockedSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF6B7280),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This account is private',
              style: TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _profileUser.isRequested
                  ? 'Your follow request is pending approval.'
                  : 'Follow this account to see their posts.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostListSliver({
    required List<Post> posts,
    required String emptyMessage,
  }) {
    if (posts.isEmpty) {
      return _buildEmptyStateWithSuggestions(emptyMessage);
    }

    final itemCount = posts.length + (_isLoadingMore ? 3 : 0);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= posts.length) {
            return PostSkeletonCard(variant: index % 4);
          }
          return _buildSnappablePostCard(posts[index]);
        },
        childCount: itemCount,
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            final id = key.value.replaceFirst('snappable-post-card-', '');
            final index = posts.indexWhere((p) => p.id == id);
            return index >= 0 ? index : null;
          }
          return null;
        },
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
      ),
    );
  }

  List<Post> _snapCandidatePosts({
    required List<Post> profilePosts,
    required List<Post> discussionPosts,
  }) {
    if (_tabController.index == 0) {
      return profilePosts;
    }
    if (_tabController.index == 3) {
      return discussionPosts;
    }
    return const <Post>[];
  }

  bool _handleProfileScrollNotification(
    ScrollNotification notification,
    List<Post> posts,
  ) {
    _mediaSnapCoordinator.handleNotification(
      notification,
      posts: posts,
      enabled: (_tabController.index == 0 || _tabController.index == 3) &&
          posts.isNotEmpty,
      isMediaPost: hasSnappableMedia,
    );
    return false;
  }

  Widget _buildSnappablePostCard(Post post) {
    return KeyedSubtree(
      key: ValueKey<String>('snappable-post-card-${post.id}'),
      child: KeyedSubtree(
        key: _mediaSnapCoordinator.keyForPost(post),
        child: _postCard(post),
      ),
    );
  }

  Widget _buildReelsGridSliver(List<Post> posts) {
    final reels = posts
        .where((post) =>
            post.isReel &&
            (post.videoUrl.trim().isNotEmpty || post.imageUrls.isNotEmpty))
        .toList();
    if (reels.isEmpty) {
      return _buildEmptyReelsWithSuggestions();
    }

    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final reel = reels[index];
            return _ReelCoverTile(
              key: ValueKey<String>('profile-reel-tile-${reel.id}'),
              reel: reel,
              onTap: () => _openProfileReel(reel),
            );
          },
          childCount: reels.length,
          findChildIndexCallback: (Key key) {
            if (key is ValueKey<String>) {
              final id = key.value.replaceFirst('profile-reel-tile-', '');
              final index = reels.indexWhere((p) => p.id == id);
              return index >= 0 ? index : null;
            }
            return null;
          },
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }

  Widget _emptySliver(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: _EmptyTab(message: message),
    );
  }

  Future<void> _loadStories() async {
    try {
      final stories = await _feedService.loadStories();
      if (mounted) {
        setState(() {
          _stories = stories;
        });
      }
    } catch (_) {}
  }

  void _openUserStories(String username) {
    if (username.isEmpty) return;
    final targetLower = username.trim().toLowerCase();
    final userStories = _stories.where((s) => s.authorUsername.trim().toLowerCase() == targetLower).toList();
    
    if (userStories.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            storyGroups: [userStories],
            initialGroupIndex: 0,
            initialStoryIndex: 0,
          ),
        ),
      );
    }
  }

  Future<void> _loadProfilePosts() async {
    final username = _profileUser.username?.trim() ?? '';
    if (username.isEmpty) {
      setState(() {
        _profilePosts = [];
        _isLoadingProfilePosts = false;
        _isLoadingMore = false;
        _nextOffset = 0;
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _isLoadingProfilePosts =
          !_hasLoadedInitialContent && _profilePosts.isEmpty;
      _isLoadingMore = false;
      _nextOffset = 0;
      _hasMore = true;
    });

    try {
      final page = await _feedService.loadUserPosts(
        username,
        offset: 0,
        limit: 20,
      );
      if (!mounted) return;
      _mediaSnapCoordinator.clearKeys();
      setState(() {
        _profilePosts = page.posts;
        _profilePostCount =
            page.totalCount > 0 ? page.totalCount : page.posts.length;
        _isLoadingProfilePosts = false;
        _hasLoadedInitialContent = true;
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profilePosts = [];
        _isLoadingProfilePosts = false;
        _hasLoadedInitialContent = true;
      });
    }
  }

  Future<void> _loadMoreProfilePosts() async {
    final username = _profileUser.username?.trim() ?? '';
    if (username.isEmpty || _isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _feedService.loadUserPosts(
        username,
        offset: _nextOffset,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        final seenPostIds = <String>{};
        final mergedPosts = <Post>[];

        for (final post in [..._profilePosts, ...page.posts]) {
          if (seenPostIds.add(post.id)) {
            mergedPosts.add(post);
          }
        }

        _profilePosts = mergedPosts;
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

  Widget _postCard(Post post) {
    return PostCard(
      key: ValueKey<String>('profile-post-card-${post.id}'),
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
      showPinnedBadge: true,
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

    _mediaSnapCoordinator.clearKeys();
    bool shouldReload = false;

    setState(() {
      if (updatedPost.isPinned) {
        final others = _profilePosts
            .where((item) => item.id != updatedPost.id)
            .map((item) => item.isPinned ? item.copyWith(isPinned: false) : item)
            .toList();
        _profilePosts = [updatedPost, ...others];
      } else {
        final wasPinnedLocally = _profilePosts.any((item) => item.id == updatedPost.id && item.isPinned);
        _profilePosts = _profilePosts
            .map((item) => item.id == updatedPost.id ? updatedPost : item)
            .toList();
        if (wasPinnedLocally && !updatedPost.isPinned) {
          shouldReload = true;
        }
      }
    });

    if (shouldReload) {
      _loadProfilePosts();
    }
  }

  void _clearAllPostcardThemes() {
    if (!mounted) {
      return;
    }

    setState(() {
      _profilePosts = _profilePosts.map((item) {
        Post? cleanOriginal;
        if (item.originalPost != null) {
          cleanOriginal = item.originalPost!.copyWith(authorPostcardTheme: '');
        }
        return item.copyWith(
          authorPostcardTheme: '',
          originalPost: cleanOriginal,
        );
      }).toList();
    });
  }

  Future<void> _openComments(Post post) async {
    final commentCount = await showCommentsModal(context: context, post: post);
    if (!mounted || commentCount == null) {
      return;
    }

    setState(() {
      _profilePosts = _profilePosts
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
      _profilePosts =
          _profilePosts.where((item) => item.id != post.id).toList();
      if (_profilePostCount != null && _profilePostCount! > 0) {
        _profilePostCount = _profilePostCount! - 1;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post successfully deleted.')),
    );
  }

  Future<void> _hidePost(Post post) async {
    final previousPosts = List<Post>.from(_profilePosts);
    final previousCount = _profilePostCount;

    setState(() {
      _profilePosts =
          _profilePosts.where((item) => item.id != post.id).toList();
      if (_profilePostCount != null && _profilePostCount! > 0) {
        _profilePostCount = _profilePostCount! - 1;
      }
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
        _profilePosts = previousPosts;
        _profilePostCount = previousCount;
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
          currentUser: widget.onLogout == null ? null : _profileUser,
          onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
          onOpenUserProfile: widget.onOpenUserProfile,
        ),
      ),
    );
  }

  void _openProfileReel(Post reel) {
    final profileReels = _profilePosts
        .where((post) =>
            post.isReel &&
            (post.videoUrl.trim().isNotEmpty || post.imageUrls.isNotEmpty))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelsViewerScreen(
          initialReel: reel,
          initialReelId: reel.id,
          initialPlaylist: profileReels,
          loadMoreFromFeed: false,
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
            currentUser: widget.onLogout == null ? null : _profileUser,
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
          post: post,
          currentUser: widget.onLogout == null ? null : _profileUser,
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

  void _openNotifications() {
    final onOpenNotifications = widget.onOpenNotifications;
    if (onOpenNotifications != null) {
      onOpenNotifications();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  bool _isCurrentUser(String username) {
    if (widget.onLogout == null) {
      return false;
    }

    final currentUsername = _profileUser.username?.trim().toLowerCase() ?? '';
    return currentUsername.isNotEmpty &&
        username.trim().toLowerCase() == currentUsername;
  }

  void _showSharePlaceholder(Post post) async {
    final currentUser = await AuthService().getSavedUser();
    if (!mounted) return;
    SharePostSheet.show(
      context,
      post: post,
      currentUser: currentUser,
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

  Future<void> _handleCopyProfileLink() async {
    final username = _profileUser.username?.trim() ?? '';
    final path = username.isEmpty ? 'profile' : 'profile/$username';
    await Clipboard.setData(ClipboardData(text: 'https://katsklub.top/$path'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile link copied.')),
    );
  }

  void _showMenu(BuildContext context) {
    final onLogout = widget.onLogout;
    if (onLogout == null) {
      return;
    }

    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (sheetContext) => _MenuSheet(
        user: _profileUser,
      ),
    ).then((action) {
      if (action == null || !context.mounted) return;

      switch (action) {
        case 'copy_link':
          _handleCopyProfileLink();
          break;
        case 'about':
          showProfileAboutSheet(
            context,
            user: _profileUser,
            showPrivateFields: true,
          );
          break;
        case 'edit_profile':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfileScreen(
                user: _profileUser,
              ),
            ),
          ).then((updatedUser) {
            if (updatedUser is User && mounted) {
              setState(() {
                _profileUser = updatedUser;
              });
              widget.onUserUpdated?.call(updatedUser);
            }
          });
          break;
        case 'settings':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsScreen(
                user: _profileUser,
                onLogout: onLogout,
              ),
            ),
          ).then((updatedUser) {
            if (updatedUser is User && mounted) {
              setState(() {
                _profileUser = updatedUser;
              });
              widget.onUserUpdated?.call(updatedUser);
            }
          });
          break;
        case 'manage_featured_photos':
          _manageFeaturedPhotos();
          break;
        case 'admin_dashboard':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(
                sessionCookie: null,
                authToken: null,
              ),
            ),
          );
          break;
      }
    });
  }

  void _manageFeaturedPhotos() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ManageFeaturedPhotosSheet(
          user: _profileUser,
          onUpdated: (updatedUser) {
            if (!mounted) return;
            setState(() {
              _profileUser = updatedUser;
              _featuredPhotosVersion++;
            });
            widget.onUserUpdated?.call(updatedUser);
          },
        );
      },
    );
  }

  Future<void> _toggleFollow() async {
    final username = _profileUser.username?.trim() ?? '';
    if (username.isEmpty || _isUpdatingFollow || widget.onLogout != null) {
      return;
    }

    setState(() {
      _isUpdatingFollow = true;
    });

    try {
      final shouldUndo = _profileUser.isFollowing || _profileUser.isRequested;
      final updatedUser = shouldUndo
          ? await _feedService.unfollowUser(username)
          : await _feedService.followUser(username);
      if (!mounted) return;
      if (updatedUser != null) {
        setState(() {
          _profileUser = updatedUser;
          _isUpdatingFollow = false;
        });
        return;
      }

      setState(() {
        _isUpdatingFollow = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUpdatingFollow = false;
      });
    }
  }

  Future<void> _openMessage() async {
    final username = _profileUser.username?.trim() ?? '';
    if (username.isEmpty || widget.onLogout != null || _isOpeningMessage) {
      return;
    }

    setState(() {
      _isOpeningMessage = true;
    });

    final thread = await _feedService.startMessageThread(username);
    if (!mounted) return;

    setState(() {
      _isOpeningMessage = false;
    });

    if (thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open messages.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(initialThread: thread),
      ),
    );
  }

  void _openUserList(bool isFollowersList) async {
    final currentUser = await AuthService().getSavedUser();
    if (currentUser == null) {
      return;
    }

    final isOwnProfile = widget.onLogout != null;

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserRelationsScreen(
          username: _profileUser.username ?? '',
          isOwnProfile: isOwnProfile,
          showListFollowers: _profileUser.profileShowFollowers,
          showListFollowing: _profileUser.profileShowFollowing,
          currentUser: currentUser,
          initialTabIndex: isFollowersList ? 0 : 1,
          onOpenUserProfile: widget.onOpenUserProfile,
        ),
      ),
    );
  }
  void _openSuggestedReel(Post reel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelsViewerScreen(
          initialReel: reel,
          initialReelId: reel.id,
          initialPlaylist: _reelsSuggestions,
          loadMoreFromFeed: false,
        ),
      ),
    );
  }

  Widget _buildEmptyReelsWithSuggestions() {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(
                Icons.video_collection_outlined,
                size: 48,
                color: Color(0xFFD1D5DB),
              ),
              const SizedBox(height: 12),
              const Text(
                'No reels yet',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              if (_reelsSuggestions.isNotEmpty) ...[
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFFF7A59), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Suggested Reels',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _reelsSuggestions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.62,
                  ),
                  itemBuilder: (context, index) {
                    final reel = _reelsSuggestions[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _ReelCoverTile(
                        key: ValueKey<String>('profile-suggested-reel-tile-${reel.id}'),
                        reel: reel,
                        onTap: () => _openSuggestedReel(reel),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
  Future<void> _toggleFollowSuggestedUser(User targetUser) async {
    final targetUsername = targetUser.username ?? '';
    if (targetUsername.isEmpty || _loadingSuggestedUsernames.contains(targetUsername)) {
      return;
    }

    setState(() {
      _loadingSuggestedUsernames.add(targetUsername);
    });

    try {
      final User? updated;
      if (targetUser.isFollowing) {
        updated = await _feedService.unfollowUser(targetUsername);
      } else {
        updated = await _feedService.followUser(targetUsername);
      }

      if (mounted && updated != null) {
        setState(() {
          final index = _followSuggestions.indexWhere((u) => u.username == targetUsername);
          if (index >= 0) {
            _followSuggestions[index] = _followSuggestions[index].copyWith(
              isFollowing: updated!.isFollowing,
              isRequested: updated.isRequested,
            );
          }
        });
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) {
        setState(() {
          _loadingSuggestedUsernames.remove(targetUsername);
        });
      }
    }
  }

  Widget _buildEmptyStateWithSuggestions(String emptyMessage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.post_add_rounded,
              size: 48,
              color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            if (_followSuggestions.isNotEmpty) ...[
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFFF7A45), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Suggested for you',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _followSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestedUser = _followSuggestions[index];
                    return _buildSuggestionCard(suggestedUser);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(User user) {
    final borderType = AvatarBorderType.parse(user.profileBorder);
    final username = user.username ?? '';
    final isPending = _loadingSuggestedUsernames.contains(username);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (user.username != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(username: user.username!),
            ),
          );
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242526) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarWithBorder(
              avatarUrl: user.avatarUrl ?? '',
              initials: user.initials,
              borderType: borderType,
              size: 50,
            ),
            const SizedBox(height: 8),
            Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.handle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: isPending
                  ? Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? const Color(0xFFFF7A45) : Colors.black,
                        ),
                      ),
                    )
                  : user.isFollowing
                      ? OutlinedButton(
                          onPressed: () => _toggleFollowSuggestedUser(user),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151),
                            side: BorderSide(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Following',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        )
                      : user.isRequested
                          ? OutlinedButton(
                              onPressed: () => _toggleFollowSuggestedUser(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                                side: BorderSide(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Requested',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () => _toggleFollowSuggestedUser(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A45),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Follow',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.stories,
    required this.isOwnProfile,
    required this.onTapStory,
  });

  final User user;
  final List<Story> stories;
  final bool isOwnProfile;
  final VoidCallback onTapStory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _ProfileAvatar(
          user: user,
          stories: stories,
          isOwnProfile: isOwnProfile,
          onTapStory: onTapStory,
        ),
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({required this.controller});

  static const String _postsSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 22h6c5 0 7-2 7-7V9c0-5-2-7-7-7H9C4 2 2 4 2 9v6c0 5 2 7 7 7z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><g opacity=".4"><path d="M18.3801 15.2702V7.58023C18.3801 6.81023 17.7601 6.25024 17.0001 6.31024H16.9601C15.6201 6.42024 13.5901 7.11025 12.4501 7.82025L12.3401 7.89026c-.18.110000000000001-.49.110000000000001-.68.0L11.5001 7.79025c-1.13-.71-3.15998-1.38002-4.49998-1.49002-.76-.0599999999999996-1.38.51002-1.38 1.27002V15.2702c0 .609999999999999.49998 1.19 1.10998 1.26L6.9101 16.5602C8.2901 16.7402 10.4301 17.4502 11.6501 18.1202L11.6801 18.1302C11.8501 18.2302 12.1301 18.2302 12.2901 18.1302c1.22-.68 3.37-1.38 4.76-1.57L17.2601 16.5302C17.8801 16.4602 18.3801 15.8902 18.3801 15.2702z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 8.1001v9.56" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></g></svg>';
  static const String _reelsSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 22h6c5 0 7-2 7-7V9c0-5-2-7-7-7H9C4 2 2 4 2 9v6c0 5 2 7 7 7z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M9.09961 12V10.52c0-1.91001 1.34999-2.68001 2.99999-1.73001l1.28.74 1.28.74001c1.65.950000000000001 1.65 2.51.0 3.46l-1.28.74-1.28.74C10.4496 16.16 9.09961 15.38 9.09961 13.48V12z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  static const String _musicSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M6.28016 21.9998c1.72312.0 3.12-1.3969 3.12-3.12.0-1.7232-1.39688-3.12-3.12-3.12-1.72313.0-3.12 1.3968-3.12 3.12.0 1.7231 1.39687 3.12 3.12 3.12z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M17.7196 19.9202c1.7231.0 3.12-1.3969 3.12-3.12.0-1.7232-1.3969-3.12-3.12-3.12-1.7231.0-3.12 1.3968-3.12 3.12.0 1.7231 1.3969 3.12 3.12 3.12z" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><g opacity=".4"><path d="M20.8404 16.8003V4.60034c0-2.6-1.63-2.96-3.28-2.51l-6.24 1.7c-1.14.31-1.92001 1.21-1.92001 2.51v2.17 1.46V18.8703" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M9.40039 9.52039l11.44001-3.12" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></g></svg>';
  static const String _othersSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9.31993 13.28H12.4099v7.2c0 1.06 1.32 1.56 2.02.759999999999998l7.57-8.6C22.6599 11.89 22.1299 10.72 21.1299 10.72h-3.09V3.51997c0-1.06-1.32-1.56-2.02-.76L8.44994 11.36c-.65.75-.120010000000001 1.92.86999 1.92z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M8.5 4h-7" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M7.5 20h-6" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M4.5 12h-3" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final selectedColor = const Color(0xFFFF7A45); // Orange
    final unselectedColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B3B8)
        : const Color(0xFF65676B);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: controller,
            indicatorColor: selectedColor,
            indicatorWeight: 1,
            labelColor: selectedColor,
            unselectedLabelColor: unselectedColor,
            tabs: [
              Tab(
                icon: _ProfileTabSvgIcon(
                  svg: _postsSvg,
                  color: controller.index == 0 ? selectedColor : unselectedColor,
                ),
                text: 'Posts',
              ),
              Tab(
                icon: _ProfileTabSvgIcon(
                  svg: _reelsSvg,
                  color: controller.index == 1 ? selectedColor : unselectedColor,
                ),
                text: 'Reels',
              ),
              Tab(
                icon: _ProfileTabSvgIcon(
                  svg: _musicSvg,
                  color: controller.index == 2 ? selectedColor : unselectedColor,
                ),
                text: 'Music',
              ),
              Tab(
                icon: _ProfileTabSvgIcon(
                  svg: _othersSvg,
                  color: controller.index == 3 ? selectedColor : unselectedColor,
                ),
                text: 'Others',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileTabSvgIcon extends StatelessWidget {
  const _ProfileTabSvgIcon({
    required this.svg,
    required this.color,
  });

  final String svg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svg,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class _ProfileTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_ProfileTabBarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.stories,
    required this.isOwnProfile,
    required this.onTapStory,
  });

  final User user;
  final List<Story> stories;
  final bool isOwnProfile;
  final VoidCallback onTapStory;

  @override
  Widget build(BuildContext context) {
    final borderType = AvatarBorderType.parse(user.profileBorder);
    final Widget avatar;

    final profileUsername = user.username?.trim().toLowerCase() ?? '';
    final userStories = stories.where((s) => s.authorUsername.trim().toLowerCase() == profileUsername).toList();
    final hasStories = userStories.isNotEmpty;

    if (borderType == AvatarBorderType.none) {
      final avatarUrl = user.avatarUrl;
      avatar = Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasStories
              ? LinearGradient(
                  colors: isOwnProfile
                      ? const [Color(0xFF2563EB), Color(0xFF06B6D4)]
                      : const [Color(0xFFF97316), Color(0xFFEC4899)],
                )
              : null,
          border: !hasStories
              ? Border.all(color: const Color(0xFFE5E7EB), width: 1)
              : null,
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 39,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(
                    ApiConfig.assetUrl(avatarUrl),
                    maxWidth: 180,
                  )
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    user.initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: Color(0xFF111827),
                    ),
                  )
                : null,
          ),
        ),
      );
    } else {
      avatar = AvatarWithBorder(
        avatarUrl: user.avatarUrl ?? '',
        initials: user.initials,
        borderType: borderType,
        size: 86,
      );
    }

    return GestureDetector(
      onTap: hasStories ? onTapStory : null,
      child: PresenceAvatarDot(
        userId: user.id,
        size: 18,
        child: avatar,
      ),
    );
  }
}

class _ProfileInlineCounters extends StatelessWidget {
  const _ProfileInlineCounters({
    required this.user,
    required this.postCount,
    required this.onTapFollowing,
    required this.onTapFollowers,
    required this.isOwnProfile,
  });

  final User user;
  final int? postCount;
  final VoidCallback onTapFollowing;
  final VoidCallback onTapFollowers;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsLabel = postCount == null ? '...' : _formatCount(postCount!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 8,
        children: [
          GestureDetector(
            onTap: onTapFollowing,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF65676B),
                  height: 1.3,
                ),
                children: [
                  _boldNumber(context, _formatCount(user.followingCount)),
                  const TextSpan(text: ' Following'),
                ],
              ),
            ),
          ),
          const Text(
            '  ·  ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF65676B),
            ),
          ),
          GestureDetector(
            onTap: onTapFollowers,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF65676B),
                  height: 1.3,
                ),
                children: [
                  _boldNumber(context, _formatCount(user.followersCount)),
                  const TextSpan(text: ' Followers'),
                ],
              ),
            ),
          ),
          const Text(
            '  ·  ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF65676B),
            ),
          ),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF65676B),
                height: 1.3,
              ),
              children: [
                _boldNumber(context, postsLabel),
                const TextSpan(text: ' Posts'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _boldNumber(BuildContext context, String value) {
    return TextSpan(
      text: value,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

class _ProfileBio extends StatelessWidget {
  const _ProfileBio({
    required this.user,
    required this.isOwnProfile,
  });

  final User user;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final achievements = _resolveProfileAchievements(user.achievements);
    final secondaryLines = <_ProfileBioLine>[
      if (user.roleTitle != null && user.roleTitle!.trim().isNotEmpty)
        _ProfileBioLine(
          text: user.roleTitle!.trim(),
          color: const Color(0xFF65676B),
        ),
      if (user.bio != null && user.bio!.trim().isNotEmpty)
        _ProfileBioLine(
          text: user.bio!.trim(),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFE4E6EB)
              : const Color(0xFF000000),
        ),
      if (isOwnProfile &&
          user.profileShowEmail &&
          user.bio == null &&
          user.email != null &&
          user.email!.trim().isNotEmpty)
        _ProfileBioLine(
          text: user.email!.trim(),
          color: const Color(0xFF65676B),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SpecialNameText(
                  username: user.username ?? '',
                  displayName: user.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.verified,
                  size: 18,
                  color: Color(0xFF1D9BF0),
                ),
              ],
              const SizedBox(width: 6),
              _buildCharmLevelBadge(user.charmLevel),
            ],
          ),
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ProfileAchievementPillGroup(achievements: achievements),
          ],
          for (final line in secondaryLines) ...[
            const SizedBox(height: 4),
            Text(
              line.text,
              style: TextStyle(
                fontSize: 14,
                color: line.color,
              ),
            ),
          ],
          if (user.profileLinks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: user.profileLinks.map((link) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final linkColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

                return GestureDetector(
                  onTap: () {
                    var urlStr = link.url.trim();
                    if (!urlStr.startsWith('http://') &&
                        !urlStr.startsWith('https://')) {
                      urlStr = 'https://$urlStr';
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebViewScreen(
                          url: urlStr,
                          title:
                              link.title.isNotEmpty ? link.title : 'Web Link',
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.string(
                        '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M13.0598 10.9399c2.25 2.25 2.25 5.89.0 8.13-2.25 2.24-5.88995 2.25-8.12995.0s-2.25-5.89.0-8.13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M10.5909 13.4099c-2.33996-2.34-2.33996-6.14002.0-8.49002 2.34-2.35 6.14-2.34 8.49.0s2.34 6.14002.0 8.49002" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>''',
                        width: 14,
                        height: 14,
                        colorFilter: ColorFilter.mode(linkColor, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        link.title.isNotEmpty ? link.title : link.url,
                        style: TextStyle(
                          fontSize: 13,
                          color: linkColor,
                          decoration: TextDecoration.underline,
                          decorationColor: linkColor,
                          decorationThickness: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharmLevelBadge(int level) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.string(
          '''<svg width="800" height="800" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" role="img" class="iconify iconify--noto"><path d="M68.05 7.23l13.46 30.7a7.047 7.047.0 005.82 4.19l32.79 2.94c3.71.54 5.19 5.09 2.5 7.71l-24.7 20.75c-2 1.68-2.91 4.32-2.36 6.87l7.18 33.61c.63 3.69-3.24 6.51-6.56 4.76L67.56 102a7.033 7.033.0 00-7.12.0l-28.62 16.75c-3.31 1.74-7.19-1.07-6.56-4.76l7.18-33.61c.54-2.55-.36-5.19-2.36-6.87L5.37 52.78c-2.68-2.61-1.2-7.17 2.5-7.71l32.79-2.94a7.047 7.047.0 005.82-4.19l13.46-30.7c1.67-3.36 6.45-3.36 8.11-.01z" fill="#fdd835"/><path d="M67.07 39.77l-2.28-22.62c-.09-1.26-.35-3.42 1.67-3.42 1.6.0 2.47 3.33 2.47 3.33l6.84 18.16c2.58 6.91 1.52 9.28-.97 10.68-2.86 1.6-7.08.35-7.73-6.13z" fill="#ffff8d"/><path d="M95.28 71.51 114.9 56.2c.97-.81 2.72-2.1 1.32-3.57-1.11-1.16-4.11.51-4.11.51l-17.17 6.71c-5.12 1.77-8.52 4.39-8.82 7.69-.39 4.4 3.56 7.79 9.16 3.97z" fill="#f4b400"/></svg>''',
          width: 15,
          height: 15,
        ),
        const SizedBox(width: 2),
        Text(
          '$level',
          style: const TextStyle(
            color: Color(0xFFFF7A45),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProfileBioLine {
  const _ProfileBioLine({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;
}

class _ProfileAchievementDefinition {
  const _ProfileAchievementDefinition({
    required this.key,
    required this.title,
    required this.theme,
  });

  final String key;
  final String title;
  final _ProfileAchievementTheme theme;
}

const Map<String, _ProfileAchievementDefinition>
    _profileAchievementDefinitions = {
  'richie_rich': _ProfileAchievementDefinition(
    key: 'richie_rich',
    title: 'Richie Rich',
    theme: _ProfileAchievementTheme.richieRich,
  ),
  'stars_catcher': _ProfileAchievementDefinition(
    key: 'stars_catcher',
    title: 'Stars catcher',
    theme: _ProfileAchievementTheme.starsCatcher,
  ),
  'soulmate': _ProfileAchievementDefinition(
    key: 'soulmate',
    title: 'Soulmate',
    theme: _ProfileAchievementTheme.soulmate,
  ),
  'spring_herald_pink': _ProfileAchievementDefinition(
    key: 'spring_herald_pink',
    title: 'Spring Herald',
    theme: _ProfileAchievementTheme.springHeraldPink,
  ),
  'spring_herald_purple': _ProfileAchievementDefinition(
    key: 'spring_herald_purple',
    title: 'Spring Herald',
    theme: _ProfileAchievementTheme.springHeraldPurple,
  ),
  'spring_herald_blue': _ProfileAchievementDefinition(
    key: 'spring_herald_blue',
    title: 'Spring Herald',
    theme: _ProfileAchievementTheme.springHeraldBlue,
  ),
  'supreme_warlord': _ProfileAchievementDefinition(
    key: 'supreme_warlord',
    title: 'Supreme Warlord',
    theme: _ProfileAchievementTheme.supremeWarlord,
  ),
  'tech_support': _ProfileAchievementDefinition(
    key: 'tech_support',
    title: 'Tech & Support',
    theme: _ProfileAchievementTheme.techSupport,
  ),
  'google_workspace': _ProfileAchievementDefinition(
    key: 'google_workspace',
    title: 'Google Workspace',
    theme: _ProfileAchievementTheme.googleWorkspace,
  ),
  'pop_superstar': _ProfileAchievementDefinition(
    key: 'pop_superstar',
    title: 'Pop Superstar',
    theme: _ProfileAchievementTheme.popSuperstar,
  ),
  'fresh_paw': _ProfileAchievementDefinition(
    key: 'fresh_paw',
    title: 'Fresh Paw',
    theme: _ProfileAchievementTheme.freshPaw,
  ),
  'rising_paw': _ProfileAchievementDefinition(
    key: 'rising_paw',
    title: 'Rising Paw',
    theme: _ProfileAchievementTheme.risingPaw,
  ),
  'top_50': _ProfileAchievementDefinition(
    key: 'top_50',
    title: 'Top 50 Club',
    theme: _ProfileAchievementTheme.top50,
  ),
  'asset_preview': _ProfileAchievementDefinition(
    key: 'asset_preview',
    title: 'Preview',
    theme: _ProfileAchievementTheme.assetPreview,
  ),
};

List<_ProfileAchievementDefinition> _resolveProfileAchievements(
  List<String> keys,
) {
  final seen = <String>{};
  final resolved = <_ProfileAchievementDefinition>[];
  for (final rawKey in keys) {
    final key = rawKey.trim().toLowerCase();
    final definition = _profileAchievementDefinitions[key];
    if (definition == null || !seen.add(key)) {
      continue;
    }
    resolved.add(definition);
  }
  return resolved;
}

class _ProfileAchievementPillGroup extends StatefulWidget {
  const _ProfileAchievementPillGroup({required this.achievements});

  final List<_ProfileAchievementDefinition> achievements;

  @override
  State<_ProfileAchievementPillGroup> createState() =>
      _ProfileAchievementPillGroupState();
}

class _ProfileAchievementPillGroupState
    extends State<_ProfileAchievementPillGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sparkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _sparkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.67, 1.0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: widget.achievements
          .map(
            (achievement) => RepaintBoundary(
              child: _ProfileAchievementPill(
                title: achievement.title,
                theme: achievement.theme,
                sparkAnimation: _sparkAnimation,
                motionAnimation: _controller,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProfileAchievementPill extends StatelessWidget {
  const _ProfileAchievementPill({
    required this.title,
    required this.theme,
    required this.sparkAnimation,
    required this.motionAnimation,
  });

  final String title;
  final _ProfileAchievementTheme theme;
  final Animation<double> sparkAnimation;
  final Animation<double> motionAnimation;

  @override
  Widget build(BuildContext context) {
    final style = theme.style;
    if (style.assetPillPath != null) {
      return _AssetAchievementPill(assetPath: style.assetPillPath!);
    }
    if (theme == _ProfileAchievementTheme.googleWorkspace) {
      return const _RawSvgAchievement(svgString: _googleWorkspaceSvg);
    }
    final borderRadius = BorderRadius.circular(999);
    final isSpringHerald = theme == _ProfileAchievementTheme.springHeraldPink ||
        theme == _ProfileAchievementTheme.springHeraldPurple ||
        theme == _ProfileAchievementTheme.springHeraldBlue;
    final hasSweepShimmer = theme == _ProfileAchievementTheme.starsCatcher ||
        isSpringHerald ||
        theme == _ProfileAchievementTheme.supremeWarlord ||
        theme == _ProfileAchievementTheme.techSupport ||
        theme == _ProfileAchievementTheme.top50;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: style.pillColors,
                ),
                borderRadius: borderRadius,
                border: style.pillBorderColor != null
                    ? Border.all(
                        color: style.pillBorderColor!,
                        width: 1.0,
                      )
                    : null,
                boxShadow: theme == _ProfileAchievementTheme.top50
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF5E3A).withValues(alpha: 0.65),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF2A00).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  if (style.pillPattern == _AchievementPillPattern.soulmate)
                    const Positioned.fill(child: _SoulmatePillPattern()),
                  if (hasSweepShimmer)
                    Positioned.fill(
                      child:
                          _AchievementSweepShimmer(animation: motionAnimation),
                    ),
                  if (style.pillPattern ==
                      _AchievementPillPattern.springHeraldPink)
                    const Positioned.fill(
                      child: _SpringHeraldBackgroundPattern(
                        patternColor: Color(0x3DFFF6D3),
                      ),
                    ),
                  if (style.pillPattern ==
                      _AchievementPillPattern.springHeraldPurple)
                    const Positioned.fill(
                      child: _SpringHeraldBackgroundPattern(
                        patternColor: Color(0x26FFF8D7),
                      ),
                    ),
                  if (style.pillPattern ==
                      _AchievementPillPattern.springHeraldBlue)
                    const Positioned.fill(
                      child: _SpringHeraldBackgroundPattern(
                        patternColor: Color(0x26FFFFFF),
                      ),
                    ),
                  if (isSpringHerald) const _SpringHeraldGlossySheen(),
                  if (style.pillPattern ==
                      _AchievementPillPattern.supremeWarlord)
                    Positioned.fill(
                      child: _WarlordFireBand(animation: motionAnimation),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AchievementBadge(
                animation: sparkAnimation,
                motionAnimation: motionAnimation,
                theme: theme,
              ),
              const SizedBox(width: 5),
              _AchievementPillLabel(
                text: title,
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetAchievementPill extends StatelessWidget {
  const _AssetAchievementPill({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: 34,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _AchievementPillLabel extends StatelessWidget {
  const _AchievementPillLabel({
    required this.text,
    required this.style,
  });

  final String text;
  final _AchievementThemeStyle style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: style.fontSize ?? 10.8,
      fontWeight: FontWeight.w800,
      fontFamily: style.fontFamily,
      letterSpacing: style.fontFamily != null ? 0.3 : 0.02,
      height: 1,
    );

    return Stack(
      children: [
        if (style.textStrokeColor != null)
          Text(
            text,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = style.textStrokeColor!,
              shadows: style.textShadows,
            ),
          ),
        Text(
          text,
          style: baseStyle.copyWith(
            color: style.textColor,
            shadows: style.textShadows,
          ),
        ),
      ],
    );
  }
}

enum _ProfileAchievementTheme {
  richieRich(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFFE6B85A),
        Color(0xFFF0B13A),
        Color(0xFFFFBF2F),
      ],
      badgeGradient: [
        Color(0xFFFFF0A6),
        Color(0xFFFFD84D),
        Color(0xFFFFC21A),
      ],
      badgeBorderColor: Color(0xFFE0AF1D),
      badgeInnerRingColor: Color(0x88EA580C),
      badgeIconColor: Color(0xFFEA580C),
      badgeShape: _AchievementBadgeShape.coin,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M2 4l3 12h14l3-12-6 7-4-7-4 7-6-7z"/></svg>',
      iconWidth: 11.2,
      iconHeight: 11.2,
    ),
  ),
  starsCatcher(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFF34447E),
        Color(0xFF5E4FA7),
        Color(0xFF88579D),
      ],
      badgeGradient: [
        Color(0xFFFFF5C8),
        Color(0xFFFFE288),
        Color(0xFFFFC95C),
      ],
      badgeBorderColor: Color(0xFFFFC769),
      badgeInnerRingColor: Color(0x88FFF8D7),
      badgeIconColor: Color(0xFFFDFCF7),
      badgeShape: _AchievementBadgeShape.star,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="none"><path d="M5.25 14.8c2.15-2.95 5.1-5.3 8.86-7.05" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><path d="M13.75 7.1l1.35-.15-.7 1.15" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/><path d="M7.7 9.4l.75 1.7 1.85.2-1.38 1.18.4 1.8-1.62-.95-1.62.95.4-1.8L5 11.3l1.85-.2.85-1.7z" fill="currentColor"/><path d="M15.9 11.35l.54 1.18 1.3.14-.97.83.28 1.27-1.15-.67-1.15.67.28-1.27-.97-.83 1.3-.14.54-1.18z" fill="currentColor" opacity=".82"/></svg>',
      iconWidth: 11.4,
      iconHeight: 11.4,
    ),
  ),
  soulmate(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFFF4C7DA),
        Color(0xFFF7D9E8),
        Color(0xFFF2CFE7),
      ],
      badgeGradient: [
        Color(0xFFFFECF5),
        Color(0xFFF8C8E3),
        Color(0xFFE8B3DC),
      ],
      badgeBorderColor: Color(0xFFB995D8),
      badgeInnerRingColor: Color(0x90FFF4FB),
      badgeIconColor: Color(0xFFFDFBFF),
      badgeShape: _AchievementBadgeShape.heart,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="none"><path d="M8.05 11.65c1.42 0 2.57-1.19 2.57-2.66S9.47 6.33 8.05 6.33 5.48 7.52 5.48 8.99s1.15 2.66 2.57 2.66z" fill="currentColor"/><path d="M15.95 11.65c1.42 0 2.57-1.19 2.57-2.66s-1.15-2.66-2.57-2.66-2.57 1.19-2.57 2.66 1.15 2.66 2.57 2.66z" fill="currentColor" opacity=".96"/><path d="M12 12.55c.82-1.02 1.98-1.62 3.22-1.62 2.12 0 3.83 1.74 3.83 3.88 0 .83-.28 1.56-.81 2.18L12 21.1l-6.24-4.11c-.53-.62-.81-1.35-.81-2.18 0-2.14 1.71-3.88 3.83-3.88 1.24 0 2.4.6 3.22 1.62z" fill="currentColor" opacity=".92"/><path d="M9.15 9.05c.24 0 .44-.2.44-.45s-.2-.45-.44-.45-.44.2-.44.45.2.45.44.45zm5.7 0c.24 0 .44-.2.44-.45s-.2-.45-.44-.45-.44.2-.44.45.2.45.44.45z" fill="#D2A4EC"/></svg>',
      iconWidth: 11.5,
      iconHeight: 11.5,
      textColor: Colors.white,
      textStrokeColor: Color(0xFFB68AD8),
      pillPattern: _AchievementPillPattern.soulmate,
    ),
  ),
  springHeraldPink(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFFFFCDE8),
        Color(0xFFFFA8D8),
        Color(0xFFFF85C2),
      ],
      pillBorderColor: Color(0x52FFFFFF),
      badgeScale: 1.0,
      pillPattern: _AchievementPillPattern.springHeraldPink,
      textColor: Colors.white,
      textStrokeColor: Color(0xFFF472B6),
      badgeShape: _AchievementBadgeShape.fairy,
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      iconWidth: 0,
      iconHeight: 0,
      iconSvg: '<svg viewBox="0 0 32 32" fill="none">'
          '  <!-- Wings -->'
          '  <!-- Left Wing Top -->'
          '  <path d="M13.5 15 C10.5 10.5, 3.5 10.5, 3.5 15 C3.5 18.5, 8.5 19.5, 13.5 16" fill="#FFB3D9" opacity="0.9"/>'
          '  <!-- Left Wing Bottom -->'
          '  <path d="M13.5 16.5 C10.5 19.5, 6.5 19.5, 6.5 17.5 C6.5 15.5, 10.5 15.5, 13.5 16.5" fill="#FFF0F5" opacity="0.7"/>'
          '  <!-- Right Wing Top -->'
          '  <path d="M18.5 15 C21.5 10.5, 28.5 10.5, 28.5 15 C28.5 18.5, 23.5 19.5, 18.5 16" fill="#FFB3D9" opacity="0.9"/>'
          '  <!-- Right Wing Bottom -->'
          '  <path d="M18.5 16.5 C21.5 19.5, 25.5 19.5, 25.5 17.5 C25.5 15.5, 21.5 15.5, 18.5 16.5" fill="#FFF0F5" opacity="0.7"/>'
          '  <!-- Legs -->'
          '  <rect x="13.8" y="22" width="1.2" height="3.2" rx="0.6" fill="#FFE5D9"/>'
          '  <rect x="17.0" y="22" width="1.2" height="3.2" rx="0.6" fill="#FFE5D9"/>'
          '  <!-- Feet -->'
          '  <path d="M13.8 25.2c-.3 0-.6-.2-.6-.5s.2-.5.5-.5h1c.3 0 .5.2.5.5s-.2.5-.5.5z" fill="#FFE5D9"/>'
          '  <path d="M17.0 25.2c-.3 0-.6-.2-.6-.5s.2-.5.5-.5h1c.3 0 .5.2.5.5s-.2.5-.5.5z" fill="#FFE5D9"/>'
          '  <!-- Dress/Skirt -->'
          '  <path d="M13.2 19 L11.5 23 C11.5 23.5, 12 24, 13 24 L19 24 C20 24, 20.5 23.5, 20.5 23 L18.8 19 Z" fill="#8DE8A4"/>'
          '  <!-- Grass at feet -->'
          '  <path d="M4 27 C10 24.5, 22 24.5, 28 27 C28 29, 4 29, 4 27 Z" fill="#32D74B" opacity="0.95"/>'
          '  <!-- Grass blades -->'
          '  <path d="M7 26.5 L8.5 22 L10 26.5" stroke="#1E8230" stroke-width="1.2" stroke-linecap="round"/>'
          '  <path d="M22 26.5 L23.5 22 L25 26.5" stroke="#1E8230" stroke-width="1.2" stroke-linecap="round"/>'
          '  <circle cx="10.5" cy="24.5" r="1.3" fill="#FFD700"/>'
          '  <circle cx="21.5" cy="24.5" r="1.3" fill="#FF69B4"/>'
          '  <!-- Head & Face -->'
          '  <circle cx="16" cy="14" r="5" fill="#FFE5D9"/>'
          '  <ellipse cx="13" cy="15.2" rx="1.1" ry="0.6" fill="#FFB3B3" opacity="0.75"/>'
          '  <ellipse cx="19" cy="15.2" rx="1.1" ry="0.6" fill="#FFB3B3" opacity="0.75"/>'
          '  <path d="M12.5 13.8 C13 14.5, 14 14.5, 14.5 13.8" stroke="#4A2F13" stroke-width="0.9" stroke-linecap="round" fill="none"/>'
          '  <path d="M17.5 13.8 C18 14.5, 19 14.5, 19.5 13.8" stroke="#4A2F13" stroke-width="0.9" stroke-linecap="round" fill="none"/>'
          '  <path d="M15.2 16.2 C15.6 16.9, 16.4 16.9, 16.8 16.2" stroke="#4A2F13" stroke-width="0.8" stroke-linecap="round" fill="none"/>'
          '  <!-- Hair -->'
          '  <path d="M10.8 14.5 C10.8 8.5, 21.2 8.5, 21.2 14.5" fill="#C084FC"/>'
          '  <path d="M11 13.5 C11 9, 21 9, 21 13.5 C21 13.8, 20.5 14, 20 14 C19 12, 17 11.5, 16 11.5 C15 11.5, 13 12, 12 14 C11.5 14, 11 13.8, 11 13.5 Z" fill="#C084FC"/>'
          '  <path d="M11 13 L9.5 16.5 C9.2 17, 9.8 17.5, 10.5 17 L11.5 15 Z" fill="#C084FC"/>'
          '  <path d="M21 13 L22.5 16.5 C22.8 17, 22.2 17.5, 21.5 17 L20.5 15 Z" fill="#C084FC"/>'
          '  <!-- Crown -->'
          '  <path d="M16 8.5 L17 10 L18.5 10 L17.3 11 L17.8 12.5 L16 11.5 L14.2 12.5 L14.7 11 L13.5 10 L15 10 Z" fill="#FFD700"/>'
          '</svg>',
    ),
  ),
  springHeraldPurple(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFFBEA6FF),
        Color(0xFF9E77FF),
        Color(0xFF7E4FFF),
      ],
      pillBorderColor: Color(0x52FFFFFF),
      badgeScale: 1.0,
      pillPattern: _AchievementPillPattern.springHeraldPurple,
      textColor: Colors.white,
      textStrokeColor: Color(0xFFA855F7),
      badgeShape: _AchievementBadgeShape.fairy,
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      iconWidth: 0,
      iconHeight: 0,
      iconSvg: '<svg viewBox="0 0 32 32" fill="none">'
          '  <!-- Wings -->'
          '  <!-- Left Wing Top -->'
          '  <path d="M13.5 15 C10.5 10.5, 3.5 10.5, 3.5 15 C3.5 18.5, 8.5 19.5, 13.5 16" fill="#A5F3FC" opacity="0.9"/>'
          '  <!-- Left Wing Bottom -->'
          '  <path d="M13.5 16.5 C10.5 19.5, 6.5 19.5, 6.5 17.5 C6.5 15.5, 10.5 15.5, 13.5 16.5" fill="#ECFEFF" opacity="0.7"/>'
          '  <!-- Right Wing Top -->'
          '  <path d="M18.5 15 C21.5 10.5, 28.5 10.5, 28.5 15 C28.5 18.5, 23.5 19.5, 18.5 16" fill="#A5F3FC" opacity="0.9"/>'
          '  <!-- Right Wing Bottom -->'
          '  <path d="M18.5 16.5 C21.5 19.5, 25.5 19.5, 25.5 17.5 C25.5 15.5, 21.5 15.5, 18.5 16.5" fill="#ECFEFF" opacity="0.7"/>'
          '  <!-- Legs -->'
          '  <rect x="13.8" y="22" width="1.2" height="3.2" rx="0.6" fill="#FFE5D9"/>'
          '  <rect x="17.0" y="22" width="1.2" height="3.2" rx="0.6" fill="#FFE5D9"/>'
          '  <!-- Feet -->'
          '  <path d="M13.8 25.2c-.3 0-.6-.2-.6-.5s.2-.5.5-.5h1c.3 0 .5.2.5.5s-.2.5-.5.5z" fill="#FFE5D9"/>'
          '  <path d="M17.0 25.2c-.3 0-.6-.2-.6-.5s.2-.5.5-.5h1c.3 0 .5.2.5.5s-.2.5-.5.5z" fill="#FFE5D9"/>'
          '  <!-- Dress/Skirt -->'
          '  <path d="M13.2 19 L11.5 23 C11.5 23.5, 12 24, 13 24 L19 24 C20 24, 20.5 23.5, 20.5 23 L18.8 19 Z" fill="#FF8DA1"/>'
          '  <!-- Grass at feet -->'
          '  <path d="M4 27 C10 24.5, 22 24.5, 28 27 C28 29, 4 29, 4 27 Z" fill="#32D74B" opacity="0.95"/>'
          '  <!-- Grass blades -->'
          '  <path d="M7 26.5 L8.5 22 L10 26.5" stroke="#1E8230" stroke-width="1.2" stroke-linecap="round"/>'
          '  <path d="M22 26.5 L23.5 22 L25 26.5" stroke="#1E8230" stroke-width="1.2" stroke-linecap="round"/>'
          '  <circle cx="10.5" cy="24.5" r="1.3" fill="#A855F7"/>'
          '  <circle cx="21.5" cy="24.5" r="1.3" fill="#EB5757"/>'
          '  <!-- Head & Face -->'
          '  <circle cx="16" cy="14" r="5" fill="#FFE5D9"/>'
          '  <ellipse cx="13" cy="15.2" rx="1.1" ry="0.6" fill="#FFB3B3" opacity="0.75"/>'
          '  <ellipse cx="19" cy="15.2" rx="1.1" ry="0.6" fill="#FFB3B3" opacity="0.75"/>'
          '  <path d="M12.5 13.8 C13 14.5, 14 14.5, 14.5 13.8" stroke="#4A2F13" stroke-width="0.9" stroke-linecap="round" fill="none"/>'
          '  <path d="M17.5 13.8 C18 14.5, 19 14.5, 19.5 13.8" stroke="#4A2F13" stroke-width="0.9" stroke-linecap="round" fill="none"/>'
          '  <path d="M15.2 16.2 C15.6 16.9, 16.4 16.9, 16.8 16.2" stroke="#4A2F13" stroke-width="0.8" stroke-linecap="round" fill="none"/>'
          '  <!-- Hair -->'
          '  <path d="M10.8 14.5 C10.8 8.5, 21.2 8.5, 21.2 14.5" fill="#38BDF8"/>'
          '  <path d="M11 13.5 C11 9, 21 9, 21 13.5 C21 13.8, 20.5 14, 20 14 C19 12, 17 11.5, 16 11.5 C15 11.5, 13 12, 12 14 C11.5 14, 11 13.8, 11 13.5 Z" fill="#38BDF8"/>'
          '  <path d="M11 13 L9.5 16.5 C9.2 17, 9.8 17.5, 10.5 17 L11.5 15 Z" fill="#38BDF8"/>'
          '  <path d="M21 13 L22.5 16.5 C22.8 17, 22.2 17.5, 21.5 17 L20.5 15 Z" fill="#38BDF8"/>'
          '  <!-- Crown -->'
          '  <path d="M16 8.5 L17 10 L18.5 10 L17.3 11 L17.8 12.5 L16 11.5 L14.2 12.5 L14.7 11 L13.5 10 L15 10 Z" fill="#FFD700"/>'
          '</svg>',
    ),
  ),
  springHeraldBlue(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFF70C9FF),
        Color(0xFF3B9EFF),
        Color(0xFF1E80F5),
      ],
      pillBorderColor: Color(0x52FFFFFF),
      badgeScale: 1.0,
      pillPattern: _AchievementPillPattern.springHeraldBlue,
      textColor: Colors.white,
      textStrokeColor: Color(0xFF1B75E0),
      badgeShape: _AchievementBadgeShape.fairy,
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      iconWidth: 0,
      iconHeight: 0,
      iconSvg: '<svg viewBox="0 0 32 32" fill="none">'
          '  <!-- Wings -->'
          '  <!-- Left Wing Top -->'
          '  <path d="M13.5 15 C10.5 10.5, 3.5 10.5, 3.5 15 C3.5 18.5, 8.5 19.5, 13.5 16" fill="#F472B6" opacity="0.9"/>'
          '  <!-- Left Wing Bottom -->'
          '  <path d="M13.5 16.5 C10.5 19.5, 6.5 19.5, 6.5 17.5 C6.5 15.5, 10.5 15.5, 13.5 16.5" fill="#FDF2F8" opacity="0.7"/>'
          '  <!-- Right Wing Top -->'
          '  <path d="M18.5 15 C21.5 10.5, 28.5 10.5, 28.5 15 C28.5 18.5, 23.5 19.5, 18.5 16" fill="#F472B6" opacity="0.9"/>'
          '  <!-- Right Wing Bottom -->'
          '  <path d="M18.5 16.5 C21.5 19.5, 25.5 19.5, 25.5 17.5 C25.5 15.5, 21.5 15.5, 18.5 16.5" fill="#FDF2F8" opacity="0.7"/>'
          '  <!-- Legs -->'
          '  <rect x="13.8" y="22" width="1.2" height="3.2" rx="0.6" fill="#FFE5D9"/>'
          '  <rect x="17.0" y="22" width="1.2" height="3.2" rx="0.6" fill="#FFE5D9"/>'
          '  <!-- Feet -->'
          '  <path d="M13.8 25.2c-.3 0-.6-.2-.6-.5s.2-.5.5-.5h1c.3 0 .5.2.5.5s-.2.5-.5.5z" fill="#FFE5D9"/>'
          '  <path d="M17.0 25.2c-.3 0-.6-.2-.6-.5s.2-.5.5-.5h1c.3 0 .5.2.5.5s-.2.5-.5.5z" fill="#FFE5D9"/>'
          '  <!-- Dress/Skirt -->'
          '  <path d="M13.2 19 L11.5 23 C11.5 23.5, 12 24, 13 24 L19 24 C20 24, 20.5 23.5, 20.5 23 L18.8 19 Z" fill="#FDE047"/>'
          '  <!-- Grass at feet -->'
          '  <path d="M4 27 C10 24.5, 22 24.5, 28 27 C28 29, 4 29, 4 27 Z" fill="#32D74B" opacity="0.95"/>'
          '  <!-- Grass blades -->'
          '  <path d="M7 26.5 L8.5 22 L10 26.5" stroke="#1E8230" stroke-width="1.2" stroke-linecap="round"/>'
          '  <path d="M22 26.5 L23.5 22 L25 26.5" stroke="#1E8230" stroke-width="1.2" stroke-linecap="round"/>'
          '  <circle cx="10.5" cy="24.5" r="1.3" fill="#22C55E"/>'
          '  <circle cx="21.5" cy="24.5" r="1.3" fill="#3B82F6"/>'
          '  <!-- Head & Face -->'
          '  <circle cx="16" cy="14" r="5" fill="#FFE5D9"/>'
          '  <ellipse cx="13" cy="15.2" rx="1.1" ry="0.6" fill="#FFB3B3" opacity="0.75"/>'
          '  <ellipse cx="19" cy="15.2" rx="1.1" ry="0.6" fill="#FFB3B3" opacity="0.75"/>'
          '  <path d="M12.5 13.8 C13 14.5, 14 14.5, 14.5 13.8" stroke="#4A2F13" stroke-width="0.9" stroke-linecap="round" fill="none"/>'
          '  <path d="M17.5 13.8 C18 14.5, 19 14.5, 19.5 13.8" stroke="#4A2F13" stroke-width="0.9" stroke-linecap="round" fill="none"/>'
          '  <path d="M15.2 16.2 C15.6 16.9, 16.4 16.9, 16.8 16.2" stroke="#4A2F13" stroke-width="0.8" stroke-linecap="round" fill="none"/>'
          '  <!-- Hair -->'
          '  <path d="M10.8 14.5 C10.8 8.5, 21.2 8.5, 21.2 14.5" fill="#22D3EE"/>'
          '  <path d="M11 13.5 C11 9, 21 9, 21 13.5 C21 13.8, 20.5 14, 20 14 C19 12, 17 11.5, 16 11.5 C15 11.5, 13 12, 12 14 C11.5 14, 11 13.8, 11 13.5 Z" fill="#22D3EE"/>'
          '  <path d="M11 13 L9.5 16.5 C9.2 17, 9.8 17.5, 10.5 17 L11.5 15 Z" fill="#22D3EE"/>'
          '  <path d="M21 13 L22.5 16.5 C22.8 17, 22.2 17.5, 21.5 17 L20.5 15 Z" fill="#22D3EE"/>'
          '  <!-- Crown -->'
          '  <path d="M16 8.5 L17 10 L18.5 10 L17.3 11 L17.8 12.5 L16 11.5 L14.2 12.5 L14.7 11 L13.5 10 L15 10 Z" fill="#FFD700"/>'
          '</svg>',
    ),
  ),
  supremeWarlord(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFF3B0606),
        Color(0xFF611111),
        Color(0xFF260303),
      ],
      pillBorderColor: Color(0x66FF7A3C),
      badgeScale: 1.08,
      pillPattern: _AchievementPillPattern.supremeWarlord,
      textColor: Color(0xFFFFF6EA),
      textStrokeColor: Color(0xFF6E0C0C),
      badgeShape: _AchievementBadgeShape.warlord,
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      iconWidth: 0,
      iconHeight: 0,
      iconSvg: '<svg viewBox="0 0 32 32" fill="none">'
          '  <path d="M10.8 5.5L16 3l5.2 2.5 1.8 6.7-3.5 9.8H12.5L9 12.2l1.8-6.7z" fill="#111318"/>'
          '  <path d="M12.6 7.2L16 5.7l3.4 1.5 1.2 4.8-2.4 7.2h-4.4L11.4 12l1.2-4.8z" fill="#202630"/>'
          '  <path d="M9.8 8.2l2.9 2.4 1.5-3.9-4.4 1.5z" fill="#A91D1D"/>'
          '  <path d="M22.2 8.2l-2.9 2.4-1.5-3.9 4.4 1.5z" fill="#A91D1D"/>'
          '  <path d="M12.7 10.7h6.6l-1.1 7.3h-4.4l-1.1-7.3z" fill="#2C0C0C"/>'
          '  <path d="M13.5 14.2l2.5-1 2.5 1-1.1 2.5h-2.8l-1.1-2.5z" fill="#F6B11A"/>'
          '  <path d="M12.4 21.2h7.2v1.8h-7.2z" fill="#3A0D0D"/>'
          '  <path d="M12.2 4.7L16 3l3.8 1.7-1.4 1.3h-5l-1.2-1.3z" fill="#6A707C"/>'
          '  <circle cx="14.3" cy="12.3" r="0.72" fill="#FF6C34"/>'
          '  <circle cx="17.7" cy="12.3" r="0.72" fill="#FF6C34"/>'
          '  <path d="M14.7 14.8h2.6" stroke="#FF9A2F" stroke-width="1.1" stroke-linecap="round"/>'
          '</svg>',
    ),
  ),
  techSupport(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFF131314),
        Color(0xFF1E1E20),
        Color(0xFF131314),
      ],
      pillBorderColor: Color(0xFF4285F4),
      badgeScale: 1.16,
      textColor: Colors.white,
      textStrokeColor: Color(0x4DEA4335),
      badgeShape: _AchievementBadgeShape.fairy,
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="11.5" fill="white" stroke="#E0E0E0" stroke-width="0.5"/><path d="M21.35 11.1h-9.17v2.73h6.51c-.33 1.56-1.56 2.95-3.24 3.51v2.9h5.18c3.07-2.83 4.83-7 4.83-11.97 0-.75-.08-1.46-.23-2.17z" fill="#4285F4"/><path d="M12.18 20.5c3.08 0 5.67-1.02 7.56-2.77l-5.18-2.9c-1.42.97-3.24 1.54-5.32 1.54-4.1 0-7.57-2.77-8.81-6.5H.61v3a11.99 11.99 0 0011.57 7.63z" fill="#34A853"/><path d="M3.37 12.37a7.16 7.16 0 010-2.24V7.13H.61a11.98 11.98 0 000 10.49l2.76-2.25v-3z" fill="#FBBC05"/><path d="M12.18 6.27c2.08 0 3.95.72 5.42 2.12l4.07-4.07C19.18 1.95 15.93 1 12.18 1A11.99 11.99 0 00.61 7.13l2.76 3c1.24-3.73 4.71-6.5 8.81-6.5z" fill="#EA4335"/></svg>',
      iconWidth: 0,
      iconHeight: 0,
    ),
  ),
  googleWorkspace(
    _AchievementThemeStyle(
      pillColors: [Colors.transparent],
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      badgeShape: _AchievementBadgeShape.fairy,
      iconSvg: '',
      iconWidth: 0,
      iconHeight: 0,
    ),
  ),
  popSuperstar(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFF2563EB),
        Color(0xFF6D28D9),
        Color(0xFF8B5CF6),
      ],
      badgeGradient: [
        Color(0xFF93C5FD),
        Color(0xFFC084FC),
        Color(0xFFE9D5FF),
      ],
      badgeBorderColor: Color(0xFFA78BFA),
      badgeInnerRingColor: Color(0x553B82F6),
      badgeIconColor: Colors.white,
      badgeShape: _AchievementBadgeShape.coin,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" fill="currentColor"/><path d="M19 10v1a7 7 0 0 1-14 0v-1"/><line x1="12" x2="12" y1="18" y2="21"/><line x1="9" y1="21" x2="15" y2="21"/></svg>',
      iconWidth: 11.5,
      iconHeight: 11.5,
      textColor: Colors.white,
      textStrokeColor: Color(0xFFC084FC),
      textShadows: [
        Shadow(
          color: Color(0xFFC084FC),
          blurRadius: 5.0,
        ),
        Shadow(
          color: Color(0xFF3B82F6),
          blurRadius: 10.0,
        ),
      ],
    ),
  ),
  freshPaw(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFF10B981),
        Color(0xFF059669),
        Color(0xFF06B6D4),
      ],
      badgeGradient: [
        Color(0xFFD1FAE5),
        Color(0xFF6EE7B7),
        Color(0xFF34D399),
      ],
      badgeBorderColor: Color(0xFF059669),
      badgeInnerRingColor: Color(0x33047857),
      badgeIconColor: Color(0xFF047857),
      badgeShape: _AchievementBadgeShape.coin,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="7.5" cy="7.5" r="2.0"/><circle cx="10.5" cy="5.0" r="2.0"/><circle cx="14.5" cy="5.0" r="2.0"/><circle cx="17.5" cy="7.5" r="2.0"/><path d="M12 10.5c-3 0-5 2-5 4.5s2 4.5 5 4.5 5-2 5-4.5-2-4.5-5-4.5z"/></svg>',
      iconWidth: 11.5,
      iconHeight: 11.5,
      textColor: Colors.white,
      textStrokeColor: Color(0xFF047857),
    ),
  ),
  risingPaw(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFFFF5E36),
        Color(0xFFFFAE33),
        Color(0xFFFEDB37),
      ],
      badgeGradient: [
        Color(0xFFFFFBEB),
        Color(0xFFFEF3C7),
        Color(0xFFFDE68A),
      ],
      badgeBorderColor: Color(0xFFEA580C),
      badgeInnerRingColor: Color(0x66F97316),
      badgeIconColor: Color(0xFFEA580C),
      badgeShape: _AchievementBadgeShape.coin,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.64 5.64l1.41 1.41M16.95 16.95l1.41 1.41M18.36 5.64l-1.41 1.41M7.05 16.95l-1.41 1.41" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="8.5" cy="11.5" r="1.2"/><circle cx="10.8" cy="9.5" r="1.2"/><circle cx="13.2" cy="9.5" r="1.2"/><circle cx="15.5" cy="11.5" r="1.2"/><path d="M12 12.8c-1.8 0-3 1.2-3 2.7s1.2 2.7 3 2.7 3-1.2 3-2.7-1.2-2.7-3-2.7z"/></svg>',
      iconWidth: 12.0,
      iconHeight: 12.0,
      textColor: Colors.white,
      textStrokeColor: Color(0xFFC2410C),
    ),
  ),
  top50(
    _AchievementThemeStyle(
      pillColors: [
        Color(0xFFFF8C00),
        Color(0xFFFF5E3A),
        Color(0xFFFF2A00),
      ],
      badgeGradient: [
        Color(0xFFFF9F43),
        Color(0xFFFF5E3A),
      ],
      badgeBorderColor: Color(0xFFFF5E3A),
      badgeInnerRingColor: Color(0xFFFFE5B4),
      badgeIconColor: Colors.white,
      badgeShape: _AchievementBadgeShape.pixel,
      iconSvg:
          '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>',
      iconWidth: 12.0,
      iconHeight: 12.0,
      textColor: Colors.white,
      textStrokeColor: const Color(0xFFC2410C),
      fontFamily: 'monospace',
      fontSize: 11.2,
      textShadows: const [
        Shadow(
          color: Color(0xFFFF8C00),
          blurRadius: 4.0,
          offset: Offset(0, 0),
        ),
        Shadow(
          color: Color(0xFFFF2A00),
          blurRadius: 10.0,
          offset: Offset(0, 0),
        ),
      ],
    ),
  ),
  assetPreview(
    _AchievementThemeStyle(
      pillColors: [Colors.transparent],
      badgeGradient: [Colors.transparent],
      badgeBorderColor: Colors.transparent,
      badgeInnerRingColor: Colors.transparent,
      badgeIconColor: Colors.transparent,
      badgeShape: _AchievementBadgeShape.coin,
      iconSvg: '',
      iconWidth: 0,
      iconHeight: 0,
      assetPillPath: 'assets/images/achievement_pill_preview_v1_trimmed.png',
    ),
  );

  const _ProfileAchievementTheme(this.style);

  final _AchievementThemeStyle style;
}

enum _AchievementBadgeShape { coin, star, heart, fairy, warlord, pixel }

enum _AchievementPillPattern {
  none,
  soulmate,
  springHeraldPink,
  springHeraldPurple,
  springHeraldBlue,
  supremeWarlord,
}

class _AchievementThemeStyle {
  const _AchievementThemeStyle({
    required this.pillColors,
    required this.badgeGradient,
    required this.badgeBorderColor,
    required this.badgeInnerRingColor,
    required this.badgeIconColor,
    required this.badgeShape,
    required this.iconSvg,
    required this.iconWidth,
    required this.iconHeight,
    this.textColor = Colors.white,
    this.textStrokeColor,
    this.pillPattern = _AchievementPillPattern.none,
    this.pillBorderColor,
    this.badgeScale = 1.16,
    this.assetPillPath,
    this.textShadows,
    this.fontFamily,
    this.fontSize,
  });

  final List<Color> pillColors;
  final List<Color> badgeGradient;
  final Color badgeBorderColor;
  final Color badgeInnerRingColor;
  final Color badgeIconColor;
  final _AchievementBadgeShape badgeShape;
  final String iconSvg;
  final double iconWidth;
  final double iconHeight;
  final Color textColor;
  final Color? textStrokeColor;
  final _AchievementPillPattern pillPattern;
  final Color? pillBorderColor;
  final double badgeScale;
  final String? assetPillPath;
  final List<Shadow>? textShadows;
  final String? fontFamily;
  final double? fontSize;
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.animation,
    required this.motionAnimation,
    required this.theme,
  });

  final Animation<double> animation;
  final Animation<double> motionAnimation;
  final _ProfileAchievementTheme theme;

  @override
  Widget build(BuildContext context) {
    final style = theme.style;
    final isSpringHerald = theme == _ProfileAchievementTheme.springHeraldPink ||
        theme == _ProfileAchievementTheme.springHeraldPurple ||
        theme == _ProfileAchievementTheme.springHeraldBlue;
    final isSupremeWarlord = theme == _ProfileAchievementTheme.supremeWarlord;
    final isTop50 = theme == _ProfileAchievementTheme.top50;

    return SizedBox(
      width: 19,
      height: 19,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: isSpringHerald ? -8.5 : (isTop50 ? -8.0 : (isSupremeWarlord ? -1.0 : 0)),
            right: isSpringHerald ? -4.5 : (isTop50 ? -4.0 : (isSupremeWarlord ? -1.0 : 0)),
            top: isSpringHerald ? -7.0 : (isTop50 ? -9.0 : (isSupremeWarlord ? -1.5 : 0)),
            bottom: isSpringHerald ? -6.0 : (isTop50 ? -5.0 : (isSupremeWarlord ? -0.5 : 0)),
            child: switch (style.badgeShape) {
              _AchievementBadgeShape.coin => Transform.scale(
                  scale: style.badgeScale,
                  child: _CoinAchievementFace(style: style),
                ),
              _AchievementBadgeShape.star => Transform.scale(
                  scale: style.badgeScale,
                  child: _StarAchievementFace(style: style),
                ),
              _AchievementBadgeShape.heart => Transform.scale(
                  scale: style.badgeScale,
                  child: _HeartAchievementFace(style: style),
                ),
              _AchievementBadgeShape.fairy =>
                _FairyAchievementFace(style: style),
              _AchievementBadgeShape.warlord => _WarlordAchievementFace(
                  style: style,
                  animation: motionAnimation,
                ),
              _AchievementBadgeShape.pixel => AnimatedBuilder(
                  animation: motionAnimation,
                  builder: (context, child) {
                    final floatOffset = math.sin(motionAnimation.value * 2 * math.pi) * 2.2;
                    return Transform.translate(
                      offset: Offset(0, floatOffset - 3.5),
                      child: Transform.scale(
                        scale: style.badgeScale * 1.22,
                        child: child,
                      ),
                    );
                  },
                  child: _PixelAchievementFace(style: style),
                ),
            },
          ),
          Positioned(
            left: isSpringHerald ? -0.5 : -2.8,
            top: isSpringHerald ? 0.0 : -2.4,
            child: _BlinkStarSpark(
              animation: animation,
              size: 7.4,
              color: isSpringHerald ? const Color(0xFFFFD700) : Colors.white,
              shadowColor: isSpringHerald
                  ? const Color(0x80FFA000)
                  : const Color(0x80D9D9D9),
            ),
          ),
          Positioned(
            right: isSpringHerald ? 4.5 : -2.8,
            top: isSpringHerald ? 1.0 : null,
            bottom: isSpringHerald ? null : -2.8,
            child: _BlinkStarSpark(
              animation: animation,
              size: 7.6,
              color: isSpringHerald ? const Color(0xFFFFD700) : Colors.white,
              shadowColor: isSpringHerald
                  ? const Color(0x80FFA000)
                  : const Color(0x80D9D9D9),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinAchievementFace extends StatelessWidget {
  const _CoinAchievementFace({required this.style});

  final _AchievementThemeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.badgeGradient,
        ),
        border: Border.all(
          color: style.badgeBorderColor,
          width: 0.65,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 13.6,
                height: 13.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: style.badgeInnerRingColor,
                    width: 0.85,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SvgPicture.string(
              style.iconSvg,
              width: style.iconWidth,
              height: style.iconHeight,
              colorFilter: ColorFilter.mode(
                style.badgeIconColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarAchievementFace extends StatelessWidget {
  const _StarAchievementFace({required this.style});

  final _AchievementThemeStyle style;

  static const String _starShellSvg =
      '<svg viewBox="0 0 24 24" fill="none"><path d="M12 1.9l2.1 5.6 5.95.62-4.55 3.95 1.38 5.75L12 15.07 7.12 17.82 8.5 12.07 3.95 8.12l5.95-.62L12 1.9z" fill="url(#g1)" stroke="url(#g2)" stroke-width="1.15"/><defs><linearGradient id="g1" x1="4.5" y1="3.5" x2="18.8" y2="19.2" gradientUnits="userSpaceOnUse"><stop stop-color="#FFF6D3"/><stop offset=".48" stop-color="#FFE38E"/><stop offset="1" stop-color="#FFC45E"/></linearGradient><linearGradient id="g2" x1="6" y1="4" x2="18" y2="18" gradientUnits="userSpaceOnUse"><stop stop-color="#FFF2C2"/><stop offset="1" stop-color="#F2A745"/></linearGradient></defs></svg>';

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.string(
          _starShellSvg,
          width: 19,
          height: 19,
        ),
        SizedBox(
          width: 14.2,
          height: 14.2,
          child: SvgPicture.string(
            style.iconSvg,
            colorFilter: ColorFilter.mode(
              style.badgeIconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeartAchievementFace extends StatelessWidget {
  const _HeartAchievementFace({required this.style});

  final _AchievementThemeStyle style;

  static const String _heartShellSvg =
      '<svg viewBox="0 0 24 24" fill="none"><path d="M12 21.15l-1.25-.74C4.6 16.8 1.2 13.78 1.2 9.95 1.2 6.94 3.57 4.65 6.5 4.65c2.05 0 3.48.98 4.31 2.2.83-1.22 2.26-2.2 4.31-2.2 2.92 0 5.3 2.29 5.3 5.3 0 3.83-3.4 6.85-9.55 10.46L12 21.15z" fill="url(#g1)" stroke="url(#g2)" stroke-width="1.15"/><path d="M12 18.1l-.85-.5C6.52 14.94 3.95 12.6 3.95 9.8c0-1.88 1.45-3.25 3.1-3.25 1.48 0 2.48.7 3.12 1.76.64-1.06 1.64-1.76 3.12-1.76 1.65 0 3.1 1.37 3.1 3.25 0 2.8-2.57 5.14-7.2 7.8L12 18.1z" stroke="#FFF7FC" stroke-opacity=".78" stroke-width=".9"/><defs><linearGradient id="g1" x1="4.5" y1="5" x2="18.9" y2="18.6" gradientUnits="userSpaceOnUse"><stop stop-color="#FFF5FB"/><stop offset=".52" stop-color="#F8CEE5"/><stop offset="1" stop-color="#E7A9D1"/></linearGradient><linearGradient id="g2" x1="5.5" y1="5" x2="18.2" y2="18" gradientUnits="userSpaceOnUse"><stop stop-color="#E2B6F1"/><stop offset="1" stop-color="#A778D6"/></linearGradient></defs></svg>';

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.string(
          _heartShellSvg,
          width: 19,
          height: 19,
        ),
        SizedBox(
          width: 14.0,
          height: 14.0,
          child: SvgPicture.string(
            style.iconSvg,
            colorFilter: ColorFilter.mode(
              style.badgeIconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoulmatePillPattern extends StatelessWidget {
  const _SoulmatePillPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 1,
            child: Icon(
              Icons.favorite_rounded,
              size: 8,
              color: Color(0x26FFFFFF),
            ),
          ),
          Positioned(
            right: 7,
            top: -1,
            child: Icon(
              Icons.favorite_rounded,
              size: 7,
              color: Color(0x30B68AD8),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x18FFFFFF),
              ),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 2,
            child: Icon(
              Icons.circle,
              size: 3.8,
              color: Color(0x30FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _FairyAchievementFace extends StatelessWidget {
  const _FairyAchievementFace({required this.style});

  final _AchievementThemeStyle style;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      style.iconSvg,
      fit: BoxFit.contain,
    );
  }
}

class _WarlordAchievementFace extends StatelessWidget {
  const _WarlordAchievementFace({
    required this.style,
    required this.animation,
  });

  final _AchievementThemeStyle style;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final phase = animation.value * math.pi * 2;
        final bob = math.sin(phase) * 0.9;
        final tilt = math.sin(phase * 0.6) * 0.055;
        final glow = 0.38 + (((math.sin(phase * 1.4) + 1) / 2) * 0.34);
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 2,
                  right: 2,
                  bottom: 0,
                  top: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF6B1A).withValues(alpha: glow),
                          blurRadius: 9,
                          spreadRadius: 1.1,
                        ),
                        BoxShadow(
                          color: const Color(0xFFB01212)
                              .withValues(alpha: glow * 0.75),
                          blurRadius: 13,
                          spreadRadius: 1.6,
                        ),
                      ],
                    ),
                  ),
                ),
                child!,
                Positioned(
                  top: -1.6,
                  child: Icon(
                    Icons.keyboard_double_arrow_up_rounded,
                    size: 7.2,
                    color: const Color(0xFFFFB347)
                        .withValues(alpha: 0.55 + glow * 0.55),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: SvgPicture.string(
        style.iconSvg,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _WarlordFireBand extends StatelessWidget {
  const _WarlordFireBand({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final phase = animation.value * math.pi * 2;
          final drift = math.sin(phase * 0.9) * 7;
          final sway = math.cos((phase * 1.15) + 0.5) * 5;
          final frontPulse = 0.68 + (((math.sin(phase * 1.8) + 1) / 2) * 0.28);
          final backPulse =
              0.34 + (((math.sin((phase * 1.2) + 1.4) + 1) / 2) * 0.22);

          Widget flameTongue({
            required double left,
            required double width,
            required double height,
            required double bottom,
            required double tilt,
            required List<Color> colors,
            required List<double> stops,
            double opacity = 1,
            double blur = 0,
          }) {
            Widget tongue = Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(width * 0.42, height * 0.88),
                  topRight: Radius.elliptical(width * 0.42, height * 0.88),
                  bottomLeft: Radius.elliptical(width * 0.24, height * 0.28),
                  bottomRight: Radius.elliptical(width * 0.24, height * 0.28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors:
                      colors.map((c) => c.withValues(alpha: opacity)).toList(),
                  stops: stops,
                ),
                boxShadow: blur > 0
                    ? [
                        BoxShadow(
                          color: colors.first.withValues(alpha: opacity * 0.55),
                          blurRadius: blur,
                          spreadRadius: 0.2,
                        ),
                      ]
                    : null,
              ),
            );

            return Positioned(
              left: left,
              bottom: bottom,
              child: Transform.rotate(
                angle: tilt,
                alignment: Alignment.bottomCenter,
                child: tongue,
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -22 + drift,
                right: -16 - drift,
                bottom: -7,
                height: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0x80610A05).withValues(alpha: backPulse),
                        const Color(0xFF170202),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E0202).withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: -18 + sway,
                right: -12 - sway,
                bottom: -5,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0x8BFF7A12)
                            .withValues(alpha: backPulse + 0.08),
                        const Color(0xF3E02E05),
                      ],
                      stops: const [0.0, 0.38, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xCCFF5A1F)
                            .withValues(alpha: backPulse + 0.18),
                        blurRadius: 16,
                        spreadRadius: 2.4,
                      ),
                    ],
                  ),
                ),
              ),
              flameTongue(
                left: 6 + drift,
                width: 12,
                height: 14 + (((math.sin(phase * 1.6) + 1) / 2) * 2.6),
                bottom: -2.2,
                tilt: -0.26,
                colors: const [
                  Color(0xFFFF5E16),
                  Color(0xFFFFA31F),
                  Color(0xFFFFE08A),
                ],
                stops: const [0.0, 0.52, 1.0],
                opacity: frontPulse,
                blur: 9,
              ),
              flameTongue(
                left: 18 + (sway * 0.85),
                width: 10.5,
                height:
                    12.8 + (((math.sin((phase * 1.4) + 0.7) + 1) / 2) * 2.8),
                bottom: -1.8,
                tilt: 0.1,
                colors: const [
                  Color(0xFFFF4B0B),
                  Color(0xFFFF8B16),
                  Color(0xFFFFDB73),
                ],
                stops: const [0.0, 0.56, 1.0],
                opacity: frontPulse,
                blur: 8,
              ),
              flameTongue(
                left: 29 + (drift * 0.55),
                width: 13.5,
                height:
                    15.5 + (((math.sin((phase * 1.9) + 1.4) + 1) / 2) * 2.4),
                bottom: -2.4,
                tilt: -0.08,
                colors: const [
                  Color(0xFFFF5C0F),
                  Color(0xFFFFB01B),
                  Color(0xFFFFF0A5),
                ],
                stops: const [0.0, 0.5, 1.0],
                opacity: frontPulse,
                blur: 10,
              ),
              flameTongue(
                left: 43 + (sway * 0.7),
                width: 11.5,
                height:
                    13.2 + (((math.sin((phase * 1.5) + 2.2) + 1) / 2) * 2.6),
                bottom: -1.5,
                tilt: 0.2,
                colors: const [
                  Color(0xFFFF4613),
                  Color(0xFFFF9121),
                  Color(0xFFFFDC7F),
                ],
                stops: const [0.0, 0.56, 1.0],
                opacity: frontPulse,
                blur: 8,
              ),
              flameTongue(
                left: 56 + (drift * 0.38),
                width: 13,
                height: 15 + (((math.sin((phase * 1.7) + 2.8) + 1) / 2) * 2.5),
                bottom: -2.1,
                tilt: -0.14,
                colors: const [
                  Color(0xFFFF5A11),
                  Color(0xFFFFAF22),
                  Color(0xFFFFED9A),
                ],
                stops: const [0.0, 0.52, 1.0],
                opacity: frontPulse,
                blur: 9,
              ),
              flameTongue(
                left: 69 + (sway * 0.28),
                width: 10,
                height:
                    11.8 + (((math.sin((phase * 1.25) + 3.2) + 1) / 2) * 2.2),
                bottom: -1.4,
                tilt: 0.18,
                colors: const [
                  Color(0xFFFF480F),
                  Color(0xFFFF8D1D),
                  Color(0xFFFFD973),
                ],
                stops: const [0.0, 0.58, 1.0],
                opacity: frontPulse,
                blur: 8,
              ),
              flameTongue(
                left: 11 + drift,
                width: 5.2,
                height: 8.5,
                bottom: 1.2,
                tilt: -0.12,
                colors: const [
                  Color(0xFFFFF1B3),
                  Color(0xFFFFC13B),
                  Color(0x00FFF1B3),
                ],
                stops: const [0.0, 0.46, 1.0],
                opacity: 0.74 + (((math.sin(phase * 2.3) + 1) / 2) * 0.18),
                blur: 4,
              ),
              flameTongue(
                left: 35 + sway,
                width: 5.8,
                height: 9.2,
                bottom: 1.0,
                tilt: 0.08,
                colors: const [
                  Color(0xFFFFF0B0),
                  Color(0xFFFFC84A),
                  Color(0x00FFF0B0),
                ],
                stops: const [0.0, 0.45, 1.0],
                opacity:
                    0.72 + (((math.sin((phase * 2.1) + 1.1) + 1) / 2) * 0.2),
                blur: 4,
              ),
              flameTongue(
                left: 60 + (drift * 0.3),
                width: 5.4,
                height: 8.4,
                bottom: 1.4,
                tilt: -0.06,
                colors: const [
                  Color(0xFFFFEBA8),
                  Color(0xFFFFBD38),
                  Color(0x00FFEBA8),
                ],
                stops: const [0.0, 0.42, 1.0],
                opacity:
                    0.7 + (((math.sin((phase * 2.35) + 2.4) + 1) / 2) * 0.18),
                blur: 4,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 2.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0x00FFB25D),
                        const Color(0xB5FFD46B),
                        const Color(0xFFFF7B1A),
                        const Color(0xB5FFD46B),
                        const Color(0x00FFB25D),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xAAFF6A00)
                            .withValues(alpha: frontPulse),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementSweepShimmer extends StatelessWidget {
  const _AchievementSweepShimmer({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          const activeUntil = 0.67;
          final isActive = value < activeUntil;
          if (!isActive) {
            return const SizedBox.shrink();
          }

          final progress = value / activeUntil;
          final travel = -46 + (progress * 132);
          final pulse =
              0.24 + (((math.sin(progress * math.pi) + 1) / 2) * 0.16);

          return Stack(
            children: [
              Positioned(
                left: travel,
                top: -10,
                bottom: -10,
                child: Transform.rotate(
                  angle: -0.34,
                  alignment: Alignment.center,
                  child: Container(
                    width: 26,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: pulse * 0.7),
                          Colors.white.withValues(alpha: pulse),
                          Colors.white.withValues(alpha: pulse * 0.68),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: pulse * 0.32),
                          blurRadius: 10,
                          spreadRadius: 0.8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpringHeraldBackgroundPattern extends StatelessWidget {
  const _SpringHeraldBackgroundPattern({required this.patternColor});

  final Color patternColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 2,
            child: Icon(
              Icons.star_rounded,
              size: 5,
              color: patternColor,
            ),
          ),
          Positioned(
            right: 15,
            bottom: 3,
            child: Icon(
              Icons.star_rounded,
              size: 6,
              color: patternColor,
            ),
          ),
          Positioned(
            right: 40,
            top: 0,
            child: Icon(
              Icons.circle,
              size: 4,
              color: patternColor.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            left: 35,
            bottom: -2,
            child: Icon(
              Icons.circle,
              size: 3,
              color: patternColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpringHeraldGlossySheen extends StatelessWidget {
  const _SpringHeraldGlossySheen();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FractionallySizedBox(
        alignment: Alignment.topCenter,
        heightFactor: 0.48,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkStarSpark extends StatelessWidget {
  const _BlinkStarSpark({
    required this.animation,
    required this.size,
    this.color = Colors.white,
    this.shadowColor = const Color(0x80D9D9D9),
  });

  final Animation<double> animation;
  final double size;
  final Color color;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final isOn = animation.value > 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: size,
              color: shadowColor,
              weight: 900,
            ),
            Opacity(
              opacity: isOn ? 1 : 0,
              child: Transform.scale(
                scale: isOn ? 1.12 : 1,
                child: child,
              ),
            ),
          ],
        );
      },
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size,
        color: color,
        weight: 900,
      ),
    );
  }
}

class _ProfileMetadataRow extends StatelessWidget {
  const _ProfileMetadataRow({required this.user});

  static const String _locationSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3.61971 8.49C5.58971-.169998 18.4197-.159997 20.3797 8.5c1.15 5.08-2.01 9.38-4.78 12.04-2.01 1.94-5.19 1.94-7.20999.0-2.76-2.66-5.92-6.97-4.77-12.05z" stroke="#292D32" stroke-width="1.5"/><path opacity=".4" d="M9.25 11.5l1.5 1.5 4-4" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  static const String _joinedSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M8 2V5" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path d="M16 2V5" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M3.5 9.08984h17" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path d="M21 8.5V17c0 3-1.5 5-5 5H8c-3.5.0-5-2-5-5V8.5c0-3 1.5-5 5-5h8c3.5.0 5 2 5 5z" stroke="#292D32" stroke-width="1.5" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M15.6947 13.7002H15.7037" stroke="#292D32" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M15.6947 16.7002H15.7037" stroke="#292D32" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M11.9955 13.7002H12.0045" stroke="#292D32" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M11.9955 16.7002H12.0045" stroke="#292D32" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M8.29431 13.7002H8.30329" stroke="#292D32" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M8.29395 16.7002H8.30293" stroke="#292D32" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  final User user;

  @override
  Widget build(BuildContext context) {
    final location = user.profileShowLocation ? user.location?.trim() : null;
    final joinedLabel = _formatJoinedDate(user.createdAt);
    final items = <Widget>[
      if (location != null && location.isNotEmpty)
        _ProfileMetadataSvgItem(
          svg: _locationSvg,
          label: location,
        ),
      if (location != null && location.isNotEmpty && joinedLabel != null)
        const SizedBox(height: 8),
      if (joinedLabel != null)
        _ProfileMetadataSvgItem(
          svg: _joinedSvg,
          label: joinedLabel,
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  String? _formatJoinedDate(String? rawCreatedAt) {
    final value = rawCreatedAt?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }

    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = monthNames[parsed.month - 1];
    return 'Joined $month ${parsed.year}';
  }
}

class _ProfileMetadataSvgItem extends StatelessWidget {
  const _ProfileMetadataSvgItem({
    required this.svg,
    required this.label,
  });

  final String svg;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = const Color(0xFFFF7A45);
    final textColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.string(
          svg,
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.user,
    required this.isOwnProfile,
    required this.isUpdatingFollow,
    required this.onToggleFollow,
    required this.isOpeningMessage,
    required this.onMessage,
  });

  final User user;
  final bool isOwnProfile;
  final bool isUpdatingFollow;
  final VoidCallback onToggleFollow;
  final bool isOpeningMessage;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final username = user.username?.trim() ?? '';
    if (isOwnProfile || username.isEmpty) {
      return const SizedBox.shrink();
    }

    final isFollowing = user.isFollowing;
    final isRequested = user.isRequested && !isFollowing;
    final showMuted = isFollowing || isRequested;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? (showMuted ? const Color(0xFF1E1E20) : const Color(0xFFFF7A45))
                      : (showMuted ? const Color(0xFFF9FAFB) : const Color(0xFFFF7A45)),
                  foregroundColor: showMuted ? const Color(0xFFFF7A45) : Colors.white,
                  side: showMuted
                      ? const BorderSide(color: Color(0xFFFF7A45), width: 1.2)
                      : BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isUpdatingFollow ? null : onToggleFollow,
                child: isUpdatingFollow
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: showMuted ? const Color(0xFFFF7A45) : Colors.white,
                        ),
                      )
                    : Text(
                        isFollowing
                            ? 'Following'
                            : isRequested
                                ? 'Requested'
                                : 'Follow',
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2F3031)
                        : const Color(0xFFD1D5DB),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isOpeningMessage ? null : onMessage,
                icon: isOpeningMessage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Message'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelCoverTile extends StatelessWidget {
  const _ReelCoverTile({
    super.key,
    required this.reel,
    required this.onTap,
  });

  final Post reel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final posterUrl = reel.videoPosterUrl.trim().isNotEmpty
        ? reel.videoPosterUrl.trim()
        : reel.thumbnailUrls.isNotEmpty
            ? reel.thumbnailUrls.first.trim()
            : reel.imageUrls.isNotEmpty
                ? reel.imageUrls.first.trim()
                : '';

    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: const Color(0xFF1C1E21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (posterUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: ApiConfig.assetUrl(posterUrl),
                fit: BoxFit.contain,
                useOldImageOnUrlChange: true,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                memCacheWidth: 400,
                maxWidthDiskCache: 400,
                placeholder: (context, url) =>
                    const ColoredBox(color: Color(0xFF1C1E21)),
                errorWidget: (context, url, error) => const Icon(
                  Icons.video_library_outlined,
                  color: Colors.white70,
                ),
              )
            else
              const Icon(
                Icons.video_library_outlined,
                color: Colors.white70,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _MenuSheet extends StatelessWidget {
  const _MenuSheet({
    required this.user,
  });

  final User user;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF3F4F6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 18 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF9CA3AF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          _MoreOptionsCard(
            children: [
              _MoreOptionsRow(
                label: 'Copy profile link',
                icon: Icons.link_rounded,
                onTap: () => Navigator.pop(context, 'copy_link'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MoreOptionsCard(
            children: [
              _MoreOptionsRow(
                label: 'About account',
                icon: Icons.info_outline_rounded,
                onTap: () => Navigator.pop(context, 'about'),
              ),
              const _MoreOptionsDivider(),
              _MoreOptionsRow(
                label: 'Edit profile',
                icon: Icons.edit_outlined,
                onTap: () => Navigator.pop(context, 'edit_profile'),
              ),
              const _MoreOptionsDivider(),
              _MoreOptionsRow(
                label: 'Account settings',
                icon: Icons.tune_rounded,
                onTap: () => Navigator.pop(context, 'settings'),
              ),
              const _MoreOptionsDivider(),
              _MoreOptionsRow(
                label: 'Manage Featured Photos',
                icon: Icons.star_border_rounded,
                onTap: () => Navigator.pop(context, 'manage_featured_photos'),
              ),
              if (user.isAdmin) ...[
                const _MoreOptionsDivider(),
                _MoreOptionsRow(
                  label: 'Admin Dashboard',
                  icon: Icons.shield_outlined,
                  onTap: () => Navigator.pop(context, 'admin_dashboard'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreOptionsCard extends StatelessWidget {
  const _MoreOptionsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242526) : Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _MoreOptionsRow extends StatelessWidget {
  const _MoreOptionsRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark ? const Color(0xFF242526) : Colors.white;

    return Material(
      color: rowBg,
      child: InkWell(
        onTap: onTap,
        splashColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
        highlightColor: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  icon,
                  color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreOptionsDivider extends StatelessWidget {
  const _MoreOptionsDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? const Color(0xFF3E4042) : const Color(0xFFE5E7EB),
      ),
    );
  }
}

Future<void> showProfileAboutSheet(
  BuildContext context, {
  required User user,
  bool showPrivateFields = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    isScrollControlled: true,
    builder: (_) => _ProfileAboutAccountSheet(
      user: user,
      showPrivateFields: showPrivateFields,
    ),
  );
}

class _ProfileAboutAccountSheet extends StatelessWidget {
  const _ProfileAboutAccountSheet({
    required this.user,
    required this.showPrivateFields,
  });

  final User user;
  final bool showPrivateFields;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final items = _buildItems();
    final avatarUrl = user.avatarUrl?.trim() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF9FAFB),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + bottomPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'About account',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Theme.of(context).colorScheme.onSurface,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2F3031)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFEFF6FF),
                        backgroundImage: avatarUrl.isEmpty
                            ? null
                            : CachedNetworkImageProvider(
                                ApiConfig.assetUrl(avatarUrl),
                              ),
                        child: avatarUrl.isEmpty
                            ? Text(
                                user.initials,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF2563EB),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (user.handle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                user.handle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF65676B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AboutSectionHeader(
                  icon: Icons.info_outline_rounded,
                  title: 'Profile information',
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2F3031)
                            : const Color(0xFFE5E7EB),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: items.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No visible account information yet.',
                              style: TextStyle(
                                color: Color(0xFF65676B),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2F3031)
                                        : const Color(0xFFF3F4F6),
                                  ),
                                items[i],
                              ],
                            ],
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

  List<Widget> _buildItems() {
    final items = <Widget>[];

    void add({
      required IconData icon,
      required String label,
      required String? value,
    }) {
      final cleanValue = value?.trim();
      if (cleanValue == null || cleanValue.isEmpty) {
        return;
      }
      items.add(_AboutInfoRow(icon: icon, label: label, value: cleanValue));
    }

    add(icon: Icons.badge_outlined, label: 'Role', value: user.roleTitle);
    add(icon: Icons.notes_rounded, label: 'Bio', value: user.bio);
    add(
      icon: Icons.email_outlined,
      label: 'Email',
      value: showPrivateFields || user.profileShowEmail ? user.email : null,
    );
    add(
      icon: Icons.phone_outlined,
      label: 'Phone',
      value: showPrivateFields || user.profileShowPhone ? user.phone : null,
    );
    add(
      icon: Icons.person_outline_rounded,
      label: 'Gender',
      value: showPrivateFields || user.profileShowGender
          ? _formatGender(user.gender)
          : null,
    );
    add(
      icon: Icons.cake_outlined,
      label: 'Birthday',
      value: showPrivateFields || user.profileShowBirthday
          ? _formatFullDate(user.birthday)
          : null,
    );
    add(
      icon: Icons.location_on_outlined,
      label: 'Location',
      value:
          showPrivateFields || user.profileShowLocation ? user.location : null,
    );
    add(
      icon: Icons.calendar_today_outlined,
      label: 'Joined',
      value: _formatFullDate(user.createdAt),
    );

    return items;
  }

  String? _formatGender(String? rawGender) {
    final value = rawGender?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value
        .split(RegExp(r'\s+'))
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String? _formatFullDate(String? rawDate) {
    final value = rawDate?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}

class _AboutSectionHeader extends StatelessWidget {
  const _AboutSectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF65676B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF65676B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF65676B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RawSvgAchievement extends StatelessWidget {
  const _RawSvgAchievement({required this.svgString});

  final String svgString;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: SvgPicture.string(
        svgString,
        height: 12,
        fit: BoxFit.contain,
      ),
    );
  }
}

const String _googleWorkspaceSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 66"><path fill="#5F6368" d="M402.551 18.199q6.024 0 10.253 4.742q4.357 4.742 4.357 11.534q0 6.92-4.357 11.663q-4.23 4.742-10.253 4.742h-.128q-3.332 0-6.152-1.41t-4.229-3.845h-.256l.256 4.23v13.584h-5.767V19.096h5.51v4.357h.257q1.41-2.435 4.23-3.844q2.818-1.41 6.28-1.41m-32.68-.128q4.1 0 7.433 2.05q3.332 2.05 4.613 5.127l-5.126 2.178a6.54 6.54 0 0 0-2.82-3.076a9 9 0 0 0-4.485-1.025a7.43 7.43 0 0 0-4.101 1.025q-1.795 1.155-1.795 2.82q0 2.691 4.999 3.717l4.614 1.281q9.227 2.18 9.227 9.228q0 3.973-3.46 6.792t-8.972 2.692q-4.613 0-8.074-2.435a13.33 13.33 0 0 1-4.998-6.28l5.127-2.179q1.153 2.691 3.204 4.23a7.95 7.95 0 0 0 4.741 1.537q2.82 0 4.614-1.153q1.794-1.155 1.923-2.82q0-2.947-4.486-4.357l-5.383-1.282q-8.97-2.307-8.97-8.715q0-4.23 3.46-6.792q3.46-2.563 8.714-2.563m-81.126.128q6.92 0 11.278 4.614q4.486 4.613 4.486 11.662q0 7.178-4.486 11.79q-4.485 4.615-11.278 4.615q-6.792 0-11.406-4.614q-4.486-4.614-4.486-11.79q0-7.05 4.486-11.663t11.406-4.614m208.26 0q6.92 0 10.894 4.357T512 34.988v.64h-24.222q.128 4.486 2.947 7.306t6.921 2.691q5.511 0 8.715-5.51l5.126 2.562a15.4 15.4 0 0 1-5.767 6.024q-3.588 2.178-8.33 2.179q-6.793 0-11.15-4.614t-4.358-11.79q0-6.922 4.23-11.663q4.23-4.743 10.893-4.614m-30.63 0q4.742 0 8.202 2.307t5.255 6.536l-5.255 2.179q-2.434-5.768-8.587-5.768q-3.972 0-6.92 3.204q-2.82 3.204-2.82 7.818t2.82 7.946q2.948 3.204 6.92 3.204q6.28 0 8.844-5.767l5.254 2.179q-1.794 4.23-5.383 6.536q-3.588 2.307-8.33 2.307q-6.921 0-11.406-4.614q-4.486-4.742-4.486-11.79q0-7.05 4.486-11.663t11.406-4.614m-33.45 0q6.408 0 10.125 3.332t3.716 9.356v18.967h-5.51v-4.229h-.257q-3.588 5.255-9.612 5.255q-4.998 0-8.458-2.948t-3.46-7.562q0-4.74 3.588-7.561t9.74-2.82q5.127 0 8.459 1.795v-1.282q0-3.076-2.435-5.126a8.2 8.2 0 0 0-5.423-2.051h-.088q-4.87 0-7.69 4.101l-5.126-3.204q4.23-6.023 12.431-6.023M223.64 4.999l9.483 35.243h.257l9.74-29.22h5.383l9.74 29.22h.256l8.971-35.244h6.024l-12.047 44.856h-5.896L245.94 20.25h-.256l-9.74 29.605h-5.895L217.616 4.998zm99.836 13.2q2.435 0 4.23.769l-1.795 5.639q-1.025-.385-3.332-.385q-3.332 0-5.767 2.563t-2.435 6.152v16.917h-5.767V19.096h5.51v5.126h.257q.897-2.563 3.717-4.229t5.382-1.794m12.688-13.2V32.68l13.329-13.585h7.305v.256l-11.919 11.92l12.56 18.326v.256h-7.049l-9.484-14.482l-4.742 4.742v9.74h-5.767V4.998zm97.53 29.604q-3.46 0-5.895 1.666q-2.436 1.666-2.307 4.23q0 2.307 1.922 3.716q1.923 1.41 4.486 1.538q3.588 0 6.408-2.691t2.948-6.28q-2.692-2.18-7.562-2.179m-32.168-11.15q-4.23 0-7.049 3.076q-2.691 3.204-2.691 7.946q0 4.999 2.691 8.074q2.82 3.075 7.049 3.076t7.049-3.076q2.82-3.075 2.82-8.074q0-4.742-2.82-7.946t-7.05-3.076m-112.781 0q-4.23 0-7.177 3.076q-2.948 3.076-2.948 7.946q0 4.999 2.948 8.074t7.177 3.076t7.177-3.076q2.947-3.075 2.82-8.074q0-4.87-2.82-7.946q-2.948-3.075-7.177-3.076m208.132 0q-3.204 0-5.51 1.923q-2.308 1.922-3.205 5.382h17.686q-.255-3.204-2.563-5.254q-2.307-2.05-6.408-2.05"/><path fill="#4285F4" d="M25.888 30.246v-7.049h23.326c.267 1.437.396 2.896.384 4.357c0 5.127-1.41 11.663-6.024 16.149C39.09 48.445 33.45 50.88 25.76 50.88C11.79 50.88 0 39.473 0 25.504S11.79 0 25.76 0c7.818 0 13.329 3.076 17.558 7.049l-4.998 4.87A18.199 18.199 0 0 0 7.56 25.504c0 10.253 8.075 18.455 18.2 18.455c6.664 0 10.508-2.691 12.943-5.126c1.923-1.923 3.204-4.742 3.717-8.587z"/><path fill="#EA4335" d="M85.098 34.475c0 9.484-7.433 16.405-16.532 16.405S52.16 43.959 52.16 34.475s7.433-16.404 16.405-16.404c8.97 0 16.532 6.92 16.532 16.404m-7.305 0c0-5.895-4.229-9.868-9.227-9.868s-9.228 3.973-9.228 9.868s4.358 9.997 9.228 9.997s9.227-4.102 9.227-9.997"/><path fill="#FBBC04" d="M120.983 34.475c0 9.484-7.433 16.405-16.532 16.405s-16.405-6.921-16.405-16.405s7.433-16.404 16.405-16.404c8.97 0 16.532 6.92 16.532 16.404m-7.305 0c0-5.895-4.23-9.868-9.227-9.868c-4.999 0-9.228 3.973-9.228 9.868s4.357 9.997 9.228 9.997s9.227-4.102 9.227-9.997"/><path fill="#4285F4" d="M155.33 19.096v29.477c0 12.047-7.177 17.045-15.635 17.045c-7.946 0-12.688-5.383-14.482-9.74l6.28-2.563c1.153 2.691 3.844 5.895 8.202 5.895c5.51 0 8.843-3.46 8.843-9.612v-2.435h-.257a11.15 11.15 0 0 1-8.715 3.717c-8.074 0-15.635-7.177-15.635-16.277c0-9.227 7.561-16.532 15.635-16.532c3.973 0 7.05 1.794 8.715 3.716h.257v-2.691zm-6.28 15.507c0-5.767-3.844-9.996-8.843-9.996c-4.87 0-9.1 4.229-9.1 9.996c0 5.64 4.23 9.869 9.1 9.869c4.999 0 8.843-4.23 8.843-9.869"/><path fill="#34A853" d="M160.328 1.922h7.177v48.06h-7.177z"/><path fill="#EA4335" d="m195.316 39.858l5.64 3.845c-1.795 2.563-6.152 7.177-13.714 7.177c-9.356 0-16.276-7.177-16.276-16.405c0-9.74 7.049-16.404 15.507-16.404c8.459 0 12.688 6.792 13.97 10.509l.769 1.794l-21.916 9.1c1.666 3.332 4.23 4.998 7.946 4.998c3.717 0 6.152-1.795 8.074-4.614m-17.173-5.896l14.61-6.023c-.769-2.05-3.204-3.46-6.024-3.46c-3.716 0-8.843 3.204-8.586 9.483"/></svg>';

class _PixelAchievementFace extends StatelessWidget {
  const _PixelAchievementFace({required this.style});

  final _AchievementThemeStyle style;

  static const String _pixelStarShellSvg =
      '<svg viewBox="0 0 24 24" fill="none">'
      '<path d="M12 2h2v2h-2zm-3 4h8v2H9zm-3 4h14v2H6zm-3 4h20v2H3zm-2 4h24v2H1z" fill="url(#pixelStarG1)" stroke="url(#pixelStarG2)" stroke-width="1.15"/>'
      '<defs>'
      '<linearGradient id="pixelStarG1" x1="4" y1="4" x2="20" y2="20" gradientUnits="userSpaceOnUse">'
      '<stop stop-color="#FF9F43"/>'
      '<stop offset="1" stop-color="#FF5E3A"/>'
      '</linearGradient>'
      '<linearGradient id="pixelStarG2" x1="4" y1="4" x2="20" y2="20" gradientUnits="userSpaceOnUse">'
      '<stop stop-color="#FF5E3A"/>'
      '<stop offset="1" stop-color="#E23E1D"/>'
      '</linearGradient>'
      '</defs>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.string(
          _pixelStarShellSvg,
          width: 19,
          height: 19,
        ),
        SizedBox(
          width: 12.0,
          height: 12.0,
          child: SvgPicture.string(
            style.iconSvg,
            colorFilter: ColorFilter.mode(
              style.badgeIconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}
