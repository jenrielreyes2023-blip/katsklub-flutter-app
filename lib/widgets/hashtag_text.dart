import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/emoji_presentation.dart';

class HashtagText extends StatefulWidget {
  const HashtagText({
    required this.text,
    required this.style,
    required this.onHashtagTap,
    this.onMentionTap,
    this.textScaler,
    this.maxLines,
    this.overflow,
    this.hashtagStyle,
    this.mentionStyle,
    this.prefixSpans,
    super.key,
  });

  final String text;
  final TextStyle style;
  final ValueChanged<String> onHashtagTap;
  final ValueChanged<String>? onMentionTap;
  final TextScaler? textScaler;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? hashtagStyle;
  final TextStyle? mentionStyle;
  final List<InlineSpan>? prefixSpans;

  @override
  State<HashtagText> createState() => _HashtagTextState();
}

class _HashtagTextState extends State<HashtagText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan>? _cachedSpans;
  String? _lastText;
  TextStyle? _lastStyle;
  TextStyle? _lastHashtagStyle;
  TextStyle? _lastMentionStyle;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _buildSpans() {
    if (_cachedSpans != null &&
        _lastText == widget.text &&
        _lastStyle == widget.style &&
        _lastHashtagStyle == widget.hashtagStyle &&
        _lastMentionStyle == widget.mentionStyle) {
      return _cachedSpans!;
    }
    
    _disposeRecognizers();
    _lastText = widget.text;
    _lastStyle = widget.style;
    _lastHashtagStyle = widget.hashtagStyle;
    _lastMentionStyle = widget.mentionStyle;

    _cachedSpans = buildHashtagTextSpans(
      text: widget.text,
      style: widget.style,
      onHashtagTap: widget.onHashtagTap,
      onMentionTap: widget.onMentionTap,
      hashtagStyle: widget.hashtagStyle,
      mentionStyle: widget.mentionStyle,
      recognizers: _recognizers,
    );
    return _cachedSpans!;
  }

  @override
  void didUpdateWidget(HashtagText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.hashtagStyle != widget.hashtagStyle ||
        oldWidget.mentionStyle != widget.mentionStyle) {
      _cachedSpans = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
      text: TextSpan(
        children: [
          ...?widget.prefixSpans,
          ..._buildSpans(),
        ],
        style: widget.style,
      ),
    );
  }
}

final RegExp _hashtagPattern = RegExp(
  r'#([\p{L}\p{N}_]+)',
  unicode: true,
);
final RegExp _mentionPattern = RegExp(
  r'@([\p{L}\p{N}_]+)',
  unicode: true,
);
final RegExp _linkifiedPattern = RegExp(
  r'(#([\p{L}\p{N}_]+)|@([\p{L}\p{N}_]+))',
  unicode: true,
);

List<InlineSpan> buildHashtagTextSpans({
  required String text,
  required TextStyle style,
  required ValueChanged<String> onHashtagTap,
  ValueChanged<String>? onMentionTap,
  TextStyle? hashtagStyle,
  TextStyle? mentionStyle,
  List<TapGestureRecognizer>? recognizers,
}) {
  text = ensureEmojiPresentation(text);
  final spans = <InlineSpan>[];
  var currentIndex = 0;

  for (final match in _linkifiedPattern.allMatches(text)) {
    if (match.start > currentIndex) {
      spans.addAll(
        splitTextByEmoji(text.substring(currentIndex, match.start), style),
      );
    }

    final token = match.group(0) ?? '';
    final hashtagMatch = _hashtagPattern.matchAsPrefix(token);
    final mentionMatch = _mentionPattern.matchAsPrefix(token);

    if (hashtagMatch != null) {
      final tag = hashtagMatch.group(1)?.trim() ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (tag.isNotEmpty) {
            onHashtagTap(tag);
          }
        };
      recognizers?.add(recognizer);

      spans.addAll(
        splitTextByEmoji(
          token,
          hashtagStyle ??
              style.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
        ).map((s) => s is TextSpan ? TextSpan(text: s.text, style: s.style, recognizer: recognizer) : s),
      );
    } else if (mentionMatch != null && onMentionTap != null) {
      final username = mentionMatch.group(1)?.trim() ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (username.isNotEmpty) {
            onMentionTap(username);
          }
        };
      recognizers?.add(recognizer);

      spans.addAll(
        splitTextByEmoji(
          token,
          mentionStyle ??
              style.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
        ).map((s) => s is TextSpan ? TextSpan(text: s.text, style: s.style, recognizer: recognizer) : s),
      );
    } else {
      spans.addAll(
        splitTextByEmoji(token, style),
      );
    }
    currentIndex = match.end;
  }

  if (currentIndex < text.length) {
    spans.addAll(
      splitTextByEmoji(text.substring(currentIndex), style),
    );
  }

  if (spans.isEmpty) {
    spans.addAll(splitTextByEmoji(text, style));
  }

  return spans;
}
