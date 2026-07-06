import 'package:flutter/foundation.dart';

import '../models/post.dart';

class MediaPostLoadRegistry {
  static final Set<String> _readyPostIds = <String>{};
  static final ValueNotifier<int> _changeTick = ValueNotifier<int>(0);

  static Listenable get changes => _changeTick;

  static void markReady(String postId) {
    final cleanId = postId.trim();
    if (cleanId.isEmpty) {
      return;
    }
    final added = _readyPostIds.add(cleanId);
    if (added) {
      _changeTick.value++;
    }
  }

  static bool isReady(String postId) {
    final cleanId = postId.trim();
    if (cleanId.isEmpty) {
      return false;
    }
    return _readyPostIds.contains(cleanId);
  }
}

bool shouldGuardOnSuperFling(Post post) {
  final hasDirectMedia = post.imageUrls.isNotEmpty || post.hasVideo;
  if (!hasDirectMedia) {
    return false;
  }
  return !MediaPostLoadRegistry.isReady(post.id);
}
