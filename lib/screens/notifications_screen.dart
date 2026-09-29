import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/hashtag_text.dart';
import '../widgets/user_avatar_with_frame.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

String? _readString(Object? value) {
  if (value == null) {
    return null;
  }
  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? null : stringValue;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotificationFilter {
  all('All'),
  unread('Unread'),
  replies('Replies'),
  follows('Follows'),
  tagsMentions('Tags & Mentions');

  const _NotificationFilter(this.label);

  final String label;
}

enum _NotificationSection {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  earlier('Earlier');

  const _NotificationSection(this.label);

  final String label;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FeedService _feedService = FeedService();

  List<Map<String, dynamic>> _notifications = const [];
  bool _isLoading = true;
  _NotificationFilter _activeFilter = _NotificationFilter.all;
  final Set<String> _followingUsernames = <String>{};
  final Set<String> _followingInFlight = <String>{};
  // Follow-request resolution: username -> 'accepted' | 'rejected'.
  final Map<String, String> _resolvedRequests = <String, String>{};
  final Set<String> _requestsInFlight = <String>{};
  List<User> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _notifications = FeedService.notificationsNotifier.value;
    _isLoading = _notifications.isEmpty;
    FeedService.notificationsNotifier.addListener(_handleNotificationsChanged);
    unawaited(FeedService.ensureRealtimeSync());
    unawaited(_primeState());
  }

  @override
  void dispose() {
    FeedService.notificationsNotifier
        .removeListener(_handleNotificationsChanged);
    super.dispose();
  }

  Future<void> _primeState() async {
    await Future.wait<void>([
      _loadNotifications(),
      _loadFriendUsernames(),
      _loadSuggestions(),
    ]);
  }

  void _handleNotificationsChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = FeedService.notificationsNotifier.value;
      _isLoading = false;
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final notifications = await _feedService.loadNotifications();
    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _loadFriendUsernames() async {
    final usernames = await _feedService.loadFriendUsernames();
    if (!mounted) {
      return;
    }

    setState(() {
      _followingUsernames
        ..clear()
        ..addAll(usernames);
    });
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await _feedService.loadFollowSuggestions();
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _loadNotifications(),
      _loadFriendUsernames(),
      _loadSuggestions(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications =
        _notifications.where(_matchesFilter).toList(growable: false);
    final groupedNotifications = _groupNotifications(filteredNotifications);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          'Activity',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_notifications.any(_isUnread))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 16,
                  color: Color(0xFFFF7A45),
                ),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: Color(0xFFFF7A45),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _NotificationFilterBar(
                activeFilter: _activeFilter,
                onChanged: (filter) {
                  setState(() {
                    _activeFilter = filter;
                  });
                },
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredNotifications.isEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60, bottom: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/animations/empty_status.json',
                        width: 180,
                        height: 180,
                        repeat: true,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _activeFilter == _NotificationFilter.unread
                              ? 'You have caught up! No unread notifications.'
                              : (_notifications.isEmpty
                                  ? 'No activity yet. When people interact with you, they will appear here.'
                                  : 'No notifications match this filter.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ..._buildSuggestionSlivers(topPadding: 24, bottomPadding: 20),
            ] else ...[
              ...groupedNotifications.entries.map(
                (entry) => _NotificationSectionSliver(
                  title: entry.key.label,
                  children: entry.value
                      .map(
                        (notification) => _NotificationActivityRow(
                          notification: notification,
                          isUnread: _isUnread(notification),
                          actorUsername: _actorUsername(notification),
                          timestampLabel: _relativeTimestamp(
                            _parseDate(notification['createdAt']),
                          ),
                          followAction: _followActionForNotification(
                            notification,
                          ),
                          requestAction: _requestActionForNotification(
                            notification,
                          ),
                          onTap: () => _openNotification(notification),
                          onAvatarTap: () => _openActorProfile(notification),
                          onThumbnailTap: () =>
                              _openNotificationPost(notification),
                          onMentionTap: _openMentionProfile,
                          onHashtagTap: _openHashtag,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              ..._buildSuggestionSlivers(topPadding: 28, bottomPadding: 28),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSuggestionSlivers({
    required double topPadding,
    required double bottomPadding,
  }) {
    if (_suggestions.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: topPadding,
            bottom: 12,
          ),
          child: Text(
            'Suggested for you',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final user = _suggestions[index];
            final username = user.username ?? '';
            final normalized = username.toLowerCase();
            final isFollowing = _followingUsernames.contains(normalized);
            final isLoading = _followingInFlight.contains(normalized);
            final displayName =
                user.fullName != null && user.fullName!.isNotEmpty
                    ? user.fullName!
                    : username;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(username: username),
                        ),
                      );
                    },
                    child: _NotificationAvatar(
                      avatarUrl:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? user.avatarUrl
                              : null,
                      label: displayName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(username: username),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                          if (user.bio != null &&
                              user.bio!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.bio!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _NotificationFollowButton(
                    action: _FollowAction(
                      isFollowing: isFollowing,
                      isLoading: isLoading,
                      onPressed: () => _toggleFollow(normalized),
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: _suggestions.length,
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
    ];
  }

  bool _matchesFilter(Map<String, dynamic> notification) {
    if (_activeFilter == _NotificationFilter.all) {
      return true;
    }

    final type = _readString(notification['type'])?.toLowerCase() ?? '';
    final action = _readString(notification['action'])?.toLowerCase() ?? '';
    final body = _readString(notification['body'])?.toLowerCase() ?? '';

    bool containsAny(List<String> terms) {
      for (final term in terms) {
        if (type.contains(term) ||
            action.contains(term) ||
            body.contains(term)) {
          return true;
        }
      }
      return false;
    }

    switch (_activeFilter) {
      case _NotificationFilter.unread:
        return _isUnread(notification);
      case _NotificationFilter.tagsMentions:
        return containsAny(['tag', 'mention', '@']);
      case _NotificationFilter.replies:
        return containsAny(['reply', 'comment']);
      case _NotificationFilter.follows:
        return containsAny(['follow']);
      case _NotificationFilter.all:
        return true;
    }
  }

  Map<_NotificationSection, List<Map<String, dynamic>>> _groupNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    final aggregated = _aggregateNotifications(notifications);
    final grouped = <_NotificationSection, List<Map<String, dynamic>>>{};

    for (final notification in aggregated) {
      final section = _sectionForDate(_parseDate(notification['createdAt']));
      grouped.putIfAbsent(section, () => <Map<String, dynamic>>[]).add(
            notification,
          );
    }

    final ordered = <_NotificationSection, List<Map<String, dynamic>>>{};
    for (final section in _NotificationSection.values) {
      final items = grouped[section];
      if (items != null && items.isNotEmpty) {
        ordered[section] = items;
      }
    }
    return ordered;
  }

  List<Map<String, dynamic>> _aggregateNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    final result = <Map<String, dynamic>>[];
    final keyToIndex = <String, int>{};

    for (final notification in notifications) {
      final aggKey = _getAggregationKey(notification);
      if (aggKey == null) {
        result.add(Map<String, dynamic>.from(notification));
        continue;
      }

      final actor = _extractActor(notification);

      if (!keyToIndex.containsKey(aggKey)) {
        final groupItem = Map<String, dynamic>.from(notification);
        groupItem['_actors'] = <Map<String, dynamic>>[if (actor != null) actor];
        groupItem['_groupedNotificationIds'] = <String>[
          if (notification['id'] != null) notification['id'].toString(),
        ];
        keyToIndex[aggKey] = result.length;
        result.add(groupItem);
      } else {
        final index = keyToIndex[aggKey]!;
        final existingGroup = result[index];

        final existingIds =
            existingGroup['_groupedNotificationIds'] as List<String>;
        if (notification['id'] != null) {
          final idStr = notification['id'].toString();
          if (!existingIds.contains(idStr)) {
            existingIds.add(idStr);
          }
        }

        if (notification['isRead'] != true) {
          existingGroup['isRead'] = false;
        }

        if (actor != null) {
          final actors =
              existingGroup['_actors'] as List<Map<String, dynamic>>;
          final username = actor['username']?.toString().toLowerCase() ?? '';
          final actorId = actor['id']?.toString() ?? '';
          final alreadyPresent = actors.any((a) {
            final aUsername = a['username']?.toString().toLowerCase() ?? '';
            final aId = a['id']?.toString() ?? '';
            return (username.isNotEmpty && aUsername == username) ||
                (actorId.isNotEmpty && aId == actorId);
          });
          if (!alreadyPresent) {
            actors.add(actor);
          }
        }
      }
    }

    for (final item in result) {
      final actors = item['_actors'] as List<Map<String, dynamic>>?;
      if (actors != null && actors.length > 1) {
        _formatAggregatedCopy(item, actors);
      }
    }

    return result;
  }

  String? _getAggregationKey(Map<String, dynamic> notification) {
    final type = _readString(notification['type'])?.toLowerCase() ?? '';
    final data = notification['data'] is Map<String, dynamic>
        ? notification['data'] as Map<String, dynamic>
        : (notification['data'] is Map
            ? Map<String, dynamic>.from(notification['data'] as Map)
            : null);

    final postId = _readString(notification['postId']) ??
        _readString(notification['targetPostId']) ??
        _readString(data?['postId']) ??
        _readString(data?['post_id']);
    final commentId = _readString(notification['commentId']) ??
        _readString(notification['targetCommentId']) ??
        _readString(data?['commentId']) ??
        _readString(data?['comment_id']);
    final slideId = _readString(notification['slideId']) ??
        _readString(notification['targetSlideId']) ??
        _readString(data?['slideId']) ??
        _readString(data?['slide_id']);

    if (type.contains('like')) {
      if (commentId != null) {
        return 'like_comment_$commentId';
      }
      if (slideId != null && postId != null) {
        return 'like_slide_${postId}_$slideId';
      }
      if (postId != null) {
        return 'like_post_$postId';
      }
    }

    if (type.contains('comment') && postId != null && commentId == null) {
      return 'comment_post_$postId';
    }

    return null;
  }

  Map<String, dynamic>? _extractActor(Map<String, dynamic> notification) {
    final actor = notification['actor'];
    if (actor is Map<String, dynamic>) {
      return Map<String, dynamic>.from(actor);
    } else if (actor is Map) {
      return Map<String, dynamic>.from(actor);
    }

    final sender = notification['sender'];
    if (sender is Map<String, dynamic>) {
      return Map<String, dynamic>.from(sender);
    } else if (sender is Map) {
      return Map<String, dynamic>.from(sender);
    }

    final username = _readString(notification['username']) ??
        _readString(notification['actorUsername']);
    if (username != null) {
      return {
        'username': username,
        'fullName': _readString(notification['fullName']) ?? username,
        'avatarUrl': _readString(notification['avatarUrl']) ?? '',
      };
    }
    return null;
  }

  void _formatAggregatedCopy(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> actors,
  ) {
    final type = _readString(item['type'])?.toLowerCase() ?? '';
    final name1 = _readString(actors[0]['fullName']) ??
        _readString(actors[0]['displayName']) ??
        _readString(actors[0]['username']) ??
        'Someone';
    final name2 = _readString(actors[1]['fullName']) ??
        _readString(actors[1]['displayName']) ??
        _readString(actors[1]['username']) ??
        'Someone';

    String actionText;
    if (type.contains('comment')) {
      actionText = 'commented on your post.';
    } else if (item['slideId'] != null || item['targetSlideId'] != null) {
      actionText = 'liked a photo in your post.';
    } else if (item['commentId'] != null || item['targetCommentId'] != null) {
      actionText = 'liked your comment.';
    } else {
      actionText = 'liked your post.';
    }

    if (actors.length == 2) {
      item['body'] = '$name1 and $name2 $actionText';
    } else {
      final othersCount = actors.length - 2;
      final othersText = othersCount == 1 ? '1 other' : '$othersCount others';
      item['body'] = '$name1, $name2, and $othersText $actionText';
    }

    item['title'] = type.contains('comment') ? 'Comments' : 'Likes';
  }

  _NotificationSection _sectionForDate(DateTime? date) {
    if (date == null) {
      return _NotificationSection.earlier;
    }

    final now = DateTime.now();
    final localDate = date.toLocal();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfNotificationDay =
        DateTime(localDate.year, localDate.month, localDate.day);
    final difference = startOfToday.difference(startOfNotificationDay).inDays;

    if (difference <= 0) {
      return _NotificationSection.today;
    }
    if (difference == 1) {
      return _NotificationSection.yesterday;
    }
    if (difference < 7) {
      return _NotificationSection.thisWeek;
    }
    return _NotificationSection.earlier;
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    if (await _openNotificationPost(notification)) {
      return;
    }

    if (await _openActorProfile(notification)) {
      return;
    }

    unawaited(_markRead(notification));
    _showMessage('Notification opened.');
  }

  Future<bool> _openNotificationPost(
    Map<String, dynamic> notification, {
    bool markRead = true,
  }) async {
    final postId = _readString(notification['postId']) ??
        _readString(notification['targetPostId']) ??
        _readString(notification['entityId']);
    if (postId == null) {
      return false;
    }

    final commentIdRaw = _readString(notification['commentId']) ??
        _readString(notification['targetCommentId']);
    final targetCommentId =
        commentIdRaw == null ? null : int.tryParse(commentIdRaw);

    final slideIdRaw = _readString(notification['slideId']) ??
        _readString(notification['targetSlideId']);
    final targetSlideId =
        slideIdRaw == null ? null : int.tryParse(slideIdRaw);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: postId,
          targetCommentId: targetCommentId,
          targetSlideId: targetSlideId,
        ),
      ),
    );
    if (markRead) {
      unawaited(_markRead(notification));
    }
    return true;
  }

  Future<bool> _openActorProfile(
    Map<String, dynamic> notification, {
    bool markRead = true,
  }) async {
    final username = _actorUsername(notification);
    if (username == null) {
      return false;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
    if (markRead) {
      unawaited(_markRead(notification));
    }
    return true;
  }

  void _openMentionProfile(String username) {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: cleanUsername),
      ),
    );
  }

  void _openHashtag(String tag) {
    final cleanTag = tag.trim().replaceFirst(RegExp(r'^#'), '');
    if (cleanTag.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagScreen(tag: cleanTag),
      ),
    );
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    final groupIds = notification['_groupedNotificationIds'];
    if (groupIds is List && groupIds.isNotEmpty) {
      final unreadGroupIds = groupIds
          .map((e) => e.toString())
          .where((id) => _notifications
              .any((n) => _readString(n['id']) == id && _isUnread(n)))
          .toList(growable: false);
      if (unreadGroupIds.isNotEmpty) {
        await _feedService.markNotificationsRead(unreadGroupIds);
      }
      return;
    }

    final id = _readString(notification['id']);
    if (id == null || !_isUnread(notification)) {
      return;
    }

    await _feedService.markNotificationRead(id);
  }

  Future<void> _markAllAsRead() async {
    final unreadIds = _notifications
        .where(_isUnread)
        .map((notification) => _readString(notification['id']))
        .whereType<String>()
        .toList(growable: false);
    if (unreadIds.isEmpty) {
      return;
    }

    await _feedService.markNotificationsRead(unreadIds);
    if (!mounted) {
      return;
    }
    _showMessage('All notifications marked as read.');
  }


  _FollowAction? _followActionForNotification(
      Map<String, dynamic> notification) {
    final type = _readString(notification['type'])?.toLowerCase() ?? '';
    if (type == 'follow_request') {
      return null;
    }
    if (!_matchesFollowNotification(notification)) {
      return null;
    }

    final username = _actorUsername(notification);
    if (username == null || username.isEmpty) {
      return null;
    }

    final normalized = username.toLowerCase();
    return _FollowAction(
      isFollowing: _followingUsernames.contains(normalized),
      isLoading: _followingInFlight.contains(normalized),
      onPressed: () => _toggleFollow(normalized),
    );
  }

  Future<void> _toggleFollow(String username) async {
    if (_followingInFlight.contains(username)) {
      return;
    }

    final wasFollowing = _followingUsernames.contains(username);
    setState(() {
      _followingInFlight.add(username);
      if (wasFollowing) {
        _followingUsernames.remove(username);
      } else {
        _followingUsernames.add(username);
      }
    });

    try {
      if (wasFollowing) {
        await _feedService.unfollowUser(username);
      } else {
        await _feedService.followUser(username);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (wasFollowing) {
          _followingUsernames.add(username);
        } else {
          _followingUsernames.remove(username);
        }
      });
      _showMessage('Unable to update follow status.');
    } finally {
      if (mounted) {
        setState(() {
          _followingInFlight.remove(username);
        });
      }
    }
  }

  _RequestAction? _requestActionForNotification(
      Map<String, dynamic> notification) {
    final type = _readString(notification['type'])?.toLowerCase() ?? '';
    if (type != 'follow_request') {
      return null;
    }
    final username = _actorUsername(notification);
    if (username == null || username.isEmpty) {
      return null;
    }
    final normalized = username.toLowerCase();
    return _RequestAction(
      resolution: _resolvedRequests[normalized],
      isLoading: _requestsInFlight.contains(normalized),
      onAccept: () => _resolveRequest(normalized, accept: true),
      onReject: () => _resolveRequest(normalized, accept: false),
    );
  }

  Future<void> _resolveRequest(String username, {required bool accept}) async {
    if (_requestsInFlight.contains(username) ||
        _resolvedRequests.containsKey(username)) {
      return;
    }

    setState(() {
      _requestsInFlight.add(username);
    });

    bool ok = false;
    try {
      ok = accept
          ? await _feedService.acceptFollowRequest(username)
          : await _feedService.rejectFollowRequest(username);
    } catch (_) {
      ok = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _requestsInFlight.remove(username);
      if (ok) {
        _resolvedRequests[username] = accept ? 'accepted' : 'rejected';
      }
    });

    if (!ok) {
      _showMessage('Unable to update follow request.');
    }
  }

  bool _matchesFollowNotification(Map<String, dynamic> notification) {
    final type = _readString(notification['type'])?.toLowerCase() ?? '';
    final action = _readString(notification['action'])?.toLowerCase() ?? '';
    final body = _readString(notification['body'])?.toLowerCase() ?? '';
    return type.contains('follow') ||
        action.contains('follow') ||
        body.contains('followed you');
  }

  bool _isUnread(Map<String, dynamic> notification) {
    final groupIds = notification['_groupedNotificationIds'];
    if (groupIds is List && groupIds.isNotEmpty) {
      return groupIds.any((id) => _notifications.any(
          (n) => _readString(n['id']) == id.toString() && n['isRead'] != true));
    }
    return notification['isRead'] != true;
  }

  String? _actorUsername(Map<String, dynamic> notification) {
    final actors = notification['_actors'];
    if (actors is List && actors.isNotEmpty) {
      final first = actors.first;
      if (first is Map) {
        return _readString(first['username']);
      }
    }
    final actor = notification['actor'];
    if (actor is Map<String, dynamic>) {
      return _readString(actor['username']);
    } else if (actor is Map) {
      return _readString(actor['username']);
    }
    return _readString(notification['username']);
  }

  DateTime? _parseDate(Object? value) {
    final raw = _readString(value);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String _relativeTimestamp(DateTime? date) {
    if (date == null) {
      return '';
    }

    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) {
      return '${weeks}w';
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) {
      return '${months}mo';
    }
    final years = (diff.inDays / 365).floor();
    return '${years}y';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _readString(Object? value) {
    if (value == null) {
      return null;
    }
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.activeFilter,
    required this.onChanged,
  });

  final _NotificationFilter activeFilter;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        scrollDirection: Axis.horizontal,
        itemCount: _NotificationFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _NotificationFilter.values[index];
          final isActive = filter == activeFilter;
          return GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.onSurface
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2D2E30)
                        : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive
                      ? Theme.of(context).colorScheme.onSurface
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2F3031)
                          : const Color(0xFFE5E7EB)),
                ),
              ),
              child: Center(
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: isActive
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationSectionSliver extends StatelessWidget {
  const _NotificationSectionSliver({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate.fixed([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ]),
    );
  }
}

class _NotificationActivityRow extends StatelessWidget {
  const _NotificationActivityRow({
    required this.notification,
    required this.isUnread,
    required this.actorUsername,
    required this.timestampLabel,
    required this.onTap,
    required this.onAvatarTap,
    required this.onThumbnailTap,
    required this.onMentionTap,
    required this.onHashtagTap,
    this.followAction,
    this.requestAction,
  });

  final Map<String, dynamic> notification;
  final bool isUnread;
  final String? actorUsername;
  final String timestampLabel;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onThumbnailTap;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<String> onHashtagTap;
  final _FollowAction? followAction;
  final _RequestAction? requestAction;

  @override
  Widget build(BuildContext context) {
    final rawActors = notification['_actors'];
    final actors = (rawActors is List)
        ? rawActors.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    final actor = notification['actor'];
    final actorMap =
        actor is Map<String, dynamic> ? actor : (actor is Map ? Map<String, dynamic>.from(actor) : <String, dynamic>{});
    final avatarUrl = _readString(
      actorMap['avatarUrl'] ??
          actorMap['avatar_url'] ??
          notification['avatarUrl'],
    );
    final actorName = _readString(
          actorMap['fullName'] ??
              actorMap['full_name'] ??
              actorMap['displayName'] ??
              actorMap['username'] ??
              notification['title'],
        ) ??
        'KatsKlub';

    final String body;
    if (actors.length >= 2) {
      final type = _readString(notification['type'])?.toLowerCase() ?? '';
      if (type.contains('comment')) {
        body = 'commented on your post.';
      } else if (notification['slideId'] != null ||
          notification['targetSlideId'] != null) {
        body = 'liked a photo in your post.';
      } else if (notification['commentId'] != null ||
          notification['targetCommentId'] != null) {
        body = 'liked your comment.';
      } else {
        body = 'liked your post.';
      }
    } else {
      body = _normalizedBody(
        _readString(notification['body']) ?? 'sent you a notification',
        actorName: actorName,
        actorUsername: actorUsername,
      );
    }
    final preview = _readString(
      notification['commentPreview'] ??
          notification['preview'] ??
          notification['replyPreview'] ??
          notification['postPreview'],
    );
    final thumbnailUrl = _readString(
      notification['thumbnailUrl'] ??
          notification['postThumbnailUrl'] ??
          notification['imageUrl'] ??
          notification['postImageUrl'],
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            actors.length >= 2
                ? _GroupedNotificationAvatar(
                    actors: actors,
                    onOpenProfile: onMentionTap,
                    isUnread: isUnread,
                  )
                : GestureDetector(
                    onTap: onAvatarTap,
                    child: _NotificationAvatar(
                      avatarUrl: avatarUrl,
                      label: actorName,
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationBodyText(
                    actorName: actorName,
                    actorUsername: actorUsername,
                    body: body,
                    timestampLabel: timestampLabel,
                    onMentionTap: onMentionTap,
                    onHashtagTap: onHashtagTap,
                    actors: actors.length >= 2 ? actors : null,
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 5),
                    HashtagText(
                      text: preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.35,
                      ),
                      onHashtagTap: onHashtagTap,
                      onMentionTap: onMentionTap,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (requestAction != null)
                  _NotificationRequestButtons(action: requestAction!)
                else if (followAction != null)
                  _NotificationFollowButton(action: followAction!)
                else if (thumbnailUrl != null)
                  GestureDetector(
                    onTap: onThumbnailTap,
                    child: _NotificationThumbnail(url: thumbnailUrl),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _readString(Object? value) {
    if (value == null) {
      return null;
    }
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  String _normalizedBody(
    String rawBody, {
    required String actorName,
    required String? actorUsername,
  }) {
    final trimmed = rawBody.trim();
    for (final prefix in <String?>[
      actorName,
      actorUsername,
      actorUsername == null ? null : '@$actorUsername',
    ]) {
      final cleanPrefix = _readString(prefix);
      if (cleanPrefix == null) {
        continue;
      }

      final lowerBody = trimmed.toLowerCase();
      final lowerPrefix = cleanPrefix.toLowerCase();
      if (!lowerBody.startsWith(lowerPrefix)) {
        continue;
      }

      final remaining = trimmed.substring(cleanPrefix.length).trimLeft();
      if (remaining.isEmpty) {
        return 'sent you a notification';
      }
      return remaining;
    }

    return trimmed;
  }
}

class _NotificationBodyText extends StatefulWidget {
  const _NotificationBodyText({
    required this.actorName,
    required this.body,
    required this.timestampLabel,
    required this.onMentionTap,
    required this.onHashtagTap,
    this.actorUsername,
    this.actors,
  });

  final String actorName;
  final String? actorUsername;
  final String body;
  final String timestampLabel;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<String> onHashtagTap;
  final List<Map<String, dynamic>>? actors;

  @override
  State<_NotificationBodyText> createState() => _NotificationBodyTextState();
}

class _NotificationBodyTextState extends State<_NotificationBodyText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final List<InlineSpan> spans = <InlineSpan>[];

    if (widget.actors != null && widget.actors!.length >= 2) {
      final actors = widget.actors!;
      final first = actors[0];
      final second = actors[1];
      final name1 = _readString(first['fullName']) ??
          _readString(first['username']) ??
          'Someone';
      final user1 = _readString(first['username']) ?? '';
      final name2 = _readString(second['fullName']) ??
          _readString(second['username']) ??
          'Someone';
      final user2 = _readString(second['username']) ?? '';

      final tap1 = TapGestureRecognizer()
        ..onTap = () {
          if (user1.isNotEmpty) widget.onMentionTap(user1);
        };
      _recognizers.add(tap1);

      final tap2 = TapGestureRecognizer()
        ..onTap = () {
          if (user2.isNotEmpty) widget.onMentionTap(user2);
        };
      _recognizers.add(tap2);

      spans.add(
        TextSpan(
          text: name1,
          style: const TextStyle(fontWeight: FontWeight.w800),
          recognizer: tap1,
        ),
      );
      if (actors.length > 2) {
        spans.add(const TextSpan(text: ', '));
      } else {
        spans.add(const TextSpan(text: ' and '));
      }
      spans.add(
        TextSpan(
          text: name2,
          style: const TextStyle(fontWeight: FontWeight.w800),
          recognizer: tap2,
        ),
      );

      if (actors.length > 2) {
        final remaining = actors.length - 2;
        spans.add(
          TextSpan(
            text: ', and ${remaining == 1 ? '1 other' : '$remaining others'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      }

      spans.add(const TextSpan(text: ' '));
      spans.addAll(buildHashtagTextSpans(
        text: widget.body,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          height: 1.35,
        ),
        onHashtagTap: widget.onHashtagTap,
        onMentionTap: widget.onMentionTap,
        recognizers: _recognizers,
      ));
    } else {
      final username = widget.actorUsername;
      TapGestureRecognizer? nameTap;
      if (username != null && username.isNotEmpty) {
        nameTap = TapGestureRecognizer()
          ..onTap = () => widget.onMentionTap(username);
        _recognizers.add(nameTap);
      }

      spans.add(
        TextSpan(
          text: widget.actorName,
          style: const TextStyle(fontWeight: FontWeight.w800),
          recognizer: nameTap,
        ),
      );
      spans.add(const TextSpan(text: ' '));
      spans.addAll(buildHashtagTextSpans(
        text: widget.body,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          height: 1.35,
        ),
        onHashtagTap: widget.onHashtagTap,
        onMentionTap: widget.onMentionTap,
        recognizers: _recognizers,
      ));
    }

    if (widget.timestampLabel.isNotEmpty) {
      spans.add(
        TextSpan(
          text: '  ${widget.timestampLabel}',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          height: 1.35,
        ),
        children: spans,
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({
    required this.avatarUrl,
    required this.label,
  });

  final String? avatarUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return UserAvatarWithFrame(
      avatarUrl: avatarUrl ?? '',
      initials: label.isEmpty ? 'K' : label.characters.first.toUpperCase(),
      radius: 24,
      isAdmin: false,
    );
  }
}

class _GroupedNotificationAvatar extends StatelessWidget {
  const _GroupedNotificationAvatar({
    required this.actors,
    required this.onOpenProfile,
    this.isUnread = false,
  });

  final List<Map<String, dynamic>> actors;
  final ValueChanged<String> onOpenProfile;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isUnread
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
        : (isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white);

    final first = actors[0];
    final second = actors[1];

    final firstAvatar =
        (first['avatarUrl'] ?? first['avatar_url'] ?? '').toString();
    final firstName =
        (first['fullName'] ?? first['username'] ?? 'K').toString();
    final firstUsername = (first['username'] ?? '').toString();

    final secondAvatar =
        (second['avatarUrl'] ?? second['avatar_url'] ?? '').toString();
    final secondName =
        (second['fullName'] ?? second['username'] ?? 'K').toString();
    final secondUsername = (second['username'] ?? '').toString();

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Older actor (Top-Left)
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: () {
                if (secondUsername.isNotEmpty) {
                  onOpenProfile(secondUsername);
                }
              },
              child: UserAvatarWithFrame(
                avatarUrl: secondAvatar,
                initials: secondName.isEmpty
                    ? 'K'
                    : secondName.characters.first.toUpperCase(),
                radius: 15,
                isAdmin: false,
              ),
            ),
          ),
          // Newer actor (Bottom-Right with outline cutout)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                if (firstUsername.isNotEmpty) {
                  onOpenProfile(firstUsername);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: 2.0,
                  ),
                ),
                child: UserAvatarWithFrame(
                  avatarUrl: firstAvatar,
                  initials: firstName.isEmpty
                      ? 'K'
                      : firstName.characters.first.toUpperCase(),
                  radius: 15,
                  isAdmin: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationThumbnail extends StatelessWidget {
  const _NotificationThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Image.network(
          ApiConfig.assetUrl(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
            alignment: Alignment.center,
            child: Icon(
              Icons.image_outlined,
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationFollowButton extends StatelessWidget {
  const _NotificationFollowButton({required this.action});

  final _FollowAction action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final followingBg = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    final followBg = isDark ? const Color(0xFFFF7A45) : const Color(0xFFF2F2F2);
    final followingFg = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final followFg = isDark ? Colors.white : const Color(0xFF111111);

    return TextButton(
      onPressed: action.isLoading ? null : action.onPressed,
      style: TextButton.styleFrom(
        backgroundColor: action.isFollowing ? followingBg : followBg,
        foregroundColor: action.isFollowing ? followingFg : followFg,
        minimumSize: const Size(84, 36),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: action.isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: action.isFollowing ? followingFg : followFg,
              ),
            )
          : Text(action.isFollowing ? 'Following' : 'Follow'),
    );
  }
}

class _FollowAction {
  const _FollowAction({
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback onPressed;
}

class _RequestAction {
  const _RequestAction({
    required this.resolution,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
  });

  // null = pending, 'accepted', or 'rejected'.
  final String? resolution;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
}

class _NotificationRequestButtons extends StatelessWidget {
  const _NotificationRequestButtons({required this.action});

  final _RequestAction action;

  @override
  Widget build(BuildContext context) {
    if (action.resolution != null) {
      return Text(
        action.resolution == 'accepted' ? 'Accepted' : 'Declined',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (action.isLoading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111111),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: action.onAccept,
          style: TextButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFFF7A45) : const Color(0xFF1C1E21),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Accept'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: action.onReject,
          style: TextButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF2D2E30) : const Color(0xFFF2F2F2),
            foregroundColor: isDark ? Colors.white : const Color(0xFF111111),
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
