import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/feed_service.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: FeedService().loadNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(child: Text('No new notifications.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final actor = notification['actor'];
              final actorMap = actor is Map<String, dynamic> ? actor : <String, dynamic>{};
              final avatarUrl = _readString(actorMap['avatarUrl']);
              final fullName = _readString(actorMap['fullName']) ?? 'KatsKlub';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        avatarUrl == null ? null : NetworkImage(ApiConfig.assetUrl(avatarUrl)),
                    child: avatarUrl == null ? Text(fullName[0].toUpperCase()) : null,
                  ),
                  title: Text(_readString(notification['body']) ?? 'Notification'),
                  subtitle: Text(_readString(notification['createdAt']) ?? ''),
                  onTap: () => _openNotification(context, notification, actorMap),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    Map<String, dynamic> notification,
    Map<String, dynamic> actor,
  ) async {
    final id = _readString(notification['id']);
    if (id != null) {
      await FeedService().markNotificationRead(id);
    }

    if (!context.mounted) return;

    final postId = _readString(notification['postId']);
    if (postId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: postId),
        ),
      );
      return;
    }

    final username = _readString(actor['username']);
    if (username != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(username: username),
        ),
      );
    }
  }

  String? _readString(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}
