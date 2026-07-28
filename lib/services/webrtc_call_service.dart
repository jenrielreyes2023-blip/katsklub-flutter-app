import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'feed_service.dart';
import 'call_sound_service.dart';
import '../utils/update_checker.dart';
import '../widgets/audio_call_overlay.dart';

enum CallStatus {
  idle,
  outgoing,
  incoming,
  connecting,
  connected,
  ended,
}

class CallSessionInfo {
  const CallSessionInfo({
    required this.callId,
    required this.targetUserId,
    required this.targetUsername,
    required this.targetFullName,
    required this.targetAvatarUrl,
    required this.threadId,
    this.status = CallStatus.idle,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.duration = Duration.zero,
  });

  final String callId;
  final String targetUserId;
  final String targetUsername;
  final String targetFullName;
  final String targetAvatarUrl;
  final int threadId;
  final CallStatus status;
  final bool isMuted;
  final bool isSpeakerOn;
  final Duration duration;

  CallSessionInfo copyWith({
    CallStatus? status,
    bool? isMuted,
    bool? isSpeakerOn,
    Duration? duration,
  }) {
    return CallSessionInfo(
      callId: callId,
      targetUserId: targetUserId,
      targetUsername: targetUsername,
      targetFullName: targetFullName,
      targetAvatarUrl: targetAvatarUrl,
      threadId: threadId,
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      duration: duration ?? this.duration,
    );
  }
}

class WebRTCCallService {
  factory WebRTCCallService() => _instance;
  WebRTCCallService._internal() {
    sessionNotifier.addListener(_onSessionStatusChanged);
  }
  static final WebRTCCallService _instance = WebRTCCallService._internal();

  final ValueNotifier<CallSessionInfo?> sessionNotifier =
      ValueNotifier<CallSessionInfo?>(null);

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

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  Timer? _durationTimer;
  StreamSubscription<void>? _socketSub;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  void initSocketListeners() {
    final socket = FeedService.getSocket();
    if (socket == null) return;

    socket.off('call:incoming');
    socket.off('call:accepted');
    socket.off('call:ended');
    socket.off('call:ice-candidate');

    socket.on('call:incoming', (data) async {
      if (data is! Map) return;
      final callId = data['callId']?.toString() ?? '';
      final caller = data['caller'];
      final sdpOffer = data['sdpOffer']?.toString();
      final threadId = NumberUtils.parseInt(data['threadId']);

      if (callId.isEmpty || caller is! Map || sdpOffer == null) return;

      // If already in a call, reject incoming call as busy
      if (sessionNotifier.value != null &&
          sessionNotifier.value!.status != CallStatus.idle) {
        socket.emit('call:reject', {
          'callId': callId,
          'targetUserId': caller['id']?.toString() ?? '',
          'reason': 'busy',
        });
        return;
      }

      final callerId = caller['id']?.toString() ?? '';
      final callerUsername = caller['username']?.toString() ?? '';
      final callerFullName = caller['fullName']?.toString() ?? callerUsername;
      final callerAvatarUrl = caller['avatarUrl']?.toString() ?? '';

      sessionNotifier.value = CallSessionInfo(
        callId: callId,
        targetUserId: callerId,
        targetUsername: callerUsername,
        targetFullName: callerFullName,
        targetAvatarUrl: callerAvatarUrl,
        threadId: threadId,
        status: CallStatus.incoming,
      );

      _pendingRemoteSdp = sdpOffer;

      final navContext = UpdateChecker.navigatorKey.currentContext;
      if (navContext != null) {
        AudioCallScreen.open(navContext);
      }
    });

    socket.on('call:accepted', (data) async {
      if (data is! Map) return;
      final callId = data['callId']?.toString() ?? '';
      final sdpAnswer = data['sdpAnswer']?.toString();
      final current = sessionNotifier.value;

      if (current == null || current.callId != callId || sdpAnswer == null) {
        return;
      }

      try {
        final answer = RTCSessionDescription(sdpAnswer, 'answer');
        await _peerConnection?.setRemoteDescription(answer);
        _startCallTimer();
        sessionNotifier.value = current.copyWith(status: CallStatus.connected);
      } catch (e) {
        debugPrint('[WebRTC] Error setting remote description: $e');
      }
    });

    socket.on('call:ended', (data) {
      endCall(reason: 'ended');
    });

    socket.on('call:ice-candidate', (data) async {
      if (data is! Map) return;
      final candidateMap = data['candidate'];
      if (candidateMap is Map) {
        final candidate = RTCIceCandidate(
          candidateMap['candidate']?.toString(),
          candidateMap['sdpMid']?.toString(),
          NumberUtils.parseInt(candidateMap['sdpMLineIndex']),
        );
        await _peerConnection?.addCandidate(candidate);
      }
    });
  }

  String? _pendingRemoteSdp;

  Future<bool> startAudioCall({
    required String targetUserId,
    required String targetUsername,
    required String targetFullName,
    required String targetAvatarUrl,
    required int threadId,
  }) async {
    final socket = FeedService.getSocket();
    if (socket == null || !socket.connected) {
      return false;
    }

    final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    sessionNotifier.value = CallSessionInfo(
      callId: callId,
      targetUserId: targetUserId,
      targetUsername: targetUsername,
      targetFullName: targetFullName,
      targetAvatarUrl: targetAvatarUrl,
      threadId: threadId,
      status: CallStatus.outgoing,
    );

    final navContext = UpdateChecker.navigatorKey.currentContext;
    if (navContext != null) {
      AudioCallScreen.open(navContext);
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      _peerConnection = await createPeerConnection(_configuration);

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        socket.emit('call:ice-candidate', {
          'callId': callId,
          'targetUserId': targetUserId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        }
      };

      final offer = await _peerConnection!.createOffer({'offerToReceiveAudio': 1});
      await _peerConnection!.setLocalDescription(offer);

      socket.emit('call:invite', {
        'callId': callId,
        'targetUserId': targetUserId,
        'threadId': threadId,
        'sdpOffer': offer.sdp,
        'isVideo': false,
      });

      return true;
    } catch (e) {
      debugPrint('[WebRTC] Start audio call error: $e');
      endCall(reason: 'error');
      return false;
    }
  }

  Future<void> acceptCall() async {
    final current = sessionNotifier.value;
    final socket = FeedService.getSocket();
    if (current == null || socket == null || _pendingRemoteSdp == null) {
      return;
    }

    sessionNotifier.value = current.copyWith(status: CallStatus.connecting);

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      _peerConnection = await createPeerConnection(_configuration);

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        socket.emit('call:ice-candidate', {
          'callId': current.callId,
          'targetUserId': current.targetUserId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        }
      };

      final offer = RTCSessionDescription(_pendingRemoteSdp!, 'offer');
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer({'offerToReceiveAudio': 1});
      await _peerConnection!.setLocalDescription(answer);

      socket.emit('call:accept', {
        'callId': current.callId,
        'callerUserId': current.targetUserId,
        'sdpAnswer': answer.sdp,
      });

      _startCallTimer();
      sessionNotifier.value = current.copyWith(status: CallStatus.connected);
    } catch (e) {
      debugPrint('[WebRTC] Accept call error: $e');
      endCall(reason: 'error');
    }
  }

  void rejectCall() {
    final current = sessionNotifier.value;
    final socket = FeedService.getSocket();
    if (current != null && socket != null) {
      socket.emit('call:reject', {
        'callId': current.callId,
        'targetUserId': current.targetUserId,
        'reason': 'declined',
      });
    }
    endCall(reason: 'declined');
  }

  void endCall({String reason = 'ended'}) {
    final current = sessionNotifier.value;
    final socket = FeedService.getSocket();

    if (current != null && socket != null && socket.connected) {
      socket.emit('call:end', {
        'callId': current.callId,
        'targetUserId': current.targetUserId,
        'reason': reason,
      });
    }

    _durationTimer?.cancel();
    _durationTimer = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.dispose();
    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    _pendingRemoteSdp = null;

    if (sessionNotifier.value != null) {
      sessionNotifier.value = sessionNotifier.value!.copyWith(status: CallStatus.ended);
      Future.delayed(const Duration(milliseconds: 800), () {
        sessionNotifier.value = null;
      });
    }
  }

  void toggleMute() {
    final current = sessionNotifier.value;
    if (current == null || _localStream == null) return;

    final newMute = !current.isMuted;
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !newMute;
    });

    sessionNotifier.value = current.copyWith(isMuted: newMute);
  }

  void toggleSpeaker() {
    final current = sessionNotifier.value;
    if (current == null || _localStream == null) return;

    final newSpeaker = !current.isSpeakerOn;
    _localStream!.getAudioTracks().forEach((track) {
      track.enableSpeakerphone(newSpeaker);
    });

    sessionNotifier.value = current.copyWith(isSpeakerOn: newSpeaker);
  }

  void _startCallTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = sessionNotifier.value;
      if (current == null || current.status != CallStatus.connected) {
        timer.cancel();
        return;
      }
      sessionNotifier.value = current.copyWith(
        duration: current.duration + const Duration(seconds: 1),
      );
    });
  }
}

class NumberUtils {
  static int parseInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }
}
