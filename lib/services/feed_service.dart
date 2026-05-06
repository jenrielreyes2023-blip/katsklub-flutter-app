import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/story.dart';
import '../models/user.dart';
import 'auth_service.dart';

class HomeFeedData {
  const HomeFeedData({
    required this.posts,
    required this.stories,
    required this.unreadNotifications,
  });

  final List<Post> posts;
  final List<Story> stories;
  final int unreadNotifications;
}

class SearchResults {
  const SearchResults({
    required this.people,
    required this.posts,
  });

  final List<User> people;
  final List<Post> posts;
}

class FeedService {
  final http.Client _client;

  FeedService({http.Client? client}) : _client = client ?? http.Client();

  Future<HomeFeedData> loadHomeFeed() async {
    return _loadFeedData();
  }

  Future<HomeFeedData> loadFeed() async {
    return _loadFeedData();
  }

  Future<Post?> loadPost(String postId) async {
    final data = await _authenticatedGet('/api/posts/$postId');
    final post = data['post'];
    if (post is Map<String, dynamic>) {
      return Post.fromJson(post);
    }

    return null;
  }

  Future<Post> toggleLike(Post post) async {
    final data = await _authenticatedPost('/api/posts/${post.id}/like');
    if (data['ok'] != true) {
      throw StateError('Failed to toggle like.');
    }
    final likeCount = _readInt(data['likeCount']);
    final liked = data['liked'] == true;
    return post.copyWith(
      likeCount: likeCount,
      likedByMe: liked,
    );
  }

  Future<User?> loadUserProfile(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedGet('/api/users/$cleanUsername');
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      return User.fromJson(user);
    }

    return null;
  }

  Future<SearchResults> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      return const SearchResults(people: [], posts: []);
    }

    final encodedQuery = Uri.encodeQueryComponent(cleanQuery);
    final data = await _authenticatedGet('/api/search?q=$encodedQuery');
    final people = data['people'];
    final posts = data['posts'];

    return SearchResults(
      people: people is List
          ? people.whereType<Map<String, dynamic>>().map(User.fromJson).toList()
          : [],
      posts: posts is List
          ? posts.whereType<Map<String, dynamic>>().map(Post.fromJson).toList()
          : [],
    );
  }

  Future<List<Map<String, dynamic>>> loadNotifications() async {
    final data = await _authenticatedGet('/api/notifications?status=unread&limit=50');
    final notifications = data['notifications'];
    if (notifications is! List) {
      return [];
    }

    return notifications.whereType<Map<String, dynamic>>().toList();
  }

  Future<Set<String>> loadFriendUsernames() async {
    final data = await _authenticatedGet('/api/me/friends');
    final friends = data['friends'];
    if (friends is! List) {
      return <String>{};
    }

    return friends
        .whereType<Map<String, dynamic>>()
        .map((friend) => friend['username']?.toString().trim().toLowerCase() ?? '')
        .where((username) => username.isNotEmpty)
        .toSet();
  }

  Future<void> markNotificationRead(String id) async {
    if (id.trim().isEmpty) {
      return;
    }

    await _authenticatedPatch(
      '/api/notifications/read',
      body: {
        'notificationIds': [id],
      },
    );
  }

  Future<HomeFeedData> _loadFeedData() async {
    final cookie = await _readSessionCookie();
    if (cookie == null || cookie.isEmpty) {
      return const HomeFeedData(
        posts: [],
        stories: [],
        unreadNotifications: 0,
      );
    }

    final headers = {
      'Accept': 'application/json',
      'Cookie': cookie,
    };

    final results = await Future.wait([
      _getJson(ApiConfig.uri('${ApiConfig.feedPath}?offset=0&limit=10'), headers),
      _getJson(ApiConfig.uri(ApiConfig.storiesPath), headers),
      _getJson(ApiConfig.uri(ApiConfig.notificationsUnreadCountPath), headers),
    ]);

    final feedData = results[0];
    final storiesData = results[1];
    final unreadData = results[2];

    return HomeFeedData(
      posts: _readPosts(feedData),
      stories: _readStories(storiesData),
      unreadNotifications: _readInt(unreadData['unreadCount']),
    );
  }

  Future<Map<String, dynamic>> _authenticatedGet(String path) async {
    final cookie = await _readSessionCookie();
    if (cookie == null || cookie.isEmpty) {
      return <String, dynamic>{};
    }

    return _getJson(ApiConfig.uri(path), {
      'Accept': 'application/json',
      'Cookie': cookie,
    });
  }

  Future<Map<String, dynamic>> _authenticatedPost(String path) async {
    final cookie = await _readSessionCookie();
    if (cookie == null || cookie.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.post(
        ApiConfig.uri(path),
        headers: {
          'Accept': 'application/json',
          'Cookie': cookie,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _authenticatedPatch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final cookie = await _readSessionCookie();
    if (cookie == null || cookie.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.patch(
        ApiConfig.uri(path),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Cookie': cookie,
        },
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<String?> _readSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AuthService.sessionCookieKey);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{};
  }

  List<Post> _readPosts(Map<String, dynamic> data) {
    final posts = data['posts'];
    if (posts is! List) {
      return [];
    }

    return posts
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .where((post) => post.id.isNotEmpty)
        .toList();
  }

  List<Story> _readStories(Map<String, dynamic> data) {
    final stories = data['stories'];
    if (stories is! List) {
      return [];
    }

    return stories
        .whereType<Map<String, dynamic>>()
        .map(Story.fromJson)
        .where((story) => story.id.isNotEmpty)
        .toList();
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
