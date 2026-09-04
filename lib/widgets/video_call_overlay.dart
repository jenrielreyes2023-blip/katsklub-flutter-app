import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import '../config/api_config.dart';
import '../services/trtc_call_service.dart';

/// Fullscreen immersive Video Call Screen powered by Tencent Cloud RTC.
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  static Future<void> open(BuildContext context) async {
    final nav = Navigator.of(context, rootNavigator: true);
    await nav.push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const VideoCallScreen(),
          );
        },
      ),
    );
  }

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isDismissing = false;
  Offset _localPipPosition = const Offset(20, 90);

  @override
  void initState() {
    super.initState();
    TRTCCallService().sessionNotifier.addListener(_handleSessionChanged);
  }

  @override
  void dispose() {
    TRTCCallService().sessionNotifier.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _dismissScreen() {
    if (mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    }
  }

  void _handleSessionChanged() {
    final session = TRTCCallService().sessionNotifier.value;
    if ((session == null ||
            session.status == CallStatus.idle ||
            session.status == CallStatus.ended) &&
        !_isDismissing) {
      _isDismissing = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _dismissScreen();
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TRTCCallSession?>(
      valueListenable: TRTCCallService().sessionNotifier,
      builder: (context, session, _) {
        final isEndedOrIdle = session == null ||
            session.status == CallStatus.idle ||
            session.status == CallStatus.ended;

        final isIncoming = session?.status == CallStatus.incoming;
        final isOutgoing = session?.status == CallStatus.outgoing;
        final isConnected = session?.status == CallStatus.connected;
        final isEnded = session?.status == CallStatus.ended;

        final avatarUrl = (session?.targetAvatarUrl.trim().isNotEmpty == true)
            ? ApiConfig.assetUrl(session!.targetAvatarUrl)
            : '';

        return PopScope(
          canPop: isEndedOrIdle || _isDismissing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_isDismissing) {
              TRTCCallService().endCall();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: session == null
                ? const SizedBox.shrink()
                : Stack(
                    children: [
                      // 1. Remote Video / Background
                      Positioned.fill(
                        child: _buildRemoteView(session, avatarUrl, isConnected),
                      ),

                      // Gradient overlay for readability
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.25, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // 2. Top Bar (Caller info & duration)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFFF7A45),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        session.targetFullName.isNotEmpty
                                            ? session.targetFullName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.targetFullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isIncoming
                                          ? 'Incoming Video Call...'
                                          : isOutgoing
                                              ? 'Calling...'
                                              : isConnected
                                                  ? _formatDuration(session.duration)
                                                  : isEnded
                                                      ? 'Call ended'
                                                      : 'Connecting...',
                                      style: TextStyle(
                                        color: isConnected
                                            ? const Color(0xFF10B981)
                                            : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isConnected)
                                IconButton(
                                  icon: const Icon(
                                    Icons.flip_camera_ios_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    TRTCCallService().switchCamera();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Draggable Local Camera PiP (Picture-in-Picture)
                      if (!isIncoming && !isEnded)
                        Positioned(
                          right: _localPipPosition.dx,
                          top: _localPipPosition.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                final screenSize = MediaQuery.of(context).size;
                                final newX = (_localPipPosition.dx - details.delta.dx)
                                    .clamp(12.0, screenSize.width - 130);
                                final newY = (_localPipPosition.dy + details.delta.dy)
                                    .clamp(60.0, screenSize.height - 240);
                                _localPipPosition = Offset(newX, newY);
                              });
                            },
                            child: _buildLocalPip(session),
                          ),
                        ),

                      // 4. Bottom Controls Bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 24,
                            ),
                            child: isIncoming
                                ? _buildIncomingControls()
                                : _buildActiveControls(session),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  /// Remote video render view or elegant audio/waiting placeholder.
  Widget _buildRemoteView(
    TRTCCallSession session,
    String avatarUrl,
    bool isConnected,
  ) {
    if (session.isRemoteVideoAvailable && isConnected) {
      return TRTCCloudVideoView(
        key: const ValueKey('remote_trtc_view'),
        onViewCreated: (viewId) {
          TRTCCallService().bindRemoteView(session.targetUserId, viewId);
        },
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF7A45).withValues(alpha: 0.4),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.25),
                  blurRadius: 36,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      session.targetFullName.isNotEmpty
                          ? session.targetFullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            session.targetFullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Camera is off'
                : session.status == CallStatus.outgoing
                    ? 'Ringing...'
                    : 'Connecting...',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// Draggable Floating Local Preview card.
  Widget _buildLocalPip(TRTCCallSession session) {
    return Container(
      width: 110,
      height: 155,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: session.isCameraOff
          ? const Center(
              child: Icon(
                Icons.videocam_off_rounded,
                color: Colors.white54,
                size: 32,
              ),
            )
          : TRTCCloudVideoView(
              key: const ValueKey('local_trtc_view'),
              onViewCreated: (viewId) {
                TRTCCallService().bindLocalView(viewId);
              },
            ),
    );
  }

  /// Incoming Call controls (Accept / Reject).
  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: Icons.call_end_rounded,
          label: 'Decline',
          color: const Color(0xFFEF4444),
          onTap: () {
            TRTCCallService().rejectCall();
          },
        ),
        _controlButton(
          icon: Icons.videocam_rounded,
          label: 'Accept',
          color: const Color(0xFF10B981),
          onTap: () {
            TRTCCallService().acceptCall();
          },
        ),
      ],
    );
  }

  /// Active or Outgoing Call controls (Mute, Camera, Flip, Speaker, End).
  Widget _buildActiveControls(TRTCCallSession session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _iconAction(
            icon: session.isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            isActive: !session.isMuted,
            onTap: () {
              TRTCCallService().toggleMute();
            },
          ),
          _iconAction(
            icon: session.isCameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            isActive: !session.isCameraOff,
            onTap: () {
              TRTCCallService().toggleCamera();
            },
          ),
          _iconAction(
            icon: Icons.flip_camera_ios_rounded,
            isActive: true,
            onTap: () {
              TRTCCallService().switchCamera();
            },
          ),
          _iconAction(
            icon: session.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            isActive: session.isSpeakerOn,
            onTap: () {
              TRTCCallService().toggleSpeakerphone();
            },
          ),
          _controlButton(
            icon: Icons.call_end_rounded,
            label: '',
            color: const Color(0xFFEF4444),
            onTap: () {
              TRTCCallService().endCall();
            },
            size: 50,
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.redAccent.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.redAccent,
          size: 22,
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 64,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: size * 0.45,
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
