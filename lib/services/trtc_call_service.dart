import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/tx_device_manager.dart';

import '../utils/update_checker.dart';
import '../widgets/audio_call_overlay.dart';
import '../widgets/video_call_overlay.dart';
import 'auth_service.dart';
import 'call_sound_service.dart';
import 'feed_service.dart';

enum CallStatus {
  idle,
  outgoing,
  incoming,
  connecting,
  connected,
  ended,
}

/// Generates cryptographic UserSig required by Tencent Cloud TRTC SDK.
class GenerateTestUserSig {
  static const int sdkAppId = 20047589;
  static const String secretKey =
      'c0b8b7bcfa71a45063ec13d8cb56f919d872473dd4222a1e320497d963d78ae6';
  static const int expireTime = 604800; // 7 days in seconds

  static String genTestSig(String userId) {
    final currTime = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final sigDoc = <String, dynamic>{
      'TLS.ver': '2.0',
      'TLS.identifier': userId,
      'TLS.sdkappid': sdkAppId,
      'TLS.expire': expireTime,
      'TLS.time': currTime,
    };

    final sig = _hmacsha256(
      identifier: userId,
      currTime: currTime,
      expire: expireTime,
    );
    sigDoc['TLS.sig'] = sig;
    final jsonStr = json.encode(sigDoc);
    final compress = zlib.encode(utf8.encode(jsonStr));
    return _escape(base64.encode(compress));
  }

  static String _hmacsha256({
    required String identifier,
    required int currTime,
    required int expire,
  }) {
    final contentToBeSigned =
        'TLS.identifier:$identifier\nTLS.sdkappid:$sdkAppId\nTLS.time:$currTime\nTLS.expire:$expire\n';
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(contentToBeSigned));
    return base64.encode(digest.bytes);
  }

  static String _escape(String content) {
    return content
        .replaceAll('+', '*')
        .replaceAll('/', '-')
        .replaceAll('=', '_');
  }
}

/// Information snapshot for active TRTC call session.
class TRTCCallSession {
  const TRTCCallSession({
    required this.callId,
    required this.targetUserId,
    required this.targetUsername,
    required this.targetFullName,
    required this.targetAvatarUrl,
    required this.threadId,
    this.status = CallStatus.idle,
    this.isVideo = true,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.isSpeakerOn = true,
    this.duration = Duration.zero,
    this.isRemoteVideoAvailable = false,
    this.isRemoteAudioAvailable = false,
  });

  final String callId;
  final String targetUserId;
  final String targetUsername;
  final String targetFullName;
  final String targetAvatarUrl;
  final int threadId;
  final CallStatus status;
  final bool isVideo;
  final bool isMuted;
  final bool isCameraOff;
  final bool isFrontCamera;
  final bool isSpeakerOn;
  final Duration duration;
  final bool isRemoteVideoAvailable;
  final bool isRemoteAudioAvailable;

  TRTCCallSession copyWith({
    CallStatus? status,
    bool? isVideo,
    bool? isMuted,
    bool? isCameraOff,
    bool? isFrontCamera,
    bool? isSpeakerOn,
    Duration? duration,
    bool? isRemoteVideoAvailable,
    bool? isRemoteAudioAvailable,
  }) {
    return TRTCCallSession(
      callId: callId,
      targetUserId: targetUserId,
      targetUsername: targetUsername,
      targetFullName: targetFullName,
      targetAvatarUrl: targetAvatarUrl,
      threadId: threadId,
      status: status ?? this.status,
      isVideo: isVideo ?? this.isVideo,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      duration: duration ?? this.duration,
      isRemoteVideoAvailable:
          isRemoteVideoAvailable ?? this.isRemoteVideoAvailable,
      isRemoteAudioAvailable:
          isRemoteAudioAvailable ?? this.isRemoteAudioAvailable,
    );
  }
}

/// Global Singleton Service managing Tencent Cloud RTC Calls (Audio & Video).
class TRTCCallService {
  factory TRTCCallService() => _instance;
  TRTCCallService._internal() {
    sessionNotifier.addListener(_onSessionStatusChanged);
  }
  static final TRTCCallService _instance = TRTCCallService._internal();

  final ValueNotifier<TRTCCallSession?> sessionNotifier =
      ValueNotifier<TRTCCallSession?>(null);

  TRTCCloud? _trtcCloud;
  TXDeviceManager? _deviceManager;
  Timer? _durationTimer;
  bool _isEngineReady = false;
  TRTCCloudListener? _cloudListener;

  // Cached view IDs for reconnect / late binding
  int? _localViewId;
  int? _remoteViewId;

  void _onSessionStatusChanged() {
    final status = sessionNotifier.value?.status;
    if (status == CallStatus.outgoing) {
      CallSoundService.playOutgoingRingback();
    } else if (status == CallStatus.incoming) {
      CallSoundService.playIncomingRingtone();
    } else {
      CallSoundService.stop();
    }
  }

  /// Ensures TRTCCloud instance and listeners are initialized.
  Future<void> _ensureEngine() async {
    if (_isEngineReady && _trtcCloud != null) return;
    try {
      _trtcCloud = await TRTCCloud.sharedInstance();
      _deviceManager = _trtcCloud!.getDeviceManager();

      _cloudListener = TRTCCloudListener(
        onEnterRoom: (result) {
          debugPrint('[TRTC] onEnterRoom: $result');
          if (result > 0) {
            final cur = sessionNotifier.value;
            if (cur != null) {
              sessionNotifier.value = cur.copyWith(status: CallStatus.connected);
              _startDurationTimer();
            }
          } else {
            debugPrint('[TRTC] onEnterRoom failed with code: $result');
            endCall(reason: 'enter_room_failed');
          }
        },
        onExitRoom: (reason) {
          debugPrint('[TRTC] onExitRoom: reason=$reason');
        },
        onRemoteUserEnterRoom: (userId) {
          debugPrint('[TRTC] onRemoteUserEnterRoom: $userId');
          final cur = sessionNotifier.value;
          if (cur != null) {
            sessionNotifier.value = cur.copyWith(status: CallStatus.connected);
            _startDurationTimer();
            // If remote view was already attached before user entered
            if (_remoteViewId != null) {
              _trtcCloud?.startRemoteView(
                userId,
                TRTCVideoStreamType.big,
                _remoteViewId,
              );
            }
          }
        },
        onRemoteUserLeaveRoom: (userId, reason) {
          debugPrint('[TRTC] onRemoteUserLeaveRoom: $userId (reason=$reason)');
          endCall(reason: 'remote_left');
        },
        onUserVideoAvailable: (userId, available) {
          debugPrint('[TRTC] onUserVideoAvailable: $userId, available=$available');
          final cur = sessionNotifier.value;
          if (cur != null) {
            sessionNotifier.value =
                cur.copyWith(isRemoteVideoAvailable: available);
            if (available && _remoteViewId != null) {
              _trtcCloud?.startRemoteView(
                userId,
                TRTCVideoStreamType.big,
                _remoteViewId,
              );
            } else if (!available) {
              _trtcCloud?.stopRemoteView(userId, TRTCVideoStreamType.big);
            }
          }
        },
        onUserAudioAvailable: (userId, available) {
          debugPrint('[TRTC] onUserAudioAvailable: $userId, available=$available');
          final cur = sessionNotifier.value;
          if (cur != null) {
            sessionNotifier.value =
                cur.copyWith(isRemoteAudioAvailable: available);
          }
        },
        onError: (errCode, errMsg, extraInfo) {
          debugPrint('[TRTC] Error $errCode: $errMsg ($extraInfo)');
        },
      );

      _trtcCloud!.registerListener(_cloudListener!);
      _isEngineReady = true;
    } catch (e) {
      debugPrint('[TRTC] Engine init error: $e');
    }
  }

  /// Initializes real-time socket events for call signaling.
  void initSocketListeners() {
    final socket = FeedService.getSocket();
    if (socket == null) return;

    socket.off('call:incoming');
    socket.off('call:accepted');
    socket.off('call:ended');
    socket.off('call:reject');
    socket.off('call:rejected');

    socket.on('call:incoming', (data) async {
      if (data is! Map) return;
      final callId = data['callId']?.toString() ?? '';
      final caller = data['caller'];
      final threadId = _parseInt(data['threadId']);
      final isVideo = data['isVideo'] == true;

      if (callId.isEmpty || caller is! Map) return;

      final callerId = caller['id']?.toString() ?? '';
      final callerUsername = caller['username']?.toString() ?? '';
      final callerFullName = caller['fullName']?.toString() ?? callerUsername;
      final callerAvatarUrl = caller['avatarUrl']?.toString() ?? '';

      // If already in an active call, reject incoming call as busy
      if (sessionNotifier.value != null &&
          sessionNotifier.value!.status != CallStatus.idle &&
          sessionNotifier.value!.status != CallStatus.ended) {
        socket.emit('call:reject', {
          'callId': callId,
          'targetUserId': callerId,
          'reason': 'busy',
        });
        return;
      }

      sessionNotifier.value = TRTCCallSession(
        callId: callId,
        targetUserId: callerId,
        targetUsername: callerUsername,
        targetFullName: callerFullName,
        targetAvatarUrl: callerAvatarUrl,
        threadId: threadId,
        status: CallStatus.incoming,
        isVideo: isVideo,
      );

      final navContext = UpdateChecker.navigatorKey.currentContext;
      if (navContext != null) {
        if (isVideo) {
          VideoCallScreen.open(navContext);
        } else {
          AudioCallScreen.open(navContext);
        }
      }
    });

    socket.on('call:accepted', (data) async {
      if (data is! Map) return;
      final callId = data['callId']?.toString() ?? '';
      final current = sessionNotifier.value;

      if (current == null || current.callId != callId) return;

      sessionNotifier.value = current.copyWith(status: CallStatus.connected);
      _startDurationTimer();
    });

    socket.on('call:ended', (_) {
      endCall(reason: 'ended', notifyPeer: false);
    });

    socket.on('call:reject', (_) {
      endCall(reason: 'rejected', notifyPeer: false);
    });

    socket.on('call:rejected', (_) {
      endCall(reason: 'rejected', notifyPeer: false);
    });
  }

  /// Starts a voice or video call to target user.
  Future<bool> startCall({
    required String targetUserId,
    required String targetUsername,
    required String targetFullName,
    required String targetAvatarUrl,
    required int threadId,
    required bool isVideo,
  }) async {
    // 1. Request microphone & camera permissions
    if (isVideo) {
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera]?.isGranted != true ||
          statuses[Permission.microphone]?.isGranted != true) {
        return false;
      }
    } else {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return false;
    }

    final socket = FeedService.getSocket();
    if (socket == null || !socket.connected) {
      return false;
    }

    await _ensureEngine();

    final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    sessionNotifier.value = TRTCCallSession(
      callId: callId,
      targetUserId: targetUserId,
      targetUsername: targetUsername,
      targetFullName: targetFullName,
      targetAvatarUrl: targetAvatarUrl,
      threadId: threadId,
      status: CallStatus.outgoing,
      isVideo: isVideo,
      isSpeakerOn: isVideo,
    );

    // Open Screen
    final navContext = UpdateChecker.navigatorKey.currentContext;
    if (navContext != null) {
      if (isVideo) {
        VideoCallScreen.open(navContext);
      } else {
        AudioCallScreen.open(navContext);
      }
    }

    // 2. Emit invite to socket
    socket.emit('call:invite', {
      'callId': callId,
      'targetUserId': targetUserId,
      'threadId': threadId,
      'isVideo': isVideo,
    });

    // 3. Enter TRTC Room as anchor
    await _enterTRTCRoom(callId, isVideo);

    return true;
  }

  /// Accepts an incoming call.
  Future<bool> acceptCall() async {
    final current = sessionNotifier.value;
    if (current == null) return false;

    if (current.isVideo) {
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera]?.isGranted != true ||
          statuses[Permission.microphone]?.isGranted != true) {
        rejectCall(reason: 'permission_denied');
        return false;
      }
    } else {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        rejectCall(reason: 'permission_denied');
        return false;
      }
    }

    await _ensureEngine();

    final socket = FeedService.getSocket();
    if (socket != null && socket.connected) {
      socket.emit('call:accept', {
        'callId': current.callId,
        'targetUserId': current.targetUserId,
      });
    }

    sessionNotifier.value = current.copyWith(
      status: CallStatus.connected,
      isSpeakerOn: current.isVideo,
    );
    _startDurationTimer();

    await _enterTRTCRoom(current.callId, current.isVideo);
    return true;
  }

  /// Rejects an incoming call.
  void rejectCall({String reason = 'rejected'}) {
    final current = sessionNotifier.value;
    if (current != null) {
      final socket = FeedService.getSocket();
      if (socket != null && socket.connected) {
        socket.emit('call:reject', {
          'callId': current.callId,
          'targetUserId': current.targetUserId,
          'reason': reason,
        });
      }
    }
    endCall(reason: reason, notifyPeer: false);
  }

  /// Ends an active or outgoing call.
  void endCall({String reason = 'ended', bool notifyPeer = true}) {
    final current = sessionNotifier.value;
    if (current != null && notifyPeer) {
      final socket = FeedService.getSocket();
      if (socket != null && socket.connected) {
        socket.emit('call:end', {
          'callId': current.callId,
          'targetUserId': current.targetUserId,
          'reason': reason,
        });
      }
    }

    _stopDurationTimer();
    CallSoundService.stop();

    try {
      _trtcCloud?.stopLocalAudio();
      _trtcCloud?.stopLocalPreview();
      if (current != null) {
        _trtcCloud?.stopRemoteView(
          current.targetUserId,
          TRTCVideoStreamType.big,
        );
      }
      _trtcCloud?.exitRoom();
    } catch (e) {
      debugPrint('[TRTC] Error stopping TRTC: $e');
    }

    _localViewId = null;
    _remoteViewId = null;

    if (sessionNotifier.value != null) {
      sessionNotifier.value = sessionNotifier.value!.copyWith(
        status: CallStatus.ended,
      );
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      sessionNotifier.value = null;
    });
  }

  Future<void> _enterTRTCRoom(String callId, bool isVideo) async {
    final user = await AuthService().getSavedUser();
    final myUserId = user?.id?.toString() ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final userSig = GenerateTestUserSig.genTestSig(myUserId);

    final trtcParams = TRTCParams(
      sdkAppId: GenerateTestUserSig.sdkAppId,
      userId: myUserId,
      userSig: userSig,
      strRoomId: callId,
      roomId: 0,
      role: TRTCRoleType.anchor,
    );

    _trtcCloud?.enterRoom(
      trtcParams,
      isVideo ? TRTCAppScene.videoCall : TRTCAppScene.audioCall,
    );

    _trtcCloud?.startLocalAudio(TRTCAudioQuality.defaultMode);
    _deviceManager?.setAudioRoute(
      isVideo ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece,
    );
  }

  /// Binds local camera preview viewId when widget is mounted.
  void bindLocalView(int viewId) {
    _localViewId = viewId;
    final cur = sessionNotifier.value;
    final isFront = cur?.isFrontCamera ?? true;
    _trtcCloud?.startLocalPreview(isFront, viewId);
  }

  /// Binds remote camera viewId when widget is mounted.
  void bindRemoteView(String userId, int viewId) {
    _remoteViewId = viewId;
    _trtcCloud?.startRemoteView(userId, TRTCVideoStreamType.big, viewId);
  }

  /// Mutes / unmutes microphone.
  void toggleMute() {
    final cur = sessionNotifier.value;
    if (cur == null) return;
    final newMute = !cur.isMuted;
    _trtcCloud?.muteLocalAudio(newMute);
    sessionNotifier.value = cur.copyWith(isMuted: newMute);
  }

  /// Turns camera on / off.
  void toggleCamera() {
    final cur = sessionNotifier.value;
    if (cur == null) return;
    final newCameraOff = !cur.isCameraOff;
    _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, newCameraOff);
    sessionNotifier.value = cur.copyWith(isCameraOff: newCameraOff);
  }

  /// Flips front / back camera.
  void switchCamera() {
    final cur = sessionNotifier.value;
    if (cur == null) return;
    final newFront = !cur.isFrontCamera;
    _deviceManager?.switchCamera(newFront);
    sessionNotifier.value = cur.copyWith(isFrontCamera: newFront);
  }

  /// Toggles speakerphone vs earpiece.
  void toggleSpeakerphone() {
    final cur = sessionNotifier.value;
    if (cur == null) return;
    final newSpeaker = !cur.isSpeakerOn;
    _deviceManager?.setAudioRoute(
      newSpeaker ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece,
    );
    sessionNotifier.value = cur.copyWith(isSpeakerOn: newSpeaker);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    var seconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds++;
      final cur = sessionNotifier.value;
      if (cur != null && cur.status == CallStatus.connected) {
        sessionNotifier.value = cur.copyWith(
          duration: Duration(seconds: seconds),
        );
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  int _parseInt(dynamic val) {
    if (val is int) return val;
    return int.tryParse(val?.toString() ?? '') ?? 0;
  }
}
