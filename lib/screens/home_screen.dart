import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/kats_top_bar.dart';
import '../widgets/post_card.dart';
import '../widgets/story_avatar.dart';
import 'image_viewer_screen.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import 'search_screen.dart';
import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.user,
    required this.refreshToken,
    super.key,
  });

  final User user;
  final int refreshToken;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeFeedData> _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = FeedService().loadHomeFeed();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _feedFuture = FeedService().loadHomeFeed();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _feedFuture = FeedService().loadHomeFeed();
    });
    await _feedFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeFeedData>(
      future: _feedFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final posts = data?.posts.isNotEmpty == true
            ? _homePosts(data!.posts)
            : _samplePosts(widget.user);
        final stories = _storyGroups(data?.stories ?? []);

        return Container(
          color: const Color(0xFFF7F8FA),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                KatsTopBar(
                  unreadNotifications: data?.unreadNotifications ?? 0,
                  onSearchTap: _openSearch,
                  onNotificationsTap: _openNotifications,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Welcome, ${widget.user.displayName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                _StoriesRow(
                  user: widget.user,
                  stories: stories,
                  onStoryTap: _showStoryPlaceholder,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Column(
                    children: [
                      const _ApiStatusCard(),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          data == null)
                        const _LoadingCard(),
                      ...posts.map(_postCard),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Story> _storyGroups(List<Story> stories) {
    final seen = <String>{};
    final grouped = <Story>[];

    for (final story in stories) {
      if (story.ownedByMe) {
        continue;
      }

      final key = story.authorUsername.trim().toLowerCase().isNotEmpty
          ? story.authorUsername.trim().toLowerCase()
          : story.authorFullName.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      grouped.add(story);
    }

    return grouped;
  }

  List<Post> _homePosts(List<Post> posts) {
    return posts
        .where(
          (post) => post.authorIsAdmin || post.authorIsAuthor || post.ownedByMe,
        )
        .toList();
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

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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

  void _showStoryPlaceholder(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Story viewer coming soon: $label')),
    );
  }

  List<Post> _samplePosts(User user) {
    return [
      Post(
        id: 'sample-1',
        authorFullName: user.displayName,
        authorUsername: user.username ?? '',
        authorAvatarUrl: user.avatarUrl ?? '',
        authorIsVerified: false,
        authorIsAdmin: false,
        authorIsAuthor: false,
        ownedByMe: true,
        visibility: 'public',
        text:
            'KatsKlub Flutter home is connected. Real posts from the API will appear here when your feed returns content.',
        isReel: false,
        isAlbum: false,
        isDiscussion: false,
        albumTitle: '',
        discussionTitle: '',
        discussionCoverUrl: '',
        videoUrl: '',
        videoPosterUrl: '',
        videoTitle: '',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        imageUrls: const [
          'sample://blue',
          'sample://orange',
          'sample://green',
          'sample://pink',
        ],
        likeCount: 12,
        likedByMe: false,
        commentCount: 3,
      ),
    ];
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.user,
    required this.stories,
    required this.onStoryTap,
  });

  final User user;
  final List<Story> stories;
  final ValueChanged<String> onStoryTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return StoryAvatar(
              label: 'Your Story',
              initials: user.initials,
              avatarUrl: user.avatarUrl ?? '',
              isOwnStory: true,
              showPlus: true,
              onTap: () => onStoryTap('Your Story'),
            );
          }

          final story = stories[index - 1];
          return StoryAvatar(
            label: story.authorFullName,
            initials: story.initials,
            avatarUrl: story.authorAvatarUrl,
            onTap: () => onStoryTap(story.authorFullName),
          );
        },
      ),
    );
  }
}

class _ApiStatusCard extends StatelessWidget {
  const _ApiStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connected to KatsKlub API',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Loading home feed...',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
