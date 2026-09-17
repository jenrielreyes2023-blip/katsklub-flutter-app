import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katsklub_flutter/widgets/hashtag_text.dart';

const _linkBlue = Color(0xFF2563EB);

/// Black base style => _linkified treats theme as light => blue links.
const _baseStyle = TextStyle(color: Colors.black);

String _spanText(InlineSpan span) =>
    span is TextSpan ? (span.text ?? '') : '';

TextSpan? _findMentionSpan(List<InlineSpan> spans) {
  for (final span in spans) {
    if (span is TextSpan &&
        (span.text ?? '').startsWith('@') &&
        span.style?.color == _linkBlue) {
      return span;
    }
  }
  return null;
}

void main() {
  group('HashtagText mentions', () {
    test('dotted username highlights as ONE blue span with full name',
        () {
      String? tapped;
      final recognizers = <TapGestureRecognizer>[];
      final spans = buildHashtagTextSpans(
        text: 'hi @itsuki.ren!',
        style: _baseStyle,
        onHashtagTap: (_) {},
        onMentionTap: (u) => tapped = u,
        recognizers: recognizers,
      );

      final mention = _findMentionSpan(spans);
      expect(mention, isNotNull);
      expect(_spanText(mention!), '@itsuki.ren');
      expect(mention.style?.fontWeight, FontWeight.w700);

      // Firing the attached recognizer must yield the FULL username,
      // otherwise the app opens the wrong profile.
      (mention.recognizer as TapGestureRecognizer?)?.onTap?.call();
      expect(tapped, 'itsuki.ren');
    });

    test('trailing dot is not part of the mention', () {
      final spans = buildHashtagTextSpans(
        text: 'see @ronaldo.',
        style: _baseStyle,
        onHashtagTap: (_) {},
        onMentionTap: (_) {},
      );

      final mention = _findMentionSpan(spans);
      expect(mention, isNotNull);
      expect(_spanText(mention!), '@ronaldo');
      expect(spans.map(_spanText).join(), 'see @ronaldo.');
    });

    test('mention stays plain when onMentionTap is null', () {
      final spans = buildHashtagTextSpans(
        text: 'hi @ronaldo',
        style: _baseStyle,
        onHashtagTap: (_) {},
      );

      expect(_findMentionSpan(spans), isNull);
      expect(spans.map(_spanText).join(), 'hi @ronaldo');
    });

    test('hashtag highlighting is unaffected', () {
      final spans = buildHashtagTextSpans(
        text: '#manila vibes',
        style: _baseStyle,
        onHashtagTap: (_) {},
        onMentionTap: (_) {},
      );

      final tag = spans.whereType<TextSpan>().firstWhere(
            (s) => (s.text ?? '').startsWith('#'),
          );
      expect(tag.text, '#manila');
      expect(tag.style?.color, _linkBlue);
    });
  });
}
