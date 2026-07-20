import 'package:flutter/material.dart';
import 'gold_shimmer_text.dart';
import 'rainbow_shimmer_text.dart';

class SpecialNameText extends StatelessWidget {
  const SpecialNameText({
    super.key,
    required this.username,
    required this.displayName,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.isAdmin = false,
  });

  final String username;
  final String displayName;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername == 'human_equality') {
      return RainbowShimmerText(
        text: displayName,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    } else if (cleanUsername == 'gemini' || isAdmin) {
      return GoldShimmerText(
        text: displayName,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    } else {
      return Text(
        displayName,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
  }
}
