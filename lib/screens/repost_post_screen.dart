import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../utils/emoji_presentation.dart';
import '../widgets/mention_autocomplete.dart';
import '../widgets/repost_source_preview.dart';
import '../widgets/special_name_text.dart';

class RepostPostScreen extends StatefulWidget {
  const RepostPostScreen({
    required this.originalPost,
    this.currentUser,
    super.key,
  });

  final Post originalPost;
  final User? currentUser;

  @override
  State<RepostPostScreen> createState() => _RepostPostScreenState();
}

class _RepostPostScreenState extends State<RepostPostScreen> {
  final FeedService _feedService = FeedService();
  final AuthService _authService = AuthService();
  late final TextEditingController _textController;
  final FocusNode _textFocusNode = FocusNode();

  static const _visibilityLabels = <String, String>{
    'public': 'Public',
    'friends': 'Friends',
    'only_me': 'Only me',
  };

  User? _currentUser;
  String _visibility = 'public';
  bool _isSaving = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_clearInlineError);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _textController.removeListener(_clearInlineError);
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final resolvedUser = widget.currentUser ?? await _authService.getSavedUser();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = resolvedUser;
    });
  }

  void _clearInlineError() {
    if (_inlineError == null || !mounted) {
      return;
    }

    setState(() {
      _inlineError = null;
    });
  }

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

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    try {
      final repostedPost = await _feedService.repostPost(
        originalPostId: widget.originalPost.id,
        text: _textController.text.trim(),
        visibility: _visibility,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(repostedPost);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Bad state: ', '');
      setState(() {
        _inlineError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _currentUser;
    final displayName = currentUser?.displayName ?? 'KatsKlub user';
    final handle = currentUser?.handle;
    final avatarUrl = currentUser?.avatarUrl?.trim() ?? '';
    final initials = currentUser?.initials ?? 'K';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    const activeOrange = Color(0xFFFF7A45);

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
          'Repost',
          style: TextStyle(
            color: titleColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: activeOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? const Color(0xFF2D2E30) : const Color(0xFFD1D5DB),
                    disabledForegroundColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Repost',
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cardBgColor,
                    backgroundImage: avatarUrl.isEmpty
                        ? null
                        : NetworkImage(ApiConfig.assetUrl(avatarUrl)),
                    child: avatarUrl.isEmpty
                        ? Text(
                            initials,
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
                          username: currentUser?.username ?? '',
                          displayName: displayName,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (handle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            handle,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _textController,
                focusNode: _textFocusNode,
                minLines: 5,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [EmojiPresentationFormatter()],
                decoration: InputDecoration(
                  hintText: 'Add your thoughts... Leave it blank for a simple repost.',
                  hintStyle: TextStyle(
                    color: subtitleColor,
                    fontSize: 16,
                    height: 1.45,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  height: 1.45,
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
              const SizedBox(height: 18),
              RepostSourcePreview(
                post: widget.originalPost,
                label: 'Reposting from ${widget.originalPost.authorFullName}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
