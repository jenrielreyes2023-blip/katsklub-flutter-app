import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static const MethodChannel _nativeTapChannel =
      MethodChannel('com.katsklub.app/notification_taps');

  final AuthService _authService = AuthService();

  final StreamController<Map<String, dynamic>> _clickStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Persistent guard keys so hot restart / process relaunch does not replay
  // the same initial notification tap data over and over.
  static const String _consumedFcmInitialKey =
      'push.consumedFcmInitialMessageId';
  static const String _consumedNativeInitialKey =
      'push.consumedNativeInitialTapSignature';

  bool _initialized = false;
  bool _nativeTapHandlerAttached = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  Stream<Map<String, dynamic>> get clickStream => _clickStreamController.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _attachNativeTapHandler();
    // 1. Request permissions
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // 2. Configure foreground notification behavior
    try {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // 3. Get FCM token and register it
    await _registerCurrentToken();

    // 4. Listen to token refresh
    _tokenRefreshSubscription ??= _fcm.onTokenRefresh.listen((newToken) async {
      try {
        await _authService.registerPushToken(newToken, 'android');
      } catch (_) {}
    });

    // 5. Handle notification click when app is in background but alive
    _messageOpenedSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _clickStreamController.add(message.data);
    });

    // 6. Handle notification click when app is launched from terminated state
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final messageId = initialMessage.messageId ?? '';
        final prefs = await SharedPreferences.getInstance();
        final lastConsumed = prefs.getString(_consumedFcmInitialKey) ?? '';

        // If we've already routed this exact initial message in a prior run
        // (e.g. before a hot restart or process relaunch), skip the replay.
        if (messageId.isEmpty || messageId != lastConsumed) {
          if (messageId.isNotEmpty) {
            await prefs.setString(_consumedFcmInitialKey, messageId);
          }
          // Delay slightly to allow the app routing/screens to build
          Future.delayed(const Duration(milliseconds: 500), () {
            _clickStreamController.add(initialMessage.data);
          });
        }
      }
    } catch (_) {}

    await _consumeInitialNativeTap();
  }

  void _attachNativeTapHandler() {
    if (_nativeTapHandlerAttached) {
      return;
    }
    _nativeTapHandlerAttached = true;
    _nativeTapChannel.setMethodCallHandler((call) async {
      if (call.method != 'notificationTap') {
        return null;
      }

      final data = _readNativeTapData(call.arguments);
      if (data.isNotEmpty) {
        _clickStreamController.add(data);
      }
      return null;
    });
  }

  Future<void> _consumeInitialNativeTap() async {
    try {
      final data = _readNativeTapData(
        await _nativeTapChannel.invokeMethod<Object?>(
          'getInitialNotificationData',
        ),
      );
      if (data.isEmpty) {
        return;
      }

      // Guard against replay on hot restart / process relaunch: the native
      // side may keep the last tap payload in a static field until the
      // process is fully killed, so the same data can come back across
      // Dart isolate restarts.
      final signature = _signatureForNativeTap(data);
      final prefs = await SharedPreferences.getInstance();
      final lastConsumed = prefs.getString(_consumedNativeInitialKey) ?? '';
      if (signature.isNotEmpty && signature == lastConsumed) {
        return;
      }
      if (signature.isNotEmpty) {
        await prefs.setString(_consumedNativeInitialKey, signature);
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        _clickStreamController.add(data);
      });
    } catch (_) {}
  }

  String _signatureForNativeTap(Map<String, dynamic> data) {
    // Prefer an explicit FCM messageId if the native bridge surfaces it.
    final messageId = (data['google.message_id'] ??
            data['gcm.message_id'] ??
            data['messageId'] ??
            '')
        .toString()
        .trim();
    if (messageId.isNotEmpty) {
      return 'mid:$messageId';
    }

    // Otherwise derive a stable signature from the payload itself. Two
    // different taps practically never produce the same sorted-JSON.
    try {
      final sortedKeys = data.keys.toList()..sort();
      final ordered = <String, String>{
        for (final key in sortedKeys) key: data[key]?.toString() ?? '',
      };
      return 'sig:${jsonEncode(ordered)}';
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> _readNativeTapData(Object? value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }

    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(
          entry.key.toString(),
          entry.value?.toString() ?? '',
        ),
      ),
    );
  }

  Future<void> _registerCurrentToken() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      final status = settings.authorizationStatus;
      if (status == AuthorizationStatus.denied) {
        return;
      }
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _authService.registerPushToken(token, 'android');
    } catch (_) {}
  }
}
