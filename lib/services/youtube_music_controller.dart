import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'youtube_service.dart';

/// Global controller managing persistent YouTube Music playback across all screens in KatsKlub.
/// Keeps audio playing continuously in the background when users navigate through tabs or screens.
class YouTubeMusicController extends ChangeNotifier {
  static final YouTubeMusicController instance = YouTubeMusicController._internal();
  factory YouTubeMusicController() => instance;
  YouTubeMusicController._internal();

  YouTubeVideoItem? _currentTrack;
  bool _isOpen = false;
  bool _isMinimized = false;
  bool _isPlaying = true;
  bool _isLoading = true;
  WebViewController? _webViewController;
  Timer? _cleanDomTimer;

  YouTubeVideoItem? get currentTrack => _currentTrack;
  bool get isOpen => _isOpen;
  bool get isMinimized => _isMinimized;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  WebViewController? get webViewController => _webViewController;

  void play({
    required String videoId,
    String? title,
    String? author,
    String? thumbnail,
    bool startMinimized = false,
  }) {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return;

    final item = YouTubeVideoItem(
      id: cleanId,
      title: title ?? 'YouTube Music',
      duration: '',
      thumbnail: thumbnail ?? 'https://img.youtube.com/vi/$cleanId/hqdefault.jpg',
      author: author ?? 'YouTube Creator',
    );

    // If same track is already loaded, just expand if needed
    if (_currentTrack?.id == cleanId && _webViewController != null) {
      _isOpen = true;
      if (!startMinimized) {
        _isMinimized = false;
      }
      playWebVideo();
      notifyListeners();
      return;
    }

    _currentTrack = item;
    _isOpen = true;
    _isMinimized = startMinimized;
    _isPlaying = true;
    _isLoading = true;

    _initWebViewController(cleanId);
    notifyListeners();
  }

  void _initWebViewController(String videoId) {
    _cleanDomTimer?.cancel();

    final watchUrl = 'https://m.youtube.com/watch?v=$videoId&autoplay=1';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _isLoading = true;
            notifyListeners();
          },
          onPageFinished: (_) {
            _isLoading = false;
            _isPlaying = true;
            _injectCleanPlayerStyles();
            playWebVideo();
            notifyListeners();
          },
        ),
      );

    try {
      (controller.platform as dynamic).setMediaPlaybackRequiresUserGesture(false);
    } catch (_) {}

    controller.loadRequest(Uri.parse(watchUrl));
    _webViewController = controller;

    // Periodically enforce clean UI
    _cleanDomTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (timer.tick > 15) {
        timer.cancel();
      }
      _injectCleanPlayerStyles();
    });
  }

  void _injectCleanPlayerStyles() {
    if (_webViewController == null) return;
    const css = """
      (function() {
        var style = document.getElementById('kk-yt-music-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'kk-yt-music-style';
          document.head.appendChild(style);
        }
        style.textContent = `
          header, ytm-header-bar, .header-bar,
          #header-bar, ytm-pivot-bar-renderer,
          .pivot-bar-renderer, ytm-comment-section-renderer,
          .comment-section-renderer, ytm-item-section-renderer[section-identifier="comment-item-section"],
          ytm-watch-metadata-renderer, .related-chips-slot-wrapper,
          ytm-item-section-renderer:not(:first-child),
          .yt-spec-bottom-sheet-layout__bottom-sheet-content-scroller,
          .mobile-topbar-header, .search-btn-header,
          .ad-container, .ytp-ad-overlay-container,
          .ytm-carousel-footers, ytm-engagement-panel,
          ytm-single-column-watch-next-results-renderer-footer {
            display: none !important;
          }
          html, body {
            background-color: #000000 !important;
            overflow-x: hidden !important;
          }
          #player-container-id, .player-container, #player {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            z-index: 99999 !important;
            background: #000 !important;
          }
          video {
            object-fit: contain !important;
            width: 100% !important;
            height: 100% !important;
          }
        `;
      })();
    """;
    _webViewController?.runJavaScript(css).catchError((_) {});
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pauseWebVideo();
    } else {
      playWebVideo();
    }
  }

  void playWebVideo() {
    const script = """
      (function() {
        var v = document.querySelector('video');
        if (v) { v.play(); }
      })();
    """;
    _webViewController?.runJavaScript(script).catchError((_) {});
    _isPlaying = true;
    notifyListeners();
  }

  void pauseWebVideo() {
    const script = """
      (function() {
        var v = document.querySelector('video');
        if (v) { v.pause(); }
      })();
    """;
    _webViewController?.runJavaScript(script).catchError((_) {});
    _isPlaying = false;
    notifyListeners();
  }

  void seekRelative(int seconds) {
    final script = """
      (function() {
        var v = document.querySelector('video');
        if (v) { v.currentTime = Math.max(0, v.currentTime + ($seconds)); }
      })();
    """;
    _webViewController?.runJavaScript(script).catchError((_) {});
  }

  void minimize() {
    _isMinimized = true;
    notifyListeners();
  }

  void expand() {
    _isMinimized = false;
    notifyListeners();
  }

  void close() {
    _cleanDomTimer?.cancel();
    pauseWebVideo();
    _isOpen = false;
    _isMinimized = false;
    _currentTrack = null;
    _webViewController = null;
    notifyListeners();
  }
}

final youTubeMusicController = YouTubeMusicController.instance;
