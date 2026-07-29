import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/story.dart';
import '../screens/messages_screen.dart';
import '../services/feed_service.dart';
import '../widgets/sensitive_content_wrapper.dart';
import '../widgets/special_name_text.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    required this.storyGroups,
    required this.initialGroupIndex,
    required this.initialStoryIndex,
    super.key,
  });

  final List<List<Story>> storyGroups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  Timer? _advanceTimer;
  bool _isPaused = false;
  double _progress = 0;
  Timer? _progressTimer;
  VideoPlayerController? _musicController;
  int _musicRequestToken = 0;
  static const _defaultStoryDuration = Duration(seconds: 5);
  static const _musicStoryDuration = Duration(seconds: 30);
  static const _progressInterval = Duration(milliseconds: 50);

  List<Story> get _currentGroup => widget.storyGroups[_currentGroupIndex];
  Story get _currentStory => _currentGroup[_currentStoryIndex];
  Duration get _currentStoryDuration {
    final videoUrl = _currentStory.videoUrl?.trim() ?? '';
    if (videoUrl.isNotEmpty) {
      return const Duration(seconds: 15);
    }
    final previewUrl = _currentStory.musicPreviewUrl?.trim() ?? '';
    return previewUrl.isEmpty ? _defaultStoryDuration : _musicStoryDuration;
  }

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndex = widget.initialStoryIndex;
    _startAutoAdvance();
    _syncMusicPreview();
    _recordCurrentView();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _progressTimer?.cancel();
    _disposeMusicController();
    super.dispose();
  }

  void _recordCurrentView() {
    final story = _currentStory;
    if (!story.ownedByMe) {
      FeedService().recordStoryView(story.id);
    }
  }

  void _startAutoAdvance() {
    _advanceTimer?.cancel();
    _progressTimer?.cancel();
    _progress = 0;

    _progressTimer = Timer.periodic(_progressInterval, (_) {
      if (_isPaused) return;
      setState(() {
        _progress += _progressInterval.inMilliseconds / _currentStoryDuration.inMilliseconds;
        if (_progress >= 1) {
          _progress = 1;
        }
      });
    });

    _advanceTimer = Timer(_currentStoryDuration, () {
      _nextStory();
    });
  }

  Future<void> _disposeMusicController() async {
    final controller = _musicController;
    _musicController = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _syncMusicPreview() async {
    final previewUrl = _currentStory.musicPreviewUrl?.trim() ?? '';
    final requestToken = ++_musicRequestToken;
    await _disposeMusicController();

    if (previewUrl.isEmpty) {
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(previewUrl));
      await controller.initialize();
      await controller.setVolume(1.0);
      await controller.setLooping(false);
      if (!mounted || requestToken != _musicRequestToken) {
        await controller.dispose();
        return;
      }
      _musicController = controller;
      if (!_isPaused) {
        await controller.play();
      }
    } catch (_) {
      await _disposeMusicController();
    }
  }

  void _pause() {
    setState(() => _isPaused = true);
    _musicController?.pause();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _musicController?.play();
  }

  void _nextStory() {
    if (_currentStoryIndex < _currentGroup.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      _recordCurrentView();
      return;
    }

    if (_currentGroupIndex < widget.storyGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      _recordCurrentView();
      return;
    }

    _close();
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      _recordCurrentView();
      return;
    }

    if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = _currentGroup.length - 1;
      });
      _startAutoAdvance();
      _syncMusicPreview();
      _recordCurrentView();
    }
  }

  void _close() {
    _disposeMusicController();
    Navigator.of(context).pop();
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < width * 0.3) {
      _previousStory();
    } else if (tapPosition > width * 0.7) {
      _nextStory();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _pause();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _resume();
  }

  Future<void> _toggleReaction() async {
    final story = _currentStory;
    final currentlyReacted = story.hasReacted;
    final newCount = currentlyReacted ? (story.reactionCount > 0 ? story.reactionCount - 1 : 0) : story.reactionCount + 1;

    setState(() {
      _currentGroup[_currentStoryIndex] = story.copyWith(
        hasReacted: !currentlyReacted,
        reactionCount: newCount,
      );
    });

    try {
      final res = await FeedService().reactToStory(story.id);
      if (res['ok'] == true && mounted) {
        final serverReacted = res['hasReacted'] == true;
        final serverCount = res['reactionCount'] is int ? res['reactionCount'] as int : newCount;
        setState(() {
          _currentGroup[_currentStoryIndex] = story.copyWith(
            hasReacted: serverReacted,
            reactionCount: serverCount,
          );
        });
      }
    } catch (_) {}
  }

  void _openReplyModal() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => _StoryReplySheet(
        story: _currentStory,
        onSend: (text) async {
          final success = await FeedService().replyToStory(_currentStory.id, text);
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reply sent to @${_currentStory.authorUsername}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    ).then((_) {
      if (mounted) _resume();
    });
  }

  void _openViewersModal() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoryViewersSheet(storyId: _currentStory.id),
    ).then((_) {
      if (mounted) _resume();
    });
  }

  void _openShareModal() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ShareStorySheet(
        story: _currentStory,
        hostContext: context,
      ),
    ).then((_) {
      if (mounted) _resume();
    });
  }

  void _openOptionsMenu() {
    _pause();
    final story = _currentStory;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
        final cardColor = isDark ? const Color(0xFF2D2E30) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF111827);

        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: cardColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (story.ownedByMe) ...[
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            title: const Text('Delete story', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF242526),
                                  title: const Text('Delete story?', style: TextStyle(color: Colors.white)),
                                  content: const Text('This story will be permanently removed.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                await FeedService().deleteStory(story.id);
                                FeedService.notifyStoryCreated();
                                _currentGroup.removeAt(_currentStoryIndex);
                                if (_currentGroup.isEmpty) {
                                  widget.storyGroups.removeAt(_currentGroupIndex);
                                  if (widget.storyGroups.isEmpty) {
                                    _close();
                                    return;
                                  }
                                  if (_currentGroupIndex >= widget.storyGroups.length) {
                                    _currentGroupIndex = widget.storyGroups.length - 1;
                                  }
                                  _currentStoryIndex = 0;
                                } else if (_currentStoryIndex >= _currentGroup.length) {
                                  _currentStoryIndex = _currentGroup.length - 1;
                                }
                                _startAutoAdvance();
                                _syncMusicPreview();
                              }
                            },
                          ),
                        ] else ...[
                          ListTile(
                            leading: Icon(Icons.flag_outlined, color: textColor),
                            title: Text('Report story', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              final success = await FeedService().reportStory(int.tryParse(story.id) ?? 0, 'Reported from viewer');
                              if (mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Story reported. Thank you.')),
                                );
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) _resume();
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _ProgressBar(
                progress: _progress,
                count: _currentGroup.length,
                currentIndex: _currentStoryIndex,
              ),
              _StoryHeader(
                story: story,
                onClose: _close,
                onMore: _openOptionsMenu,
              ),
              Expanded(
                child: GestureDetector(
                  onTapDown: _onTapDown,
                  onLongPressStart: _onLongPressStart,
                  onLongPressEnd: _onLongPressEnd,
                  child: _StoryContent(story: story, isPaused: _isPaused),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (story.ownedByMe) ...[
                      GestureDetector(
                        onTap: _openViewersModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${story.viewCount} views',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openShareModal,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: _openReplyModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              'Send message to @${story.authorUsername}...',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _toggleReaction,
                        child: Icon(
                          story.hasReacted ? Icons.favorite : Icons.favorite_border,
                          color: story.hasReacted ? Colors.redAccent : Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _openShareModal,
                        child: const Icon(Icons.ios_share, color: Colors.white, size: 26),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareStorySheet extends StatelessWidget {
  const _ShareStorySheet({
    required this.story,
    required this.hostContext,
  });

  final Story story;
  final BuildContext hostContext;

  String get _storyLink {
    final baseUrl = ApiConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    return '$baseUrl/stories/${story.id}';
  }

  String get _shareText {
    final snippet = story.text?.trim() ?? '';
    final author = '@${story.authorUsername}';
    if (snippet.isNotEmpty) {
      return 'Check out $author\'s story on KatsKlub: "$snippet"\n\n$_storyLink';
    }
    return 'Check out $author\'s story on KatsKlub!\n\n$_storyLink';
  }

  Future<void> _systemShare(BuildContext context) async {
    Navigator.of(context).pop();
    await Share.share(
      _shareText,
      subject: 'KatsKlub Story by @${story.authorUsername}',
    );
  }

  void _copyLink(BuildContext context) {
    Navigator.of(context).pop();
    Clipboard.setData(ClipboardData(text: _storyLink));
    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Story link copied to clipboard.')),
    );
  }

  void _sendInMessage(BuildContext context) {
    Navigator.of(context).pop();
    Clipboard.setData(ClipboardData(text: _storyLink));
    Navigator.of(hostContext).push(
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    );
    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Story link copied. Open a chat to paste it.')),
    );
  }

  void _repostToFeed(BuildContext context) {
    Navigator.of(context).pop();
    Clipboard.setData(ClipboardData(text: _storyLink));
    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Story link copied! Paste it in Create Post to share with your followers.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
    final handleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final cardColor = isDark ? const Color(0xFF2D2E30) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Share story',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Story by ${story.authorFullName} (@${story.authorUsername})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _StoryShareActionButton(
                                icon: Icons.share_outlined,
                                label: 'Share app',
                                onTap: () => _systemShare(context),
                              ),
                              const SizedBox(width: 18),
                              _StoryShareActionButton(
                                icon: Icons.repeat_rounded,
                                label: 'Post to feed',
                                onTap: () => _repostToFeed(context),
                              ),
                              const SizedBox(width: 18),
                              _StoryShareActionButton(
                                icon: Icons.content_copy_rounded,
                                label: 'Copy link',
                                onTap: () => _copyLink(context),
                              ),
                              const SizedBox(width: 18),
                              _StoryShareActionButton(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Message',
                                onTap: () => _sendInMessage(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryShareActionButton extends StatelessWidget {
  const _StoryShareActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF3F4F6);
    final iconColor = isDark ? Colors.white : const Color(0xFF111827);
    final textColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: buttonBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryReplySheet extends StatefulWidget {
  const _StoryReplySheet({required this.story, required this.onSend});

  final Story story;
  final ValueChanged<String> onSend;

  @override
  State<_StoryReplySheet> createState() => _StoryReplySheetState();
}

class _StoryReplySheetState extends State<_StoryReplySheet> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
    final handleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final cardColor = isDark ? const Color(0xFF2D2E30) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reply to @${widget.story.authorUsername}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                autofocus: true,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Send a message...',
                                  hintStyle: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF3F4F6),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: Color(0xFFFF7A59)),
                              onPressed: () {
                                final text = _textController.text.trim();
                                if (text.isNotEmpty) {
                                  Navigator.of(context).pop();
                                  widget.onSend(text);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryViewersSheet extends StatefulWidget {
  const _StoryViewersSheet({required this.storyId});

  final String storyId;

  @override
  State<_StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<_StoryViewersSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _viewers = const [];

  @override
  void initState() {
    super.initState();
    _fetchViewers();
  }

  Future<void> _fetchViewers() async {
    final list = await FeedService().getStoryViewers(widget.storyId);
    if (mounted) {
      setState(() {
        _viewers = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
    final handleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final cardColor = isDark ? const Color(0xFF2D2E30) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye_outlined, color: textColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Story Viewers (${_viewers.length})',
                              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A59)))
                              : _viewers.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No viewers yet.',
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _viewers.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final item = _viewers[index];
                                        final fullName = item['fullName']?.toString() ?? 'User';
                                        final username = item['username']?.toString() ?? '';
                                        final avatarUrl = item['avatarUrl']?.toString() ?? '';
                                        return Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
                                              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(ApiConfig.assetUrl(avatarUrl)) : null,
                                              child: avatarUrl.isEmpty
                                                  ? Text(
                                                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SpecialNameText(
                                                    username: username,
                                                    displayName: fullName,
                                                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
                                                  ),
                                                  if (username.isNotEmpty)
                                                    Text(
                                                      '@$username',
                                                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({required this.story, required this.isPaused});

  final Story story;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final imageUrl = story.imageUrl;
    final text = story.text;
    final videoUrl = story.videoUrl;

    Widget body;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body = _ImageStory(imageUrl: imageUrl);
    } else if (videoUrl != null && videoUrl.isNotEmpty) {
      body = _VideoStory(
        key: ValueKey('story-video-${story.id}'),
        videoUrl: videoUrl,
        isPaused: isPaused,
        posterUrl: story.videoPosterUrl,
        text: story.text,
      );
    } else if (text != null && text.isNotEmpty) {
      body = _TextStory(
        text: text,
        backgroundStartColor: story.backgroundStartColor,
        backgroundEndColor: story.backgroundEndColor,
      );
    } else {
      body = _PlaceholderStory(story: story);
    }

    return SensitiveContentWrapper(
      isSensitive: story.isSensitive,
      child: body,
    );
  }
}

class _ImageStory extends StatelessWidget {
  const _ImageStory({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: ApiConfig.assetUrl(imageUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 64,
          ),
        ),
      ),
    );
  }
}

class _TextStory extends StatelessWidget {
  const _TextStory({required this.text, this.backgroundStartColor, this.backgroundEndColor});

  final String text;
  final String? backgroundStartColor;
  final String? backgroundEndColor;

  Color _parseColor(String? hex, Color fallback) {
    final value = (hex ?? '').trim().replaceFirst('#', '');
    if (value.length != 6) {
      return fallback;
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return fallback;
    }
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final start = _parseColor(backgroundStartColor, const Color(0xFF667EEA));
    final end = _parseColor(backgroundEndColor, const Color(0xFF764BA2));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoStory extends StatefulWidget {
  const _VideoStory({
    super.key,
    required this.videoUrl,
    required this.isPaused,
    this.posterUrl,
    this.text,
  });

  final String videoUrl;
  final bool isPaused;
  final String? posterUrl;
  final String? text;

  @override
  State<_VideoStory> createState() => _VideoStoryState();
}

class _VideoStoryState extends State<_VideoStory> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(ApiConfig.assetUrl(widget.videoUrl)),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      if (!widget.isPaused) {
        await controller.play();
      }
    } catch (e) {
      debugPrint('Error playing story video: $e');
    }
  }

  @override
  void didUpdateWidget(_VideoStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _initialized) {
      if (widget.isPaused != oldWidget.isPaused) {
        if (widget.isPaused) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget videoWidget;
    if (_initialized && _controller != null) {
      videoWidget = Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    } else {
      videoWidget = _VideoStoryPlaceholder(posterUrl: widget.posterUrl);
    }

    if (widget.text != null && widget.text!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          videoWidget,
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                widget.text!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return videoWidget;
  }
}

class _VideoStoryPlaceholder extends StatelessWidget {
  const _VideoStoryPlaceholder({this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl?.trim() ?? '';
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (poster.isNotEmpty)
            CachedNetworkImage(
              imageUrl: ApiConfig.assetUrl(poster),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            ),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderStory extends StatelessWidget {
  const _PlaceholderStory({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            SpecialNameText(
              username: story.authorUsername,
              displayName: story.authorFullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Story content unavailable',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.count,
    required this.currentIndex,
  });

  final double progress;
  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(count, (index) {
          final isActive = index == currentIndex;
          final isCompleted = index < currentIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.3),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: isCompleted
                        ? 1.0
                        : isActive
                            ? progress
                            : 0.0,
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.story,
    required this.onClose,
    required this.onMore,
  });

  final Story story;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: story.authorAvatarUrl.isEmpty
                  ? ColoredBox(
                      color: const Color(0xFFE5E7EB),
                      child: Center(
                        child: Text(
                          story.initials,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: ApiConfig.assetUrl(story.authorAvatarUrl),
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      placeholder: (context, url) => const ColoredBox(
                        color: Color(0xFFE5E7EB),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: const Color(0xFFE5E7EB),
                        child: Center(
                          child: Text(
                            story.initials,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpecialNameText(
                  username: story.authorUsername,
                  displayName: story.authorFullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (story.authorUsername.isNotEmpty || (story.musicTitle?.isNotEmpty ?? false))
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      children: [
                        if (story.authorUsername.isNotEmpty)
                          TextSpan(text: '@${story.authorUsername}'),
                        if (story.authorUsername.isNotEmpty && (story.musicTitle?.isNotEmpty ?? false))
                          const TextSpan(text: '  ·  '),
                        if (story.musicTitle?.isNotEmpty ?? false)
                          TextSpan(
                            text: story.musicTitle!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                if ((story.musicArtist?.isNotEmpty ?? false) && (story.musicTitle?.isNotEmpty ?? false))
                  Text(
                    story.musicArtist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: onMore,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
