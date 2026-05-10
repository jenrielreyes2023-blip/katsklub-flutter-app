import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/feed_service.dart';
import 'profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.username,
    this.onOpenCurrentUserProfile,
    this.onOpenUserProfile,
    this.onOpenNotifications,
    this.onBack,
    super.key,
  });

  final String username;
  final VoidCallback? onOpenCurrentUserProfile;
  final ValueChanged<String>? onOpenUserProfile;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onBack;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<User?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = FeedService().loadUserProfile(widget.username);
  }

  @override
  void didUpdateWidget(UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _profileFuture = FeedService().loadUserProfile(widget.username);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Profile unavailable.')),
          );
        }

        return ProfileScreen(
          user: user,
          refreshToken: 0,
          onOpenCurrentUserProfile: widget.onOpenCurrentUserProfile,
          onOpenUserProfile: widget.onOpenUserProfile,
          onOpenNotifications: widget.onOpenNotifications,
          onBack: widget.onBack,
        );
      },
    );
  }
}
