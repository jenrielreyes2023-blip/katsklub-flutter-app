import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';

Future<List<User>?> showPostWithUsersPicker({
  required BuildContext context,
  required List<User> initialSelected,
  String? currentUserId,
}) {
  return showModalBottomSheet<List<User>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostWithUsersPickerSheet(
      initialSelected: initialSelected,
      currentUserId: currentUserId,
    ),
  );
}

class _PostWithUsersPickerSheet extends StatefulWidget {
  const _PostWithUsersPickerSheet({
    required this.initialSelected,
    this.currentUserId,
  });

  final List<User> initialSelected;
  final String? currentUserId;

  @override
  State<_PostWithUsersPickerSheet> createState() =>
      _PostWithUsersPickerSheetState();
}

class _PostWithUsersPickerSheetState extends State<_PostWithUsersPickerSheet> {
  final FeedService _feedService = FeedService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  late List<User> _selected;
  List<User> _results = const <User>[];
  bool _isLoading = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = _dedupe(widget.initialSelected);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<User> _dedupe(List<User> users) {
    final seen = <String>{};
    final currentUserId = (widget.currentUserId ?? '').trim();
    final output = <User>[];
    for (final user in users) {
      final id = (user.id ?? '').trim();
      if (id.isEmpty || id == currentUserId || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      output.add(user);
    }
    return output;
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _activeQuery) {
      return;
    }
    _activeQuery = query;
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = const <User>[];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = true;
      });
      try {
        final users = await _feedService.searchUsers(query);
        if (!mounted || _activeQuery != query) {
          return;
        }
        final currentUserId = (widget.currentUserId ?? '').trim();
        setState(() {
          _results = users.where((user) {
            final id = (user.id ?? '').trim();
            return id.isNotEmpty && id != currentUserId;
          }).toList(growable: false);
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted || _activeQuery != query) {
          return;
        }
        setState(() {
          _results = const <User>[];
          _isLoading = false;
        });
      }
    });
  }

  bool _isSelected(User user) {
    final id = (user.id ?? '').trim();
    return id.isNotEmpty && _selected.any((item) => item.id == id);
  }

  void _toggleUser(User user) {
    final id = (user.id ?? '').trim();
    if (id.isEmpty) {
      return;
    }

    setState(() {
      if (_isSelected(user)) {
        _selected = _selected.where((item) => item.id != id).toList();
      } else {
        _selected = [..._selected, user];
      }
    });
  }

  void _removeUser(User user) {
    final id = (user.id ?? '').trim();
    if (id.isEmpty) {
      return;
    }
    setState(() {
      _selected = _selected.where((item) => item.id != id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final titleColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final inputFillColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6);
    final secondaryTextColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6);
    final dragHandleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final chipBgColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6);
    final avatarBgColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dragHandleColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'With people',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF7A45),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  hintText: 'Search people',
                  hintStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon: Icon(Icons.search_rounded, color: secondaryTextColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selected
                      .map(
                        (user) => InputChip(
                          label: Text(
                            user.displayName,
                            style: TextStyle(color: titleColor),
                          ),
                          onDeleted: () => _removeUser(user),
                          deleteIcon: Icon(Icons.close_rounded, size: 18, color: secondaryTextColor),
                          backgroundColor: chipBgColor,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                ),
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF7A45),
                            ),
                          ),
                        ),
                      )
                    : _activeQuery.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Search to add people to this post.',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        : _results.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No people found.',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _results.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: dividerColor,
                                ),
                                itemBuilder: (context, index) {
                                  final user = _results[index];
                                  final selected = _isSelected(user);
                                  final avatarUrl =
                                      (user.avatarUrl ?? '').trim();
                                  return ListTile(
                                    onTap: () => _toggleUser(user),
                                    contentPadding: EdgeInsets.zero,
                                    leading: avatarUrl.isEmpty
                                        ? CircleAvatar(
                                            radius: 20,
                                            backgroundColor: avatarBgColor,
                                            child: Text(
                                              user.initials,
                                              style: TextStyle(
                                                color: titleColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          )
                                        : ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  ApiConfig.assetUrl(avatarUrl),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              fadeInDuration: Duration.zero,
                                              fadeOutDuration: Duration.zero,
                                              placeholderFadeInDuration:
                                                  Duration.zero,
                                              placeholder: (_, __) =>
                                                  CircleAvatar(
                                                radius: 20,
                                                backgroundColor: avatarBgColor,
                                                child: Text(
                                                  user.initials,
                                                  style: TextStyle(
                                                    color: titleColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  CircleAvatar(
                                                radius: 20,
                                                backgroundColor: avatarBgColor,
                                                child: Text(
                                                  user.initials,
                                                  style: TextStyle(
                                                    color: titleColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    title: Text(
                                      user.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: (user.handle ?? '').isEmpty
                                        ? null
                                        : Text(
                                            user.handle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: secondaryTextColor),
                                          ),
                                    trailing: Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.add_circle_outline_rounded,
                                      color: selected
                                          ? const Color(0xFFFF7A45)
                                          : secondaryTextColor,
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
