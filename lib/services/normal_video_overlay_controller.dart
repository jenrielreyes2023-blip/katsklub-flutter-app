import 'package:flutter/foundation.dart';

import '../models/post.dart';

final NormalVideoOverlayController normalVideoOverlayController =
    NormalVideoOverlayController();

class NormalVideoOverlayController extends ChangeNotifier {
  Post? _video;
  Duration _initialPosition = Duration.zero;
  int _openNonce = 0;

  Post? get video => _video;
  Duration get initialPosition => _initialPosition;
  int get openNonce => _openNonce;
  bool get isOpen => _video != null;

  void open(
    Post video, {
    Duration initialPosition = Duration.zero,
  }) {
    _video = video;
    _initialPosition = initialPosition;
    _openNonce++;
    notifyListeners();
  }

  void close() {
    if (_video == null) {
      return;
    }

    _video = null;
    notifyListeners();
  }
}
