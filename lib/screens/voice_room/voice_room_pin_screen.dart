import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/voice_room_controller.dart';
import 'voice_room_screen.dart';

/// Full-Page PIN Verification Screen for Locked Voice Rooms
class VoiceRoomPinScreen extends StatefulWidget {
  final VoiceRoom room;
  final User currentUser;

  const VoiceRoomPinScreen({
    super.key,
    required this.room,
    required this.currentUser,
  });

  /// Static helper to open room with PIN check
  static Future<void> tryOpen(BuildContext context, VoiceRoom room, User currentUser) async {
    final isHost = room.host.id.toString() == currentUser.id.toString();

    // Hosts can always enter directly without PIN
    if (isHost || !room.isLocked) {
      VoiceRoomScreen.open(context, room, currentUser);
      return;
    }

    // Guests must pass the PIN screen
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => VoiceRoomPinScreen(room: room, currentUser: currentUser),
      ),
    );

    if (ok == true && context.mounted) {
      VoiceRoomScreen.open(context, room, currentUser);
    }
  }

  @override
  State<VoiceRoomPinScreen> createState() => _VoiceRoomPinScreenState();
}

class _VoiceRoomPinScreenState extends State<VoiceRoomPinScreen> {
  // Static memory state to persist lockout across pop/push within session
  static final Map<int, DateTime> _roomLockoutUntil = {};
  static final Map<int, int> _roomFailedAttempts = {};

  String _enteredPin = '';
  bool _isVerifying = false;
  bool _hasError = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _lockdownRemainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkLockdownState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _checkLockdownState() {
    final lockoutTime = _roomLockoutUntil[widget.room.id];
    if (lockoutTime != null) {
      final diff = lockoutTime.difference(DateTime.now()).inSeconds;
      if (diff > 0) {
        _startLockdownCountdown(diff);
      } else {
        _roomLockoutUntil.remove(widget.room.id);
        _roomFailedAttempts[widget.room.id] = 0;
      }
    }
  }

  void _startLockdownCountdown(int seconds) {
    _lockdownRemainingSeconds = seconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockdownRemainingSeconds > 1) {
          _lockdownRemainingSeconds--;
        } else {
          _lockdownRemainingSeconds = 0;
          _roomLockoutUntil.remove(widget.room.id);
          _roomFailedAttempts[widget.room.id] = 0;
          timer.cancel();
        }
      });
    });
  }

  int get _attempts => _roomFailedAttempts[widget.room.id] ?? 0;
  bool get _isLockedDown => _lockdownRemainingSeconds > 0;

  void _handleDigitTap(String digit) {
    if (_isLockedDown || _isVerifying) return;
    if (_enteredPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _handleBackspace() {
    if (_isLockedDown || _isVerifying || _enteredPin.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    if (_enteredPin.length != 4) return;

    setState(() => _isVerifying = true);

    final ok = await VoiceRoomController().verifyRoomPin(widget.room.id, _enteredPin);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      _roomFailedAttempts.remove(widget.room.id);
      _roomLockoutUntil.remove(widget.room.id);
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      final newAttempts = _attempts + 1;
      _roomFailedAttempts[widget.room.id] = newAttempts;

      setState(() {
        _isVerifying = false;
        _hasError = true;
        _enteredPin = '';

        if (newAttempts >= 6) {
          // 5 Minutes Lockdown
          _roomLockoutUntil[widget.room.id] = DateTime.now().add(const Duration(minutes: 5));
          _startLockdownCountdown(300);
        } else {
          final left = 6 - newAttempts;
          _errorMessage = 'Incorrect PIN. $left attempt${left == 1 ? '' : 's'} remaining.';
        }
      });
    }
  }

  String _formatCountdown(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1015),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Protected Room',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),

                    // Host Avatar with Lock Badge
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 36.r,
                            backgroundColor: const Color(0xFF17181F),
                            backgroundImage: widget.room.host.avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(widget.room.host.avatarUrl)
                                : null,
                            child: widget.room.host.avatarUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.white54, size: 36)
                                : null,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF17181F),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F1015), width: 2),
                              ),
                              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // Room Title
                    Text(
                      widget.room.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),

                    SizedBox(height: 4.h),

                    Text(
                      'Hosted by ${widget.room.host.fullName}',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Main Content: Lockdown vs 4 PIN Boxes
                    if (_isLockedDown) ...[
                      // 5-Minute Lockdown View
                      Container(
                        padding: EdgeInsets.all(22.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17181F),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 36),
                            SizedBox(height: 10.h),
                            Text(
                              'Too Many Failed Attempts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'You have exceeded the maximum of 6 attempts.\nThis room is on lockdown for 5 minutes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.sp,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _formatCountdown(_lockdownRemainingSeconds),
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // 4 PIN Boxes
                      Text(
                        'Enter 4-Digit PIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Please enter the private PIN to access this room.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11.5.sp,
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // 4 Center Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < _enteredPin.length;
                          final isCurrent = index == _enteredPin.length && !_isVerifying;

                          return Container(
                            width: 52.w,
                            height: 58.h,
                            margin: EdgeInsets.symmetric(horizontal: 6.w),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF17181F),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _hasError
                                    ? Colors.redAccent
                                    : (isCurrent
                                        ? Colors.white
                                        : (isFilled
                                            ? Colors.white.withValues(alpha: 0.4)
                                            : Colors.white.withValues(alpha: 0.08))),
                                width: isCurrent || _hasError ? 1.4 : 1.0,
                              ),
                            ),
                            child: isFilled
                                ? Container(
                                    width: 12.r,
                                    height: 12.r,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : (isCurrent
                                    ? Container(
                                        width: 2.w,
                                        height: 18.h,
                                        color: Colors.white60,
                                      )
                                    : const SizedBox.shrink()),
                          );
                        }),
                      ),

                      SizedBox(height: 14.h),

                      // Status or Remaining Attempts
                      if (_isVerifying) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 13.r,
                              height: 13.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Verifying PIN...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ] else if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '${6 - _attempts} attempt${(6 - _attempts) == 1 ? '' : 's'} remaining',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Modern Monochrome Numeric Keypad
            Padding(
              padding: EdgeInsets.only(left: 36.w, right: 36.w, bottom: 20.h),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  SizedBox(height: 12.h),
                  _buildKeypadRow(['4', '5', '6']),
                  SizedBox(height: 12.h),
                  _buildKeypadRow(['7', '8', '9']),
                  SizedBox(height: 12.h),
                  _buildKeypadBottomRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Empty placeholder
        SizedBox(width: 64.w, height: 60.h),

        // 0 Digit
        _buildKeypadButton('0'),

        // Backspace button
        GestureDetector(
          onTap: _isLockedDown || _isVerifying ? null : _handleBackspace,
          child: Container(
            width: 64.w,
            height: 60.h,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.backspace_outlined,
              color: _isLockedDown || _isVerifying ? Colors.white12 : Colors.white70,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    final isDisabled = _isLockedDown || _isVerifying;

    return GestureDetector(
      onTap: isDisabled ? null : () => _handleDigitTap(digit),
      child: Container(
        width: 64.w,
        height: 60.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFF13141A) : const Color(0xFF17181F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDisabled ? 0.03 : 0.08),
            width: 1,
          ),
        ),
        child: Text(
          digit,
          style: TextStyle(
            color: isDisabled ? Colors.white24 : Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
