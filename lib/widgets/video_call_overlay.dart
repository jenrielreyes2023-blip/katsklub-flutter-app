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
  Offset _localPipPosition = const Offset(16, 100);

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

        final showRemoteInMain =
            isConnected && (session?.isRemoteVideoAvailable ?? false);
        final showLocalInPip =
            showRemoteInMain && !isIncoming && !isEnded;

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
                : SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. FULLSCREEN MAIN VIDEO BACKGROUND
                        Positioned.fill(
                          child: _buildMainVideoView(
                            session: session,
                            showRemoteInMain: showRemoteInMain,
                            avatarUrl: avatarUrl,
                            isConnected: isConnected,
                            isOutgoing: isOutgoing,
                          ),
                        ),

                        // 2. GRADIENT VIGNETTE OVERLAYS (Top & Bottom for readability)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.75),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.2, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 3. CALLING / RINGING / WAITING CENTER OVERLAY (when not showing remote video)
                        if (!showRemoteInMain)
                          Center(
                            child: _buildWaitingOverlay(
                              session: session,
                              avatarUrl: avatarUrl,
                              isIncoming: isIncoming,
                              isOutgoing: isOutgoing,
                              isConnected: isConnected,
                            ),
                          ),

                        // 4. FLOATING DRAGGABLE LOCAL CAMERA PiP (When remote video is active)
                        if (showLocalInPip)
                          Positioned(
                            right: _localPipPosition.dx,
                            top: _localPipPosition.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  final size = MediaQuery.of(context).size;
                                  final newX = (_localPipPosition.dx -
                                          details.delta.dx)
                                      .clamp(12.0, size.width - 130);
                                  final newY = (_localPipPosition.dy +
                                          details.delta.dy)
                                      .clamp(80.0, size.height - 240);
                                  _localPipPosition = Offset(newX, newY);
                                });
                              },
                              child: _buildLocalPip(session),
                            ),
                          ),

                        // 5. TOP HEADER BAR (Anchored at TOP: 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFFF7A45),
                                      backgroundImage: avatarUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(avatarUrl)
                                          : null,
                                      child: avatarUrl.isEmpty
                                          ? Text(
                                              session.targetFullName.isNotEmpty
                                                  ? session.targetFullName[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.targetFullName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            isIncoming
                                                ? '📞 Incoming Video Call...'
                                                : isOutgoing
                                                    ? '🎙️ Calling...'
                                                    : isConnected
                                                        ? '⏱️ ${_formatDuration(session.duration)}'
                                                        : isEnded
                                                            ? '🔴 Call ended'
                                                            : '⚡ Connecting...',
                                            style: TextStyle(
                                              color: isConnected
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFFF9800),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.flip_camera_ios_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      tooltip: 'Flip Camera',
                                      onPressed: () {
                                        TRTCCallService().switchCamera();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 6. BOTTOM CONTROLS DOCK (Firmly anchored at BOTTOM: 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              child: isIncoming
                                  ? _buildIncomingControls()
                                  : _buildActiveControls(session),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// Fullscreen video render view (either Remote video or Local camera preview).
  Widget _buildMainVideoView({
    required TRTCCallSession session,
    required bool showRemoteInMain,
    required String avatarUrl,
    required bool isConnected,
    required bool isOutgoing,
  }) {
    if (showRemoteInMain) {
      return TRTCCloudVideoView(
        key: const ValueKey('fullscreen_remote_video_view'),
        onViewCreated: (viewId) {
          TRTCCallService().bindRemoteView(session.targetUserId, viewId);
        },
      );
    }

    // While waiting for peer to answer, or if peer has no video, display local camera fullscreen
    if (!session.isCameraOff) {
      return TRTCCloudVideoView(
        key: const ValueKey('fullscreen_local_camera_preview'),
        onViewCreated: (viewId) {
          TRTCCallService().bindLocalView(viewId);
        },
      );
    }

    // Camera is off fallback
    return Container(
      color: const Color(0xFF0F172A),
    );
  }

  /// Center badge shown while waiting or ringing.
  Widget _buildWaitingOverlay({
    required TRTCCallSession session,
    required String avatarUrl,
    required bool isIncoming,
    required bool isOutgoing,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF7A45),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
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
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            session.targetFullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '@${session.targetUsername}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : const Color(0xFFFF7A45).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isIncoming
                  ? 'Incoming Video Call...'
                  : isOutgoing
                      ? 'Ringing...'
                      : isConnected
                          ? 'Waiting for video...'
                          : 'Connecting...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isConnected
                    ? const Color(0xFF10B981)
                    : const Color(0xFFFF7A45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Draggable Floating Local Preview card (shown when remote video is fullscreen).
  Widget _buildLocalPip(TRTCCallSession session) {
    return Container(
      width: 110,
      height: 155,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
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
              key: const ValueKey('pip_local_video_view'),
              onViewCreated: (viewId) {
                TRTCCallService().bindLocalView(viewId);
              },
            ),
    );
  }

  /// Incoming Call controls (Decline / Accept).
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

  /// Active or Outgoing Call controls (Mute, Camera, Flip, Speaker, End Call).
  Widget _buildActiveControls(TRTCCallSession session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Microphone
          _iconAction(
            icon: session.isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            isActive: !session.isMuted,
            label: session.isMuted ? 'Muted' : 'Mic',
            onTap: () {
              TRTCCallService().toggleMute();
            },
          ),

          // 2. Camera Toggle
          _iconAction(
            icon: session.isCameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            isActive: !session.isCameraOff,
            label: session.isCameraOff ? 'Cam Off' : 'Cam On',
            onTap: () {
              TRTCCallService().toggleCamera();
            },
          ),

          // 3. Speaker Toggle
          _iconAction(
            icon: session.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            isActive: session.isSpeakerOn,
            label: session.isSpeakerOn ? 'Speaker' : 'Earpiece',
            onTap: () {
              TRTCCallService().toggleSpeakerphone();
            },
          ),

          // 4. Flip Camera
          _iconAction(
            icon: Icons.flip_camera_ios_rounded,
            isActive: true,
            label: 'Flip',
            onTap: () {
              TRTCCallService().switchCamera();
            },
          ),

          // 5. End Call Button
          GestureDetector(
            onTap: () {
              TRTCCallService().endCall();
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.12)
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
    );
  }
}
