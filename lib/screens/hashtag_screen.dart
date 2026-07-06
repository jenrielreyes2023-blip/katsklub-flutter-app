import 'dart:async';

import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/post_card.dart';
import 'image_viewer_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'vertical_gallery_screen.dart';

class HashtagScreen extends StatefulWidget {
  const HashtagScreen({
    required this.tag,
    this.currentUser,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    super.key,
  });

  final String tag;
  final User? currentUser;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  final FeedService _feedService = FeedService();

  StreamSubscription<String>? _postDeletedSubscription;
  StreamSubscription<String>? _postHiddenSubscription;
  StreamSubscription<Post>? _postUpdatedSubscription;
  StreamSubscription<CommentCountChange>? _commentCountSubscription;
  StreamSubscription<void>? _postcardThemesResetSubscription;

  late final String _normalizedTag;
  List<Post> _posts = const [];
  int _postCount = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _normalizedTag = widget.tag.trim().replaceFirst(RegExp(r'^#'), '');
    _bindFeedEvents();
    _loadHashtag();
  }

  @override
  void dispose() {
    _postDeletedSubscription?.cancel();
    _postHiddenSubscription?.cancel();
    _postUpdatedSubscription?.cancel();
    _commentCountSubscription?.cancel();
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
    _postcardThemesResetSubscription = FeedService.postcardThemesResetStream
        .listen((_) => _clearAllPostcardThemes());
  }

  Future<void> _loadHashtag() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await _feedService.loadHashtag(_normalizedTag);
      if (!mounted) {
        return;
      }

      setState(() {
        _posts = result.posts;
        _postCount = result.hashtag.postCount;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _removePostById(String postId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts.where((item) => item.id != postId).toList();
      _postCount = _postCount > 0 ? _postCount - 1 : 0;
    });
  }

  void _replacePost(Post updatedPost) {
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts
          .map((item) => item.id == updatedPost.id ? updatedPost : item)
          .toList();
    });
  }

  void _clearAllPostcardThemes() {
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts.map((item) {
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

  void _applyCommentCountChange(CommentCountChange event) {
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts
          .map(
            (item) => item.id == event.postId
                ? item.copyWith(commentCount: event.commentCount)
                : item,
          )
          .toList();
    });
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
      onShare: _showSharePlaceholder,
      onBookmark: _toggleBookmark,
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
    if (!mounted) {
      return;
    }

    setState(() {
      _posts = _posts.where((item) => item.id != post.id).toList();
      _postCount = _postCount > 0 ? _postCount - 1 : 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post successfully deleted.')),
    );
  }

  Future<void> _hidePost(Post post) async {
    final previousPosts = List<Post>.from(_posts);
    final previousCount = _postCount;

    setState(() {
      _posts = _posts.where((item) => item.id != post.id).toList();
      _postCount = _postCount > 0 ? _postCount - 1 : 0;
    });

    try {
      await _feedService.hidePost(post.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post hidden')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _posts = previousPosts;
        _postCount = previousCount;
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
          currentUser: widget.currentUser,
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

  void _openAuthor(Post post) {
    final authorUsername = post.authorUsername.trim();
    if (authorUsername.isEmpty) {
      return;
    }

    if (widget.currentUser != null &&
        authorUsername.toLowerCase() ==
            (widget.currentUser!.username ?? '').trim().toLowerCase()) {
      widget.onOpenCurrentUserProfile?.call();
      return;
    }

    if (widget.onOpenUserProfile != null) {
      widget.onOpenUserProfile!(authorUsername);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: authorUsername,
          onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
          onOpenUserProfile: widget.onOpenUserProfile,
        ),
      ),
    );
  }

  void _showSharePlaceholder(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share coming soon.')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: Text(
          '#$_normalizedTag',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHashtag,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Text(
                  _postCount == 1 ? '1 post' : '$_postCount posts',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Column(
                  children: [
                    PostSkeletonCard(variant: 0),
                    PostSkeletonCard(variant: 1),
                    PostSkeletonCard(variant: 2),
                  ],
                ),
              )
            else if (_hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Failed to load hashtag posts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _loadHashtag,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'No posts found for #$_normalizedTag yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _postCard(_posts[index]),
                  childCount: _posts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
