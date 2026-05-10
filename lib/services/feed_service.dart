import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
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

class FeedPageResult {
  const FeedPageResult({
    required this.posts,
    required this.offset,
    required this.limit,
    required this.hasMore,
    this.totalCount = 0,
  });

  final List<Post> posts;
  final int offset;
  final int limit;
  final bool hasMore;
  final int totalCount;
}

class CommentPageResult {
  const CommentPageResult({
    required this.comments,
    required this.totalCount,
    required this.hasMore,
    required this.nextBeforeId,
  });

  final List<PostComment> comments;
  final int totalCount;
  final bool hasMore;
  final int? nextBeforeId;
}

class CommentCreateResult {
  const CommentCreateResult({
    required this.comment,
    required this.commentCount,
  });

  final PostComment comment;
  final int commentCount;
}

class MessageThread {
  const MessageThread({
    required this.id,
    required this.otherUser,
    this.lastMessage,
  });

  final int id;
  final User otherUser;
  final DirectMessage? lastMessage;

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    final otherUser = json['otherUser'];
    final lastMessage = json['lastMessage'];

    return MessageThread(
      id: _readStaticInt(json['id']),
      otherUser: otherUser is Map<String, dynamic>
          ? User.fromJson(otherUser)
          : User.fromJson(const <String, dynamic>{}),
      lastMessage: lastMessage is Map<String, dynamic>
          ? DirectMessage.fromJson(lastMessage)
          : null,
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.createdAt,
    required this.sender,
    required this.sentByMe,
  });

  final int id;
  final int conversationId;
  final String body;
  final String createdAt;
  final User sender;
  final bool sentByMe;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];

    return DirectMessage(
      id: _readStaticInt(json['id']),
      conversationId: _readStaticInt(json['conversationId']),
      body: json['body']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      sender: sender is Map<String, dynamic>
          ? User.fromJson(sender)
          : User.fromJson(const <String, dynamic>{}),
      sentByMe: json['sentByMe'] == true,
    );
  }
}

class MessageThreadPage {
  const MessageThreadPage({
    required this.thread,
    required this.messages,
  });

  final MessageThread thread;
  final List<DirectMessage> messages;
}

class FeedService {
  static const String _cachedDiscoverPostsKey = 'cached_discover_posts';
  static const String _cachedHomePostsKey = 'cached_home_posts';

  final http.Client _client;
  final AuthService _authService;

  FeedService({http.Client? client, AuthService? authService})
      : _client = client ?? http.Client(),
        _authService = authService ?? AuthService();

  Future<HomeFeedData> loadHomeFeed() async {
    return _loadHomeData();
  }

  Future<FeedPageResult> loadFeed({
    int offset = 0,
    int limit = 10,
  }) async {
    return loadFeedPage(offset: offset, limit: limit);
  }

  Future<FeedPageResult> loadReels({
    int offset = 0,
    int limit = 20,
  }) async {
    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1 ? 20 : limit;
    final data = await _authenticatedGet(
      '/api/reels?offset=$cleanOffset&limit=$cleanLimit',
    );
    final posts = _readPosts(data);

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
      totalCount: _readInt(data['totalCount']),
    );
  }

  Future<FeedPageResult> loadFeedPage({
    required int offset,
    required int limit,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const FeedPageResult(
        posts: [],
        offset: 0,
        limit: 0,
        hasMore: false,
      );
    }

    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1 ? 10 : limit;
    final data = await _getJson(
      ApiConfig.uri(
          '${ApiConfig.feedPath}?offset=$cleanOffset&limit=$cleanLimit'),
      _authHeaders(token),
    );
    final posts = _readPosts(data);
    if (cleanOffset == 0 && posts.isNotEmpty) {
      await _saveCachedPosts(_cachedDiscoverPostsKey, posts);
    }

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
      totalCount: _readInt(data['totalCount']),
    );
  }

  Future<List<Post>> loadCachedFeedPosts() async {
    return _loadCachedPosts(_cachedDiscoverPostsKey);
  }

  Future<List<Post>> loadCachedHomePosts() async {
    return _loadCachedPosts(_cachedHomePostsKey);
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

  Future<void> deletePost(String postId) async {
    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      throw StateError('Post id is required.');
    }

    final data = await _authenticatedDelete('/api/posts/$cleanPostId');
    if (data['ok'] != true) {
      throw StateError('Failed to delete post.');
    }
  }

  Future<CommentPageResult> loadComments(
    String postId, {
    int limit = 15,
    int? beforeId,
  }) async {
    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      return const CommentPageResult(
        comments: [],
        totalCount: 0,
        hasMore: false,
        nextBeforeId: null,
      );
    }

    final cleanLimit = limit < 1
        ? 15
        : limit > 50
            ? 50
            : limit;
    final query =
        StringBuffer('/api/posts/$cleanPostId/comments?limit=$cleanLimit');
    if (beforeId != null && beforeId > 0) {
      query.write('&beforeId=$beforeId');
    }

    final data = await _authenticatedGet(query.toString());
    final comments = data['comments'];
    final pagination = data['pagination'];

    return CommentPageResult(
      comments: comments is List
          ? comments
              .whereType<Map<String, dynamic>>()
              .map(PostComment.fromJson)
              .where((comment) => comment.id > 0)
              .toList()
          : [],
      totalCount: _readInt(data['totalCount']),
      hasMore:
          pagination is Map<String, dynamic> && pagination['hasMore'] == true,
      nextBeforeId: pagination is Map<String, dynamic>
          ? _readNullableInt(pagination['nextBeforeId'])
          : null,
    );
  }

  Future<CommentCreateResult> createComment(
    String postId,
    String body, {
    int? parentCommentId,
    String? replyToUserId,
  }) async {
    final cleanPostId = postId.trim();
    final cleanBody = body.trim();
    if (cleanPostId.isEmpty || cleanBody.isEmpty) {
      throw StateError('Comment body is required.');
    }

    final data = await _authenticatedPost(
      '/api/posts/$cleanPostId/comments',
      body: {
        'body': cleanBody,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
        if (replyToUserId != null && replyToUserId.trim().isNotEmpty)
          'replyToUserId': replyToUserId.trim(),
      },
    );
    final comment = data['comment'];
    if (data['ok'] != true || comment is! Map<String, dynamic>) {
      throw StateError('Failed to create comment.');
    }

    return CommentCreateResult(
      comment: PostComment.fromJson(comment),
      commentCount: _readInt(data['commentCount']),
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

  Future<User?> followUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedPost('/api/users/$cleanUsername/follow');
    final user = data['user'];
    if (data['ok'] == true && user is Map<String, dynamic>) {
      return User.fromJson(user);
    }

    return null;
  }

  Future<User?> unfollowUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedDelete('/api/users/$cleanUsername/follow');
    final user = data['user'];
    if (data['ok'] == true && user is Map<String, dynamic>) {
      return User.fromJson(user);
    }

    return null;
  }

  Future<MessageThread?> startMessageThread(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedPost(
      '/api/messages/start',
      body: {'username': cleanUsername},
    );
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }

    return null;
  }

  Future<List<MessageThread>> loadMessageThreads() async {
    final data = await _authenticatedGet('/api/messages/threads');
    final threads = data['threads'];
    if (threads is! List) {
      return [];
    }

    return threads
        .whereType<Map<String, dynamic>>()
        .map(MessageThread.fromJson)
        .where((thread) => thread.id > 0)
        .toList();
  }

  Future<MessageThreadPage?> loadMessageThread(int threadId) async {
    if (threadId <= 0) {
      return null;
    }

    final data = await _authenticatedGet('/api/messages/threads/$threadId');
    final thread = data['thread'];
    final messages = data['messages'];
    if (data['ok'] != true || thread is! Map<String, dynamic>) {
      return null;
    }

    return MessageThreadPage(
      thread: MessageThread.fromJson(thread),
      messages: messages is List
          ? messages
              .whereType<Map<String, dynamic>>()
              .map(DirectMessage.fromJson)
              .where((message) => message.id > 0)
              .toList()
          : [],
    );
  }

  Future<DirectMessage?> sendDirectMessage(int threadId, String body) async {
    final cleanBody = body.trim();
    if (threadId <= 0 || cleanBody.isEmpty) {
      return null;
    }

    final data = await _authenticatedPost(
      '/api/messages/threads/$threadId/messages',
      body: {'body': cleanBody},
    );
    final message = data['message'];
    if (data['ok'] == true && message is Map<String, dynamic>) {
      return DirectMessage.fromJson(message);
    }

    return null;
  }

  Future<FeedPageResult> loadUserPosts(
    String username, {
    int offset = 0,
    int limit = 20,
  }) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return const FeedPageResult(
        posts: [],
        offset: 0,
        limit: 0,
        hasMore: false,
      );
    }

    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1
        ? 20
        : limit > 20
            ? 20
            : limit;
    final encodedUsername = Uri.encodeComponent(cleanUsername);
    final data = await _authenticatedGet(
      '/api/users/$encodedUsername/posts?offset=$cleanOffset&limit=$cleanLimit',
    );
    final posts = _readPosts(data);

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
      totalCount: _readInt(data['totalCount'] ?? data['postCount']),
    );
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
    final data =
        await _authenticatedGet('/api/notifications?status=unread&limit=50');
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
        .map((friend) =>
            friend['username']?.toString().trim().toLowerCase() ?? '')
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

  Future<HomeFeedData> _loadHomeData() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const HomeFeedData(
        posts: [],
        stories: [],
        unreadNotifications: 0,
      );
    }

    final headers = _authHeaders(token);

    final results = await Future.wait([
      _getJson(ApiConfig.uri('/api/posts'), headers),
      _getJson(ApiConfig.uri(ApiConfig.storiesPath), headers),
      _getJson(ApiConfig.uri(ApiConfig.notificationsUnreadCountPath), headers),
    ]);

    final feedData = results[0];
    final storiesData = results[1];
    final unreadData = results[2];
    final posts = _readPosts(feedData);
    if (posts.isNotEmpty) {
      await _saveCachedPosts(_cachedHomePostsKey, posts);
    }

    return HomeFeedData(
      posts: posts,
      stories: _readStories(storiesData),
      unreadNotifications: _readInt(unreadData['unreadCount']),
    );
  }

  Future<List<Post>> _loadCachedPosts(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .where((post) => post.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedPosts(String key, List<Post> posts) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = posts.take(10).map((post) => post.toJson()).toList();
    await prefs.setString(key, jsonEncode(normalized));
  }

  Future<Map<String, dynamic>> _authenticatedGet(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    return _getJson(ApiConfig.uri(path), _authHeaders(token));
  }

  Future<Map<String, dynamic>> _authenticatedPost(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.post(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: body != null),
        body: body == null ? null : jsonEncode(body),
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
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.patch(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: true),
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

  Future<Map<String, dynamic>> _authenticatedDelete(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.delete(
        ApiConfig.uri(path),
        headers: _authHeaders(token),
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
    final posts = data['posts'] ?? data['reels'];
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
    return _readStaticInt(value);
  }

  int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  Map<String, String> _authHeaders(
    String token, {
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }
}

int _readStaticInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
