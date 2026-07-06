import 'package:flutter/material.dart';

class DebugLogOverlay {
  static final List<String> _logs = ['debug overlay active'];
  static final ValueNotifier<int> _updateNotifier = ValueNotifier(0);
  static const int _maxLogs = 12;

  static void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    _logs.add('[$timestamp] $message');
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    _updateNotifier.value++;
    debugPrint(message);
  }

  static void clear() {
    _logs.clear();
    _updateNotifier.value++;
  }

  static Widget build() {
    return ValueListenableBuilder<int>(
      valueListenable: _updateNotifier,
      builder: (context, _, __) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'DEBUG LOGS',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _logs.map((log) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                log,
                                style: const TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
