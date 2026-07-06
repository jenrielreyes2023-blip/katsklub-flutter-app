import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final shouldHandleBack =
        isCurrentRoute && normalVideoOverlayController.isOpen;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiStyle = shouldHandleBack
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle(
            statusBarColor: isDark ? const Color(0xFF18191A) : Colors.white,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isDark ? const Color(0xFF18191A) : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: isDark ? const Color(0xFF18191A) : Colors.white,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: PopScope(
        canPop: !shouldHandleBack,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }

          if (shouldHandleBack) {
            _closeOverlayForBack();
          }
        },
        child: Stack(
          children: [
            widget.child,
            const NormalVideoOverlay(),
          ],
        ),
      ),
    );
  }
}
