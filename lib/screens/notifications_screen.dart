import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/hashtag_text.dart';
import 'hashtag_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotificationFilter {
  all('All'),
  tagsMentions('Tags & Mentions'),
  replies('Replies'),
  follows('Follows');

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

    final firstVisibleSection =
        groupedNotifications.isEmpty ? null : groupedNotifications.keys.first;

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
                          _notifications.isEmpty
                              ? 'No new activity right now.'
                              : 'No notifications match this filter.',
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
                  trailing: ((entry.key == _NotificationSection.today) ||
                              (_groupNotifications(filteredNotifications)[
                                          _NotificationSection.today] ==
                                      null &&
                                  entry.key == firstVisibleSection)) &&
                          entry.value.isNotEmpty
                      ? TextButton(
                          onPressed: _clearTodayNotifications,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: const Color(0xFF2563EB),
                          ),
                          child: const Text(
                            'Clear all',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
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
    final grouped = <_NotificationSection, List<Map<String, dynamic>>>{};

    for (final notification in notifications) {
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: postId,
          targetCommentId: targetCommentId,
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
    final id = _readString(notification['id']);
    if (id == null || !_isUnread(notification)) {
      return;
    }

    await _feedService.markNotificationRead(id);
  }

  Future<void> _clearTodayNotifications() async {
    final filteredNotifications =
        _notifications.where(_matchesFilter).toList(growable: false);
    final grouped = _groupNotifications(filteredNotifications);
    final todayNotifications = grouped[_NotificationSection.today] ??
        (grouped.isEmpty ? null : grouped[grouped.keys.first]);
    if (todayNotifications == null || todayNotifications.isEmpty) {
      return;
    }

    final ids = todayNotifications
        .map((notification) => _readString(notification['id']))
        .whereType<String>()
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }

    await _feedService.markNotificationsRead(ids);
    if (!mounted) {
      return;
    }
    _showMessage('Today notifications cleared.');
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
    return notification['isRead'] != true;
  }

  String? _actorUsername(Map<String, dynamic> notification) {
    final actor = notification['actor'];
    if (actor is Map<String, dynamic>) {
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
    this.trailing,
  });

  final String title;
  final Widget? trailing;
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
              if (trailing != null) trailing!,
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
    final actor = notification['actor'];
    final actorMap =
        actor is Map<String, dynamic> ? actor : <String, dynamic>{};
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
    final body = _normalizedBody(
      _readString(notification['body']) ?? 'sent you a notification',
      actorName: actorName,
      actorUsername: actorUsername,
    );
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
            GestureDetector(
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
                    body: body,
                    timestampLabel: timestampLabel,
                    onMentionTap: onMentionTap,
                    onHashtagTap: onHashtagTap,
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
  });

  final String actorName;
  final String body;
  final String timestampLabel;
  final ValueChanged<String> onMentionTap;
  final ValueChanged<String> onHashtagTap;

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

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          height: 1.35,
        ),
        children: [
          TextSpan(
            text: widget.actorName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: ' '),
          ...buildHashtagTextSpans(
            text: widget.body,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              height: 1.35,
            ),
            onHashtagTap: widget.onHashtagTap,
            onMentionTap: widget.onMentionTap,
            recognizers: _recognizers,
          ),
          if (widget.timestampLabel.isNotEmpty)
            TextSpan(
              text: '  ${widget.timestampLabel}',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
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
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2D2E30)
          : const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl == null
          ? null
          : NetworkImage(ApiConfig.assetUrl(avatarUrl!)),
      child: avatarUrl == null
          ? Text(
              label.isEmpty ? 'K' : label.characters.first.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _NotificationThumbnail extends StatelessWidget {
  const _NotificationThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Image.network(
          ApiConfig.assetUrl(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF3F4F6),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFF9CA3AF),
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
