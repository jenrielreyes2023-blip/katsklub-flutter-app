import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room.dart';
import '../services/voice_room_controller.dart';

/// Clean, Monochrome 2-Step PIN Setup Sheet for Host Locking Room
class VoiceRoomSetPinSheet extends StatefulWidget {
  final VoiceRoom room;
  final VoiceRoomController controller;

  const VoiceRoomSetPinSheet({
    super.key,
    required this.room,
    required this.controller,
  });

  static Future<bool?> show(BuildContext context, VoiceRoom room, VoiceRoomController controller) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => VoiceRoomSetPinSheet(room: room, controller: controller),
    );
  }

  @override
  State<VoiceRoomSetPinSheet> createState() => _VoiceRoomSetPinSheetState();
}

class _VoiceRoomSetPinSheetState extends State<VoiceRoomSetPinSheet> {
  int _step = 1; // 1 = Enter PIN, 2 = Confirm PIN
  String _firstPin = '';
  String _confirmPin = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  void _handleDigit(String digit) {
    if (_isSubmitting) return;

    if (_step == 1) {
      if (_firstPin.length >= 4) return;
      HapticFeedback.lightImpact();
      setState(() {
        _errorMessage = null;
        _firstPin += digit;
      });

      if (_firstPin.length == 4) {
        // Automatically transition to step 2 after brief delay
        Future.delayed(const Duration(milliseconds: 140), () {
          if (mounted) {
            setState(() {
              _step = 2;
              _errorMessage = null;
            });
          }
        });
      }
    } else {
      if (_confirmPin.length >= 4) return;
      HapticFeedback.lightImpact();
      setState(() {
        _errorMessage = null;
        _confirmPin += digit;
      });

      if (_confirmPin.length == 4) {
        _validateAndSubmit();
      }
    }
  }

  void _handleBackspace() {
    if (_isSubmitting) return;

    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      if (_step == 1) {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  void _resetToStepOne() {
    HapticFeedback.selectionClick();
    setState(() {
      _step = 1;
      _firstPin = '';
      _confirmPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _validateAndSubmit() async {
    if (_confirmPin != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'PINs do not match. Please re-enter to confirm.';
        _confirmPin = '';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    final ok = await widget.controller.toggleRoomLock(true, pin: _firstPin);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to lock room. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _step == 1 ? _firstPin : _confirmPin;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: 10.h,
          left: 20.w,
          right: 20.w,
          bottom: 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Top Header: Step Indicator & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _step == 1 ? 'Step 1 of 2' : 'Step 2 of 2',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
              ],
            ),

            SizedBox(height: 14.h),

            // Lock Icon
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),

            SizedBox(height: 12.h),

            // Step Title
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _step == 1 ? 'Set Room PIN' : 'Confirm Room PIN',
                key: ValueKey<int>(_step),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            SizedBox(height: 4.h),

            // Step Subtitle
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _step == 1
                    ? 'Enter a 4-digit PIN to restrict entry to your room.'
                    : 'Re-enter the 4-digit PIN to confirm and lock.',
                key: ValueKey<String>('$_step-sub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5.sp,
                ),
              ),
            ),

            SizedBox(height: 22.h),

            // 4 PIN Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < currentPin.length;
                final isCurrent = index == currentPin.length && !_isSubmitting;
                final hasError = _errorMessage != null;

                return Container(
                  width: 48.w,
                  height: 52.h,
                  margin: EdgeInsets.symmetric(horizontal: 6.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1015),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasError
                          ? Colors.redAccent
                          : (isCurrent
                              ? Colors.white
                              : (isFilled
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.08))),
                      width: isCurrent || hasError ? 1.4 : 1.0,
                    ),
                  ),
                  child: isFilled
                      ? Container(
                          width: 10.r,
                          height: 10.r,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      : (isCurrent
                          ? Container(
                              width: 1.8.w,
                              height: 16.h,
                              color: Colors.white70,
                            )
                          : const SizedBox.shrink()),
                );
              }),
            ),

            SizedBox(height: 12.h),

            // Error or Status Area
            SizedBox(
              height: 22.h,
              child: _isSubmitting
                  ? Row(
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
                          'Locking room...',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : _errorMessage != null
                      ? Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : (_step == 2
                          ? GestureDetector(
                              onTap: _resetToStepOne,
                              child: Text(
                                'Change initial PIN',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            )
                          : const SizedBox.shrink()),
            ),

            SizedBox(height: 12.h),

            // Monochrome Numeric Keypad
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  SizedBox(height: 10.h),
                  _buildKeypadRow(['4', '5', '6']),
                  SizedBox(height: 10.h),
                  _buildKeypadRow(['7', '8', '9']),
                  SizedBox(height: 10.h),
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
        SizedBox(width: 60.w, height: 50.h),

        // 0 Digit
        _buildKeypadButton('0'),

        // Backspace button
        GestureDetector(
          onTap: _isSubmitting ? null : _handleBackspace,
          child: Container(
            width: 60.w,
            height: 50.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.backspace_outlined,
              color: _isSubmitting ? Colors.white12 : Colors.white70,
              size: 19,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: _isSubmitting ? null : () => _handleDigit(digit),
      child: Container(
        width: 60.w,
        height: 50.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1015),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Text(
          digit,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
