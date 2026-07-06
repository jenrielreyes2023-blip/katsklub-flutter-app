import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/post.dart';

final NormalVideoPlaybackSession normalVideoPlaybackSession =
    NormalVideoPlaybackSession();

class NormalVideoPlaybackSession extends ChangeNotifier {
  Post? _post;
  VideoPlayerController? _controller;
  Future<void>? _initializationFuture;
  bool _isInitializing = false;
  bool _hasError = false;
  bool _viewerOpen = false;
  bool _lastNotifiedInitialized = false;
  bool _lastNotifiedPlaying = false;
  int _generation = 0;

  Post? get post => _post;
  VideoPlayerController? get controller => _controller;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _controller?.value.isInitialized == true;
  bool get hasError => _hasError;
  bool get viewerOpen => _viewerOpen;
  bool get isPlaying => _controller?.value.isPlaying == true;
  Duration get position => _controller?.value.position ?? Duration.zero;
  String? get activePostId => _post?.id;

  bool isActivePost(String postId) => _post?.id == postId;

  void setViewerOpen(bool value) {
    if (_viewerOpen == value) {
      return;
    }
    _viewerOpen = value;
    debugLog('viewerOpen=$value');
    notifyListeners();
  }

  Future<void> activate(
    Post post, {
    Duration initialPosition = Duration.zero,
    bool play = true,
    bool muted = false,
    String reason = 'activate',
  }) async {
    if (post.videoUrl.trim().isEmpty) {
      return;
    }

    final samePost = _post?.id == post.id;
    final existingController = _controller;

    if (samePost && existingController != null) {
      if (existingController.value.isInitialized) {
        debugLog('$reason reuse initialized');
        await _useReadyController(
          existingController,
          initialPosition: initialPosition,
          play: play,
          muted: muted,
          reason: '$reason reuse',
        );
        return;
      }

      if (_isInitializing && _initializationFuture != null) {
        debugLog(
            '$reason same post still initializing; awaiting existing init');
        await _initializationFuture;

        final readyController = _controller;
        if (_post?.id == post.id &&
            readyController != null &&
            readyController.value.isInitialized) {
          debugLog('$reason init finished; using existing controller');
          await _useReadyController(
            readyController,
            initialPosition: initialPosition,
            play: play,
            muted: muted,
            reason: '$reason after await',
          );
          return;
        }

        debugLog('$reason init finished but controller not usable; recreating');
      } else {
        debugLog('$reason same post stale controller; recreating');
      }
    } else {
      debugLog('$reason new controller needed');
    }

    await _disposeController();

    _post = post;
    _hasError = false;
    _isInitializing = true;
    _lastNotifiedInitialized = false;
    _lastNotifiedPlaying = false;

    final generation = ++_generation;
    notifyListeners();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(ApiConfig.assetUrl(post.videoUrl)),
    );

    _controller = controller;
    controller.addListener(_handleControllerChanged);

    final initializationFuture = _initializeController(
      controller,
      generation: generation,
      initialPosition: initialPosition,
      play: play,
      muted: muted,
      reason: reason,
    );

    _initializationFuture = initializationFuture;
    await initializationFuture;
  }

  Future<void> _initializeController(
    VideoPlayerController controller, {
    required int generation,
    required Duration initialPosition,
    required bool play,
    required bool muted,
    required String reason,
  }) async {
    try {
      await controller.setLooping(false);
      unawaited(controller.setVolume(muted ? 0 : 1));
      await controller.initialize();

      if (generation != _generation || _controller != controller) {
        debugLog('$reason abandoned stale initialized controller');
        return;
      }

      if (initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
      }

      _isInitializing = false;
      _hasError = false;
      notifyListeners();

      if (play) {
        await controller.play();
      } else {
        await controller.pause();
      }

      notifyListeners();
      debugLog('$reason initialized new controller');
    } catch (error) {
      if (generation != _generation || _controller != controller) {
        return;
      }

      _isInitializing = false;
      _hasError = true;
      notifyListeners();
      debugLog('$reason failed: $error');
    } finally {
      if (generation == _generation && _controller == controller) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _useReadyController(
    VideoPlayerController controller, {
    required Duration initialPosition,
    required bool play,
    required bool muted,
    required String reason,
  }) async {
    if (!controller.value.isInitialized) {
      return;
    }

    unawaited(controller.setVolume(muted ? 0 : 1));

    if (play) {
      // On web, call play as early as possible from the tap path.
      // Awaiting seek/volume first can lose the browser user activation.
      await controller.play();
      if (initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
      }
    } else {
      if (initialPosition > Duration.zero) {
        await controller.seekTo(initialPosition);
      }
      await controller.pause();
    }

    notifyListeners();
    debugLog('$reason complete');
  }

  Future<void> play({bool muted = false}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    // On web, do not await setVolume before play. The play call should happen
    // immediately during the user's tap gesture when possible.
    unawaited(controller.setVolume(muted ? 0 : 1));
    await controller.play();
    notifyListeners();
  }

  Future<void> pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      debugLog('pause skipped');
      return;
    }
    await controller.pause();
    notifyListeners();
    debugLog('pause complete');
  }

  Future<void> seek(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await controller.seekTo(position);
    notifyListeners();
  }

  Future<void> clear() async {
    debugLog('clear requested');
    await _disposeController();
    _post = null;
    _isInitializing = false;
    _hasError = false;
    notifyListeners();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _initializationFuture = null;
    _isInitializing = false;
    _generation++;

    if (controller != null) {
      debugLog('dispose controller');
      controller.removeListener(_handleControllerChanged);
      await controller.dispose();
    }
  }

  void debugLog(String message) {
    final controller = _controller;
    debugPrint(
      'NORMAL_VIDEO_SESSION $message '
      'activePost=${_post?.id ?? 'null'} '
      'controllerNull=${controller == null} '
      'initialized=${controller?.value.isInitialized ?? false} '
      'playing=${controller?.value.isPlaying ?? false} '
      'position=${controller?.value.position.inMilliseconds ?? 0}ms '
      'initializing=$_isInitializing '
      'hasError=$_hasError '
      'viewerOpen=$_viewerOpen',
    );
  }

  void _handleControllerChanged() {
    final controller = _controller;
    final isInitialized = controller?.value.isInitialized == true;
    final isPlaying = controller?.value.isPlaying == true;
    if (isInitialized == _lastNotifiedInitialized &&
        isPlaying == _lastNotifiedPlaying) {
      return;
    }

    _lastNotifiedInitialized = isInitialized;
    _lastNotifiedPlaying = isPlaying;
    notifyListeners();
  }
}
