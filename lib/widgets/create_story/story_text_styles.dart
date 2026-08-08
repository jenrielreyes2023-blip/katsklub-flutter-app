import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StoryTextStylePreset {
  const StoryTextStylePreset({
    required this.label,
    required this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.horizontalPadding = 16,
    this.verticalPadding = 12,
    this.borderRadius = 18,
  });

  final String label;
  final TextStyle textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
}

final List<StoryTextStylePreset> storyTextPresets = [
  StoryTextStylePreset(
    label: 'Classic',
    textStyle: TextStyle(
      fontFamily: 'SF Pro Rounded',
      color: Colors.white,
      fontSize: 34.sp,
      fontWeight: FontWeight.w700,
      height: 1.2,
      shadows: [Shadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3))],
    ),
  ),
  StoryTextStylePreset(
    label: 'Outline',
    textStyle: TextStyle(
      fontFamily: 'SF Pro Rounded',
      color: Colors.black,
      fontSize: 34.sp,
      fontWeight: FontWeight.w800,
      height: 1.18,
    ),
    backgroundColor: Colors.white,
    borderColor: Colors.black,
    horizontalPadding: 18,
    verticalPadding: 12,
    borderRadius: 18,
  ),
  StoryTextStylePreset(
    label: 'Soft',
    textStyle: TextStyle(
      fontFamily: 'SF Pro Rounded',
      color: Colors.white,
      fontSize: 32.sp,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      height: 1.24,
    ),
    backgroundColor: Color(0x33000000),
    horizontalPadding: 16,
    verticalPadding: 12,
    borderRadius: 22,
  ),
  StoryTextStylePreset(
    label: 'Bold',
    textStyle: TextStyle(
      fontFamily: 'SF Pro Rounded',
      color: Colors.white,
      fontSize: 38.sp,
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: -0.3,
    ),
    backgroundColor: Color(0xCC000000),
    horizontalPadding: 18,
    verticalPadding: 10,
    borderRadius: 14,
  ),
];
