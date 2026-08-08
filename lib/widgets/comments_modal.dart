import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../theme/app_text_styles.dart';
import '../models/post_comment.dart';
import '../screens/hashtag_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/feed_service.dart';
import '../services/normal_video_overlay_controller.dart';
import '../utils/emoji_presentation.dart';
import 'hashtag_text.dart';
import 'loading_skeletons.dart';
import 'mention_autocomplete.dart';
import 'special_name_text.dart';
import 'user_avatar_with_frame.dart';

enum CommentSortMode {
  relevance,
  newest,
}

class CommentsPageRoute<T> extends PageRouteBuilder<T> {
  CommentsPageRoute({
    required Widget builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder,
          opaque: true,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 80),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return child;
          },
        );
}

Future<int?> showCommentsModal({
  required BuildContext context,
  required Post post,
  double? sheetHeight,
}) {
  HapticFeedback.lightImpact();
  return Navigator.of(context).push<int>(
    CommentsPageRoute(
      builder: _CommentsSheet(post: post, sheetHeight: sheetHeight),
    ),
  );
}

class _ReplyTarget {
  const _ReplyTarget({
    required this.parentCommentId,
    required this.displayName,
    this.replyToUserId,
  });

  final int parentCommentId;
  final String displayName;
  final String? replyToUserId;
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, this.sheetHeight});

  final Post post;
  final double? sheetHeight;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  static final Map<String, List<PostComment>> _commentsCache = {};
  static final Map<String, int> _commentsTotalCountCache = {};
  static final Map<String, bool> _commentsHasMoreCache = {};

  void _saveToCache() {
    final cleanPostId = widget.post.id.trim();
    if (cleanPostId.isNotEmpty) {
      _commentsCache[cleanPostId] = _comments;
      _commentsTotalCountCache[cleanPostId] = _totalCount;
      _commentsHasMoreCache[cleanPostId] = _hasMore;
    }
  }

  final FeedService _feedService = FeedService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  CommentSortMode _sortMode = CommentSortMode.relevance;
  List<PostComment> _comments = [];
  final Map<int, List<PostComment>> _repliesByComment = <int, List<PostComment>>{};
  final Set<int> _expandedReplyThreads = <int>{};
  final Set<int> _loadingReplyThreads = <int>{};
  int _totalCount = 0;
  int? _nextBeforeId;
  _ReplyTarget? _activeReplyTarget;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMore = false;
  String? _error;

  bool _transitionCompleted = false;
  bool _loadTriggered = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    final cleanPostId = widget.post.id.trim();
    final cached = _commentsCache[cleanPostId];
    if (cached != null) {
      _comments = List<PostComment>.from(cached);
      _totalCount = _commentsTotalCountCache[cleanPostId] ?? widget.post.commentCount;
      _hasMore = _commentsHasMoreCache[cleanPostId] ?? false;
      _isLoading = false;
    } else {
      _totalCount = widget.post.commentCount;
      _isLoading = true;
    }
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.animation != null && _routeAnimation == null) {
      _routeAnimation = route.animation;
      if (_routeAnimation!.isCompleted) {
        _transitionCompleted = true;
        if (!_loadTriggered) {
          _loadTriggered = true;
          _loadInitialComments();
        }
      } else {
        _routeAnimation!.addStatusListener(_handleRouteAnimationStatus);
      }
    }
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      if (mounted) {
        setState(() {
          _transitionCompleted = true;
        });
        if (!_loadTriggered) {
          _loadTriggered = true;
          _loadInitialComments();
        }
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    if (_scrollController.position.extentAfter < 260) {
      _loadMoreComments();
    }
  }

  Future<void> _loadInitialComments() async {
    final cleanPostId = widget.post.id.trim();
    final cached = _commentsCache[cleanPostId];

    if (cached == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final page = await _feedService.loadComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = page.comments;
        _totalCount = page.totalCount;
        _hasMore = page.hasMore;
        _nextBeforeId = page.nextBeforeId;
        _isLoading = false;
      });
      _saveToCache();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (cached == null) {
          _error = 'Unable to load comments.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    final beforeId = _nextBeforeId;
    if (beforeId == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _feedService.loadComments(
        widget.post.id,
        beforeId: beforeId,
      );
      if (!mounted) return;
      final existingIds = _comments.map((comment) => comment.id).toSet();
      setState(() {
        _comments = [
          ..._comments,
          ...page.comments
              .where((comment) => !existingIds.contains(comment.id)),
        ];
        _totalCount = page.totalCount;
        _hasMore = page.hasMore;
        _nextBeforeId = page.nextBeforeId;
        _isLoadingMore = false;
      });
      _saveToCache();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final body = _textController.text.trim();
    final activeReplyTarget = _activeReplyTarget;
    if (body.isEmpty || _isSending) {
      return;
    }

    final previousText = _textController.text;
    final previousTotalCount = _totalCount;
    final optimisticCount = _totalCount + 1;

    setState(() {
      _isSending = true;
      _totalCount = optimisticCount;
    });
    _textController.clear();
    FeedService.notifyCommentCountChanged(
      postId: widget.post.id,
      commentCount: optimisticCount,
    );

    try {
      final result = await _feedService.createComment(
        widget.post.id,
        body,
        parentCommentId: activeReplyTarget?.parentCommentId,
        replyToUserId: activeReplyTarget?.replyToUserId,
      );
      if (!mounted) return;
      _focusNode.unfocus();
      setState(() {
        if (activeReplyTarget != null) {
          final parentId = activeReplyTarget.parentCommentId;
          final existingReplies =
              _repliesByComment[parentId] ?? const <PostComment>[];
          _repliesByComment[parentId] = [...existingReplies, result.comment]
              .fold<List<PostComment>>(<PostComment>[], (list, item) {
            if (list.any((existing) => existing.id == item.id)) {
              return list;
            }
            return [...list, item];
          });
          _expandedReplyThreads.add(parentId);
          _comments = _comments
              .map((comment) => comment.id == parentId
                  ? _copyCommentWithReplyCount(
                      comment,
                      _repliesByComment[parentId]!.length,
                    )
                  : comment)
              .toList();
        } else {
          _comments = [result.comment, ..._comments];
        }
        _totalCount = result.commentCount;
        _activeReplyTarget = null;
        _isSending = false;
      });
      _saveToCache();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _totalCount = previousTotalCount;
      });
      if (_textController.text.isEmpty) {
        _textController.text = previousText;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      }
      FeedService.notifyCommentCountChanged(
        postId: widget.post.id,
        commentCount: previousTotalCount,
      );
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

    _focusNode.requestFocus();
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

    _focusNode.requestFocus();
  }

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagScreen(tag: tag),
      ),
    );
  }

  void _openMention(String username) {
    if (normalVideoOverlayController.isOpen) {
      normalVideoOverlayController.close();
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
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

    if (_repliesByComment.containsKey(commentId)) {
      setState(() {
        _expandedReplyThreads.add(commentId);
      });
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
        _expandedReplyThreads.add(commentId);
        _loadingReplyThreads.remove(commentId);
        _comments = _comments
            .map((item) => item.id == commentId
                ? _copyCommentWithReplyCount(item, replies.length)
                : item)
            .toList();
      });
      _saveToCache();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingReplyThreads.remove(commentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load replies.')),
      );
    }
  }

  List<PostComment> get _sortedComments {
    if (_sortMode == CommentSortMode.newest) {
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
            _comments[idx] = updated;
          }
        } else {
          final parentId = comment.parentCommentId!;
          final replyList = _repliesByComment[parentId];
          if (replyList != null) {
            final idx = replyList.indexWhere((r) => r.id == comment.id);
            if (idx != -1) {
              replyList[idx] = updated;
            }
          }
        }
      });
    } catch (_) {}
  }

  Widget _buildSortModeBar(BuildContext context, bool isDark) {
    if (_isLoading || _error != null || _comments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF18191A) : const Color(0xFFF7F8FA),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showSortModeSelectionMenu(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sortMode == CommentSortMode.relevance ? 'Most Relevant' : 'Newest First',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF65676B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
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

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF242526) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                  color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.star_rounded,
                  color: _sortMode == CommentSortMode.relevance ? const Color(0xFFFF7A45) : tileColor,
                ),
                title: Text(
                  'Most Relevant',
                  style: TextStyle(
                    fontWeight: _sortMode == CommentSortMode.relevance ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: const Text('Shows comments with more likes, replies, and author responses first.'),
                onTap: () {
                  setState(() {
                    _sortMode = CommentSortMode.relevance;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.access_time_rounded,
                  color: _sortMode == CommentSortMode.newest ? const Color(0xFFFF7A45) : tileColor,
                ),
                title: Text(
                  'Newest First',
                  style: TextStyle(
                    fontWeight: _sortMode == CommentSortMode.newest ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: const Text('Shows comments in chronological order, with the newest at the top.'),
                onTap: () {
                  setState(() {
                    _sortMode = CommentSortMode.newest;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F0F10) : const Color(0xFF707276);
    final sheetBg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    final route = ModalRoute.of(context);
    final animation = route?.animation ?? const AlwaysStoppedAnimation<double>(1.0);

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    final systemUiStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: sheetBg,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          HapticFeedback.lightImpact();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemUiStyle,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
            child: SlideTransition(
              position: slideAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity! > 300) {
                          Navigator.of(context).pop(_totalCount);
                        }
                      },
                      onVerticalDragUpdate: (details) {
                        if (details.primaryDelta! > 10) {
                          Navigator.of(context).pop(_totalCount);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          _CommentsHeader(
                            totalCount: _totalCount,
                            onClose: () => Navigator.of(context).pop(_totalCount),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
                  _buildSortModeBar(context, isDark),
                  Expanded(child: _buildBody()),
                    Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
                    _CommentComposer(
                      controller: _textController,
                      focusNode: _focusNode,
                      isSending: _isSending,
                      replyTarget: _activeReplyTarget,
                      onClearReplyTarget: _clearReplyTarget,
                      onSend: _sendComment,
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

  Widget _buildBody() {
    if (_isLoading) {
      return _CommentSkeletonList(pulse: _transitionCompleted);
    }

    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: _loadInitialComments,
          child: const Text('Retry loading comments'),
        ),
      );
    }

    final sorted = _sortedComments;
    if (sorted.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/nocomment.svg',
                width: 96,
                height: 96,
              ),
              const SizedBox(height: 14),
              const Text(
                'No comments yet.',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Be the first one to start the conversation!',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      cacheExtent: 1200,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: sorted.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= sorted.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: _CommentSkeletonTile(compact: true),
          );
        }

        final comment = sorted[index];
        final replies = _repliesByComment[comment.id] ?? const <PostComment>[];
        final isRepliesExpanded = _expandedReplyThreads.contains(comment.id);
        final isLoadingReplies = _loadingReplyThreads.contains(comment.id);

        return _CommentTile(
          key: ValueKey('comment-${_comments[index].id}'),
          comment: comment,
          replies: replies,
          isRepliesExpanded: isRepliesExpanded,
          isLoadingReplies: isLoadingReplies,
          onReply: _startReply,
          onToggleReplies:
              comment.replyCount > 0 ? _toggleReplies : null,
          onReplyToReply: _startReplyToReply,
          onHashtagTap: _openHashtag,
          onMentionTap: _openMention,
          onLikeComment: _toggleLikeComment,
        );
      },
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({
    required this.totalCount,
    required this.onClose,
  });

  final int totalCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Center(
              child: Text(
                totalCount == 1 ? '1 comment' : '$totalCount comments',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 22),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.isRepliesExpanded,
    required this.isLoadingReplies,
    required this.onReply,
    required this.onReplyToReply,
    required this.onHashtagTap,
    required this.onMentionTap,
    required this.onLikeComment,
    this.onToggleReplies,
    super.key,
  });

  final PostComment comment;
  final List<PostComment> replies;
  final bool isRepliesExpanded;
  final bool isLoadingReplies;
  final ValueChanged<PostComment> onReply;
  final void Function(PostComment parent, PostComment reply) onReplyToReply;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<PostComment> onLikeComment;
  final ValueChanged<PostComment>? onToggleReplies;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);
    final primaryTextColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF1C1E21);
    final dotColor = isDark ? const Color(0xFF65676B) : const Color(0xFFB0B3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openAuthor(context, comment),
              child: _CommentAvatar(comment: comment),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () => _showCommentActionsMenu(
                      context,
                      comment,
                      onReply: () => onReply(comment),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242526) : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openAuthor(context, comment),
                                    child: SpecialNameText(
                                      username: comment.authorUsername,
                                      displayName: comment.displayName,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 13.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                if (comment.authorIsVerified ||
                                    comment.authorIsAdmin) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: Color(0xFF1D9BF0),
                                  ),
                                ],
                                if (comment.timeAgo.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '·',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    comment.timeAgo,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            HashtagText(
                              text: comment.body,
                              style: KatsText.commentBody(context),
                              onHashtagTap: onHashtagTap,
                              onMentionTap: onMentionTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => onReply(comment),
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (comment.replyCount > 0 && onToggleReplies != null) ...[
                          Text(
                            '·',
                            style: TextStyle(
                              color: dotColor,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InkWell(
                            onTap: () => onToggleReplies!(comment),
                            child: Text(
                              isRepliesExpanded
                                  ? 'Hide replies'
                                  : comment.replyCount == 1
                                      ? 'View 1 reply'
                                      : 'View ${comment.replyCount} replies',
                              style: TextStyle(
                                color: const Color(0xFFFF7A45),
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CommentLikeButton(
              comment: comment,
              onLike: () => onLikeComment(comment),
            ),
          ],
        ),
        if (isLoadingReplies)
          const Padding(
            padding: EdgeInsets.fromLTRB(46, 10, 0, 0),
            child: _ReplySkeletonList(),
          ),
        if (isRepliesExpanded && replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(46, 10, 0, 0),
            child: Column(
              children: replies
                  .map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReplyTile(
                        reply: reply,
                        onReply: () => onReplyToReply(comment, reply),
                        onHashtagTap: onHashtagTap,
                        onMentionTap: onMentionTap,
                        onLikeReply: onLikeComment,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.onReply,
    required this.onHashtagTap,
    required this.onMentionTap,
    required this.onLikeReply,
  });

  final PostComment reply;
  final VoidCallback onReply;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<PostComment> onLikeReply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);
    final primaryTextColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF1C1E21);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openAuthor(context, reply),
          child: _CommentAvatar(comment: reply, size: 30),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => _showCommentActionsMenu(
                  context,
                  reply,
                  onReply: onReply,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242526) : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openAuthor(context, reply),
                                child: SpecialNameText(
                                  username: reply.authorUsername,
                                  displayName: reply.displayName,
                                  style: KatsText.commentAuthor(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (reply.authorIsVerified ||
                                reply.authorIsAdmin) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                size: 14,
                                color: Color(0xFF1D9BF0),
                              ),
                            ],
                            if (reply.timeAgo.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '·',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                reply.timeAgo,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        HashtagText(
                          text: reply.body,
                          style: KatsText.replyBody(context),
                          onHashtagTap: onHashtagTap,
                          onMentionTap: onMentionTap,
                          prefixSpans: [
                            if ((reply.replyToFullName ?? '').trim().isNotEmpty)
                              TextSpan(
                                text: '${reply.replyToFullName!.trim()} ',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _CommentLikeButton(
          comment: reply,
          onLike: () => onLikeReply(reply),
        ),
      ],
    );
  }
}

void _openAuthor(BuildContext context, PostComment comment) {
  final username = comment.authorUsername.trim();
  if (username.isEmpty) return;
  if (normalVideoOverlayController.isOpen) {
    normalVideoOverlayController.close();
  }
  final navigator = Navigator.of(context);
  navigator.pop();
  navigator.push(
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

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.comment,
    this.size = 38,
  });

  final PostComment comment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return UserAvatarWithFrame(
      avatarUrl: comment.authorAvatarUrl,
      initials: comment.authorInitials,
      radius: size / 2,
      isAdmin: comment.authorIsAdmin,
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    this.size = 38,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151),
          fontSize: size <= 30 ? 10 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CommentSkeletonList extends StatelessWidget {
  const _CommentSkeletonList({this.pulse = true});

  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _CommentSkeletonTile(variant: index % 6),
    );

    if (pulse) {
      return SkeletonPulse(child: list);
    }
    return list;
  }
}

class _CommentSkeletonTile extends StatelessWidget {
  const _CommentSkeletonTile({
    this.compact = false,
    this.variant = 0,
  });

  final bool compact;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 34.0 : 38.0;
    final hasThirdLine = !compact && variant.isOdd;
    final nameWidth = switch (variant) {
      0 => 92.0,
      1 => 118.0,
      2 => 76.0,
      3 => 132.0,
      4 => 84.0,
      _ => 110.0,
    };
    final metaWidth = switch (variant) {
      0 => 28.0,
      1 => 36.0,
      2 => 24.0,
      3 => 42.0,
      4 => 30.0,
      _ => 34.0,
    };
    final firstLineWidth = switch (variant) {
      0 => double.infinity,
      1 => 230.0,
      2 => 188.0,
      3 => double.infinity,
      4 => 208.0,
      _ => 244.0,
    };
    final secondLineWidth = switch (variant) {
      0 => 180.0,
      1 => 214.0,
      2 => 156.0,
      3 => 132.0,
      4 => 194.0,
      _ => 168.0,
    };
    final thirdBodyLineWidth = switch (variant) {
      0 => 124.0,
      1 => 146.0,
      2 => 98.0,
      3 => 176.0,
      4 => 116.0,
      _ => 152.0,
    };
    final thirdLineWidth = switch (variant) {
      0 => 34.0,
      1 => 52.0,
      2 => 42.0,
      3 => 60.0,
      4 => 28.0,
      _ => 48.0,
    };
    final secondActionWidth = compact
        ? (variant.isEven ? 54.0 : 46.0)
        : switch (variant) {
            0 => 68.0,
            1 => 56.0,
            2 => 74.0,
            3 => 62.0,
            4 => 48.0,
            _ => 70.0,
          };

    final rightMetaGap = switch (variant) {
      3 => 12.0,
      5 => 6.0,
      _ => 8.0,
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
              const SizedBox(height: 3),
              Row(
                children: [
                  _SkeletonBox(width: nameWidth, height: 12),
                  SizedBox(width: rightMetaGap),
                  _SkeletonBox(width: metaWidth, height: 10),
                ],
              ),
              const SizedBox(height: 10),
              _SkeletonBox(width: firstLineWidth, height: 11),
              const SizedBox(height: 8),
              _SkeletonBox(width: secondLineWidth, height: 11),
              if (hasThirdLine) ...[
                const SizedBox(height: 8),
                _SkeletonBox(width: thirdBodyLineWidth, height: 11),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const _SkeletonBox(width: 34, height: 10),
                  const SizedBox(width: 12),
                  _SkeletonBox(width: secondActionWidth, height: 10),
                  const SizedBox(width: 12),
                  _SkeletonBox(width: thirdLineWidth, height: 10),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReplySkeletonList extends StatelessWidget {
  const _ReplySkeletonList();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        children: [
          _ReplySkeletonTile(variant: 0),
          SizedBox(height: 10),
          _ReplySkeletonTile(variant: 1),
          SizedBox(height: 10),
          _ReplySkeletonTile(variant: 2),
        ],
      ),
    );
  }
}

class _ReplySkeletonTile extends StatelessWidget {
  const _ReplySkeletonTile({
    this.variant = 0,
  });

  final int variant;

  @override
  Widget build(BuildContext context) {
    final hasThirdLine = variant == 1;
    final nameWidth = switch (variant) {
      0 => 96.0,
      1 => 74.0,
      _ => 118.0,
    };
    final firstLineWidth = switch (variant) {
      0 => double.infinity,
      1 => 204.0,
      _ => 172.0,
    };
    final secondLineWidth = switch (variant) {
      0 => 150.0,
      1 => 188.0,
      _ => 126.0,
    };
    final actionWidth = switch (variant) {
      0 => 34.0,
      1 => 48.0,
      _ => 28.0,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonCircle(size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              _SkeletonBox(width: nameWidth, height: 12),
              const SizedBox(height: 10),
              _SkeletonBox(width: firstLineWidth, height: 11),
              const SizedBox(height: 8),
              _SkeletonBox(width: secondLineWidth, height: 11),
              if (hasThirdLine) ...[
                const SizedBox(height: 8),
                _SkeletonBox(width: 112, height: 11),
              ],
              const SizedBox(height: 12),
              _SkeletonBox(width: actionWidth, height: 10),
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
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SkeletonBox(width: width, height: height, radius: 999),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.replyTarget,
    required this.onClearReplyTarget,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final _ReplyTarget? replyTarget;
  final VoidCallback onClearReplyTarget;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);
    final primaryTextColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF1C1E21);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTarget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${replyTarget!.displayName}',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onClearReplyTarget,
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryTextColor,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        inputFormatters: [EmojiPresentationFormatter()],
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFFE4E6EB)
                                : const Color(0xFF050505),
                            fontSize: 13.5.sp,
                            height: 1.33,
                            letterSpacing: -0.2,
                            fontWeight: FontWeight.w400),
                        decoration: InputDecoration(
                          hintText: replyTarget == null
                              ? 'Write a comment...'
                              : 'Reply to ${replyTarget!.displayName}...',
                          hintMaxLines: 1,
                          hintStyle: TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 13.5.sp,
                              height: 1.33),
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF3F4F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      MentionAutocomplete(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !isSending,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A45),
                      disabledBackgroundColor: isDark ? const Color(0xFF2D2E30) : const Color(0xFFD1D5DB),
                    ),
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
                    color: Colors.white,
                    onPressed: isSending ? null : onSend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

PostComment _copyCommentWithReplyCount(PostComment comment, int replyCount) {
  return PostComment(
    id: comment.id,
    postId: comment.postId,
    body: comment.body,
    createdAt: comment.createdAt,
    parentCommentId: comment.parentCommentId,
    replyToUserId: comment.replyToUserId,
    replyToUsername: comment.replyToUsername,
    replyToFullName: comment.replyToFullName,
    replyCount: replyCount,
    authorId: comment.authorId,
    authorFullName: comment.authorFullName,
    authorUsername: comment.authorUsername,
    authorAvatarUrl: comment.authorAvatarUrl,
    authorIsVerified: comment.authorIsVerified,
    authorIsAuthor: comment.authorIsAuthor,
    authorIsAdmin: comment.authorIsAdmin,
  );
}

Future<void> _showReportCommentDialog(BuildContext context, PostComment comment) async {
  final commentId = comment.id;
  if (commentId == 0) return;

  final reasons = [
    'Spam',
    'Harassment or bullying',
    'Hate speech',
    'Nudity or sexual content',
    'Violence or dangerous content',
    'Something else',
  ];

  String? selectedReason = reasons.first;

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

  final ok = await FeedService().reportComment(commentId, selectedReason!);
  if (!context.mounted) {
    return;
  }

  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not submit report. Please try again.')),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Thank you for reporting this comment. We will review it shortly.')),
  );
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

void _showCommentActionsMenu(BuildContext context, PostComment comment, {required VoidCallback onReply}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tileColor = isDark ? Colors.white70 : Colors.black87;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF242526) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
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
                color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.reply, color: tileColor),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: tileColor),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: comment.body));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comment copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: tileColor),
              title: const Text('Share comment'),
              onTap: () {
                Navigator.pop(context);
                Share.share(comment.body);
              },
            ),
            ListTile(
              leading: Icon(Icons.history, color: tileColor),
              title: const Text('View edit history'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No edit history available.')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.visibility_off, color: tileColor),
              title: const Text('Hide comment'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment hidden.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.redAccent),
              title: const Text('Report comment', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showReportCommentDialog(context, comment);
              },
            ),
          ],
        ),
      );
    },
  );
}
