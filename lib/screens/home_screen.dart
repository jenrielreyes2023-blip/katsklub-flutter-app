import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.user,
    required this.onLogout,
    super.key,
  });

  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  String get _displayName {
    final fullName = user['fullName'];
    final username = user['username'];
    final email = user['email'];

    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    if (username is String && username.trim().isNotEmpty) {
      return username.trim();
    }

    if (email is String && email.trim().isNotEmpty) {
      return email.trim();
    }

    return 'KatsKlub user';
  }

  String? get _username {
    final username = user['username'];
    if (username is String && username.trim().isNotEmpty) {
      return '@${username.trim()}';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KatsKlub'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $_displayName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (_username != null) ...[
                const SizedBox(height: 6),
                Text(
                  _username!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Connected to KatsKlub API'),
                  subtitle: const Text('Flutter is using the same backend session.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
