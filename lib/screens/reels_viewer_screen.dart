import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../utils/emoji_presentation.dart';
import '../widgets/comments_modal.dart';
import '../widgets/custom_icons.dart';
import '../widgets/floating_friend_reaction_overlay.dart';
import '../widgets/sensitive_content_wrapper.dart';
import '../widgets/special_name_text.dart';
import '../widgets/share_post_sheet.dart';
import 'user_profile_screen.dart';
import 'repost_post_screen.dart';

class ReelsViewerScreen extends StatefulWidget {
  const ReelsViewerScreen({
    required this.initialReel,
    required this.initialReelId,
    this.initialPlaylist,
    this.loadMoreFromFeed = true,
    super.key,
  });

  final Post initialReel;
  final String initialReelId;
  final List<Post>? initialPlaylist;
  final bool loadMoreFromFeed;

  @override
  State<ReelsViewerScreen> createState() => _ReelsViewerScreenState();
}

class _ReelsViewerScreenState extends State<ReelsViewerScreen> {
  static const int _pageSize = 20;

  final FeedService _feedService = FeedService();
  late final PageController _pageController;
  late List<Post> _reels;
  int _currentIndex = 0;
  int _nextOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    final playlist = _initialPlaylist();
    _reels = playlist;
    _currentIndex = _initialIndex(playlist);
    _pageController = PageController(initialPage: _currentIndex);
    if (widget.loadMoreFromFeed) {
      _loadInitialReels();
    } else {
      _hasMore = false;
      _nextOffset = playlist.length;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialReels() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _nextOffset = 0;
    });

    try {
      final page = await _feedService.loadReels(offset: 0, limit: _pageSize);
      if (!mounted) return;

      final mergedReels = _randomizedInitialPlaylist(page.posts);

      setState(() {
        _reels = mergedReels;
        _currentIndex = 0;
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
        _isLoading = false;
      });

      if (_pageController.page?.round() != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(0);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreReels() async {
    if (!widget.loadMoreFromFeed || _isLoading || !_hasMore) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final page = await _feedService.loadReels(
        offset: _nextOffset,
        limit: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _reels = _mergeReels(_reels, page.posts);
        _nextOffset = page.offset + page.posts.length;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  List<Post> _randomizedInitialPlaylist(List<Post> posts) {
    final tappedReel = widget.initialReel;
    final remaining = _mergeReels(
      const <Post>[],
      posts,
    ).where((reel) => reel.id != widget.initialReelId).toList();

    remaining.shuffle(math.Random());
    return [tappedReel, ...remaining];
  }

  List<Post> _initialPlaylist() {
    final playlist = widget.initialPlaylist;
    if (playlist == null || playlist.isEmpty) {
      return [widget.initialReel];
    }

    final merged = _mergeReels(const <Post>[], playlist);
    if (merged.any((reel) => reel.id == widget.initialReelId)) {
      return merged;
    }

    return [widget.initialReel, ...merged];
  }

  int _initialIndex(List<Post> playlist) {
    final index =
        playlist.indexWhere((reel) => reel.id == widget.initialReelId);
    return index < 0 ? 0 : index;
  }

  List<Post> _mergeReels(List<Post> existing, List<Post> incoming) {
    final merged = <Post>[...existing];
    final seen = existing.map((reel) => reel.id).toSet();

    for (final reel in incoming) {
      final hasMedia =
          reel.videoUrl.trim().isNotEmpty || reel.imageUrls.isNotEmpty;
      if (reel.isReel && hasMedia && seen.add(reel.id)) {
        merged.add(reel);
      }
    }

    return merged;
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (_hasMore && index >= _reels.length - 4) {
      _loadMoreReels();
    }
  }

  void _handleReelUpdated(Post updatedReel) {
    final index = _reels.indexWhere((reel) => reel.id == updatedReel.id);
    if (index < 0) return;

    setState(() {
      _reels[index] = updatedReel;
    });
  }

  void _handleReelDeleted(String reelId) {
    final index = _reels.indexWhere((reel) => reel.id == reelId);
    if (index < 0) return;

    setState(() {
      _reels.removeAt(index);
      if (_reels.isNotEmpty && _currentIndex >= _reels.length) {
        _currentIndex = _reels.length - 1;
      }
    });

    if (_reels.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _reels.isEmpty
            ? const Center(
                child: Text(
                  'No reels available',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _reels.length,
                onPageChanged: _handlePageChanged,
                itemBuilder: (context, index) {
                  final reel = _reels[index];
                  return _ReelPage(
                    key: ValueKey('reel-${reel.id}'),
                    reel: reel,
                    isActive: index == _currentIndex,
                    onReelUpdated: _handleReelUpdated,
                    onReelDeleted: _handleReelDeleted,
                  );
                },
              ),
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({
    required this.reel,
    required this.isActive,
    required this.onReelUpdated,
    required this.onReelDeleted,
    super.key,
  });

  final Post reel;
  final bool isActive;
  final void Function(Post reel) onReelUpdated;
  final void Function(String reelId) onReelDeleted;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  VideoPlayerController? _controller;
  late Post _reel;
  bool _isInitialized = false;
  bool _hasError = false;

  bool get _isPhotoReel =>
      _reel.videoUrl.trim().isEmpty && _reel.imageUrls.isNotEmpty;
  bool _showComments = false;
  bool _isCaptionExpanded = false;
  bool _isLiking = false;
  bool _isReposting = false;
  bool _isBookmarking = false;
  bool _isSendingComment = false;
  bool _isDeleting = false;
  bool _isSavingPrivacy = false;
  bool _isFollowingAuthor = false;
  bool _isFollowPending = false;

  @override
  void initState() {
    super.initState();
    _reel = widget.reel;
    _isFollowingAuthor = widget.reel.isFollowingAuthor;
    _initializeController();
  }

  @override
  void didUpdateWidget(_ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id) {
      _reel = widget.reel;
      _showComments = false;
      _isCaptionExpanded = false;
      _isFollowingAuthor = widget.reel.isFollowingAuthor;
      _isFollowPending = false;
      _commentController.clear();
      _commentFocus.unfocus();
    }

    if (oldWidget.reel.videoUrl != widget.reel.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _initializeController();
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _initializeController() {
    if (_isPhotoReel) {
      setState(() {
        _isInitialized = true;
      });
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(ApiConfig.assetUrl(_reel.videoUrl)),
    );
    _controller = controller;
    controller.setLooping(true);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      _syncPlayback();
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    });
  }

  void _syncPlayback() {
    if (!_isInitialized) return;
    final controller = _controller;
    if (controller == null) return;
    if (widget.isActive) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _togglePlayback() {
    if (_commentFocus.hasFocus) {
      _commentFocus.unfocus();
      return;
    }
    if (!_isInitialized) return;
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _isSendingComment) return;

    setState(() {
      _isSendingComment = true;
    });
    _commentController.clear();
    _commentFocus.unfocus();

    try {
      final result = await _feedService.createComment(_reel.id, body);
      if (!mounted) return;

      setState(() {
        _reel = _reel.copyWith(commentCount: result.commentCount);
        _isSendingComment = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSendingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment not sent.')),
      );
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final previous = _reel;
    final wasLiked = previous.likedByMe;
    final optimistic = previous.copyWith(
      likedByMe: !wasLiked,
      likeCount: wasLiked
          ? (previous.likeCount - 1).clamp(0, 999999)
          : previous.likeCount + 1,
    );

    setState(() {
      _isLiking = true;
      _reel = optimistic;
    });
    HapticFeedback.lightImpact();

    try {
      final updated = await _feedService.toggleLike(previous);
      if (!mounted) return;
      setState(() {
        _reel = updated;
        _isLiking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reel = previous;
        _isLiking = false;
      });
    }
  }

  Future<void> _openComments() async {
    final screenHeight = MediaQuery.sizeOf(context).height;
    setState(() {
      _showComments = true;
    });

    final updatedCount = await showCommentsModal(
      context: context,
      post: _reel,
      sheetHeight: screenHeight * 0.62,
    );
    if (!mounted) return;

    setState(() {
      _showComments = false;
      if (updatedCount != null) {
        _reel = _reel.copyWith(commentCount: updatedCount);
      }
    });
  }

  Future<void> _repost() async {
    if (_isReposting) return;

    HapticFeedback.lightImpact();

    final repostedPost = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => RepostPostScreen(originalPost: _reel),
      ),
    );

    if (!mounted || repostedPost == null) {
      return;
    }

    final updatedOriginal = repostedPost.originalPost;
    setState(() {
      _reel = updatedOriginal?.id == _reel.id
          ? updatedOriginal!
          : _reel.copyWith(repostCount: _reel.repostCount + 1);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reposted.')),
    );
  }

  void _share() {
    SharePostSheet.show(context, post: _reel);
  }

  Future<void> _copyReelLink() async {
    final baseUrl = ApiConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    await Clipboard.setData(ClipboardData(text: '$baseUrl/post/${_reel.id}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  Future<void> _openOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (context) => _ReelOptionsSheet(
        reel: _reel,
        isDeleting: _isDeleting,
        isSavingPrivacy: _isSavingPrivacy,
        onAudience: _openAudienceSheet,
        onShare: _share,
        onCopyLink: _copyReelLink,
        onDelete: _confirmDeleteReel,
      ),
    );
  }

  Future<void> _openAudienceSheet() async {
    final nextVisibility = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (context) =>
          _ReelAudienceSheet(currentVisibility: _reel.visibility),
    );

    if (nextVisibility == null || nextVisibility == _reel.visibility) return;
    await _updateAudience(nextVisibility);
  }

  Future<void> _updateAudience(String visibility) async {
    if (_isSavingPrivacy) return;

    setState(() {
      _isSavingPrivacy = true;
    });

    try {
      final updated = await _feedService.updatePost(
        postId: _reel.id,
        text: _reel.text,
        visibility: visibility,
        withUserIds: _reel.withUsers
            .map((user) => (user.id ?? '').trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false),
      );
      if (!mounted) return;

      setState(() {
        _reel = updated;
        _isSavingPrivacy = false;
      });
      widget.onReelUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audience changed to ${updated.privacyLabel}.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSavingPrivacy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update audience.')),
      );
    }
  }

  Future<void> _confirmDeleteReel() async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (context) => const _DeleteReelSheet(),
    );

    if (shouldDelete == true) {
      await _deleteReel();
    }
  }

  Future<void> _deleteReel() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final deletedId = _reel.id;
      await _feedService.deletePost(deletedId);
      if (!mounted) return;

      widget.onReelDeleted(deletedId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel deleted.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete reel.')),
      );
    }
  }

  Future<void> _toggleFollowAuthor() async {
    final username = _reel.authorUsername.trim();
    if (username.isEmpty || _reel.ownedByMe || _isFollowPending) return;

    final wasFollowing = _isFollowingAuthor;
    setState(() {
      _isFollowPending = true;
    });

    try {
      final updatedUser = wasFollowing
          ? await _feedService.unfollowUser(username)
          : await _feedService.followUser(username);
      if (!mounted) return;

      final nextFollowing = updatedUser?.isFollowing ?? !wasFollowing;
      final updatedReel = _reel.copyWith(isFollowingAuthor: nextFollowing);
      setState(() {
        _isFollowingAuthor = nextFollowing;
        _isFollowPending = false;
        _reel = updatedReel;
      });
      widget.onReelUpdated(updatedReel);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isFollowingAuthor = wasFollowing;
        _isFollowPending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update follow.')),
      );
    }
  }

  void _openAuthorProfile() {
    final username = _reel.authorUsername.trim();
    if (username.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: username,
          seedFullName: _reel.authorFullName,
          seedAvatarUrl: _reel.authorAvatarUrl,
        ),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarking) return;

    final previous = _reel;
    setState(() {
      _isBookmarking = true;
      _reel = _reel.copyWith(bookmarkedByMe: !_reel.bookmarkedByMe);
    });

    try {
      final updated = await _feedService.toggleBookmark(previous);
      if (!mounted) return;
      setState(() {
        _reel = updated;
        _isBookmarking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reel = previous;
        _isBookmarking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Stack(
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              height: _showComments ? screenHeight * 0.38 : screenHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayback,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildVideoPlayer(),
                    if (!_showComments) _buildGradients(),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: _ReelTopBar(
                          reel: _reel,
                          onMoreOptions: _openOptions,
                        ),
                      ),
                    ),
                    if (!_showComments)
                      Positioned(
                        right: 14,
                        bottom: 150,
                        child: SafeArea(
                          child: _ReelActionRail(
                            reel: _reel,
                            onLike: _toggleLike,
                            onComment: _openComments,
                            onRepost: _repost,
                            onShare: _share,
                            onBookmark: _toggleBookmark,
                          ),
                        ),
                      ),
                    if (!_showComments && _getReelFriendActivities(_reel).isNotEmpty)
                      FloatingFriendReactionOverlay(
                        activities: _getReelFriendActivities(_reel),
                      ),
                    if (!_showComments)
                      Positioned(
                        left: 16,
                        right: 90,
                        bottom: 95,
                        child: SafeArea(
                          child: _ReelCreatorInfo(
                            reel: _reel,
                            isCaptionExpanded: _isCaptionExpanded,
                            isFollowingAuthor: _isFollowingAuthor,
                            isFollowPending: _isFollowPending,
                            onToggleFollow: _toggleFollowAuthor,
                            onOpenAuthor: _openAuthorProfile,
                            onCaptionTap: () {
                              setState(() {
                                _isCaptionExpanded = !_isCaptionExpanded;
                              });
                            },
                          ),
                        ),
                      ),
                    if (!_isInitialized && !_hasError)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    if (_hasError)
                      const Center(
                        child: Icon(
                          Icons.video_file_outlined,
                          color: Colors.white70,
                          size: 48,
                        ),
                      ),
                    if (_isInitialized &&
                        _controller != null &&
                        !_controller!.value.isPlaying)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 74,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_showComments) _buildCommentPill(),
      ],
    );
  }

  List<FriendPostActivity> _getReelFriendActivities(Post reel) {
    final isRepost = reel.originalPost != null ||
        reel.repostOriginalPostId.isNotEmpty ||
        (reel.repostedByText != null && reel.repostedByText!.isNotEmpty);
    final isLiked = reel.likeCount > 0 || reel.likedByMe;

    final activities = <FriendPostActivity>[];
    final authorName = reel.authorUsername.trim().toLowerCase();
    final currentUserName = (AuthService().currentUser?.username ?? '').trim().toLowerCase();

    bool isSelf(String name) {
      final clean = name.trim().toLowerCase();
      if (clean.isEmpty) return true;
      if (clean == authorName) return true;
      if (currentUserName.isNotEmpty && clean == currentUserName) return true;
      return false;
    }

    // 1. Real Likers from backend likePreview (excluding post author & current user)
    if (reel.likePreview.isNotEmpty) {
      for (final liker in reel.likePreview) {
        if (activities.length >= 3) break;
        final name = (liker.username.isNotEmpty ? liker.username : liker.fullName).trim();
        if (isSelf(name)) continue;
        activities.add(
          FriendPostActivity(
            username: name,
            avatarUrl: liker.avatarUrl,
            isLiked: true,
            isReposted: false,
          ),
        );
      }
    }

    // 2. Tagged / Mentioned Friends (excluding post author & current user)
    if (activities.length < 3 && reel.withUsers.isNotEmpty) {
      for (final user in reel.withUsers) {
        if (activities.length >= 3) break;
        final name = (user.username ?? user.fullName ?? '').trim();
        if (isSelf(name)) continue;
        activities.add(
          FriendPostActivity(
            username: name,
            avatarUrl: user.avatarUrl ?? '',
            isLiked: isLiked,
            isReposted: isRepost,
          ),
        );
      }
    }

    // 3. Poll Voters (excluding post author & current user)
    if (activities.length < 3 && reel.pollVoters.isNotEmpty) {
      for (final voter in reel.pollVoters) {
        if (activities.length >= 3) break;
        final name = voter.username.trim();
        if (isSelf(name)) continue;
        activities.add(
          FriendPostActivity(
            username: name,
            avatarUrl: voter.avatarUrl,
            isLiked: isLiked,
            isReposted: isRepost,
          ),
        );
      }
    }

    // 4. Repost Author (excluding post author & current user)
    if (activities.length < 3 && isRepost && reel.repostedByText != null) {
      final reposter = reel.repostedByText!.trim();
      if (!isSelf(reposter)) {
        activities.add(
          FriendPostActivity(
            username: reposter,
            avatarUrl: '',
            isLiked: isLiked,
            isReposted: true,
          ),
        );
      }
    }

    return activities;
  }

  Widget _buildVideoPlayer() {
    return SensitiveContentWrapper(
      isSensitive: _reel.isSensitive,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (!_isPhotoReel && _reel.primaryVideoPosterUrl.isNotEmpty && (!_isInitialized || _controller == null))
            Center(
              child: CachedNetworkImage(
                imageUrl: ApiConfig.assetUrl(_reel.primaryVideoPosterUrl),
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const ColoredBox(color: Colors.black),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
          if (_isPhotoReel)
            Hero(
              tag: 'video_${_reel.id}',
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: ApiConfig.assetUrl(_reel.imageUrls.first),
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const ColoredBox(color: Colors.black),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
            )
          else if (_isInitialized && _controller != null)
            Hero(
              tag: 'video_${_reel.id}',
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradients() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0, 0.25, 0.65, 1],
        ),
      ),
    );
  }

  Widget _buildCommentPill() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = keyboardInset > 0 ? keyboardInset + 8.0 : safeBottom + 16.0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                inputFormatters: [EmojiPresentationFormatter()],
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            if (_isSendingComment)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _commentController,
                builder: (_, value, __) {
                  if (value.text.trim().isEmpty) {
                    return const SizedBox(width: 12);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _submitComment,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReelTopBar extends StatelessWidget {
  const _ReelTopBar({
    required this.reel,
    required this.onMoreOptions,
  });

  final Post reel;
  final VoidCallback onMoreOptions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Reels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 26),
            onPressed: () {},
          ),
          if (reel.ownedByMe && reel.privacyLabel.isNotEmpty) ...[
            Icon(
              _privacyIcon(reel.visibility),
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              reel.privacyLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
          ],
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 27),
            onPressed: onMoreOptions,
          ),
        ],
      ),
    );
  }

  IconData _privacyIcon(String visibility) {
    switch (visibility) {
      case 'friends':
        return Icons.group_outlined;
      case 'only_me':
        return Icons.lock_outline;
      default:
        return Icons.public;
    }
  }
}

class _ReelOptionsSheet extends StatelessWidget {
  const _ReelOptionsSheet({
    required this.reel,
    required this.isDeleting,
    required this.isSavingPrivacy,
    required this.onAudience,
    required this.onShare,
    required this.onCopyLink,
    required this.onDelete,
  });

  final Post reel;
  final bool isDeleting;
  final bool isSavingPrivacy;
  final VoidCallback onAudience;
  final VoidCallback onShare;
  final VoidCallback onCopyLink;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final actions = <_ReelOptionItem>[
      if (reel.ownedByMe)
        _ReelOptionItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Audience privacy',
          subtitle: 'Currently ${reel.privacyLabel}',
          isLoading: isSavingPrivacy,
          onTap: () {
            Navigator.of(context).pop();
            onAudience();
          },
        ),
      _ReelOptionItem(
        icon: Icons.share_outlined,
        label: 'Share reel',
        onTap: () {
          Navigator.of(context).pop();
          onShare();
        },
      ),
      _ReelOptionItem(
        icon: Icons.link_rounded,
        label: 'Copy link',
        onTap: () {
          Navigator.of(context).pop();
          onCopyLink();
        },
      ),
      if (reel.ownedByMe)
        _ReelOptionItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete reel',
          subtitle: 'Permanently remove this reel.',
          isDestructive: true,
          isLoading: isDeleting,
          onTap: () {
            Navigator.of(context).pop();
            onDelete();
          },
        ),
    ];

    return _ReelBottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          ...actions.map((action) => action),
        ],
      ),
    );
  }
}

class _ReelAudienceSheet extends StatelessWidget {
  const _ReelAudienceSheet({required this.currentVisibility});

  final String currentVisibility;

  static const _options = [
    _AudienceOption(
      value: 'public',
      icon: Icons.public,
      label: 'Public',
      subtitle: 'Anyone can see this reel.',
    ),
    _AudienceOption(
      value: 'friends',
      icon: Icons.group_outlined,
      label: 'Friends',
      subtitle: 'Only friends can see this reel.',
    ),
    _AudienceOption(
      value: 'only_me',
      icon: Icons.lock_outline,
      label: 'Only me',
      subtitle: 'Only you can see this reel.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ReelBottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 8.h),
            child: Text(
              'Audience privacy',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final option in _options)
            _ReelOptionItem(
              icon: option.icon,
              label: option.label,
              subtitle: option.subtitle,
              trailing: currentVisibility == option.value
                  ? Icon(Icons.check_circle, color: const Color(0xFF2563EB), size: 18.r)
                  : null,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    );
  }
}

class _AudienceOption {
  const _AudienceOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final String value;
  final IconData icon;
  final String label;
  final String subtitle;
}

class _DeleteReelSheet extends StatelessWidget {
  const _DeleteReelSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ReelBottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 6.h),
            child: Text(
              'Delete reel?',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              "This reel will be permanently deleted. This can't be undone.",
              style: TextStyle(
                color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                    side: BorderSide(color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                  ),
                  child: Text(
                    'Delete',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReelBottomSheetFrame extends StatelessWidget {
  const _ReelBottomSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3E4042) : const Color(0xFF9CA3AF),
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            SizedBox(height: 10.h),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReelOptionItem extends StatelessWidget {
  const _ReelOptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final bool isDestructive;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? const Color(0xFFDC2626)
        : (isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827));
    final iconColor = isDestructive
        ? const Color(0xFFDC2626)
        : (isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827));

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Material(
        color: isDark ? const Color(0xFF242526) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        child: ListTile(
          enabled: !isLoading,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 0),
          minVerticalPadding: 8.h,
          leading: isLoading
              ? SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: iconColor, size: 20.r),
          title: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.sp,
              letterSpacing: -0.1,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          trailing: trailing,
          onTap: isLoading ? null : onTap,
        ),
      ),
    );
  }
}

class _ReelActionRail extends StatelessWidget {
  const _ReelActionRail({
    required this.reel,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
    required this.onBookmark,
  });

  final Post reel;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    const activeLikeColor = Color(0xFFEF4444);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: reel.likedByMe
              ? CustomIcons.heartFilled(color: activeLikeColor, size: 30)
              : CustomIcons.heart(color: Colors.white, size: 30),
          count: _formatCount(reel.likeCount),
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: CustomIcons.comment(color: Colors.white, size: 30),
          count: _formatCount(reel.commentCount),
          onTap: onComment,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: CustomIcons.repost(color: Colors.white, size: 30),
          count: _formatCount(reel.repostCount),
          onTap: onRepost,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: CustomIcons.share(color: Colors.white, size: 30),
          count: '',
          onTap: onShare,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: CustomIcons.bookmark(
            color: reel.bookmarkedByMe
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            size: 30,
            isFilled: reel.bookmarkedByMe,
          ),
          count: '',
          onTap: onBookmark,
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else if (count > 0) {
      return count.toString();
    }
    return '';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final Widget icon;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReelCreatorInfo extends StatelessWidget {
  const _ReelCreatorInfo({
    required this.reel,
    required this.isCaptionExpanded,
    required this.isFollowingAuthor,
    required this.isFollowPending,
    required this.onToggleFollow,
    required this.onOpenAuthor,
    required this.onCaptionTap,
  });

  final Post reel;
  final bool isCaptionExpanded;
  final bool isFollowingAuthor;
  final bool isFollowPending;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenAuthor;
  final VoidCallback onCaptionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: reel.authorUsername.trim().isEmpty ? null : onOpenAuthor,
              child: CircleAvatar(
                radius: 18,
                backgroundImage: reel.authorAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(
                        ApiConfig.assetUrl(reel.authorAvatarUrl),
                      )
                    : null,
                backgroundColor: Colors.grey[800],
                child: reel.authorAvatarUrl.isEmpty
                    ? Text(
                        reel.authorInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: reel.authorUsername.trim().isEmpty ? null : onOpenAuthor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SpecialNameText(
                        username: reel.authorUsername,
                        displayName: reel.authorFullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (reel.authorIsVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: Color(0xFF1D9BF0),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!reel.ownedByMe && reel.authorUsername.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              const Text(
                '.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isFollowPending ? null : onToggleFollow,
                child: SizedBox(
                  height: 18,
                  child: Center(
                    child: isFollowPending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isFollowingAuthor ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: isFollowingAuthor
                                  ? Colors.white70
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (reel.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCaptionTap,
            child: Text(
              reel.text.trim(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
              maxLines: isCaptionExpanded ? null : 2,
              overflow: isCaptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
