import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/feed_service.dart';
import '../widgets/post_card.dart';
import 'image_viewer_screen.dart';
import 'user_profile_screen.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({
    required this.postId,
    this.initialPost,
    super.key,
  });

  final String postId;
  final Post? initialPost;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: FutureBuilder<Post?>(
        future: FeedService().loadPost(postId),
        initialData: initialPost,
        builder: (context, snapshot) {
          final post = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting && post == null) {
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
                onOpenImages: (post, index) => _openImages(context, post, index),
                onOpenAuthor: (post) => _openAuthor(context, post),
                onComment: (_) => _showCommentsPlaceholder(context),
                onShare: (_) => _showSharePlaceholder(context),
                onBookmark: (_) => _showBookmarkPlaceholder(context),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.mode_comment_outlined),
                  title: Text('Comments'),
                  subtitle: Text('Comment thread view coming soon.'),
                ),
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
        ),
      ),
    );
  }

  void _openAuthor(BuildContext context, Post post) {
    if (post.authorUsername.trim().isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: post.authorUsername),
      ),
    );
  }

  void _showCommentsPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment composer coming soon.')),
    );
  }

  void _showSharePlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share is a placeholder for now.')),
    );
  }

  void _showBookmarkPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save/bookmark is not wired in the web app feed yet.')),
    );
  }
}
