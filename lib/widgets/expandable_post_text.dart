import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../screens/hashtag_screen.dart';
import '../screens/user_profile_screen.dart';
import 'hashtag_text.dart';

class ExpandablePostText extends StatefulWidget {
  const ExpandablePostText({
    required this.text,
    required this.expanded,
    required this.onToggle,
    this.onInteractiveTap,
    super.key,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onInteractiveTap;

  @override
  State<ExpandablePostText> createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<ExpandablePostText> {
  static const int _collapsedMaxLines = 5;
  static const int _minHiddenCharsForSeeMore = 200;
  static const int _minHiddenLinesForSeeMore = 2;

  static final RegExp _sentenceEndRe = RegExp(r"""[.!?…]+["')\]]*\s+""");
  static final RegExp _whitespaceRe = RegExp(r'\s+');

  static final TextStyle _textStyle = TextStyle(
    inherit: false,
    fontSize: 13.sp,
    height: 1.3,
    color: const Color(0xFF1C1E21),
  );

  String? _cachedText;
  double? _cachedMaxWidth;
  bool? _cachedShowSeeMore;
  String? _cachedCollapsedText;

  bool _fits({
    required String value,
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: _textStyle),
      textDirection: textDirection,
      maxLines: _collapsedMaxLines,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);

    return !painter.didExceedMaxLines;
  }

  List<int> _candidateEnds(String text) {
    final candidateEnds = <int>{};

    for (final match in _sentenceEndRe.allMatches(text)) {
      final end = match.end;
      if (end > 0) {
        candidateEnds.add(end);
      }
    }

    for (final match in _whitespaceRe.allMatches(text)) {
      final end = match.start;
      if (end > 0) {
        candidateEnds.add(end);
      }
    }

    final sorted = candidateEnds.toList()..sort();
    return sorted;
  }

  String _collapsedText({
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    if (_fits(
      value: widget.text,
      maxWidth: maxWidth,
      textDirection: textDirection,
    )) {
      return widget.text;
    }

    final candidateEnds = _candidateEnds(widget.text);
    if (candidateEnds.isEmpty) {
      return widget.text;
    }

    var low = 0;
    var high = candidateEnds.length - 1;
    var bestEnd = candidateEnds.first;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final end = candidateEnds[mid];
      final candidate = widget.text.substring(0, end).trimRight();

      if (_fits(
        value: candidate,
        maxWidth: maxWidth,
        textDirection: textDirection,
      )) {
        bestEnd = end;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return widget.text.substring(0, bestEnd).trimRight();
  }

  int _lineCount({
    required String value,
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: _textStyle),
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);

    return painter.computeLineMetrics().length;
  }

  bool _shouldShowSeeMore({
    required String collapsedText,
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    if (collapsedText == widget.text) {
      return false;
    }

    final hiddenRemainder =
        widget.text.substring(collapsedText.length).trimLeft();
    if (hiddenRemainder.isEmpty) {
      return false;
    }

    if (hiddenRemainder.length < _minHiddenCharsForSeeMore) {
      return false;
    }

    final hiddenLineCount = _lineCount(
      value: hiddenRemainder,
      maxWidth: maxWidth,
      textDirection: textDirection,
    );

    return hiddenLineCount >= _minHiddenLinesForSeeMore;
  }

  void _openHashtag(BuildContext context, String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HashtagScreen(tag: tag),
      ),
    );
  }

  void _openMention(BuildContext context, String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        final currentText = widget.text;
        final currentMaxWidth = constraints.maxWidth;

        final bool showSeeMore;
        final String collapsedText;

        if (_cachedText == currentText &&
            _cachedMaxWidth == currentMaxWidth &&
            _cachedShowSeeMore != null &&
            _cachedCollapsedText != null) {
          showSeeMore = _cachedShowSeeMore!;
          collapsedText = _cachedCollapsedText!;
        } else {
          final overflowed = !_fits(
            value: currentText,
            maxWidth: currentMaxWidth,
            textDirection: textDirection,
          );

          final measuredCollapsedText = overflowed
              ? _collapsedText(
                  maxWidth: currentMaxWidth,
                  textDirection: textDirection,
                )
              : currentText;

          showSeeMore = overflowed &&
              _shouldShowSeeMore(
                collapsedText: measuredCollapsedText,
                maxWidth: currentMaxWidth,
                textDirection: textDirection,
              );
          collapsedText = showSeeMore ? measuredCollapsedText : currentText;

          _cachedText = currentText;
          _cachedMaxWidth = currentMaxWidth;
          _cachedShowSeeMore = showSeeMore;
          _cachedCollapsedText = collapsedText;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) => widget.onInteractiveTap?.call(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HashtagText(
                text: widget.expanded ? widget.text : collapsedText,
                style: _textStyle.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF1C1E21),
                ),
                textScaler: TextScaler.noScaling,
                onHashtagTap: (tag) => _openHashtag(context, tag),
                onMentionTap: (username) => _openMention(context, username),
              ),
              if (showSeeMore) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => widget.onInteractiveTap?.call(),
                  onTap: widget.onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      widget.expanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF7A45),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
