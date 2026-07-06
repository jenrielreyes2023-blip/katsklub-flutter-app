import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';

class MentionAutocomplete extends StatefulWidget {
  const MentionAutocomplete({
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.maxResults = 5,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final int maxResults;

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  static final RegExp _mentionQueryPattern = RegExp(
    r'(^|[\s([{])@([\p{L}\p{N}_]*)$',
    unicode: true,
  );

  final FeedService _feedService = FeedService();
  Timer? _debounce;
  List<User> _results = const <User>[];
  bool _isLoading = false;
  String _activeQuery = '';
  _MentionMatch? _activeMatch;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
    widget.focusNode.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(MentionAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleChanged);
      widget.focusNode.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_handleChanged);
    widget.focusNode.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (!widget.enabled || !widget.focusNode.hasFocus) {
      _clearResults();
      return;
    }

    final match = _findMentionMatch(
      widget.controller.text,
      widget.controller.selection.baseOffset,
    );
    if (match == null || match.query.isEmpty) {
      _clearResults();
      return;
    }

    _activeMatch = match;
    if (_activeQuery == match.query) {
      return;
    }

    _activeQuery = match.query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted || !widget.enabled) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final users = await _feedService.searchUsers(match.query);
        if (!mounted) {
          return;
        }
        if (_activeQuery != match.query) {
          return;
        }

        setState(() {
          _results = users
              .where(
                (user) =>
                    (user.username ?? '').trim().toLowerCase() != match.query,
              )
              .take(widget.maxResults)
              .toList();
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted || _activeQuery != match.query) {
          return;
        }
        setState(() {
          _results = const <User>[];
          _isLoading = false;
        });
      }
    });
  }

  _MentionMatch? _findMentionMatch(String text, int selectionStart) {
    if (selectionStart < 0 || selectionStart > text.length) {
      return null;
    }

    final textBeforeCursor = text.substring(0, selectionStart);
    final match = _mentionQueryPattern.firstMatch(textBeforeCursor);
    if (match == null) {
      return null;
    }

    final prefixLength = match.group(1)?.length ?? 0;
    final start = match.start + prefixLength;
    final query = (match.group(2) ?? '').trim().toLowerCase();
    return _MentionMatch(start: start, end: selectionStart, query: query);
  }

  void _clearResults() {
    _debounce?.cancel();
    if (_results.isEmpty && !_isLoading && _activeQuery.isEmpty) {
      _activeMatch = null;
      return;
    }

    setState(() {
      _results = const <User>[];
      _isLoading = false;
      _activeQuery = '';
      _activeMatch = null;
    });
  }

  void _selectUser(User user) {
    final match = _activeMatch;
    final username = (user.username ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (match == null || username.isEmpty) {
      return;
    }

    final currentText = widget.controller.text;
    final replacement = '@$username ';
    final nextText = currentText.replaceRange(match.start, match.end, replacement);
    final cursorOffset = match.start + replacement.length;

    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
    _clearResults();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || (!_isLoading && _results.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return InkWell(
                      onTap: () => _selectUser(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: (user.avatarUrl ?? '').trim().isEmpty
                                  ? CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFE5E7EB),
                                      child: Text(
                                        user.initials,
                                        style: const TextStyle(
                                          color: Color(0xFF111827),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: ApiConfig.assetUrl(user.avatarUrl!),
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholderFadeInDuration: Duration.zero,
                                        placeholder: (_, __) => CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFFE5E7EB),
                                          child: Text(
                                            user.initials,
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFFE5E7EB),
                                          child: Text(
                                            user.initials,
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.handle ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _MentionMatch {
  const _MentionMatch({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}
