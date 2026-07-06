import 'package:flutter/material.dart';

import '../services/presence_service.dart';

/// Wraps an avatar widget and overlays a green online dot when the user is online.
class PresenceAvatarDot extends StatelessWidget {
  const PresenceAvatarDot({
    super.key,
    required this.child,
    required this.userId,
    this.size = 12,
    this.borderColor = Colors.white,
  });

  final Widget child;
  final String? userId;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) return child;

    PresenceService.ensureLoaded(id);

    return ValueListenableBuilder<Map<String, PresenceState>>(
      valueListenable: PresenceService.presenceNotifier,
      builder: (context, map, _) {
        final state = map[id];
        final isOnline = state?.isOnline == true;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (isOnline)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Active now" / "Active 5m ago" / "Active yesterday" — null if unknown.
String? presenceLabel(PresenceState? state) {
  if (state == null) return null;
  if (state.isOnline) return 'Active now';
  final last = state.lastSeenAt;
  if (last == null) return null;
  final diff = DateTime.now().difference(last.toLocal());
  if (diff.inMinutes < 1) return 'Active now';
  if (diff.inHours < 1) return 'Active ${diff.inMinutes}m ago';
  if (diff.inDays < 1) return 'Active ${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Active yesterday';
  if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return 'Active ${weeks}w ago';
  return 'Active a while ago';
}
