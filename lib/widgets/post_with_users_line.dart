import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import 'special_name_text.dart';

class PostWithUsersLine extends StatefulWidget {
  const PostWithUsersLine({
    required this.users,
    required this.style,
    this.linkStyle,
    this.onUserTap,
    this.prefix = 'is with ',
    this.prefixHighlight,
    this.prefixHighlightStyle,
    super.key,
  });

  final List<User> users;
  final TextStyle style;
  final TextStyle? linkStyle;
  final ValueChanged<String>? onUserTap;
  final String prefix;
  final String? prefixHighlight;
  final TextStyle? prefixHighlightStyle;

  @override
  State<PostWithUsersLine> createState() => _PostWithUsersLineState();
}

class _PostWithUsersLineState extends State<PostWithUsersLine> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

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

  InlineSpan _userSpan(User user) {
    final username = (user.username ?? '').trim();
    final label = user.displayName.trim();
    final onUserTap = widget.onUserTap;
    final cleanUsername = username.toLowerCase();
    
    final style = widget.linkStyle ?? widget.style;
    final isSpecial = cleanUsername == 'gemini' || cleanUsername == 'human_equality';
    
    if (isSpecial) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: onUserTap != null ? () => onUserTap(username) : null,
          child: SpecialNameText(
            username: username,
            displayName: label,
            style: style,
          ),
        ),
      );
    }

    if (username.isEmpty || onUserTap == null) {
      return TextSpan(text: label, style: style);
    }

    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        onUserTap(username);
      };
    _recognizers.add(recognizer);

    return TextSpan(
      text: label,
      style: style,
      recognizer: recognizer,
    );
  }

  List<InlineSpan> _buildPrefixSpans() {
    final prefix = widget.prefix;
    final highlight = widget.prefixHighlight;
    final highlightStyle = widget.prefixHighlightStyle;

    if (prefix.isEmpty ||
        highlight == null ||
        highlight.isEmpty ||
        highlightStyle == null ||
        !prefix.contains(highlight)) {
      return <InlineSpan>[
        TextSpan(text: prefix, style: widget.style),
      ];
    }

    final start = prefix.indexOf(highlight);
    final end = start + highlight.length;
    final before = prefix.substring(0, start);
    final after = prefix.substring(end);

    return <InlineSpan>[
      if (before.isNotEmpty) TextSpan(text: before, style: widget.style),
      TextSpan(text: highlight, style: highlightStyle),
      if (after.isNotEmpty) TextSpan(text: after, style: widget.style),
    ];
  }

  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();
    final users = widget.users
        .where((user) => user.displayName.trim().isNotEmpty)
        .toList(growable: false);
    if (users.isEmpty) {
      return const <InlineSpan>[];
    }

    final spans = <InlineSpan>[
      ..._buildPrefixSpans(),
    ];

    if (users.length == 1) {
      spans.add(_userSpan(users.first));
      return spans;
    }

    if (users.length == 2) {
      spans
        ..add(_userSpan(users.first))
        ..add(TextSpan(text: ' and ', style: widget.style))
        ..add(_userSpan(users[1]));
      return spans;
    }

    spans
      ..add(_userSpan(users.first))
      ..add(
        TextSpan(
          text: ' and ${users.length - 1} others',
          style: widget.style,
        ),
      );
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty) {
      return const SizedBox.shrink();
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: widget.style,
        children: _buildSpans(),
      ),
    );
  }
}
