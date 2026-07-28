import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/webrtc_call_service.dart';

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({super.key});

  static Future<void> open(BuildContext context) async {
    final nav = Navigator.of(context, rootNavigator: true);
    await nav.push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const AudioCallScreen(),
          );
        },
      ),
    );
  }

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    WebRTCCallService().sessionNotifier.addListener(_handleSessionChanged);
  }

  @override
  void dispose() {
    WebRTCCallService().sessionNotifier.removeListener(_handleSessionChanged);
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
    final session = WebRTCCallService().sessionNotifier.value;
    if ((session == null || session.status == CallStatus.idle || session.status == CallStatus.ended) &&
        !_isDismissing) {
      _isDismissing = true;
      Future.delayed(const Duration(milliseconds: 500), () {
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
    return ValueListenableBuilder<CallSessionInfo?>(
      valueListenable: WebRTCCallService().sessionNotifier,
      builder: (context, session, _) {
        final isEndedOrIdle = session == null ||
            session.status == CallStatus.idle ||
            session.status == CallStatus.ended;

        final isIncoming = session?.status == CallStatus.incoming;
        final isOutgoing = session?.status == CallStatus.outgoing;
        final isConnecting = session?.status == CallStatus.connecting;
        final isConnected = session?.status == CallStatus.connected;
        final isEnded = session?.status == CallStatus.ended;

        final avatarUrl = (session?.targetAvatarUrl.trim().isNotEmpty == true)
            ? ApiConfig.assetUrl(session!.targetAvatarUrl)
            : '';

        return PopScope(
          canPop: isEndedOrIdle || _isDismissing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_isDismissing) {
              WebRTCCallService().endCall();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: session == null
                ? const SizedBox.shrink()
                : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Header Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isIncoming
                            ? '📞 INCOMING VOICE CALL'
                            : isOutgoing
                                ? '🎙️ CALLING...'
                                : isConnecting
                                    ? '⚡ CONNECTING...'
                                    : isEnded
                                        ? '🔴 CALL ENDED'
                                        : '⏱️ ${_formatDuration(session.duration)}',
                        style: TextStyle(
                          color: isConnected
                              ? const Color(0xFF34D399)
                              : const Color(0xFFA5B4FC),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Target Name
                    Text(
                      session.targetFullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${session.targetUsername}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),

                    // Avatar Container
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6366F1),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isConnected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6366F1))
                                .withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFF334155),
                                ),
                                errorWidget: (_, __, ___) => _avatarFallback(session),
                              )
                            : _avatarFallback(session),
                      ),
                    ),

                    const Spacer(),

                    // Controls Row
                    if (isIncoming) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Decline Button
                          _CallControlButton(
                            icon: Icons.call_end_rounded,
                            color: const Color(0xFFEF4444),
                            label: 'Decline',
                            size: 64,
                            onTap: () => WebRTCCallService().rejectCall(),
                          ),
                          // Accept Button
                          _CallControlButton(
                            icon: Icons.call_rounded,
                            color: const Color(0xFF10B981),
                            label: 'Accept',
                            size: 64,
                            onTap: () => WebRTCCallService().acceptCall(),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mute Button
                          _CallControlButton(
                            icon: session.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            color: session.isMuted
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF334155),
                            label: session.isMuted ? 'Muted' : 'Mute',
                            onTap: isConnected
                                ? () => WebRTCCallService().toggleMute()
                                : null,
                          ),

                          // End Call Button
                          _CallControlButton(
                            icon: Icons.call_end_rounded,
                            color: const Color(0xFFEF4444),
                            label: 'End Call',
                            size: 64,
                            onTap: () => WebRTCCallService().endCall(),
                          ),

                          // Speaker Button
                          _CallControlButton(
                            icon: session.isSpeakerOn
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: session.isSpeakerOn
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF334155),
                            label: 'Speaker',
                            onTap: isConnected
                                ? () => WebRTCCallService().toggleSpeaker()
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _avatarFallback(CallSessionInfo session) {
    return Container(
      color: const Color(0xFF334155),
      alignment: Alignment.center,
      child: Text(
        session.targetUsername.isNotEmpty
            ? session.targetUsername[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 52,
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.size = 54,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: onTap != null ? color : color.withValues(alpha: 0.4),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
