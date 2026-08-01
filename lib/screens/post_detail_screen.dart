import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../services/normal_video_inline_controls.dart';
import '../services/normal_video_overlay_controller.dart';
import '../services/normal_video_playback_session.dart';
import '../utils/emoji_presentation.dart';
import '../widgets/custom_icons.dart';
import '../widgets/expandable_post_text.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/mention_autocomplete.dart';
import '../widgets/normal_video_overlay_host.dart';
import '../widgets/post_image_grid.dart';
import '../widgets/post_card.dart';
import '../widgets/special_name_text.dart';
import '../widgets/post_with_users_line.dart';
import '../widgets/repost_source_preview.dart';
import '../widgets/share_post_sheet.dart';
import '../widgets/sensitive_content_wrapper.dart';
import '../widgets/smooth_bottom_sheet.dart';
import 'image_viewer_screen.dart';
import 'repost_post_screen.dart';
import 'youtube_player_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';

enum _CommentSortMode {
  relevance,
  newest,
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    required this.postId,
    this.initialPost,
    this.currentUser,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    this.targetCommentId,
    this.targetSlideId,
    super.key,
  });

  final String postId;
  final Post? initialPost;
  final User? currentUser;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;
  final int? targetCommentId;
  final int? targetSlideId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Post? _post;
  StreamSubscription<Post>? _postUpdatedSubscription;
  StreamSubscription<ProfileStatsChange>? _profileStatsSubscription;
  _CommentSortMode _sortMode = _CommentSortMode.relevance;
  List<PostComment> _comments = const [];
  final Map<int, List<PostComment>> _repliesByComment =
      <int, List<PostComment>>{};
  final Set<int> _expandedReplyThreads = <int>{};
  final Set<int> _loadingReplyThreads = <int>{};
  _ReplyTarget? _activeReplyTarget;
  int _musicCarouselIndex = 0;
  int? _nextCommentsBeforeId;
  bool _hasMoreComments = false;
  bool _isLoadingPost = true;
  bool _isLoadingComments = true;
  bool _isLoadingMoreComments = false;
  bool _isLiking = false;
  bool _isVotingPoll = false;
  bool _isSendingComment = false;
  bool _isTextExpanded = false;
  bool _hasLocalLikeState = false;
  final Map<int, GlobalKey> _commentKeys = <int, GlobalKey>{};
  int? _highlightedCommentId;
  bool _targetDeliveryStarted = false;
  bool _targetSlideOpened = false;
  Timer? _highlightFadeTimer;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    if (_post != null && _post!.isGhost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _isLoadingPost = widget.initialPost == null;
    _scrollController.addListener(_handleCommentsScroll);
    _bindFeedEvents();
    _loadPost();
    _loadCommentsPreview();
  }

  @override
  void dispose() {
    _highlightFadeTimer?.cancel();
    _scrollController.removeListener(_handleCommentsScroll);
    _scrollController.dispose();
    _postUpdatedSubscription?.cancel();
    _profileStatsSubscription?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _bindFeedEvents() {
    _postUpdatedSubscription =
        FeedService.postUpdatedStream.listen(_applyUpdatedPost);
    _profileStatsSubscription =
        FeedService.profileStatsChangedStream.listen(_applyProfileStatsChange);
  }

  void _applyUpdatedPost(Post updatedPost) {
    if (!mounted || _post?.id != updatedPost.id) {
      return;
    }

    setState(() {
      _post = updatedPost.copyWith(commentCount: _post?.commentCount);
    });
  }

  void _applyProfileStatsChange(ProfileStatsChange event) {
    final post = _post;
    final nextTheme = event.user?.postcardTheme ?? '';
    final username = event.username.trim().toLowerCase();
    if (!mounted || post == null || username.isEmpty) {
      return;
    }
    if (post.authorUsername.trim().toLowerCase() != username ||
        (post.authorPostcardTheme ?? '') == nextTheme) {
      return;
    }

    setState(() {
      _post = post.copyWith(authorPostcardTheme: nextTheme);
    });
  }

  Future<void> _loadPost() async {
    final loadedPost = await _feedService.loadPost(widget.postId);
    if (!mounted) {
      return;
    }

    if (loadedPost != null && loadedPost.isGhost) {
      Navigator.of(context).pop();
      return;
    }

    final currentPost = _post;
    setState(() {
      if (loadedPost == null) {
        _post = currentPost;
      } else if (currentPost != null && _hasLocalLikeState) {
        _post = loadedPost.copyWith(
          likeCount: currentPost.likeCount,
          likedByMe: currentPost.likedByMe,
        );
      } else {
        _post = loadedPost;
      }
      _isLoadingPost = false;
      _isTextExpanded = false;

      if (_post != null && widget.targetSlideId != null && !_targetSlideOpened) {
        _targetSlideOpened = true;
        final slideIndex = _post!.slides.indexWhere((s) => s.id == widget.targetSlideId);
        if (slideIndex >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openImages(slideIndex);
          });
        }
      }
    });
  }

  Future<void> _loadCommentsPreview() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final page = await _feedService.loadComments(widget.postId, limit: 5);
      if (!mounted) {
        return;
      }

      setState(() {
        _comments = page.comments;
        _repliesByComment.clear();
        _expandedReplyThreads.clear();
        _loadingReplyThreads.clear();
        _nextCommentsBeforeId = page.nextBeforeId;
        _hasMoreComments = page.hasMore;
        _isLoadingMoreComments = false;
        if (_post != null && page.totalCount != _post!.commentCount) {
          _post = _post!.copyWith(commentCount: page.totalCount);
        }
        _isLoadingComments = false;
      });

      _maybeDeliverToTargetComment();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingComments = false;
        _isLoadingMoreComments = false;
      });
    }
  }

  void _handleCommentsScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingComments ||
        _isLoadingMoreComments ||
        !_hasMoreComments) {
      return;
    }

    if (_scrollController.position.extentAfter < 360) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    final beforeId = _nextCommentsBeforeId;
    if (beforeId == null || _isLoadingMoreComments || !_hasMoreComments) {
      return;
    }

    setState(() {
      _isLoadingMoreComments = true;
    });

    try {
      final page = await _feedService.loadComments(
        widget.postId,
        limit: 10,
        beforeId: beforeId,
      );
      if (!mounted) {
        return;
      }

      final existingIds = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _comments = [
          ..._comments,
          ...page.comments
              .where((comment) => !existingIds.contains(comment.id)),
        ];
        _nextCommentsBeforeId = page.nextBeforeId;
        _hasMoreComments = page.hasMore;
        _isLoadingMoreComments = false;
        if (_post != null && page.totalCount != _post!.commentCount) {
          _post = _post!.copyWith(commentCount: page.totalCount);
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingMoreComments = false;
      });
    }
  }

  void _maybeDeliverToTargetComment() {
    final targetId = widget.targetCommentId;
    if (targetId == null || targetId <= 0 || _targetDeliveryStarted) {
      return;
    }
    _targetDeliveryStarted = true;
    unawaited(_deliverToTargetComment(targetId));
  }

  Future<void> _deliverToTargetComment(int targetId) async {
    const maxPageFetches = 20;
    var fetched = 0;
    while (mounted &&
        !_comments.any((c) => c.id == targetId) &&
        _hasMoreComments &&
        fetched < maxPageFetches) {
      fetched += 1;
      await _loadMoreComments();
    }

    if (!mounted) {
      return;
    }

    var found = _comments.any((c) => c.id == targetId);
    if (!found) {
      found = await _findTargetInReplies(targetId);
    }
    if (!found || !mounted) {
      return;
    }

    await _scrollToCommentKey(targetId);
    if (!mounted) {
      return;
    }

    setState(() {
      _highlightedCommentId = targetId;
    });

    _highlightFadeTimer?.cancel();
    _highlightFadeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _highlightedCommentId = null;
      });
    });
  }

  Future<bool> _findTargetInReplies(int targetId) async {
    for (final parent in List<PostComment>.from(_comments)) {
      if (!mounted) return false;
      if (parent.replyCount <= 0) continue;
      List<PostComment>? replies = _repliesByComment[parent.id];
      if (replies == null) {
        try {
          replies = await _feedService.loadCommentReplies(parent.id);
        } catch (_) {
          continue;
        }
        if (!mounted) return false;
      }
      if (replies.any((r) => r.id == targetId)) {
        setState(() {
          _repliesByComment[parent.id] = replies!;
          _expandedReplyThreads.add(parent.id);
        });
        return true;
      }
    }
    return false;
  }

  Future<void> _scrollToCommentKey(int commentId) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      final context = _commentKeys[commentId]?.currentContext;
      if (context != null) {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.25,
        );
        return;
      }
      if (!_scrollController.hasClients) {
        continue;
      }
      final pos = _scrollController.position;
      final next = (pos.pixels + pos.viewportDimension * 0.85)
          .clamp(0.0, pos.maxScrollExtent);
      if (next <= pos.pixels + 1) {
        return;
      }
      await _scrollController.animateTo(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null || _isLiking) {
      return;
    }

    setState(() {
      _isLiking = true;
      _hasLocalLikeState = true;
      _post = post.copyWith(
        likedByMe: !post.likedByMe,
        likeCount: (post.likeCount + (post.likedByMe ? -1 : 1))
            .clamp(0, 1 << 31)
            .toInt(),
      );
    });

    try {
      final updatedPost = await _feedService.toggleLike(post);
      if (!mounted) {
        return;
      }

      setState(() {
        _post = updatedPost;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _post = post;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  void _focusCommentComposer() {
    if (!mounted) {
      return;
    }

    if (_activeReplyTarget != null) {
      setState(() {
        _activeReplyTarget = null;
      });
    }

    _commentFocusNode.requestFocus();
  }

  Future<void> _sendInlineComment() async {
    final post = _post;
    final body = _commentController.text.trim();
    final activeReplyTarget = _activeReplyTarget;
    if (post == null || body.isEmpty || _isSendingComment) {
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      final result = await _feedService.createComment(
        post.id,
        body,
        parentCommentId: activeReplyTarget?.parentCommentId,
        replyToUserId: activeReplyTarget?.replyToUserId,
      );
      if (!mounted) {
        return;
      }

      _commentController.clear();
      _commentFocusNode.unfocus();
      setState(() {
        if (activeReplyTarget != null) {
          final parentId = activeReplyTarget.parentCommentId;
          final existingReplies =
              _repliesByComment[parentId] ?? const <PostComment>[];
          _repliesByComment[parentId] = [result.comment, ...existingReplies]
              .fold<List<PostComment>>(<PostComment>[], (list, item) {
            if (list.any((existing) => existing.id == item.id)) {
              return list;
            }
            return [...list, item];
          });
          _expandedReplyThreads.add(parentId);
        } else {
          _comments = [result.comment, ..._comments];
        }
        _post = post.copyWith(commentCount: result.commentCount);
        _activeReplyTarget = null;
        _isSendingComment = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingComment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment was not sent.')),
      );
    }
  }

  void _startReply(PostComment comment) {
    setState(() {
      _activeReplyTarget = _ReplyTarget(
        parentCommentId: comment.id,
        replyToUserId: comment.authorId,
        displayName: comment.displayName,
      );
    });

    _commentFocusNode.requestFocus();
  }

  void _startReplyToReply(PostComment parentComment, PostComment replyComment) {
    setState(() {
      _activeReplyTarget = _ReplyTarget(
        parentCommentId: parentComment.id,
        replyToUserId: replyComment.authorId,
        displayName: replyComment.displayName,
      );
      _expandedReplyThreads.add(parentComment.id);
    });

    _commentFocusNode.requestFocus();
  }

  void _clearReplyTarget() {
    if (_activeReplyTarget == null) {
      return;
    }

    setState(() {
      _activeReplyTarget = null;
    });
  }

  Future<void> _toggleReplies(PostComment comment) async {
    final commentId = comment.id;
    if (_expandedReplyThreads.contains(commentId)) {
      setState(() {
        _expandedReplyThreads.remove(commentId);
      });
      return;
    }

    setState(() {
      _expandedReplyThreads.add(commentId);
    });

    if (_repliesByComment.containsKey(commentId) ||
        _loadingReplyThreads.contains(commentId)) {
      return;
    }

    setState(() {
      _loadingReplyThreads.add(commentId);
    });

    try {
      final replies = await _feedService.loadCommentReplies(commentId);
      if (!mounted) {
        return;
      }
      setState(() {
        _repliesByComment[commentId] = replies;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingReplyThreads.remove(commentId);
        });
      }
    }
  }

  void _openImages(int index) {
    final post = _post;
    if (post == null) {
      return;
    }

    if (post.imageUrls.length == 1) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ImageViewerScreen(
            imageUrls: post.imageUrls,
            initialIndex: index,
            post: post,
            currentUser: widget.currentUser,
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
          currentUser: widget.currentUser,
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

  void _openAuthor() {
    final post = _post;
    if (post == null) {
      return;
    }

    final authorUsername = post.authorUsername.trim();
    if (authorUsername.isEmpty) {
      return;
    }

    if (_isCurrentUser(authorUsername)) {
      widget.onOpenCurrentUserProfile?.call();
      Navigator.of(context).maybePop();
      return;
    }

    final onOpenUserProfile = widget.onOpenUserProfile;
    if (onOpenUserProfile != null) {
      onOpenUserProfile(authorUsername);
      Navigator.of(context).maybePop();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: authorUsername),
      ),
    );
  }

  void _openOriginalPost() {
    final originalPost = _post?.originalPost;
    if (originalPost == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: originalPost.id,
          initialPost: originalPost,
          currentUser: widget.currentUser,
          onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
          onOpenUserProfile: widget.onOpenUserProfile,
        ),
      ),
    );
  }

  bool _isCurrentUser(String username) {
    final currentUsername =
        widget.currentUser?.username?.trim().toLowerCase() ?? '';
    return currentUsername.isNotEmpty &&
        username.trim().toLowerCase() == currentUsername;
  }

  void _sharePost() {
    final post = _post;
    if (post == null) {
      return;
    }

    SharePostSheet.show(
      context,
      post: post,
      currentUser: widget.currentUser,
    );
  }

  Future<void> _repostPost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final repostedPost = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => RepostPostScreen(
          originalPost: post,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (!mounted || repostedPost == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post reposted.')),
    );
  }

  Future<void> _bookmarkPost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    // Optimistically update UI
    setState(() {
      _post = post.copyWith(
        bookmarkedByMe: !post.bookmarkedByMe,
      );
    });

    try {
      final updatedPost = await _feedService.toggleBookmark(post);
      if (!mounted) {
        return;
      }

      setState(() {
        _post = updatedPost;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updatedPost.bookmarkedByMe
              ? 'Added to Bookmarks'
              : 'Removed from Bookmarks'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      // Rollback on error
      setState(() {
        _post = post;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to bookmark: $e')),
      );
    }
  }

  Future<void> _votePoll(int optionIndex) async {
    final post = _post;
    if (post == null || _isVotingPoll) {
      return;
    }

    setState(() {
      _isVotingPoll = true;
    });

    try {
      final updatedPost = await _feedService.votePoll(post, optionIndex);
      if (!mounted) return;
      setState(() {
        _post = updatedPost;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to vote right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVotingPoll = false;
        });
      }
    }
  }

  void _copyLinkPreview() {
    final post = _post;
    final preview = post?.resolvedLinkPreview;
    if (preview == null) {
      return;
    }

    if (post != null && post.youtubeVideoId.trim().isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YouTubePlayerScreen(
            videoId: post.youtubeVideoId.trim(),
            title: preview.title,
          ),
        ),
      );
      return;
    }

    if (preview.url.trim().isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: preview.url.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  List<PostComment> get _sortedComments {
    if (_sortMode == _CommentSortMode.newest) {
      final sorted = List<PostComment>.from(_comments);
      sorted.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(1970);
        final dateB = b.createdAt ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return sorted;
    } else {
      final sorted = List<PostComment>.from(_comments);
      sorted.sort((a, b) {
        final scoreA = _calculateScore(a);
        final scoreB = _calculateScore(b);
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        final dateA = a.createdAt ?? DateTime(1970);
        final dateB = b.createdAt ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return sorted;
    }
  }

  int _calculateScore(PostComment comment) {
    int score = 0;
    score += comment.likeCount * 3;
    score += comment.replyCount * 5;
    if (comment.authorIsAuthor) score += 100;
    if (comment.authorIsAdmin) score += 40;
    if (comment.authorIsVerified) score += 40;
    return score;
  }

  Future<void> _toggleLikeComment(PostComment comment) async {
    try {
      final updated = await _feedService.toggleCommentLike(comment);
      setState(() {
        if (comment.parentCommentId == null) {
          final idx = _comments.indexWhere((c) => c.id == comment.id);
          if (idx != -1) {
            final list = List<PostComment>.from(_comments);
            list[idx] = updated;
            _comments = list;
          }
        } else {
          final parentId = comment.parentCommentId!;
          final replyList = _repliesByComment[parentId];
          if (replyList != null) {
            final idx = replyList.indexWhere((r) => r.id == comment.id);
            if (idx != -1) {
              final list = List<PostComment>.from(replyList);
              list[idx] = updated;
              _repliesByComment[parentId] = list;
            }
          }
        }
      });
    } catch (_) {}
  }

  Widget _buildSortModeBar(BuildContext context) {
    if (_isLoadingComments || _comments.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showSortModeSelectionMenu(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sortMode == _CommentSortMode.relevance
                      ? 'Most Relevant'
                      : 'Newest First',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE4E6EB)
                        : const Color(0xFF65676B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark
                      ? const Color(0xFFB0B3B8)
                      : const Color(0xFF65676B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSortModeSelectionMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? Colors.white70 : Colors.black87;

    SmoothBottomSheetRoute.show<void>(
      context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.star_rounded,
                  color: _sortMode == _CommentSortMode.relevance
                      ? const Color(0xFFFF7A45)
                      : tileColor,
                ),
                title: Text(
                  'Most Relevant',
                  style: TextStyle(
                    fontWeight: _sortMode == _CommentSortMode.relevance
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: const Text(
                    'Shows comments with more likes, replies, and author responses first.'),
                onTap: () {
                  setState(() {
                    _sortMode = _CommentSortMode.relevance;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.access_time_rounded,
                  color: _sortMode == _CommentSortMode.newest
                      ? const Color(0xFFFF7A45)
                      : tileColor,
                ),
                title: Text(
                  'Newest First',
                  style: TextStyle(
                    fontWeight: _sortMode == _CommentSortMode.newest
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: const Text(
                    'Shows comments in chronological order, with the newest at the top.'),
                onTap: () {
                  setState(() {
                    _sortMode = _CommentSortMode.newest;
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCommentActionsMenu(PostComment comment,
      {required VoidCallback onReply}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? Colors.white70 : Colors.black87;

    SmoothBottomSheetRoute.show<void>(
      context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.reply_rounded, color: tileColor),
                title: Text('Reply', style: TextStyle(color: tileColor)),
                onTap: () {
                  Navigator.pop(context);
                  onReply();
                },
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: tileColor),
                title: Text('Copy text', style: TextStyle(color: tileColor)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: comment.body));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_rounded, color: tileColor),
                title: Text('Share comment', style: TextStyle(color: tileColor)),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(comment.body);
                },
              ),
              ListTile(
                leading: Icon(Icons.history_rounded, color: tileColor),
                title:
                    Text('View edit history', style: TextStyle(color: tileColor)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'No edit history available for this comment.')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.visibility_off_rounded, color: tileColor),
                title: Text('Hide comment', style: TextStyle(color: tileColor)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _comments =
                        _comments.where((c) => c.id != comment.id).toList();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment hidden.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem_rounded,
                    color: Colors.redAccent),
                title: const Text('Report comment',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportCommentDialog(comment.id);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportCommentDialog(int commentId) async {
    final reasons = [
      'Spam or misleading',
      'Harassment or hate speech',
      'Inappropriate content',
      'Intellectual property violation',
      'Other'
    ];
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Comment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedReason == null) {
      return;
    }

    final ok = await _feedService.reportComment(commentId, selectedReason!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Thank you for reporting this comment. We will review it shortly.')),
    );
  }

  String _authorTitle() {
    final post = _post;
    if (post == null) {
      return 'Post';
    }

    final fullName = post.authorFullName.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    return post.authorUsername.trim();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isGemini =
        post != null && post.authorUsername.toLowerCase() == 'gemini';
    final isDaisy =
        post != null && post.authorUsername.toLowerCase() == 'daisy';
    final double gradientHeight =
        (post != null && post.isDiscussion) ? 140.0 : 75.0;
    final double daisyStickerHeight =
        (post != null && post.isDiscussion) ? 140.0 : 75.0;
    final double daisyStickerTop = 0.0;
    final double hunterStickerHeight =
        (post != null && post.isDiscussion) ? 128.0 : 78.0;
    final double wolfStickerHeight =
        (post != null && post.isDiscussion) ? 124.0 : 76.0;
    final postcardTheme =
        (post?.authorPostcardTheme ?? '').trim().toLowerCase();
    final showSunrise =
        postcardTheme == 'sunrise' || (postcardTheme.isEmpty && isDaisy);
    final showOcean = postcardTheme == 'ocean';
    final showBee = postcardTheme == 'bee';
    final showEagle = postcardTheme == 'eagle';
    final showPinkSwan = postcardTheme == 'pinkswan';
    final showDandelion = postcardTheme == 'dandelion';
    final showGtaPastel = postcardTheme == 'gta_pastel';
    final showSharinganEyes = postcardTheme == 'sharingan_eyes';
    final showPastel = postcardTheme == 'pastel';
    final showLavender = postcardTheme == 'lavender';
    final showPhFlag = postcardTheme == 'ph_flag';
    final showXmasCozy = postcardTheme == 'xmas_cozy';
    final showXmasSnowy = postcardTheme == 'xmas_snowy';
    final showBunny = postcardTheme == 'bunny';
    final showGhost = postcardTheme == 'ghost';
    final showPrince = postcardTheme == 'prince';
    final showCuteHeart = postcardTheme == 'cute_heart';
    final showGeminiRogerHunter =
        isGemini && postcardTheme == 'gemini_roger_hunter';
    final showGeminiRogerWolf =
        isGemini && postcardTheme == 'gemini_roger_wolf';
    final showThemeBackdrop = showGeminiRogerHunter ||
        showGeminiRogerWolf ||
        showSunrise ||
        showOcean ||
        showBee ||
        showEagle ||
        showPinkSwan ||
        showDandelion ||
        showGtaPastel ||
        showSharinganEyes ||
        showPastel ||
        showLavender ||
        showPhFlag ||
        showXmasCozy ||
        showXmasSnowy ||
        showBunny ||
        showGhost ||
        showPrince;
    final activeBackdropHeight = showGeminiRogerHunter
        ? hunterStickerHeight
        : showGeminiRogerWolf
            ? wolfStickerHeight
            : (showSunrise ||
                    showOcean ||
                    showBee ||
                    showEagle ||
                    showPinkSwan ||
                    showDandelion ||
                    showGtaPastel ||
                    showSharinganEyes ||
                    showPastel ||
                    showLavender ||
                    showPhFlag ||
                    showXmasCozy ||
                    showXmasSnowy ||
                    showBunny ||
                    showGhost ||
                    showPrince)
                ? daisyStickerHeight
                : gradientHeight;
    final backdropFadeTop = (activeBackdropHeight - 14).clamp(0.0, 10000.0);

    final colorScheme = Theme.of(context).colorScheme;

    return NormalVideoOverlayHost(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          foregroundColor: colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          centerTitle: true,
          title: Text(
            _authorTitle(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: const [
            SizedBox(width: 48),
          ],
        ),
        body: _isLoadingPost && post == null
            ? const _PostDetailSkeleton()
            : post == null
                ? const Center(child: Text('Post unavailable.'))
                : CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            if (showGeminiRogerHunter) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFF8FAFC),
                                        Color(0xFFE2E8F0),
                                        Color(0xFFDCE7F2),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.62, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: hunterStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.56,
                                        0.86,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/gemini_roger_hunter_v1.png',
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0.4, -0.2),
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                            ] else if (showGeminiRogerWolf) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFF8FAFC),
                                        Color(0xFFDBEAFE),
                                        Color(0xFFD9EAFE),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.62, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: wolfStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.56,
                                        0.86,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/gemini_roger_wolf_v1.png',
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0.7, -0.05),
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                            ] else if (showSunrise) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(
                                            0xFFB3E5FC), // Light Blue (top sky)
                                        Color(
                                            0xFFFFE082), // Warm Sunrise Gold (mid sky/sun glow)
                                        Color(0xFFFFF9C4), // Soft Yellow
                                        Colors
                                            .white, // Fades smoothly to white at the bottom
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/sunrise_sticker.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/sunrise_sticker.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showOcean) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF0F3D6E),
                                        Color(0xFF1D6FA5),
                                        Color(0xFFBFEAF2),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.38, 0.68, 0.88, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/ocean_sticker_v3.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/ocean_sticker_v3.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showBee) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFCF0),
                                        Color(0xFFFFF7D6),
                                        Color(0xFFFFF4CC),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/bee_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/bee_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showEagle) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFCF6),
                                        Color(0xFFF6E9D1),
                                        Color(0xFFEFD7B0),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/eagle_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/eagle_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showPinkSwan) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFCFD),
                                        Color(0xFFFCE7F3),
                                        Color(0xFFFBCFE8),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/pinkswan_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/pinkswan_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showDandelion) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFDF7),
                                        Color(0xFFFEF9C3),
                                        Color(0xFFECFCCB),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/dandelion_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/dandelion_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showGtaPastel) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFCF8),
                                        Color(0xFFFCE7F3),
                                        Color(0xFFCCFBF1),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/gta_pastel_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/gta_pastel_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showSharinganEyes) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFCFD),
                                        Color(0xFFFDE2E8),
                                        Color(0xFFFECACA),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/sharingan_eyes_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/sharingan_eyes_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showPastel) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFBF8),
                                        Color(0xFFF8E8F7),
                                        Color(0xFFEAF7F3),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/pastel_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/pastel_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showLavender) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFAF8FF),
                                        Color(0xFFF1E9FF),
                                        Color(0xFFE3D3FF),
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.7,
                                        1.0,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/lavender_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/lavender_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showPhFlag) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(
                                            0xFFF9FAFB), // left: softest off-white
                                        Color(0xFFEFF6FF), // soft blue
                                        Color(0xFFDBEAFE), // stronger blue
                                        Color(0xFFFEE2E2), // stronger red
                                      ],
                                      stops: [0.0, 0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.62,
                                        0.9,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/ph_flag_sticker_v1.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/ph_flag_sticker_v1.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showXmasCozy) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(
                                            0xFFFCFBF7), // left: soft warm white
                                        Color(0xFFFDF4F4), // soft warm red tint
                                        Color(0xFFFCA5A5), // stronger red
                                        Color(0xFFFEF08A), // strong gold/yellow
                                      ],
                                      stops: [0.0, 0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.62,
                                        0.9,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(imageUrl: 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/xmas_cozy_sticker.png', memCacheWidth: 600, memCacheHeight: 300, fit: BoxFit.cover, fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero, placeholder: (context, url) => const SizedBox(), errorWidget: (context, url, error) => Image.asset('assets/images/xmas_cozy_sticker.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                                ),
                              ),
                            ] else if (showXmasSnowy) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(
                                            0xFFF8FAFC), // left: soft ice white
                                        Color(0xFFF0F9FF), // soft blue tint
                                        Color(
                                            0xFFBAE6FD), // stronger frosty blue
                                        Color(0xFF7DD3FC), // strong winter blue
                                      ],
                                      stops: [0.0, 0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.62,
                                        0.9,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/xmas_snowy_sticker.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.centerRight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                            ] else if (showBunny) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFFFFDFB),
                                        Color(0xFFFFF5F7),
                                        Color(0xFFFCE7F3),
                                        Color(0xFFFBCFE8),
                                      ],
                                      stops: [0.0, 0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.62,
                                        0.9,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/bunny_sticker_v1.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.centerRight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                            ] else if (showGhost) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFFAF9FD),
                                        Color(0xFFF3F0FA),
                                        Color(0xFFE9E3F8),
                                        Color(0xFFDCD3F5),
                                      ],
                                      stops: [0.0, 0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.62,
                                        0.9,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/ghost_sticker_v1.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.centerRight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                            ] else if (showPrince) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFF0F7FF),
                                        Color(0xFFE0EFFF),
                                        Color(0xFFBAE0FF),
                                        Color(0xFF7DD3FC),
                                      ],
                                      stops: [0.0, 0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: daisyStickerTop,
                                height: daisyStickerHeight,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        0.62,
                                        0.9,
                                      ],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Image.asset(
                                    'assets/images/prince_sticker_v1.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.centerRight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                            ] else if (showCuteHeart) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: gradientHeight,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFFBFD),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFF7D4E3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                top: post.isDiscussion ? 8 : 6,
                                child: _CuteHeartWingBadge(
                                  large: post.isDiscussion,
                                ),
                              ),
                            ],
                            if (showThemeBackdrop)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: backdropFadeTop,
                                height: 28,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          colorScheme.surface.withValues(alpha: 0.0),
                                          colorScheme.surface.withValues(alpha: 0.82),
                                          colorScheme.surface,
                                        ],
                                        stops: const [0.0, 0.58, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: GestureDetector(
                                    onTap: _openAuthor,
                                    child: _PostMetaRow(post: post),
                                  ),
                                ),
                                if (post.displayTitle.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      post.displayTitle,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                                if (post.text.trim().isNotEmpty &&
                                    !(post.isPoll &&
                                        post.text.trim() ==
                                            post.pollQuestion.trim())) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: ExpandablePostText(
                                      text: post.text.trim(),
                                      expanded: _isTextExpanded,
                                      onToggle: () {
                                        setState(() {
                                          _isTextExpanded = !_isTextExpanded;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                                if (post.isPoll) ...[
                                  const SizedBox(height: 14),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: _PostDetailPoll(
                                      post: post,
                                      isBusy: _isVotingPoll,
                                      onVote: _votePoll,
                                    ),
                                  ),
                                ],
                                if (post.originalPost != null) ...[
                                  const SizedBox(height: 14),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: RepostSourcePreview(
                                      post: post.originalPost!,
                                      onTap: _openOriginalPost,
                                    ),
                                  ),
                                ],
                                if (post.resolvedLinkPreview != null &&
                                    post.imageUrls.isEmpty) ...[
                                  const SizedBox(height: 14),
                                  if (post.youtubeVideoId.trim().isNotEmpty)
                                    _PostDetailYouTubePreviewCard(
                                      preview: post.resolvedLinkPreview!,
                                      onTap: _copyLinkPreview,
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: _PostDetailLinkPreviewCard(
                                        preview: post.resolvedLinkPreview!,
                                        isYouTube: false,
                                        onTap: _copyLinkPreview,
                                      ),
                                    ),
                                ],
                                if (post.imageUrls.isNotEmpty || post.hasVideo) ...[
                                  const SizedBox(height: 14),
                                  SensitiveContentWrapper(
                                    isSensitive: post.isSensitive,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (post.imageUrls.isNotEmpty) ...[
                                          (post.imageUrls.length > 1 &&
                                                  (post.hasMusicPreview || post.isAlbum))
                                              ? MusicPhotoCarousel(
                                                  post: post,
                                                  activeIndex: _musicCarouselIndex.clamp(0, post.imageUrls.length - 1).toInt(),
                                                  onPageChanged: (index) {
                                                    setState(() {
                                                      _musicCarouselIndex = index;
                                                    });
                                                  },
                                                  onImageTap: _openImages,
                                                )
                                              : PostImageGrid(
                                                  imageUrls: post.imageUrls,
                                                  initialAspectRatios: post.imageAspectRatios,
                                                  postId: post.id,
                                                  onImageTap: _openImages,
                                                ),
                                        ],
                                        if (post.hasVideo) ...[
                                          if (post.imageUrls.isNotEmpty)
                                            const SizedBox(height: 14),
                                          _PostDetailVideoPreview(post: post),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _PostDetailReactionRow(
                                    post: post,
                                    onLike: _toggleLike,
                                    onComment: _focusCommentComposer,
                                    onRepost: _repostPost,
                                    onShare: _sharePost,
                                    onBookmark: _bookmarkPost,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _CommentsSummaryHeader(
                                    commentCount: post.commentCount,
                                    isLoadingMore: _isLoadingMoreComments,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _buildSortModeBar(context),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingComments)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                            child: _PostCommentsSkeletonList(),
                          ),
                        )
                      else if (_comments.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                            child: Text(
                              'No comments yet.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          sliver: SliverList.separated(
                            itemCount: _sortedComments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final comment = _sortedComments[index];
                              final replies = _repliesByComment[comment.id] ??
                                  const <PostComment>[];
                              final isRepliesExpanded =
                                  _expandedReplyThreads.contains(comment.id);
                              final isLoadingReplies =
                                  _loadingReplyThreads.contains(comment.id);

                              return _CommentThreadBlock(
                                comment: comment,
                                replies: replies,
                                isRepliesExpanded: isRepliesExpanded,
                                isLoadingReplies: isLoadingReplies,
                                onLike: () => _toggleLikeComment(comment),
                                onReply: () => _startReply(comment),
                                onToggleReplies: comment.replyCount > 0
                                    ? () => _toggleReplies(comment)
                                    : null,
                                onReplyToReply: (reply) =>
                                    _startReplyToReply(comment, reply),
                                onLongPressComment: (c) => _showCommentActionsMenu(
                                  c,
                                  onReply: () => _startReply(c),
                                ),
                                commentKey: _commentKeys.putIfAbsent(
                                    comment.id, () => GlobalKey()),
                                replyKeyResolver: (id) => _commentKeys
                                    .putIfAbsent(id, () => GlobalKey()),
                                highlightedCommentId: _highlightedCommentId,
                              );
                            },
                          ),
                        ),
                      if (_isLoadingMoreComments)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
                            child: _PostCommentSkeleton(compact: true),
                          ),
                        ),
                    ],
                  ),
        bottomNavigationBar: post == null
            ? null
            : AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: SafeArea(
                  top: false,
                  bottom: keyboardInset <= 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2F3031)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeReplyTarget != null)
                            _ReplyingToBar(
                              name: _activeReplyTarget!.displayName,
                              onClose: _clearReplyTarget,
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: _commentController,
                                      focusNode: _commentFocusNode,
                                      minLines: 1,
                                      maxLines: 4,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendInlineComment(),
                                      inputFormatters: [EmojiPresentationFormatter()],
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: _activeReplyTarget == null
                                            ? 'Add a comment...'
                                            : 'Reply to ${_activeReplyTarget!.displayName}...',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                        ),
                                        filled: true,
                                        fillColor: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF2D2E30)
                                            : const Color(0xFFF3F4F6),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFD1D5DB),
                                          ),
                                        ),
                                      ),
                                    ),
                                    MentionAutocomplete(
                                      controller: _commentController,
                                      focusNode: _commentFocusNode,
                                      enabled: !_isSendingComment,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 42,
                                child: FilledButton(
                                  onPressed: _isSendingComment
                                      ? null
                                      : _sendInlineComment,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF7A45),
                                    disabledBackgroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2D2E30)
                                        : const Color(0xFFD1D5DB),
                                    disabledForegroundColor: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF6B7280)
                                        : const Color(0xFF9CA3AF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: _isSendingComment
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Send',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PostDetailYouTubePreviewCard extends StatelessWidget {
  const _PostDetailYouTubePreviewCard({
    required this.preview,
    required this.onTap,
  });

  final LinkPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : 'YouTube video';
    final description = preview.description.trim();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                else
                  _fallback(),
                Container(color: Colors.black.withValues(alpha: 0.22)),
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCCDC2626),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Color(0xFF6B7280),
          size: 44,
        ),
      ),
    );
  }
}

class _PostDetailLinkPreviewCard extends StatelessWidget {
  const _PostDetailLinkPreviewCard({
    required this.preview,
    required this.onTap,
    this.isYouTube = false,
  });

  final LinkPreview preview;
  final VoidCallback onTap;
  final bool isYouTube;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : preview.domain.trim();
    final description = preview.description.trim();
    final domain = preview.domain.trim().isNotEmpty
        ? preview.domain.trim()
        : preview.url.trim();

    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 1.91,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isYouTube) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'YouTube',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(
          isYouTube ? Icons.play_circle_outline_rounded : Icons.link_rounded,
          color: const Color(0xFF6B7280),
          size: 34,
        ),
      ),
    );
  }
}

class _PostMetaRow extends StatelessWidget {
  const _PostMetaRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE5E7EB),
          backgroundImage: post.authorAvatarUrl.trim().isEmpty
              ? null
              : NetworkImage(ApiConfig.assetUrl(post.authorAvatarUrl)),
          child: post.authorAvatarUrl.trim().isEmpty
              ? Text(
                  post.authorInitials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SpecialNameText(
                      username: post.authorUsername,
                      displayName: post.authorFullName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (post.authorIsVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Color(0xFF1D9BF0),
                    ),
                  ],
                ],
              ),
              if (post.withUsers.isNotEmpty) ...[
                const SizedBox(height: 3),
                PostWithUsersLine(
                  users: post.withUsers,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  linkStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  onUserTap: (username) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(username: username),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _formatTimestamp(post.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (post.privacyLabel.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _getPrivacyIcon(post.visibility),
                      color: const Color(0xFF6B7280),
                      size: 13,
                    ),
                  ],
                  if (post.originalPost != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    CustomIcons.repost(size: 12, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Flexible(
                    child: SpecialNameText(
                      username: post.originalPost!.authorUsername,
                      displayName: post.originalPost!.authorFullName,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ),
                    if (post.originalPost!.authorIsVerified) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF1D9BF0),
                        size: 13,
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Now';
    }

    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) {
      return 'Now';
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

    final month = monthNames[createdAt.month - 1];
    return '$month ${createdAt.day}, ${createdAt.year}';
  }
}

class _PostDetailVideoPreview extends StatefulWidget {
  const _PostDetailVideoPreview({required this.post});

  final Post post;

  @override
  State<_PostDetailVideoPreview> createState() =>
      _PostDetailVideoPreviewState();
}

class _PostDetailVideoPreviewState extends State<_PostDetailVideoPreview> {
  @override
  void initState() {
    super.initState();
    normalVideoPlaybackSession.addListener(_handleSessionChanged);
  }

  @override
  void dispose() {
    normalVideoPlaybackSession.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final posterUrl = post.primaryVideoPosterUrl.trim();
    final ratio =
        (post.mediaAspectRatio ?? post.aspectRatio ?? 1.0).clamp(0.65, 1.91);

    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final showInlineVideo = session.isActivePost(post.id) &&
        !session.viewerOpen &&
        controller != null &&
        controller.value.isInitialized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (session.viewerOpen) {
          session.setViewerOpen(false);
        }
        if (session.isActivePost(post.id) && controller != null && controller.value.isInitialized) {
          if (session.isPlaying) {
            session.pause();
          } else {
            session.play(muted: normalVideoMuted());
          }
          return;
        }
        session.activate(
          post,
          play: true,
          muted: normalVideoMuted(),
          reason: 'post detail inline tap',
        );
      },
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showInlineVideo)
              IgnorePointer(
                ignoring: true,
                child: _PostDetailInlineVideoCover(controller: controller),
              )
            else if (posterUrl.isNotEmpty)
              Image.network(
                ApiConfig.assetUrl(posterUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            else
              _fallback(),
            if (!showInlineVideo)
              Container(color: Colors.black.withValues(alpha: 0.18)),
            if (!showInlineVideo || !session.isPlaying)
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Icon(
        Icons.videocam_outlined,
        color: Color(0xFF6B7280),
        size: 44,
      ),
    );
  }
}

class _PostDetailInlineVideoCover extends StatelessWidget {
  const _PostDetailInlineVideoCover({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return VideoPlayer(controller);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _PostDetailPoll extends StatelessWidget {
  const _PostDetailPoll({
    required this.post,
    required this.isBusy,
    required this.onVote,
  });

  final Post post;
  final bool isBusy;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final options = post.pollOptions;
    if (options.length < 2) return const SizedBox.shrink();

    final votes = [
      for (var index = 0; index < options.length; index++)
        index < post.pollOptionVotes.length ? post.pollOptionVotes[index] : 0,
    ];
    final totalVotes = post.pollVotes > 0
        ? post.pollVotes
        : votes.fold<int>(0, (sum, count) => sum + count);
    final hasEnded =
        post.pollEndTime != null && !post.pollEndTime!.isAfter(DateTime.now());
    final showResults = post.hasVoted || hasEnded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            post.pollQuestion.isNotEmpty ? post.pollQuestion : 'Poll',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++) ...[
            _PostDetailPollOption(
              label: options[index],
              votes: votes[index],
              totalVotes: totalVotes,
              selected: post.selectedOptionIndex == index,
              showResults: showResults,
              voters: post.pollVoters
                  .where((voter) => voter.optionIndex == index)
                  .toList(growable: false),
              enabled: !isBusy && !hasEnded,
              onTap: () => onVote(index),
            ),
            if (index != options.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Text(
            _meta(totalVotes, hasEnded),
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _meta(int totalVotes, bool hasEnded) {
    final voteText = totalVotes == 1 ? '1 vote' : '$totalVotes votes';
    if (hasEnded) return '$voteText - Poll ended';
    final endTime = post.pollEndTime;
    if (endTime == null) return voteText;
    final remaining = endTime.difference(DateTime.now());
    if (remaining.inDays >= 1) return '$voteText - ${remaining.inDays}d left';
    if (remaining.inHours >= 1) return '$voteText - ${remaining.inHours}h left';
    final minutes = remaining.inMinutes.clamp(1, 59);
    return '$voteText - ${minutes}m left';
  }
}

class _PostDetailPollOption extends StatelessWidget {
  const _PostDetailPollOption({
    required this.label,
    required this.votes,
    required this.totalVotes,
    required this.selected,
    required this.showResults,
    required this.voters,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int votes;
  final int totalVotes;
  final bool selected;
  final bool showResults;
  final List<PollVoterPreview> voters;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = totalVotes <= 0 ? 0.0 : (votes / totalVotes).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: showResults && voters.isNotEmpty ? 66 : 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
              width: selected ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: showResults ? ratio : 0,
                child: ColoredBox(
                  color: selected
                      ? const Color(0x332563EB)
                      : const Color(0xFFEFF4FF),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 0, 12, showResults && voters.isNotEmpty ? 18 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.12, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: showResults
                          ? Padding(
                              key: const ValueKey('poll-percent'),
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '$percent%',
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('poll-percent-hidden'),
                            ),
                    ),
                  ],
                ),
              ),
              if (showResults && voters.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 7,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _PollVoterAvatarStack(
                      key: ValueKey('poll-voters-${voters.length}'),
                      voters: voters,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollVoterAvatarStack extends StatelessWidget {
  const _PollVoterAvatarStack({required this.voters, super.key});

  final List<PollVoterPreview> voters;

  @override
  Widget build(BuildContext context) {
    final visible = voters.take(5).toList(growable: false);
    final extra = voters.length - visible.length;
    const avatarSize = 22.0;
    const overlap = 14.0;
    final width = visible.isEmpty
        ? 0.0
        : avatarSize + ((visible.length - 1) * overlap) + (extra > 0 ? 30 : 0);

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * overlap,
              child: _PollVoterAvatar(voter: visible[index], size: avatarSize),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * overlap,
              child: Container(
                width: 28,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PollVoterAvatar extends StatelessWidget {
  const _PollVoterAvatar({required this.voter, required this.size});

  final PollVoterPreview voter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = voter.avatarUrl.trim();
    return Tooltip(
      message: voter.displayName,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE5E7EB),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl.isEmpty
            ? Center(
                child: Text(
                  voter.initials,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                ApiConfig.assetUrl(avatarUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    voter.initials,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PostDetailReactionRow extends StatelessWidget {
  const _PostDetailReactionRow({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
    required this.onBookmark,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFF4B5563);
    const likedColor = Color(0xFFE11D48);

    return Row(
      children: [
        _PostDetailActionIcon(
          icon: post.likedByMe
              ? CustomIcons.heartFilled(color: likedColor, size: 23)
              : CustomIcons.heart(color: inactiveColor, size: 23),
          count: post.likeCount,
          color: post.likedByMe ? likedColor : inactiveColor,
          onTap: onLike,
        ),
        const SizedBox(width: 24),
        _PostDetailActionIcon(
          icon: CustomIcons.comment(color: inactiveColor, size: 23),
          count: post.commentCount,
          color: inactiveColor,
          onTap: onComment,
        ),
        const SizedBox(width: 24),
        _PostDetailActionIcon(
          icon: CustomIcons.repost(color: inactiveColor, size: 23),
          count: post.repostCount,
          color: inactiveColor,
          onTap: onRepost,
        ),
        const SizedBox(width: 24),
        _PostDetailActionIcon(
          icon: CustomIcons.share(color: inactiveColor, size: 23),
          count: 0,
          color: inactiveColor,
          onTap: onShare,
        ),
        const Spacer(),
        _PostDetailActionIcon(
          icon: CustomIcons.bookmark(
            color: post.bookmarkedByMe
                ? Theme.of(context).colorScheme.primary
                : inactiveColor,
            size: 23,
            isFilled: post.bookmarkedByMe,
          ),
          count: 0,
          color: post.bookmarkedByMe
              ? Theme.of(context).colorScheme.primary
              : inactiveColor,
          onTap: onBookmark,
        ),
      ],
    );
  }
}

class _PostDetailActionIcon extends StatelessWidget {
  const _PostDetailActionIcon({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final Widget icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  String _formatCount(int value) {
    if (value >= 1000000) {
      double val = value / 1000000.0;
      String str = val.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}M';
    }
    if (value >= 1000) {
      double val = value / 1000.0;
      String str = val.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentsSummaryHeader extends StatelessWidget {
  const _CommentsSummaryHeader({
    required this.commentCount,
    required this.isLoadingMore,
  });

  final int commentCount;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    final label = commentCount == 1 ? '1 comment' : '$commentCount comments';

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (isLoadingMore)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _CuteHeartWingBadge extends StatelessWidget {
  const _CuteHeartWingBadge({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final heartSize = large ? 34.0 : 24.0;
    final wingHeight = large ? 18.0 : 13.0;
    final wingWidth = large ? 14.0 : 10.0;
    final sparkleSize = large ? 8.0 : 6.0;

    Widget wing({required bool left}) {
      final feathers = [0.0, 5.0, 10.0];
      return SizedBox(
        width: wingWidth + 10,
        height: wingHeight + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final offset in feathers)
              Positioned(
                left: left ? null : offset,
                right: left ? offset : null,
                top: offset * 0.35,
                child: Transform.rotate(
                  angle: left ? -0.55 : 0.55,
                  child: Container(
                    width: wingWidth,
                    height: wingHeight - (offset * 0.22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFF0C8DA),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: large ? 84 : 62,
      height: large ? 54 : 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            left: large ? 0 : 2,
            top: large ? 9 : 7,
            child: wing(left: true),
          ),
          Positioned(
            right: large ? 18 : 12,
            top: large ? 9 : 7,
            child: wing(left: false),
          ),
          Positioned(
            right: 0,
            top: large ? 8 : 6,
            child: Container(
              width: large ? 42 : 30,
              height: large ? 42 : 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF0C5D7),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: const Color(0xFFF472B6),
                size: heartSize,
              ),
            ),
          ),
          Positioned(
            right: large ? 34 : 25,
            top: 0,
            child: Icon(
              Icons.auto_awesome,
              color: const Color(0xFFF9A8D4),
              size: sparkleSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostDetailSkeleton extends StatelessWidget {
  const _PostDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
        child: CustomScrollView(
      slivers: const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _PostDetailHeaderSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _PostDetailTextSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 14),
            child: _PostDetailMediaSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _PostDetailActionsSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _PostCommentsHeaderSkeleton(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: _PostCommentsSkeletonList(),
          ),
        ),
      ],
    ));
  }
}

class _PostDetailHeaderSkeleton extends StatelessWidget {
  const _PostDetailHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _SkeletonCircle(size: 36),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 132, height: 13),
              SizedBox(height: 8),
              _SkeletonBox(width: 92, height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostDetailTextSkeleton extends StatelessWidget {
  const _PostDetailTextSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBox(width: 154, height: 18),
        SizedBox(height: 12),
        _SkeletonBox(width: double.infinity, height: 12),
        SizedBox(height: 8),
        _SkeletonBox(width: 242, height: 12),
        SizedBox(height: 8),
        _SkeletonBox(width: 136, height: 12),
      ],
    );
  }
}

class _PostDetailMediaSkeleton extends StatelessWidget {
  const _PostDetailMediaSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 340,
      color: const Color(0xFFE6EBF2),
      child: const Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 14, bottom: 14),
          child: SkeletonBox(width: 84, height: 18, radius: 9),
        ),
      ),
    );
  }
}

class _PostDetailActionsSkeleton extends StatelessWidget {
  const _PostDetailActionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SkeletonBox(width: 28, height: 22, radius: 11),
        _SkeletonBox(width: 30, height: 22, radius: 11),
        _SkeletonBox(width: 27, height: 22, radius: 11),
        _SkeletonCircle(size: 24),
      ],
    );
  }
}

class _PostCommentsHeaderSkeleton extends StatelessWidget {
  const _PostCommentsHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _SkeletonBox(width: 108, height: 14),
      ],
    );
  }
}

class _PostCommentsSkeletonList extends StatelessWidget {
  const _PostCommentsSkeletonList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _PostCommentSkeleton(variant: 0),
        SizedBox(height: 16),
        _PostCommentSkeleton(variant: 1),
        SizedBox(height: 16),
        _PostCommentSkeleton(variant: 2),
      ],
    );
  }
}

class _PostCommentSkeleton extends StatelessWidget {
  const _PostCommentSkeleton({
    this.compact = false,
    this.variant = 0,
  });

  final bool compact;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 28.0 : 32.0;
    final messageWidth = switch (variant % 3) {
      0 => compact ? 98.0 : 132.0,
      1 => compact ? 118.0 : 152.0,
      _ => compact ? 86.0 : 116.0,
    };
    final secondLineWidth = switch (variant % 3) {
      0 => 190.0,
      1 => 228.0,
      _ => 166.0,
    };
    final thirdLineWidth = switch (variant % 3) {
      0 => 132.0,
      1 => 176.0,
      _ => 148.0,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonCircle(size: avatarSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: messageWidth, height: 12),
              const SizedBox(height: 8),
              const _SkeletonBox(width: double.infinity, height: 11),
              const SizedBox(height: 7),
              _SkeletonBox(width: secondLineWidth, height: 11),
              const SizedBox(height: 7),
              _SkeletonBox(width: thirdLineWidth, height: 10),
              const SizedBox(height: 10),
              Row(
                children: [
                  const _SkeletonBox(width: 28, height: 10),
                  SizedBox(width: 12),
                  _SkeletonBox(width: variant == 1 ? 42 : 34, height: 10),
                  SizedBox(width: 12),
                  _SkeletonBox(width: variant == 2 ? 46 : 34, height: 10),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: size, height: size, radius: size / 2);
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 999,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SkeletonBox(
        width: width,
        height: height,
        radius: radius,
      ),
    );
  }
}

class _InlineCommentRow extends StatelessWidget {
  const _InlineCommentRow({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onLongPress,
  });

  static const String _authorPenSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3 21h4.75L19.81 8.94003c.43-.43.43-1.12.0-1.55l-3.2-3.2c-.43-.43-1.12-.43-1.55.0L3 16.25V21z" stroke="#2563EB" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M13.5 5.5l5 5" stroke="#2563EB" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  final PostComment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onLongPress;

  void _openMention(BuildContext context, String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  void _openAuthor(BuildContext context) {
    final username = comment.authorUsername.trim();
    if (username.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: username,
          seedFullName: comment.authorFullName,
          seedAvatarUrl: comment.authorAvatarUrl,
          seedIsVerified: comment.authorIsVerified,
          seedIsAdmin: comment.authorIsAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.authorAvatarUrl.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openAuthor(context),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: avatarUrl.isEmpty
                ? null
                : CachedNetworkImageProvider(ApiConfig.assetUrl(avatarUrl)),
            child: avatarUrl.isEmpty
                ? Text(
                    comment.authorInitials,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: onLongPress,
                child: _CommentMessageBlock(
                  comment: comment,
                  authorPenSvg: _authorPenSvg,
                  onMentionTap: (username) => _openMention(context, username),
                  onAuthorTap: () => _openAuthor(context),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (comment.timeAgo.isNotEmpty)
                    Text(
                      comment.timeAgo,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: onReply,
                    child: const Text(
                      'Reply',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _CommentLikeButton(
          comment: comment,
          onLike: onLike,
        ),
      ],
    );
  }
}

class _CommentThreadBlock extends StatelessWidget {
  const _CommentThreadBlock({
    required this.comment,
    required this.replies,
    required this.isRepliesExpanded,
    required this.isLoadingReplies,
    required this.onLike,
    required this.onReply,
    required this.onReplyToReply,
    required this.onLongPressComment,
    this.onToggleReplies,
    this.commentKey,
    this.replyKeyResolver,
    this.highlightedCommentId,
  });

  final PostComment comment;
  final List<PostComment> replies;
  final bool isRepliesExpanded;
  final bool isLoadingReplies;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final ValueChanged<PostComment> onReplyToReply;
  final ValueChanged<PostComment> onLongPressComment;
  final VoidCallback? onToggleReplies;
  final GlobalKey? commentKey;
  final GlobalKey Function(int id)? replyKeyResolver;
  final int? highlightedCommentId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentHighlightFrame(
          key: commentKey,
          isHighlighted: highlightedCommentId == comment.id,
          child: _InlineCommentRow(
            comment: comment,
            onLike: onLike,
            onReply: onReply,
            onLongPress: () => onLongPressComment(comment),
          ),
        ),
        if (comment.replyCount > 0 || replies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: GestureDetector(
              onTap: onToggleReplies,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 1.5,
                    color: const Color(0xFFD1D5DB),
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Text(
                    isLoadingReplies
                        ? 'Loading replies...'
                        : isRepliesExpanded
                            ? 'Hide replies'
                            : 'View ${comment.replyCount} ${comment.replyCount == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(
                      color: isLoadingReplies
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF2563EB),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (isRepliesExpanded && replies.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Column(
              children: replies
                  .map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CommentHighlightFrame(
                        key: replyKeyResolver?.call(reply.id),
                        isHighlighted: highlightedCommentId == reply.id,
                        child: _InlineCommentRow(
                          comment: reply,
                          onLike: onLike,
                          onReply: () => onReplyToReply(reply),
                          onLongPress: () => onLongPressComment(reply),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _CommentHighlightFrame extends StatelessWidget {
  const _CommentHighlightFrame({
    required this.isHighlighted,
    required this.child,
    super.key,
  });

  final bool isHighlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF451A03)
                : const Color(0xFFFEF3C7))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _CommentMessageBlock extends StatelessWidget {
  const _CommentMessageBlock({
    required this.comment,
    required this.authorPenSvg,
    required this.onMentionTap,
    required this.onAuthorTap,
  });

  final PostComment comment;
  final String authorPenSvg;
  final ValueChanged<String> onMentionTap;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAuthorTap,
                child: SpecialNameText(
                  username: comment.authorUsername,
                  displayName: comment.displayName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (comment.authorIsAuthor) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.string(
                      authorPenSvg,
                      width: 11,
                      height: 11,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF2563EB),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Author',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF2563EB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        HashtagText(
          text: comment.body,
          style: TextStyle(
            inherit: false,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            height: 1.35,
          ),
          onHashtagTap: (_) {},
          onMentionTap: onMentionTap,
        ),
      ],
    );
  }
}

class _ReplyingToBar extends StatelessWidget {
  const _ReplyingToBar({
    required this.name,
    required this.onClose,
  });

  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Replying to $name',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyTarget {
  const _ReplyTarget({
    required this.parentCommentId,
    required this.replyToUserId,
    required this.displayName,
  });

  final int parentCommentId;
  final String? replyToUserId;
  final String displayName;
}

IconData _getPrivacyIcon(String visibility) {
  switch (visibility) {
    case 'friends':
      return Icons.people_alt_rounded;
    case 'only_me':
      return Icons.lock_rounded;
    default:
      return Icons.public_rounded;
  }
}

class _CommentLikeButton extends StatelessWidget {
  const _CommentLikeButton({
    required this.comment,
    required this.onLike,
  });

  final PostComment comment;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final isLiked = comment.likedByMe;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onLike,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(4),
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 15,
              color: isLiked ? Colors.redAccent : const Color(0xFF8E8E93),
            ),
          ),
        ),
        if (comment.likeCount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '${comment.likeCount}',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
