import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/feed_service.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({
    required this.username,
    super.key,
  });

  final String username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: FutureBuilder<User?>(
        future: FeedService().loadUserProfile(username),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting && user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (user == null) {
            return const Center(child: Text('Profile unavailable.'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CircleAvatar(
                radius: 48,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (user.handle != null)
                Text(
                  user.handle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Bio'),
                  subtitle: Text(user.bio ?? 'No bio yet.'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
