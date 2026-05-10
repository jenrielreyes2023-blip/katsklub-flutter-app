import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/comments_modal.dart';
import '../widgets/post_card.dart';
import 'image_viewer_screen.dart';
import 'user_profile_screen.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({
    required this.postId,
    this.initialPost,
    this.currentUser,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    super.key,
  });

  final String postId;
  final Post? initialPost;
  final User? currentUser;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: FutureBuilder<Post?>(
        future: FeedService().loadPost(postId),
        initialData: initialPost,
        builder: (context, snapshot) {
          final post = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              post == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (post == null) {
            return const Center(child: Text('Post unavailable.'));
          }

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              PostCard(
                post: post,
                onLike: FeedService().toggleLike,
                onDelete: (post) async {
                  await FeedService().deletePost(post.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                onOpenImages: (post, index) =>
                    _openImages(context, post, index),
                onOpenAuthor: (post) => _openAuthor(context, post),
                onComment: (post) =>
                    showCommentsModal(context: context, post: post),
                onShare: (_) => _showSharePlaceholder(context),
                onBookmark: (_) => _showBookmarkPlaceholder(context),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openImages(BuildContext context, Post post, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
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

  void _openAuthor(BuildContext context, Post post) {
    final authorUsername = post.authorUsername.trim();
    if (authorUsername.isEmpty) {
      return;
    }

    if (_isCurrentUser(authorUsername)) {
      onOpenCurrentUserProfile?.call();
      Navigator.of(context).maybePop();
      return;
    }

    final onOpenUserProfile = this.onOpenUserProfile;
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

  bool _isCurrentUser(String username) {
    final currentUsername = currentUser?.username?.trim().toLowerCase() ?? '';
    return currentUsername.isNotEmpty &&
        username.trim().toLowerCase() == currentUsername;
  }

  void _showSharePlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share is a placeholder for now.')),
    );
  }

  void _showBookmarkPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Save/bookmark is not wired in the web app feed yet.')),
    );
  }
}
