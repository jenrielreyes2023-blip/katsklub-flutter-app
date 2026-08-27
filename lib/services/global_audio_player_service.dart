import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class GlobalAudioQueueItem {
  const GlobalAudioQueueItem({
    required this.id,
    required this.src,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    this.playlistId,
    this.trackId,
    this.source = 'playlist',
  });

  final String id;
  final String src;
  final String title;
  final String artist;
  final String artworkUrl;
  final int? playlistId;
  final int? trackId;
  final String source;
}

class GlobalAudioPlayerService extends ChangeNotifier {
  static const Duration _autoHideDelay = Duration(seconds: 7);

  GlobalAudioPlayerService() {
    _currentIndexSubscription = _player.currentIndexStream.listen((value) {
      if (_queue.isEmpty) {
        return;
      }
      final nextIndex = value ?? -1;
      if (_currentIndex == nextIndex) {
        return;
      }
      _currentIndex = nextIndex;
      _syncAutoHideTimer();
      notifyListeners();
    });

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      final nextPlaying = state.playing;
      final processingStateChanged = _processingState != state.processingState;
      _processingState = state.processingState;
      if (_playing == nextPlaying && !processingStateChanged) {
        return;
      }
      _playing = nextPlaying;
      _syncAutoHideTimer();
      notifyListeners();
    });

    _durationSubscription = _player.durationStream.listen((value) {
      final nextDuration = value ?? Duration.zero;
      if (_duration == nextDuration) {
        return;
      }
      _duration = nextDuration;
      _syncAutoHideTimer();
      notifyListeners();
    });

    _positionSubscription = _player.positionStream.listen((value) {
      if (_queue.isEmpty) {
        return;
      }
      _currentTime = value;
      _syncAutoHideTimer();
      notifyListeners();
    });
  }

  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
  );

  late final StreamSubscription<int?> _currentIndexSubscription;
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  Timer? _autoHideTimer;

  List<GlobalAudioQueueItem> _queue = const <GlobalAudioQueueItem>[];
  int _currentIndex = -1;
  Duration _currentTime = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _hidden = false;
  ProcessingState _processingState = ProcessingState.idle;

  List<GlobalAudioQueueItem> get queue => _queue;
  int get currentIndex => _currentIndex;
  Duration get currentTime => _currentTime;
  Duration get duration => _duration;
  bool get playing => _playing;
  bool get hidden => _hidden;
  bool get hasTrack => currentTrack != null;
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex >= 0 && _currentIndex < _queue.length - 1;

  GlobalAudioQueueItem? get currentTrack {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) {
      return null;
    }
    return _queue[_currentIndex];
  }

  double get progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (_currentTime.inMilliseconds / total).clamp(0, 1).toDouble();
  }

  bool queueMatches(List<GlobalAudioQueueItem> other) {
    if (_queue.length != other.length) {
      return false;
    }
    for (var i = 0; i < other.length; i++) {
      if (_queue[i].id != other[i].id) {
        return false;
      }
    }
    return true;
  }

  Future<void> setPlaylist(
    List<GlobalAudioQueueItem> nextQueue, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    if (nextQueue.isEmpty) {
      await clearPlayer();
      return;
    }

    final boundedIndex = startIndex.clamp(0, nextQueue.length - 1);
    final source = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: nextQueue
          .map(
            (item) => AudioSource.uri(
              Uri.parse(item.src),
              headers: item.source == 'youtube'
                  ? const {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    }
                  : null,
              tag: MediaItem(
                id: item.id,
                album: item.artist.isNotEmpty ? item.artist : 'KatsKlub',
                title: item.title.isNotEmpty ? item.title : 'Unknown Title',
                artist: item.artist.isNotEmpty ? item.artist : 'Unknown Artist',
                artUri: item.artworkUrl.isNotEmpty &&
                        !item.artworkUrl.startsWith('data:')
                    ? Uri.parse(item.artworkUrl)
                    : null,
              ),
            ),
          )
          .toList(growable: false),
    );

    _queue = List<GlobalAudioQueueItem>.unmodifiable(nextQueue);
    _currentIndex = boundedIndex;
    _currentTime = Duration.zero;
    _duration = Duration.zero;
    _hidden = false;
    _syncAutoHideTimer();
    notifyListeners();

    await _player.setAudioSource(
      source,
      initialIndex: boundedIndex,
      initialPosition: Duration.zero,
    );

    if (autoPlay) {
      await _player.play();
    } else {
      await _player.pause();
    }
    _syncAutoHideTimer();
  }

  Future<void> playTrack(int index) async {
    if (_queue.isEmpty || index < 0 || index >= _queue.length) {
      return;
    }

    _currentIndex = index;
    _currentTime = Duration.zero;
    _duration = Duration.zero;
    _hidden = false;
    _syncAutoHideTimer();
    notifyListeners();

    await _player.seek(Duration.zero, index: index);
    await _player.play();
    _syncAutoHideTimer();
  }

  Future<void> playRelative(int step) async {
    final nextIndex = _currentIndex + step;
    if (nextIndex < 0 || nextIndex >= _queue.length) {
      return;
    }
    await playTrack(nextIndex);
  }

  Future<void> setPlaying(bool nextPlaying) async {
    if (_queue.isEmpty) {
      return;
    }

    if (nextPlaying) {
      _hidden = false;
      if (_player.processingState == ProcessingState.completed &&
          _currentIndex >= 0) {
        await _player.seek(Duration.zero, index: _currentIndex);
      }
      await _player.play();
    } else {
      await _player.pause();
    }
    _syncAutoHideTimer();
  }

  Future<void> togglePlaying() async {
    await setPlaying(!_playing);
  }

  Future<void> seek(Duration position) async {
    if (_queue.isEmpty) {
      return;
    }
    final safePosition = position < Duration.zero ? Duration.zero : position;
    await _player.seek(safePosition);
  }

  Future<void> clearPlayer() async {
    _cancelAutoHideTimer();
    _queue = const <GlobalAudioQueueItem>[];
    _currentIndex = -1;
    _currentTime = Duration.zero;
    _duration = Duration.zero;
    _playing = false;
    _hidden = false;
    _processingState = ProcessingState.idle;
    await _player.stop();
    notifyListeners();
  }

  void _syncAutoHideTimer() {
    if (_queue.isEmpty) {
      _cancelAutoHideTimer();
      return;
    }

    final isLoadingPlayback = _processingState == ProcessingState.loading ||
        _processingState == ProcessingState.buffering;
    final isActivelyPlaying = _playing &&
        (isLoadingPlayback ||
            _processingState == ProcessingState.ready ||
            _currentTime > Duration.zero ||
            _duration > Duration.zero);

    if (isActivelyPlaying) {
      _hidden = false;
      _cancelAutoHideTimer();
      return;
    }

    _autoHideTimer ??= Timer(_autoHideDelay, () {
      _autoHideTimer = null;
      if (_queue.isEmpty || _playing) {
        return;
      }
      _hidden = true;
      notifyListeners();
    });
  }

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  @override
  void dispose() {
    _cancelAutoHideTimer();
    _currentIndexSubscription.cancel();
    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }
}
