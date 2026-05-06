import 'package:flutter/material.dart';

import '../models/user.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.user,
    super.key,
  });

  final User user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Welcome, ${user.displayName}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (user.handle != null) ...[
          const SizedBox(height: 6),
          Text(
            user.handle!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: const Text('Connected to KatsKlub API'),
            subtitle: const Text('Session verified through /api/me.'),
          ),
        ),
      ],
    );
  }
}
