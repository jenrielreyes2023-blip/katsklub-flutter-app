import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import 'auth_service.dart';

class PresenceState {
  const PresenceState({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });

  final String userId;
  final bool isOnline;
  final DateTime? lastSeenAt;

  PresenceState copyWith({bool? isOnline, DateTime? lastSeenAt}) {
    return PresenceState(
      userId: userId,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class PresenceService {
  PresenceService._();

  static final ValueNotifier<Map<String, PresenceState>> presenceNotifier =
      ValueNotifier<Map<String, PresenceState>>(
    const <String, PresenceState>{},
  );

  static io.Socket? _socket;
  static Timer? _heartbeatTimer;
  static final Set<String> _pendingFetch = <String>{};
  static Timer? _fetchDebounce;

  static void attach(io.Socket socket) {
    _socket = socket;

    socket.on('presence:user', (payload) {
      if (payload is! Map) return;
      final map = Map<String, dynamic>.from(
        payload.map((k, v) => MapEntry(k.toString(), v)),
      );
      _applyPresence(map);
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) {
        final s = _socket;
        if (s != null && s.connected) {
          s.emit('presence:heartbeat');
        }
      },
    );
  }

  static void detach() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket = null;
  }

  static PresenceState? presenceFor(String userId) {
    return presenceNotifier.value[userId];
  }

  /// Request presence for a user. Batched + debounced so multiple widgets
  /// asking near-simultaneously share one HTTP call.
  static void ensureLoaded(String userId) {
    if (userId.isEmpty) return;
    if (presenceNotifier.value.containsKey(userId)) return;
    _pendingFetch.add(userId);
    _fetchDebounce?.cancel();
    _fetchDebounce = Timer(const Duration(milliseconds: 120), _flushFetch);
  }

  static Future<void> _flushFetch() async {
    if (_pendingFetch.isEmpty) return;
    final ids = _pendingFetch.toList(growable: false);
    _pendingFetch.clear();

    try {
      final token = await AuthService().getToken();
      if (token == null) return;
      final uri = ApiConfig.uri(
        '/api/presence?userIds=${Uri.encodeComponent(ids.join(','))}',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      if (body is! Map) return;
      final list = body['presence'];
      if (list is! List) return;

      final next = Map<String, PresenceState>.from(presenceNotifier.value);
      for (final entry in list) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        );
        final state = _stateFromMap(map);
        if (state != null) next[state.userId] = state;
      }
      presenceNotifier.value = Map.unmodifiable(next);
    } catch (_) {
      // Silent — presence is best-effort.
    }
  }

  static void _applyPresence(Map<String, dynamic> map) {
    final state = _stateFromMap(map);
    if (state == null) return;
    final next = Map<String, PresenceState>.from(presenceNotifier.value);
    next[state.userId] = state;
    presenceNotifier.value = Map.unmodifiable(next);
  }

  static PresenceState? _stateFromMap(Map<String, dynamic> map) {
    final userId = map['userId']?.toString() ?? '';
    if (userId.isEmpty) return null;
    final isOnline = map['isOnline'] == true;
    DateTime? lastSeenAt;
    final raw = map['lastSeenAt']?.toString();
    if (raw != null && raw.isNotEmpty) {
      lastSeenAt = DateTime.tryParse(raw);
    }
    return PresenceState(
      userId: userId,
      isOnline: isOnline,
      lastSeenAt: lastSeenAt,
    );
  }
}
