import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/story.dart';
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

class FeedService {
  final http.Client _client;

  FeedService({http.Client? client}) : _client = client ?? http.Client();

  Future<HomeFeedData> loadHomeFeed() async {
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
