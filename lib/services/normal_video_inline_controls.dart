import 'package:flutter/foundation.dart';

import 'normal_video_playback_session.dart';

// Web browsers block autoplay with sound until the user interacts with the
// page, so default to muted on web. On mobile, default to unmuted.
final ValueNotifier<bool> normalVideoMutedNotifier =
    ValueNotifier<bool>(kIsWeb);

bool normalVideoMuted() => normalVideoMutedNotifier.value;

void setNormalVideoMuted(bool muted) {
  if (normalVideoMutedNotifier.value == muted) return;
  normalVideoMutedNotifier.value = muted;

  final controller = normalVideoPlaybackSession.controller;
  if (controller != null && controller.value.isInitialized) {
    controller.setVolume(muted ? 0 : 1);
  }
}

void pauseAllNormalVideoInline() {
  normalVideoPlaybackSession.pause();
}

void resumeNormalVideoInline(String postId) {
  // Best-effort restore hook for inline normal videos.
  // Current shared playback session keeps the active video state.
}
