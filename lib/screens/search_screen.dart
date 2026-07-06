import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/avatar_with_border.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Future<SearchResults>? _resultsFuture;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _resultsFuture = FeedService().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search KatsKlub',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<SearchResults>(
            future: _resultsFuture,
            builder: (context, snapshot) {
              if (_resultsFuture == null) {
                return const _EmptySearch(message: 'Type a keyword to search.');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final results = snapshot.data;
              if (results == null ||
                  (results.people.isEmpty && results.posts.isEmpty)) {
                return const _EmptySearch(message: 'No results found.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (results.people.isNotEmpty) ...[
                    const _SectionTitle('People'),
                    ...results.people.map((user) => _PersonResult(user: user)),
                    const SizedBox(height: 16),
                  ],
                  if (results.posts.isNotEmpty) ...[
                    const _SectionTitle('Posts'),
                    ...results.posts.map((post) => _PostResult(post: post)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PersonResult extends StatelessWidget {
  const _PersonResult({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final borderType = AvatarBorderType.parse(user.profileBorder);

    return Card(
      child: ListTile(
        leading: AvatarWithBorder(
          avatarUrl: user.avatarUrl ?? '',
          initials: user.initials,
          borderType: borderType,
          size: 40,
        ),
        title: Text(user.displayName),
        subtitle: Text(user.handle ?? ''),
        onTap: () {
          if (user.username == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(username: user.username!),
            ),
          );
        },
      ),
    );
  }
}

class _PostResult extends StatelessWidget {
  const _PostResult({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          post.text.isEmpty ? 'Post by ${post.authorFullName}' : post.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('by ${post.authorFullName}'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                postId: post.id,
                initialPost: post,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(child: Text(message)),
    );
  }
}
