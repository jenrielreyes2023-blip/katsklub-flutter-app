import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/post_card.dart';
import 'image_viewer_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    required this.user,
    required this.refreshToken,
    super.key,
  });

  final User user;
  final int refreshToken;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<HomeFeedData> _feedFuture;
  String _activeTab = 'discover';
  Set<String> _friendUsernames = <String>{};

  @override
  void initState() {
    super.initState();
    _feedFuture = FeedService().loadFeed();
    _loadFriends();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _feedFuture = FeedService().loadFeed();
      _loadFriends();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _feedFuture = FeedService().loadFeed();
    });
    _loadFriends();
    await _feedFuture;
  }

  Future<void> _loadFriends() async {
    final friends = await FeedService().loadFriendUsernames();
    if (!mounted) return;
    setState(() {
      _friendUsernames = friends;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F8FA),
      child: FutureBuilder<HomeFeedData>(
        future: _feedFuture,
        builder: (context, snapshot) {
          final posts = _visiblePosts(snapshot.data?.posts ?? []);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              children: [
                _FeedTabs(
                  activeTab: _activeTab,
                  onChanged: (tab) {
                    setState(() {
                      _activeTab = tab;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (posts.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No posts yet.'),
                      subtitle: Text('Pull to refresh.'),
                    ),
                  )
                else
                  ...posts.map(_postCard),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Post> _visiblePosts(List<Post> posts) {
    final normalPosts = posts;
    if (_activeTab == 'friends') {
      return normalPosts
          .where(
            (post) => _friendUsernames.contains(
              post.authorUsername.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
            ),
          )
          .toList();
    }

    return [...normalPosts]..sort((a, b) {
        final engagementA = a.likeCount + a.commentCount;
        final engagementB = b.likeCount + b.commentCount;
        if (engagementA == engagementB) {
          return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        }
        return engagementB.compareTo(engagementA);
      });
  }

  Widget _postCard(Post post) {
    return PostCard(
      post: post,
      onOpenPost: _openPost,
      onOpenImages: _openImages,
      onOpenAuthor: _openAuthor,
      onLike: FeedService().toggleLike,
      onComment: _openPost,
      onShare: _showSharePlaceholder,
      onBookmark: _showBookmarkPlaceholder,
    );
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id, initialPost: post),
      ),
    );
  }

  void _openImages(Post post, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          imageUrls: post.imageUrls,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openAuthor(Post post) {
    if (post.authorUsername.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: post.authorUsername),
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
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _FeedTabButton(
            label: 'Discover',
            isActive: activeTab == 'discover',
            onTap: () => onChanged('discover'),
          ),
          _FeedTabButton(
            label: 'Friends',
            isActive: activeTab == 'friends',
            onTap: () => onChanged('friends'),
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
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF4B5563),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
