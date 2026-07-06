import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

const Set<int> _kEmojiNeedsVs16 = <int>{
  0x203C, 0x2049, 0x2122, 0x2139, 0x2194, 0x2195, 0x2196, 0x2197, 0x2198,
  0x2199, 0x21A9, 0x21AA, 0x231A, 0x231B, 0x2328, 0x23CF, 0x23E9, 0x23EA,
  0x23ED, 0x23EE, 0x23EF, 0x23F1, 0x23F2, 0x23F3, 0x23F8, 0x23F9, 0x23FA,
  0x24C2, 0x25AA, 0x25AB, 0x25B6, 0x25C0, 0x25FB, 0x25FC, 0x2600, 0x2601,
  0x2602, 0x2603, 0x2604, 0x260E, 0x2611, 0x2618, 0x261D, 0x2620, 0x2622,
  0x2623, 0x2626, 0x262A, 0x262E, 0x262F, 0x2638, 0x2639, 0x263A, 0x2640,
  0x2642, 0x265F, 0x2660, 0x2663, 0x2665, 0x2666, 0x2668, 0x267B, 0x267E,
  0x2692, 0x2694, 0x2695, 0x2696, 0x2697, 0x2699, 0x269B, 0x269C, 0x26A0,
  0x26A7, 0x26B0, 0x26B1, 0x26C8, 0x26CF, 0x26D1, 0x26D3, 0x26E9, 0x26F0,
  0x26F1, 0x26F4, 0x26F7, 0x26F8, 0x26F9, 0x2702, 0x2708, 0x2709, 0x270C,
  0x270D, 0x270F, 0x2712, 0x2714, 0x2716, 0x271D, 0x2721, 0x2733, 0x2734,
  0x2744, 0x2747, 0x2763, 0x2764, 0x27A1, 0x2934, 0x2935, 0x2B05, 0x2B06,
  0x2B07, 0x3030, 0x303D, 0x3297, 0x3299,
};

String ensureEmojiPresentation(String text) {
  if (text.isEmpty) return text;
  
  // Convert black card suit heart (\u2665) to standard red heart (\u2764)
  final replacedText = text.replaceAll('\u2665', '\u2764');
  
  const vs16 = 0xFE0F;
  final codes = replacedText.runes.toList();
  final out = StringBuffer();
  for (int i = 0; i < codes.length; i++) {
    final cp = codes[i];
    out.writeCharCode(cp);
    if (_kEmojiNeedsVs16.contains(cp)) {
      final next = (i + 1 < codes.length) ? codes[i + 1] : -1;
      if (next != vs16) {
        out.writeCharCode(vs16);
      }
    }
  }
  return out.toString();
}

class EmojiPresentationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final original = newValue.text;
    final fixed = ensureEmojiPresentation(original);
    if (fixed == original) return newValue;

    int countInsertsBefore(int upto) {
      int inserted = 0;
      final end = upto < original.length ? upto : original.length;
      for (int i = 0; i < end; i++) {
        final cu = original.codeUnitAt(i);
        if (_kEmojiNeedsVs16.contains(cu)) {
          final nextIsVs16 = (i + 1 < original.length) &&
              original.codeUnitAt(i + 1) == 0xFE0F;
          if (!nextIsVs16) inserted++;
        }
      }
      return inserted;
    }

    final selStart = newValue.selection.start;
    final selEnd = newValue.selection.end;
    final adjStart =
        selStart < 0 ? selStart : selStart + countInsertsBefore(selStart);
    final adjEnd = selEnd < 0 ? selEnd : selEnd + countInsertsBefore(selEnd);

    return TextEditingValue(
      text: fixed,
      selection: TextSelection(baseOffset: adjStart, extentOffset: adjEnd),
      composing: TextRange.empty,
    );
  }
}

List<InlineSpan> splitTextByEmoji(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final regex = RegExp(r'(\p{Emoji_Presentation}|\u2764|\u2665)\ufe0f?', unicode: true);
  var lastIndex = 0;
  
  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ),
      );
    }
    
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style.copyWith(
          fontFamily: '',
          fontFamilyFallback: const [
            'Apple Color Emoji',
            'Noto Color Emoji',
            'Segoe UI Emoji',
            'EmojiOne Color',
          ],
        ),
      ),
    );
    lastIndex = match.end;
  }
  
  if (lastIndex < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ),
    );
  }
  
  return spans;
}
