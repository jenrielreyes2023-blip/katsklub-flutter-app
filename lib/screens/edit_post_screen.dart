import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../utils/emoji_presentation.dart';
import '../widgets/mention_autocomplete.dart';
import '../widgets/post_with_users_picker.dart';
import '../widgets/special_name_text.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final FeedService _feedService = FeedService();
  late final TextEditingController _textController;
  final FocusNode _textFocusNode = FocusNode();

  late String _visibility;
  List<User> _withUsers = <User>[];
  bool _removeMedia = false;
  bool _isSaving = false;
  String? _inlineError;

  String _location = '';
  String _feeling = '';
  bool _isDetectingLocation = false;

  static const _visibilityLabels = <String, String>{
    'public': 'Public',
    'friends': 'Friends',
    'only_me': 'Only me',
  };

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.post.text);
    _textController.addListener(_onTextChanged);
    _visibility = widget.post.visibility;
    _withUsers = List<User>.from(widget.post.withUsers);
    _location = widget.post.location;
    _feeling = widget.post.feeling;
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        if (_inlineError != null) {
          _inlineError = null;
        }
      });
    }
  }

  bool get _hasExistingMedia =>
      widget.post.imageUrls.isNotEmpty || widget.post.hasVideo;

  bool get _willHaveMedia => _hasExistingMedia && !_removeMedia;

  bool get _hasChanges =>
      _textController.text != widget.post.text ||
      _visibility != widget.post.visibility ||
      _removeMedia ||
      !_sameWithUsers(_withUsers, widget.post.withUsers) ||
      _location != widget.post.location ||
      _feeling != widget.post.feeling;

  String get _privacyLabel =>
      _visibilityLabels[_visibility] ?? _visibilityLabels['public']!;

  IconData get _privacyIcon {
    switch (_visibility) {
      case 'friends':
        return Icons.group_outlined;
      case 'only_me':
        return Icons.lock_outline;
      default:
        return Icons.public;
    }
  }

  void _cycleVisibility() {
    const options = ['public', 'friends', 'only_me'];
    final currentIndex = options.indexOf(_visibility);
    final nextIndex = (currentIndex + 1) % options.length;
    setState(() {
      _visibility = options[nextIndex];
      _inlineError = null;
    });
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty && !_willHaveMedia) {
      setState(() {
        _inlineError = 'Post must have text or media.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    try {
      final updatedPost = await _feedService.updatePost(
        postId: widget.post.id,
        text: text,
        visibility: _visibility,
        removeMedia: _removeMedia,
        withUserIds: _withUsers
            .map((user) => (user.id ?? '').trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false),
        location: _location,
        feeling: _feeling,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updatedPost);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.toString().replaceFirst('Bad state: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_inlineError!)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _sameWithUsers(List<User> left, List<User> right) {
    final leftIds = left
        .map((user) => (user.id ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    final rightIds = right
        .map((user) => (user.id ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    if (leftIds.length != rightIds.length) {
      return false;
    }
    for (var index = 0; index < leftIds.length; index++) {
      if (leftIds[index] != rightIds[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _openWithUsersPicker() async {
    final selected = await showPostWithUsersPicker(
      context: context,
      initialSelected: _withUsers,
      currentUserId: null,
    );
    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _withUsers = selected;
      _inlineError = null;
    });
  }

  void _removeWithUser(User user) {
    final id = (user.id ?? '').trim();
    if (id.isEmpty) {
      return;
    }
    setState(() {
      _withUsers = _withUsers.where((item) => item.id != id).toList();
      _inlineError = null;
    });
  }

  static const _feelings = [
    ('Happy', '😊'),
    ('Blessed', '😇'),
    ('Excited', '🤩'),
    ('Sad', '😢'),
    ('Angry', '😡'),
    ('Tired', '😴'),
    ('Loved', '🥰'),
    ('Cool', '😎'),
    ('Sick', '🤒'),
    ('Confused', '😕'),
  ];

  Future<void> _selectFeeling() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1E21) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text(
                'How are you feeling?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_feeling.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.clear, color: Colors.red),
                        title: const Text('Clear feeling', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        onTap: () => Navigator.pop(context, ''),
                      ),
                    ..._feelings.map((f) {
                      final name = f.$1;
                      final emoji = f.$2;
                      return ListTile(
                        leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        onTap: () => Navigator.pop(context, '$name $emoji'),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _feeling = selected;
        _inlineError = null;
      });
    }
  }

  Future<void> _handleLocationTap() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_location.isNotEmpty) {
      final newLoc = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: _location);
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1C1E21) : Colors.white,
            title: Text('Edit Location', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            content: TextField(
              controller: controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Enter city, country',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : Colors.grey),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (newLoc != null) {
        setState(() {
          _location = newLoc;
          _inlineError = null;
        });
      }
      return;
    }

    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['city'] ?? '';
        final country = data['country'] ?? '';
        if (city.isNotEmpty && country.isNotEmpty) {
          setState(() {
            _location = '$city, $country';
            _inlineError = null;
          });
        } else if (city.isNotEmpty) {
          setState(() {
            _location = city;
            _inlineError = null;
          });
        } else {
          _promptManualLocation();
        }
      } else {
        _promptManualLocation();
      }
    } catch (_) {
      _promptManualLocation();
    } finally {
      setState(() {
        _isDetectingLocation = false;
      });
    }
  }

  void _promptManualLocation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1E21) : Colors.white,
          title: Text('Enter Location', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'e.g. Manila, Philippines',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((val) {
      if (val != null && val.isNotEmpty) {
        setState(() {
          _location = val;
          _inlineError = null;
        });
      }
    });
  }

  void _showPlaceholder(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon.')),
    );
  }

  void _showAddMediaPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add media coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    const activeOrange = Color(0xFFFF7A45);

    final saveBtnBgColor = _hasChanges
        ? activeOrange
        : (isDark ? const Color(0xFF2D2E30) : const Color(0xFFD1D5DB));
    final saveBtnFgColor = _hasChanges
        ? Colors.white
        : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close_rounded, color: titleColor),
        ),
        centerTitle: true,
        title: Text(
          'Edit post',
          style: TextStyle(
            color: titleColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _isSaving ? null : () => _showPlaceholder('More options'),
            icon: Icon(Icons.more_horiz_rounded, color: titleColor),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(color: dividerColor),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _isSaving ? null : _cycleVisibility,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_privacyIcon, size: 16, color: titleColor),
                      const SizedBox(width: 8),
                      Text(
                        _privacyLabel,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: (!_hasChanges || _isSaving) ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: saveBtnBgColor,
                    foregroundColor: saveBtnFgColor,
                    disabledBackgroundColor: saveBtnBgColor,
                    disabledForegroundColor: saveBtnFgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: saveBtnFgColor,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cardBgColor,
                    backgroundImage: post.authorAvatarUrl.trim().isEmpty
                        ? null
                        : NetworkImage(
                            ApiConfig.assetUrl(post.authorAvatarUrl)),
                    child: post.authorAvatarUrl.trim().isEmpty
                        ? Text(
                            post.authorInitials,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SpecialNameText(
                          username: post.authorUsername,
                          displayName: post.authorFullName,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${post.authorUsername}',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _EditChip(
                    icon: Icons.person_add_alt_1_outlined,
                    label: _withUsers.isEmpty
                        ? 'With'
                        : 'With (${_withUsers.length})',
                    onTap: _openWithUsersPicker,
                    active: _withUsers.isNotEmpty,
                  ),
                  _EditChip(
                    icon: Icons.place_outlined,
                    label: _location.isEmpty ? 'Location' : _location,
                    onTap: _handleLocationTap,
                    active: _location.isNotEmpty,
                  ),
                  _EditChip(
                    icon: Icons.mood_outlined,
                    label: _feeling.isEmpty ? 'Feeling/activity' : _feeling,
                    onTap: _selectFeeling,
                    active: _feeling.isNotEmpty,
                  ),
                ],
              ),
              if (_withUsers.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _withUsers
                      .map(
                        (user) => InputChip(
                          label: Text(user.displayName, style: TextStyle(color: titleColor)),
                          onDeleted:
                              _isSaving ? null : () => _removeWithUser(user),
                          deleteIcon: Icon(Icons.close_rounded, size: 18, color: titleColor),
                          backgroundColor: cardBgColor,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: _textController,
                focusNode: _textFocusNode,
                maxLines: null,
                minLines: 6,
                enabled: !_isSaving,
                inputFormatters: [EmojiPresentationFormatter()],
                decoration: InputDecoration(
                  hintText: 'What’s on your mind?',
                  hintStyle: TextStyle(color: subtitleColor),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              MentionAutocomplete(
                controller: _textController,
                focusNode: _textFocusNode,
                enabled: !_isSaving,
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _inlineError!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_hasExistingMedia)
                _EditableMediaPreview(
                  post: post,
                  removed: _removeMedia,
                  onRemove: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _removeMedia = !_removeMedia;
                            _inlineError = null;
                          });
                        },
                  onAddMedia: _isSaving ? null : _showAddMediaPlaceholder,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditChip extends StatelessWidget {
  const _EditChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color bgColor;
    final Color contentColor;
    
    if (active) {
      bgColor = isDark ? const Color(0x33FF7A45) : const Color(0xFFFFF4EC);
      contentColor = const Color(0xFFFF7A45);
    } else {
      bgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
      contentColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: active ? Border.all(color: const Color(0xFFFF7A45), width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: contentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: contentColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableMediaPreview extends StatelessWidget {
  const _EditableMediaPreview({
    required this.post,
    required this.removed,
    this.onRemove,
    this.onAddMedia,
  });

  final Post post;
  final bool removed;
  final VoidCallback? onRemove;
  final VoidCallback? onAddMedia;

  @override
  Widget build(BuildContext context) {
    final hasVideo = post.hasVideo;
    final previewImage = hasVideo
        ? post.primaryVideoPosterUrl
        : (post.imageUrls.isNotEmpty ? post.imageUrls.first : '');
    final aspectRatio =
        (post.mediaAspectRatio ?? post.aspectRatio ?? 1.0).clamp(0.75, 1.91);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
    final iconColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF6B7280);

    return Opacity(
      opacity: removed ? 0.5 : 1,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: cardBgColor,
                child: previewImage.trim().isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            ApiConfig.assetUrl(previewImage),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(hasVideo, iconColor),
                          ),
                          if (hasVideo)
                            Center(
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.48),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                        ],
                      )
                    : _fallback(hasVideo, iconColor),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: FilledButton.icon(
              onPressed: onAddMedia,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1C1E21) : Colors.white,
                foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text(
                'Add media',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton.filled(
              onPressed: onRemove,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.58),
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                removed ? Icons.undo_rounded : Icons.delete_outline_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(bool hasVideo, Color iconColor) {
    return Center(
      child: Icon(
        hasVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: iconColor,
        size: 36,
      ),
    );
  }
}
