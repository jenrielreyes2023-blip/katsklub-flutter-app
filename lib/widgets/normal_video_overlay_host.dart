import 'package:flutter/material.dart';

import '../services/normal_video_inline_controls.dart';
import '../services/normal_video_overlay_controller.dart';
import '../services/normal_video_playback_session.dart';
import 'normal_video_overlay.dart';

class NormalVideoOverlayHost extends StatefulWidget {
  const NormalVideoOverlayHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<NormalVideoOverlayHost> createState() => _NormalVideoOverlayHostState();
}

class _NormalVideoOverlayHostState extends State<NormalVideoOverlayHost> {
  LocalHistoryEntry? _historyEntry;

  @override
  void initState() {
    super.initState();
    normalVideoOverlayController.addListener(_handleOverlayChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncOverlayHistory();
      }
    });
  }

  @override
  void dispose() {
    normalVideoOverlayController.removeListener(_handleOverlayChanged);
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
    super.dispose();
  }

  void _handleOverlayChanged() {
    _syncOverlayHistory();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncOverlayHistory() {
    if (!mounted) {
      return;
    }

    final route = ModalRoute.of(context);
    final isCurrentRoute = route?.isCurrent ?? true;

    if (!isCurrentRoute) {
      // A modal/sheet is on top — keep the history entry so the overlay
      // stays open when it's dismissed. Don't call _closeOverlayForBack here.
      return;
    }

    if (normalVideoOverlayController.isOpen && _historyEntry == null) {
      _historyEntry = LocalHistoryEntry(
        onRemove: () {
          _historyEntry = null;
          _closeOverlayForBack();
        },
      );

      route?.addLocalHistoryEntry(_historyEntry!);
      return;
    }

    if (!normalVideoOverlayController.isOpen && _historyEntry != null) {
      final entry = _historyEntry;
      _historyEntry = null;
      entry?.remove();
    }
  }

  void _closeOverlayForBack() {
    final video = normalVideoOverlayController.video;

    normalVideoPlaybackSession.setViewerOpen(false);

    if (video != null) {
      resumeNormalVideoInline(video.id);
      normalVideoPlaybackSession.play(muted: normalVideoMuted());
    }

    if (normalVideoOverlayController.isOpen) {
      normalVideoOverlayController.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class NormalVideoPageRoute extends StatefulWidget {
  const NormalVideoPageRoute({super.key});

  @override
  State<NormalVideoPageRoute> createState() => _NormalVideoPageRouteState();
}

class _NormalVideoPageRouteState extends State<NormalVideoPageRoute> {
  @override
  void initState() {
    super.initState();
    normalVideoOverlayController.addListener(_onOverlayChanged);
  }

  @override
  void dispose() {
    normalVideoOverlayController.removeListener(_onOverlayChanged);
    if (normalVideoOverlayController.isOpen) {
      normalVideoOverlayController.close();
    }
    super.dispose();
  }

  void _onOverlayChanged() {
    if (!normalVideoOverlayController.isOpen && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          NormalVideoOverlay(),
        ],
      ),
    );
  }
}

