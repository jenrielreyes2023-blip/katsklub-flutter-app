import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'webview_screen.dart';
import 'story_viewer_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../models/user_note.dart';
import '../models/story.dart';
import '../models/post.dart';
import '../services/auth_service.dart';
import '../services/conversation_theme.dart';
import '../services/feed_service.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../services/message_sound_service.dart';
import '../utils/emoji_presentation.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/presence_avatar_dot.dart';
import '../widgets/special_name_text.dart';
import '../services/presence_service.dart';
import '../services/webrtc_call_service.dart';
import 'package:syncfusion_flutter_chat/chat.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum _MessagesPageState { general, groups, requests, archived }

class _MessagesPageHeader extends StatelessWidget {
  const _MessagesPageHeader({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      height: 54,
      child: Row(
        children: [
          IconButton(
            padding: const EdgeInsets.only(left: 14),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 26,
            ),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Messages',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    this.initialThread,
    this.initialThreadId,
    this.initialGhostPost,
    this.onBack,
    super.key,
  });

  final MessageThread? initialThread;
  final int? initialThreadId;
  final Post? initialGhostPost;
  final VoidCallback? onBack;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  static const int _maxAttachmentBytes = 20 * 1024 * 1024;

  final FeedService _feedService = FeedService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  MessageThread? _thread;
  List<MessageThread> _threads = [];
  List<DirectMessage> _messages = [];
  bool _isLoadingThread = false;
  bool _isLoadingThreads = false;
  bool _hasLoadedThreadOnce = false;
  bool _hasLoadedThreadsOnce = false;
  bool _hasMoreMessages = true;
  bool _isLoadingMoreMessages = false;
  bool _isSending = false;
  bool _isRecording = false;
  DirectMessage? _replyTarget;
  Post? _replyingGhostPost;
  final List<_PendingMessageAttachment> _pendingAttachments =
      <_PendingMessageAttachment>[];
  _MessagesPageState _state = _MessagesPageState.general;
  User? _currentUser;
  User? _otherUserProfile;
  List<UserNote> _notes = [];
  List<Story> _stories = [];
  bool _isLoadingNotes = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<User> _searchedUsers = [];
  bool _isSearchingUsers = false;
  Timer? _searchDebounce;

  int? _pendingThreadId;
  int _highestSeenOwnMessageIndex = -1;

  StreamSubscription<DirectMessageEvent>? _dmMessageSub;
  StreamSubscription<MessageThread>? _dmThreadSub;
  StreamSubscription<DirectTypingEvent>? _dmTypingSub;
  StreamSubscription<DirectMessageReactionEvent>? _dmReactionSub;
  StreamSubscription<DirectMessageDeletedEvent>? _dmDeletedSub;
  StreamSubscription<DirectMessageEditedEvent>? _dmEditedSub;
  StreamSubscription<void>? _notesUpdatedSub;

  final Map<int, Set<String>> _typingByThread = <int, Set<String>>{};
  final Map<String, Timer> _typingExpireTimers = <String, Timer>{};
  Timer? _typingStopDebounce;
  bool _iAmTyping = false;

  Set<String> get _typingUserIds {
    final t = _thread;
    if (t == null) return const <String>{};
    return _typingByThread[t.id] ?? const <String>{};
  }

  @override
  void initState() {
    super.initState();
    _thread = widget.initialThread;
    _replyingGhostPost = widget.initialGhostPost;
    _pendingThreadId = widget.initialThreadId;
    WidgetsBinding.instance.addObserver(this);
    ConversationThemeStore.ensureInitialized();
    ConversationThemeStore.selections.addListener(_onThemeChanged);
    MessageSoundService.ensureInitialized();

    _dmMessageSub = FeedService.dmMessageStream.listen(_onDmMessage);
    _dmThreadSub = FeedService.dmThreadUpdatedStream.listen(_onDmThreadUpdated);
    _dmTypingSub = FeedService.dmTypingStream.listen(_onDmTyping);
    _dmReactionSub = FeedService.dmReactionStream.listen(_onDmMessageReaction);
    _dmDeletedSub = FeedService.onDmMessageDeleted.listen(_onDmMessageDeleted);
    _dmEditedSub = _feedService.onDmMessageEdited.listen(_onDmMessageEdited);
    _notesUpdatedSub = FeedService.notesUpdatedStream.listen((_) => _loadNotes());

    _loadCurrentUser();

    if (widget.initialThread != null) {
      _loadThread();
    } else if (_pendingThreadId != null) {
      _loadThreadById(_pendingThreadId!);
    } else {
      _loadThreads();
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final t = _thread;
      if (t != null) {
        unawaited(FeedService.ensureRealtimeSync());
        _loadThread();
        _feedService.markThreadRead(t.id);
      } else {
        unawaited(FeedService.ensureRealtimeSync());
        _loadThreads();
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scrollToBottomSoon();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConversationThemeStore.selections.removeListener(_onThemeChanged);
    final t = _thread;
    if (t != null && _iAmTyping) {
      _feedService.emitTyping(t.id, false);
    }
    _typingStopDebounce?.cancel();
    for (final timer in _typingExpireTimers.values) {
      timer.cancel();
    }
    _typingExpireTimers.clear();
    _dmMessageSub?.cancel();
    _dmThreadSub?.cancel();
    _dmTypingSub?.cancel();
    _dmReactionSub?.cancel();
    _dmDeletedSub?.cancel();
    _dmEditedSub?.cancel();
    _notesUpdatedSub?.cancel();
    unawaited(_audioRecorder.dispose());
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDmMessageReaction(DirectMessageReactionEvent event) {
    debugPrint('[DM-DBG] socket dm:message-reaction threadId=${event.threadId} msgId=${event.messageId}');
    final t = _thread;
    if (t == null || event.threadId != t.id || !mounted) return;

    setState(() {
      final idx = _messages.indexWhere((m) => m.id == event.messageId);
      if (idx >= 0) {
        final currentMsg = _messages[idx];
        _messages[idx] = currentMsg.copyWith(
          myReaction: event.myReaction ?? currentMsg.myReaction,
          reactions: event.reactions.isNotEmpty ? event.reactions : currentMsg.reactions,
          reactionSummary: event.reactionSummary.isNotEmpty ? event.reactionSummary : currentMsg.reactionSummary,
        );
      }
    });
  }

  void _onDmMessageDeleted(DirectMessageDeletedEvent event) {
    debugPrint('[DM-DBG] socket dm:message-deleted threadId=${event.threadId} msgId=${event.messageId}');
    final t = _thread;
    if (t == null || event.threadId != t.id || !mounted) return;

    setState(() {
      _messages.removeWhere((m) => m.id == event.messageId);
    });
  }

  void _onDmMessageEdited(DirectMessageEditedEvent event) {
    debugPrint('[DM-DBG] socket dm:message-edited threadId=${event.threadId} msgId=${event.messageId}');
    final t = _thread;
    if (t == null || event.threadId != t.id || !mounted) return;

    setState(() {
      final index = _messages.indexWhere((m) => m.id == event.messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          body: event.body,
          isEdited: true,
          editedAt: event.editedAt,
        );
      }
    });
  }

  DirectMessage? _editingTarget;

  void _startEditMessage(DirectMessage message) {
    setState(() {
      _editingTarget = message;
      _replyTarget = null;
      _controller.text = message.body;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _clearEditTarget() {
    setState(() {
      _editingTarget = null;
      _controller.clear();
    });
  }

  void _showReactionsListModal(DirectMessage message, {String? initialEmoji}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242526)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _ReactionsListModalContent(
          message: message,
          initialEmoji: initialEmoji,
          feedService: _feedService,
        );
      },
    );
  }

  void _onDmMessage(DirectMessageEvent event) {
    final t = _thread;
    debugPrint(
        '[DM-DBG] socket dm:message threadId=${event.threadId} msgId=${event.message.id} body="${event.message.body}" currentThread=${t?.id} mounted=$mounted');
    if (t == null || event.threadId != t.id) {
      // Not the open thread — bump the thread row to the top of the list.
      if (event.thread != null) {
        _bumpThreadInList(event.thread!);
      }
      // Other side is no longer typing once we receive their message.
      final senderId = event.message.sender.id ?? '';
      if (!event.message.sentByMe && senderId.isNotEmpty) {
        _clearTyping(event.threadId, senderId);
      }
      return;
    }
    if (!mounted) return;

    final exists = _messages.any((m) => m.id == event.message.id);
    if (exists) {
      // Already appended optimistically by _send; just refresh thread metadata.
      if (event.thread != null) {
        setState(() => _thread = event.thread);
      }
      return;
    }

    setState(() {
      _messages = [..._messages, event.message];
      if (event.thread != null) {
        _thread = event.thread;
      }
      // Other side is no longer typing if we just got their message.
      if (!event.message.sentByMe) {
        final senderId = event.message.sender.id ?? '';
        if (senderId.isNotEmpty) {
          _clearTyping(t.id, senderId);
        }
      }
    });
    _scrollToBottomSoon();

    if (!event.message.sentByMe) {
      _feedService.markThreadRead(t.id);
    }
  }

  void _onDmThreadUpdated(MessageThread updated) {
    final t = _thread;
    if (t != null && updated.id == t.id) {
      if (!mounted) return;
      setState(() => _thread = updated);
    }
    _patchThreadInList(updated);
  }

  void _patchThreadInList(MessageThread updated) {
    if (_threads.isEmpty) return;
    final idx = _threads.indexWhere((th) => th.id == updated.id);
    if (idx < 0) return;
    if (!mounted) return;
    setState(() {
      final next = List<MessageThread>.from(_threads);
      next[idx] = updated;
      _threads = next;
    });
  }

  void _bumpThreadInList(MessageThread updated) {
    if (!mounted) return;
    setState(() {
      final next = List<MessageThread>.from(_threads);
      final idx = next.indexWhere((th) => th.id == updated.id);
      if (idx >= 0) {
        next.removeAt(idx);
      }
      next.insert(0, updated);
      _threads = next;
    });
  }

  void _onDmTyping(DirectTypingEvent event) {
    if (event.typing) {
      _markTyping(event.threadId, event.userId);
    } else {
      _clearTyping(event.threadId, event.userId);
    }
  }

  String _typingKey(int threadId, String userId) => '$threadId:$userId';

  void _markTyping(int threadId, String userId) {
    final key = _typingKey(threadId, userId);
    _typingExpireTimers[key]?.cancel();
    _typingExpireTimers[key] = Timer(const Duration(seconds: 5), () {
      _clearTyping(threadId, userId);
    });
    final set = _typingByThread.putIfAbsent(threadId, () => <String>{});
    if (!set.contains(userId)) {
      if (!mounted) return;
      setState(() => set.add(userId));
      _scrollToBottomSoon();
    }
  }

  void _clearTyping(int threadId, String userId) {
    _typingExpireTimers.remove(_typingKey(threadId, userId))?.cancel();
    final set = _typingByThread[threadId];
    if (set != null && set.contains(userId)) {
      if (!mounted) return;
      setState(() {
        set.remove(userId);
        if (set.isEmpty) _typingByThread.remove(threadId);
      });
      _scrollToBottomSoon();
    }
  }

  void _scrollToBottomSoon({bool animate = false}) {
    void doScroll() {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      doScroll();
    });
  }

  void _onComposerChanged(String text) {
    final t = _thread;
    if (t == null) return;
    if (text.isNotEmpty) {
      if (!_iAmTyping) {
        _iAmTyping = true;
        _feedService.emitTyping(t.id, true);
      }
      _typingStopDebounce?.cancel();
      _typingStopDebounce = Timer(const Duration(seconds: 2), () {
        if (_iAmTyping) {
          _iAmTyping = false;
          _feedService.emitTyping(t.id, false);
        }
      });
    } else if (_iAmTyping) {
      _typingStopDebounce?.cancel();
      _iAmTyping = false;
      _feedService.emitTyping(t.id, false);
    }
  }

  ConversationTheme _getTheme() {
    ConversationTheme theme = _thread != null
        ? ConversationThemeStore.themeFor(_thread!.id)
        : ConversationTheme.classic;

    return theme.resolveForBrightness(Theme.of(context).brightness);
  }

  @override
  Widget build(BuildContext context) {
    if (_thread == null) {
      return _messagesHomePage(context);
    }

    final theme = _getTheme();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        title: Row(
          children: [
            _ThreadAvatar(thread: _thread),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _thread?.isGroup == true
                      ? Text(
                          _thread!.name.isNotEmpty
                              ? _thread!.name
                              : 'Group chat',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : SpecialNameText(
                          username: _thread?.otherUser.username ?? '',
                          displayName: _thread?.otherUser.displayName ?? 'Messages',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  if (_thread?.isGroup == true)
                    Text(
                      '${_thread!.members.length} members',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (_thread?.otherUser.id != null)
                    _ConversationPresenceLabel(
                      userId: _thread!.otherUser.id!,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: Icon(
              Icons.call_outlined,
              color: theme.accent,
              size: 22,
            ),
            onPressed: _startAudioCall,
          ),
          IconButton(
            tooltip: 'More',
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white : const Color(0xFF111827),
              size: 22,
            ),
            onPressed: _openMoreMenu,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoadingThread && !_hasLoadedThreadOnce && _messages.isEmpty
          ? Column(
              children: [
                const Expanded(child: _MessageThreadSkeleton()),
                _composer(),
              ],
            )
          : _buildMessagesList(),
    );
  }

  Widget _messagesHomePage(BuildContext context) {
    final showSearch = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _MessagesPageHeader(onBack: widget.onBack),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadThreads,
                child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _buildSearchBar(),
                  ),
                  const SizedBox(height: 14),
                  if (showSearch)
                    _buildSearchResults()
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _statePicker(),
                    ),
                    const SizedBox(height: 14),
                    _body(),
                  ],
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E2E)
            : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D3F) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _stateButton('Chats', _MessagesPageState.general,
              badge: _tabBadgeFor(_MessagesPageState.general)),
          _stateButton('Groups', _MessagesPageState.groups,
              badge: _tabBadgeFor(_MessagesPageState.groups)),
          _stateButton('Requests', _MessagesPageState.requests,
              badge: _tabBadgeFor(_MessagesPageState.requests)),
          _stateButton('Archived', _MessagesPageState.archived,
              badge: _tabBadgeFor(_MessagesPageState.archived)),
        ],
      ),
    );
  }

  int _tabBadgeFor(_MessagesPageState state) {
    switch (state) {
      case _MessagesPageState.general:
        return _threads
            .where((t) => !t.isGroup && t.isActive && t.unreadCount > 0)
            .length;
      case _MessagesPageState.groups:
        return _threads
            .where((t) => t.isGroup && t.isActive && t.unreadCount > 0)
            .length;
      case _MessagesPageState.requests:
        return _threads.where((t) => t.isRequested).length;
      case _MessagesPageState.archived:
        return _threads
            .where((t) => t.isArchived && t.unreadCount > 0)
            .length;
    }
  }

  Widget _stateButton(String label, _MessagesPageState state, {int badge = 0}) {
    final selected = _state == state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _state = state),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFF7A45), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF7A45).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: TextStyle(
                      color: selected ? const Color(0xFFFF7A45) : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case _MessagesPageState.groups:
        final groupThreads = _threads
            .where((t) => t.isGroup && t.isActive)
            .toList(growable: false);

        if (_isLoadingThreads && !_hasLoadedThreadsOnce && _threads.isEmpty) {
          return const _MessagesThreadListSkeleton();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _CreateGroupButton(onTap: _openCreateGroupSheet),
            ),
            const SizedBox(height: 12),
            if (groupThreads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: _MessagesInfoState(
                  icon: Icons.group_outlined,
                  title: 'Groups',
                  description:
                      'Create or join groups to chat with multiple people at once. Share moments and stay connected.',
                  emptyText: 'No groups yet',
                ),
              )
            else
              _MessagesThreadList(
                threads: groupThreads,
                typingThreadIds: _typingByThread.entries
                    .where((e) => e.value.isNotEmpty)
                    .map((e) => e.key)
                    .toSet(),
                onOpenThread: (thread) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MessagesScreen(initialThread: thread),
                    ),
                  );
                },
              ),
          ],
        );
      case _MessagesPageState.requests:
        final reqThreads =
            _threads.where((t) => t.isRequested).toList(growable: false);
        if (_isLoadingThreads && !_hasLoadedThreadsOnce && _threads.isEmpty) {
          return const _MessagesThreadListSkeleton();
        }
        if (reqThreads.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _MessagesInfoState(
              icon: Icons.info_outline_rounded,
              title: 'Requests',
              description:
                  'Request from people to join to some groups or chats. You can accept or decline them at any time.',
              emptyText: 'No requests yet',
            ),
          );
        }
        return _MessagesRequestList(
          threads: reqThreads,
          onOpen: (thread) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessagesScreen(initialThread: thread),
              ),
            );
          },
          onAccept: _acceptRequest,
          onDecline: _declineRequest,
        );
      case _MessagesPageState.archived:
        final arThreads =
            _threads.where((t) => t.isArchived).toList(growable: false);
        if (_isLoadingThreads && !_hasLoadedThreadsOnce && _threads.isEmpty) {
          return const _MessagesThreadListSkeleton();
        }
        if (arThreads.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _MessagesInfoState(
              icon: Icons.archive_outlined,
              title: 'Archived chats',
              description:
                  'Here you can find all your archived chats. You can unarchive them at any time.',
              emptyText: 'No archived chats',
            ),
          );
        }
        return _MessagesThreadList(
          threads: arThreads,
          typingThreadIds: _typingByThread.entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => e.key)
              .toSet(),
          onOpenThread: (thread) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessagesScreen(initialThread: thread),
              ),
            );
          },
        );
      case _MessagesPageState.general:
        final directThreads = _threads
            .where((t) => !t.isGroup && t.isActive)
            .toList(growable: false);

        if (_isLoadingThreads && !_hasLoadedThreadsOnce && _threads.isEmpty) {
          return const _MessagesThreadListSkeleton();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNotesRail(),
            if (directThreads.isEmpty)
              const SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'No chats history',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              _MessagesThreadList(
                threads: directThreads,
                typingThreadIds: _typingByThread.entries
                    .where((e) => e.value.isNotEmpty)
                    .map((e) => e.key)
                    .toSet(),
                onOpenThread: (thread) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MessagesScreen(initialThread: thread),
                    ),
                  );
                },
              ),
          ],
        );
    }
  }

  Future<void> _loadThreads() async {
    setState(() {
      _isLoadingThreads = !_hasLoadedThreadsOnce && _threads.isEmpty;
    });

    _loadNotes();

    try {
      final threads = await _feedService.loadMessageThreads();
      if (!mounted) {
        return;
      }

      setState(() {
        _threads = threads;
        _isLoadingThreads = false;
        _hasLoadedThreadsOnce = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingThreads = false;
        _hasLoadedThreadsOnce = true;
      });
    }
  }

  void _onSearchQueryChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    _searchDebounce?.cancel();
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchedUsers = [];
        _isSearchingUsers = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isSearchingUsers = true;
      });

      try {
        final users = await _feedService.searchUsers(_searchQuery);
        if (mounted && _searchQuery.trim().isNotEmpty) {
          setState(() {
            _searchedUsers = users;
            _isSearchingUsers = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSearchingUsers = false;
          });
        }
      }
    });
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.search_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchQueryChanged,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Search chats or users...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onSearchQueryChanged("");
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF6B7280),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final query = _searchQuery.toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final headerTextColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151);
    final containerBg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);
    
    final matchedThreads = _threads.where((t) {
      if (t.isGroup) {
        return t.name.toLowerCase().contains(query);
      } else {
        final other = t.otherUser;
        final name = (other.displayName ?? '').toLowerCase();
        final username = (other.username ?? '').toLowerCase();
        return name.contains(query) || username.contains(query);
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matchedThreads.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Chats',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: headerTextColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _MessagesThreadList(
            threads: matchedThreads,
            typingThreadIds: _typingByThread.entries
                .where((e) => e.value.isNotEmpty)
                .map((e) => e.key)
                .toSet(),
            onOpenThread: (thread) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MessagesScreen(initialThread: thread),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'KatsKlub Users',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: headerTextColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_isSearchingUsers)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF7A45),
                ),
              ),
            ),
          )
        else if (_searchedUsers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No users found',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(color: containerBg),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchedUsers.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                color: dividerColor,
              ),
              itemBuilder: (context, index) {
                final user = _searchedUsers[index];
                final resolvedAvatar = ApiConfig.assetUrl(user.avatarUrl ?? '');
                return InkWell(
                  onTap: () => _startChatWithUser(user),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: resolvedAvatar.isNotEmpty
                              ? NetworkImage(resolvedAvatar)
                              : null,
                          child: resolvedAvatar.isEmpty
                              ? Text(
                                  user.initials,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4B5563),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName.isNotEmpty ? user.displayName : '@${user.username}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${user.username}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: secondaryTextColor,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _startChatWithUser(User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final thread = await _feedService.startMessageThread(user.username ?? "");
      Navigator.of(context).pop();

      if (thread != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessagesScreen(initialThread: thread),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start chat.')),
        );
      }
    } catch (_) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error starting chat.')),
      );
    }
  }

  void _loadCurrentUser() async {
    final user = await AuthService().getSavedUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNotes = true;
    });
    try {
      final results = await Future.wait([
        _feedService.loadUserNotes(),
        _feedService.loadStories(),
      ]);
      if (mounted) {
        setState(() {
          _notes = results[0] as List<UserNote>;
          _stories = results[1] as List<Story>;
          _isLoadingNotes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    }
  }

  Widget _buildNotesRail() {
    if (_currentUser == null) return const SizedBox.shrink();

    UserNote? ownNote;
    for (final n in _notes) {
      if (n.userId == _currentUser!.id) {
        ownNote = n;
        break;
      }
    }

    final otherNotes = _notes.where((n) => n.userId != _currentUser!.id).toList();

    return Container(
      height: 124,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: 1 + otherNotes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildOwnNoteItem(ownNote);
          }
          final note = otherNotes[index - 1];
          return _buildOtherNoteItem(note);
        },
      ),
    );
  }

  void _openUserStories(String username) {
    if (username.isEmpty) return;
    final targetLower = username.trim().toLowerCase();
    final userStories = _stories.where((s) => s.authorUsername.trim().toLowerCase() == targetLower).toList();
    
    if (userStories.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            storyGroups: [userStories],
            initialGroupIndex: 0,
            initialStoryIndex: 0,
          ),
        ),
      );
    }
  }

  Widget _buildOwnNoteItem(UserNote? ownNote) {
    final hasNote = ownNote != null;
    final avatarUrl = _currentUser?.avatarUrl ?? '';
    final resolvedAvatar = ApiConfig.assetUrl(avatarUrl);

    final ownStories = _stories.where((s) => s.ownedByMe).toList();
    final hasStories = ownStories.isNotEmpty;

    return SizedBox(
      width: 80,
      child: Column(
        children: [
          SizedBox(
            height: 84,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: () {
                    if (hasStories) {
                      _openUserStories(_currentUser?.username ?? '');
                    } else if (!hasNote) {
                      _openOwnNoteActionsSheet(ownNote);
                    }
                  },
                  child: hasStories
                      ? Container(
                          width: 74,
                          height: 74,
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 31,
                              backgroundColor: const Color(0xFFE5E7EB),
                              backgroundImage: resolvedAvatar.isNotEmpty
                                  ? NetworkImage(resolvedAvatar) as ImageProvider
                                  : null,
                              child: resolvedAvatar.isEmpty
                                  ? Text(
                                      _currentUser?.displayName.isNotEmpty == true
                                          ? _currentUser!.displayName[0].toUpperCase()
                                          : 'Me',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4B5563),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        )
                      : Container(
                          width: 74,
                          height: 74,
                          alignment: Alignment.center,
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: const Color(0xFFE5E7EB),
                            backgroundImage: resolvedAvatar.isNotEmpty
                                ? NetworkImage(resolvedAvatar) as ImageProvider
                                : null,
                            child: resolvedAvatar.isEmpty
                                ? Text(
                                    _currentUser?.displayName.isNotEmpty == true
                                        ? _currentUser!.displayName[0].toUpperCase()
                                        : 'Me',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4B5563),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                ),
                if (hasNote)
                  Positioned(
                    top: 0,
                    left: -10,
                    right: -10,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _openOwnNoteActionsSheet(ownNote),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 3,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Text(
                            ownNote.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 6,
                    bottom: 2,
                    child: GestureDetector(
                      onTap: () => _openOwnNoteActionsSheet(ownNote),
                      child: Container(
                        width: 21,
                        height: 21,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your note',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherNoteItem(UserNote note) {
    final resolvedAvatar = ApiConfig.assetUrl(note.avatarUrl);

    final userStories = _stories.where((s) => s.authorUsername.toLowerCase() == note.username.toLowerCase()).toList();
    final hasStories = userStories.isNotEmpty;

    return SizedBox(
      width: 80,
      child: Column(
        children: [
          SizedBox(
            height: 84,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: () {
                    if (hasStories) {
                      _openUserStories(note.username);
                    }
                  },
                  child: hasStories
                      ? Container(
                          width: 74,
                          height: 74,
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFEC4899)],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 31,
                              backgroundColor: const Color(0xFFE5E7EB),
                              backgroundImage: resolvedAvatar.isNotEmpty
                                  ? NetworkImage(resolvedAvatar) as ImageProvider
                                  : null,
                              child: resolvedAvatar.isEmpty
                                  ? Text(
                                      note.initials,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4B5563),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        )
                      : Container(
                          width: 74,
                          height: 74,
                          alignment: Alignment.center,
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: const Color(0xFFE5E7EB),
                            backgroundImage: resolvedAvatar.isNotEmpty
                                ? NetworkImage(resolvedAvatar) as ImageProvider
                                : null,
                            child: resolvedAvatar.isEmpty
                                ? Text(
                                    note.initials,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4B5563),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  left: -10,
                  right: -10,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _openReplyNoteDialog(note),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 3,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Text(
                          note.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note.fullName.isNotEmpty ? note.fullName : '@${note.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openOwnNoteActionsSheet(UserNote? ownNote) {
    if (ownNote == null) {
      _showCreateNoteDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '"${ownNote.text}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                title: const Text('Leave a new note'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showCreateNoteDialog(currentText: ownNote.text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                title: const Text('Delete note', style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteNote();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCreateNoteDialog({String? currentText}) {
    final textController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final length = textController.text.length;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Share a thought',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textController,
                    maxLength: 60,
                    maxLines: 2,
                    autofocus: true,
                    onChanged: (val) {
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: "What's on your mind? (up to 60 characters)...",
                      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      counterText: "",
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$length / 60',
                      style: TextStyle(
                        fontSize: 12,
                        color: length > 50 ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  onPressed: textController.text.trim().isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _saveNote(textController.text.trim());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Share', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveNote(String text) async {
    final note = await _feedService.saveUserNote(text);
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note shared!')),
      );
      _loadNotes();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share note.')),
      );
    }
  }

  void _deleteNote() async {
    final ok = await _feedService.deleteUserNote();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted.')),
      );
      _loadNotes();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete note.')),
      );
    }
  }

  void _openReplyNoteDialog(UserNote note) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE5E7EB),
                        backgroundImage: note.avatarUrl.isNotEmpty
                            ? NetworkImage(ApiConfig.assetUrl(note.avatarUrl))
                            : null,
                        child: note.avatarUrl.isEmpty
                            ? Text(
                                note.initials,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B5563),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.fullName.isNotEmpty ? note.fullName : '@${note.username}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${note.username}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      note.text,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: replyController,
                    autofocus: true,
                    onChanged: (val) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Send message...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  onPressed: replyController.text.trim().isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _replyToNote(note, replyController.text.trim());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Send', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _replyToNote(UserNote note, String replyText) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final thread = await _feedService.startMessageThread(note.username);
      if (thread != null) {
        final messageBody = 'Replying to your note "${note.text}":\n\n$replyText';
        final message = await _feedService.sendDirectMessage(thread.id, messageBody);
        
        Navigator.of(context).pop(); // dismiss loading

        if (message != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MessagesScreen(initialThread: thread),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send reply.')),
          );
        }
      } else {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start chat.')),
        );
      }
    } catch (_) {
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error replying to note.')),
      );
    }
  }

  Future<void> _loadOtherUserProfile(MessageThread thread) async {
    if (thread.isGroup) return;
    final username = thread.otherUser.username;
    if (username == null || username.isEmpty) return;
    try {
      final profile = await _feedService.loadUserProfile(username);
      if (mounted && _thread?.id == thread.id) {
        setState(() {
          _otherUserProfile = profile;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadThread() async {
    final thread = _thread;
    if (thread == null) {
      return;
    }

    setState(() {
      _isLoadingThread = !_hasLoadedThreadOnce && _messages.isEmpty;
      _otherUserProfile = null;
    });

    try {
      final page = await _feedService.loadMessageThread(thread.id);
      if (!mounted) {
        return;
      }

      setState(() {
        if (page != null) {
          _thread = page.thread;
          _messages = page.messages;
          _hasMoreMessages = page.messages.length >= 30;
        }
        _isLoadingThread = false;
        _hasLoadedThreadOnce = true;
      });

      _scrollToBottomSoon();
      _feedService.markThreadRead(thread.id);
      _scheduleStaleCatchup(thread.id);

      if (page != null) {
        _loadOtherUserProfile(page.thread);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingThread = false;
        _hasLoadedThreadOnce = true;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    final thread = _thread;
    if (thread == null || _isLoadingMoreMessages || !_hasMoreMessages || _messages.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMoreMessages = true;
    });

    try {
      final oldestMessageId = _messages.first.id;
      final page = await _feedService.loadMessageThread(
        thread.id,
        beforeId: oldestMessageId,
      );

      if (!mounted) return;

      setState(() {
        if (page != null && page.messages.isNotEmpty) {
          _messages = [...page.messages, ..._messages];
          _hasMoreMessages = page.messages.length >= 30;
        } else {
          _hasMoreMessages = false;
        }
        _isLoadingMoreMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreMessages = false;
      });
    }
  }

  Future<void> _loadThreadById(int threadId) async {
    setState(() {
      _isLoadingThread = true;
      _otherUserProfile = null;
    });

    debugPrint('[DM-DBG] _loadThreadById($threadId) start');
    try {
      final page = await _feedService.loadMessageThread(threadId);
      if (!mounted) return;
      if (page == null) {
        debugPrint('[DM-DBG] _loadThreadById($threadId) -> page=null');
      } else {
        final ids = page.messages.map((m) => m.id).toList();
        final last = page.messages.isEmpty ? null : page.messages.last;
        debugPrint(
            '[DM-DBG] _loadThreadById($threadId) count=${page.messages.length} ids=$ids lastId=${last?.id} lastBody="${last?.body}"');
      }
      setState(() {
        if (page != null) {
          _thread = page.thread;
          _messages = page.messages;
          _hasMoreMessages = page.messages.length >= 30;
        }
        _isLoadingThread = false;
        _hasLoadedThreadOnce = true;
      });
      _scrollToBottomSoon();
      if (page != null) {
        _feedService.markThreadRead(threadId);
        _loadOtherUserProfile(page.thread);
      }
      _scheduleStaleCatchup(threadId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingThread = false;
        _hasLoadedThreadOnce = true;
      });
    }
  }

  void _scheduleStaleCatchup(int threadId) {
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final t = _thread;
      if (t == null || t.id != threadId) return;
      try {
        final page = await _feedService.loadMessageThread(threadId);
        if (!mounted || page == null) return;
        final currentIds = _messages.map((m) => m.id).toSet();
        final fresh = page.messages
            .where((m) => m.id > 0 && !currentIds.contains(m.id))
            .toList();
        if (fresh.isEmpty) return;
        debugPrint(
            '[DM-DBG] catchup($threadId) found ${fresh.length} missed msg(s) ids=${fresh.map((m) => m.id).toList()}');
        setState(() {
          _thread = page.thread;
          _messages = [..._messages, ...fresh];
        });
        _scrollToBottomSoon();
        _feedService.markThreadRead(threadId);
      } catch (_) {}
    });
  }

  Widget _buildMessagesList() {
    final ownLastIndex = _findLastOwnIndex();
    final theme = _getTheme();
    final isKatswipeBot = _thread?.otherUser.username?.toLowerCase() == 'katswipe';
    final otherLastReadAtStr = _thread?.otherLastReadAt;
    final otherLastReadAt = otherLastReadAtStr != null
        ? DateTime.tryParse(otherLastReadAtStr)?.toLocal()
        : null;
    final threadSeen = _thread?.lastMessage?.seenByOther ?? false;

    if (ownLastIndex >= 0 && ownLastIndex < _messages.length) {
      final lastOwnMsg = _messages[ownLastIndex];
      final lastOwnTime = DateTime.tryParse(lastOwnMsg.createdAt)?.toLocal();
      final lastOwnSeen = threadSeen || (otherLastReadAt != null && lastOwnTime != null && !lastOwnTime.isAfter(otherLastReadAt));
      if (lastOwnSeen) {
        if (ownLastIndex > _highestSeenOwnMessageIndex) {
          _highestSeenOwnMessageIndex = ownLastIndex;
        }
      }
    }

    final t = _thread;
    final showTyping = t != null &&
        _typingUserIds.isNotEmpty &&
        _typingUserIds.contains(t.otherUser.id) &&
        !isKatswipeBot;

    // Convert _messages to List<ChatMessage>
    final chatMessages = <ChatMessage>[];

    // Prepend a "Load older messages" indicator if there are more
    if (_hasMoreMessages && _messages.isNotEmpty) {
      chatMessages.add(
        SfDirectChatMessage(
          directMessage: DirectMessage(
            id: -998, // Special ID for loading older messages
            conversationId: t?.id ?? 0,
            body: '',
            createdAt: DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
            sender: User.fromJson(const <String, dynamic>{}),
            sentByMe: false,
          ),
          text: '',
          time: DateTime.now().subtract(const Duration(days: 365)),
          author: const ChatAuthor(
            id: '-998',
            name: '',
          ),
        ),
      );
    }

    for (int index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      final prev = index > 0 ? _messages[index - 1] : null;
      final next = index < _messages.length - 1 ? _messages[index + 1] : null;
      final isLastOwn = index == ownLastIndex;
      final messageSeen = message.seenByOther;
      final messageTime = DateTime.tryParse(message.createdAt)?.toLocal() ?? DateTime.now();
      final seenByOther = message.sentByMe && (
        messageSeen ||
        index <= _highestSeenOwnMessageIndex ||
        (index <= ownLastIndex && threadSeen) ||
        (otherLastReadAt != null && !messageTime.isAfter(otherLastReadAt))
      );

      chatMessages.add(
        SfDirectChatMessage(
          directMessage: message,
          text: message.body,
          time: DateTime.tryParse(message.createdAt)?.toLocal() ?? DateTime.now(),
          author: ChatAuthor(
            id: message.sender.id?.toString() ?? '',
            name: message.sender.displayName ?? message.sender.username ?? '',
            avatar: message.sender.avatarUrl != null
                ? NetworkImage(message.sender.avatarUrl!)
                : null,
          ),
          seenByOther: seenByOther,
          isLastOwn: isLastOwn,
          prevMessage: prev,
          nextMessage: next,
        ),
      );
    }

    if (showTyping && t != null) {
      chatMessages.add(
        SfDirectChatMessage(
          directMessage: DirectMessage(
            id: -999, // Special ID for typing indicator
            conversationId: t.id,
            body: '',
            createdAt: DateTime.now().toIso8601String(),
            sender: t.otherUser,
            sentByMe: false,
          ),
          text: '',
          time: DateTime.now(),
          author: ChatAuthor(
            id: t.otherUser.id?.toString() ?? '',
            name: t.otherUser.displayName ?? t.otherUser.username ?? '',
            avatar: t.otherUser.avatarUrl != null
                ? NetworkImage(t.otherUser.avatarUrl!)
                : null,
          ),
        ),
      );
    }

    final currentUserId = _currentUser?.id?.toString() ?? '';

    return SfChat(
      messages: chatMessages,
      outgoingUser: currentUserId,
      incomingMessageSettings: const ChatMessageSettings(
        backgroundColor: Colors.transparent,
        showAuthorAvatar: false,
        showAuthorName: false,
        showTimestamp: false,
        padding: EdgeInsets.zero,
      ),
      outgoingMessageSettings: const ChatMessageSettings(
        backgroundColor: Colors.transparent,
        showAuthorAvatar: false,
        showAuthorName: false,
        showTimestamp: false,
        padding: EdgeInsets.zero,
      ),
      messageContentBuilder: (BuildContext context, int index, ChatMessage chatMessage) {
        if (chatMessage is SfDirectChatMessage) {
          final message = chatMessage.directMessage;
          if (message.id == -998) {
            if (!_isLoadingMoreMessages) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadOlderMessages();
              });
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              ),
            );
          }

          if (message.id == -999 && t != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: _TypingRow(otherUser: t.otherUser),
            );
          }

          final prev = chatMessage.prevMessage;
          final next = chatMessage.nextMessage;
          final isLastOwn = chatMessage.isLastOwn;
          final seenByOther = chatMessage.seenByOther;

          final bubble = Builder(
            builder: (bubbleContext) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: isKatswipeBot
                    ? null
                    : () => _showMessengerOverlay(
                          message,
                          bubbleContext,
                          prev,
                          next,
                          isLastOwn,
                          seenByOther,
                          theme,
                        ),
                child: _MessageBubble(
                  message: message,
                  previous: prev,
                  next: next,
                  isLastOwn: isLastOwn,
                  seenByOther: seenByOther,
                  theme: theme,
                ),
              );
            },
          );

          if (isKatswipeBot) {
            return bubble;
          }

          return _SwipeToReply(
            onSwipeReply: () => _startReplyTo(message),
            child: bubble,
          );
        }
        return Text(chatMessage.text);
      },
      composer: ChatComposer.builder(
        builder: (BuildContext context) {
          return _composer();
        },
      ),
    );
  }

  void _startReplyTo(DirectMessage message) {
    if (!mounted) return;
    setState(() => _replyTarget = message);
  }

  void _clearReplyTarget() {
    if (!mounted) return;
    setState(() => _replyTarget = null);
  }

  void _showMessengerOverlay(
    DirectMessage message,
    BuildContext bubbleContext,
    DirectMessage? previous,
    DirectMessage? next,
    bool isLastOwn,
    bool seenByOther,
    ConversationTheme theme,
  ) {
    HapticFeedback.selectionClick();

    final renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final bubbleOffset = renderBox.localToGlobal(Offset.zero);
    final bubbleSize = renderBox.size;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _MessengerOverlayContent(
          message: message,
          bubbleOffset: bubbleOffset,
          bubbleSize: bubbleSize,
          previous: previous,
          next: next,
          isLastOwn: isLastOwn,
          seenByOther: seenByOther,
          theme: theme,
          onDismiss: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          },
          onSelectReaction: (emoji) async {
            final isSelected = message.myReaction == emoji;
            final newReaction = isSelected ? null : emoji;
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == message.id);
              if (idx >= 0) {
                _messages[idx] = _messages[idx].copyWith(myReaction: newReaction);
              }
            });
            await _feedService.reactToMessage(message.id, newReaction ?? '');
          },
          onReply: () => _startReplyTo(message),
          onCopy: message.body.trim().isNotEmpty
              ? () {
                  Clipboard.setData(ClipboardData(text: message.body));
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              : null,
          onForward: () => _showForwardPicker(message),
          onTranslate: () => _showTranslationModal(message),
          onEdit: message.sentByMe ? () => _startEditMessage(message) : null,
          onUnsend: message.sentByMe
              ? () async {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _messages.removeWhere((m) => m.id == message.id);
                  });
                  final ok = await _feedService.deleteMessage(message.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Message unsent' : 'Failed to unsend message'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              : null,
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
  }

  void _showTranslationModal(DirectMessage message) {
    if (message.body.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.translate_rounded, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text('Translation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Original:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 2),
              Text(message.body, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 12),
              const Text('Translated:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
              const SizedBox(height: 2),
              Text(message.body, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showForwardPicker(DirectMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Forward Message to...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFF3F4F6)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _threads.length,
                  itemBuilder: (context, index) {
                    final targetThread = _threads[index];
                    final otherUser = targetThread.otherUser;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: otherUser.avatarUrl != null && otherUser.avatarUrl!.isNotEmpty
                            ? NetworkImage(otherUser.avatarUrl!)
                            : null,
                        child: (otherUser.avatarUrl == null || otherUser.avatarUrl!.isEmpty)
                            ? Text(otherUser.displayName.isNotEmpty ? otherUser.displayName[0] : '?')
                            : null,
                      ),
                      title: Text(
                        otherUser.displayName.isNotEmpty ? otherUser.displayName : (otherUser.username ?? 'User'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF3B82F6)),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        HapticFeedback.lightImpact();
                        final sent = await _feedService.sendDirectMessage(
                          targetThread.id,
                          message.body,
                          attachmentDataUrl: message.attachment?.url,
                          attachmentType: message.attachment?.type,
                          attachmentName: message.attachment?.name,
                          attachmentMime: message.attachment?.mime,
                        );
                        if (mounted && sent != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Message forwarded to ${otherUser.displayName.isNotEmpty ? otherUser.displayName : 'user'}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Typing indicator is now rendered as a list item at the bottom of ListView.builder.

  Future<void> _acceptRequest(MessageThread thread) async {
    try {
      final updated = await _feedService.acceptMessageThread(thread.id);
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          final idx = _threads.indexWhere((t) => t.id == updated.id);
          if (idx >= 0) _threads[idx] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted')),
        );
      }
    } catch (_) {}
  }

  Future<void> _declineRequest(MessageThread thread) async {
    try {
      final ok = await _feedService.declineMessageThread(thread.id);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _threads.removeWhere((t) => t.id == thread.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined')),
        );
      }
    } catch (_) {}
  }

  Future<void> _archiveCurrentThread() async {
    final t = _thread;
    if (t == null) return;
    try {
      final updated = await _feedService.archiveMessageThread(t.id);
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _thread = updated;
          final idx = _threads.indexWhere((x) => x.id == updated.id);
          if (idx >= 0) _threads[idx] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat archived')),
        );
        Navigator.of(context).maybePop();
      }
    } catch (_) {}
  }

  Future<void> _unarchiveCurrentThread() async {
    final t = _thread;
    if (t == null) return;
    try {
      final updated = await _feedService.unarchiveMessageThread(t.id);
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _thread = updated;
          final idx = _threads.indexWhere((x) => x.id == updated.id);
          if (idx >= 0) _threads[idx] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat unarchived')),
        );
      }
    } catch (_) {}
  }

  void _startAudioCall() {
    final t = _thread;
    if (t == null || t.isGroup || t.otherUser.id == null || t.otherUser.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio calls are available in 1-on-1 chats.')),
      );
      return;
    }

    WebRTCCallService().startAudioCall(
      targetUserId: t.otherUser.id!,
      targetUsername: t.otherUser.username ?? '',
      targetFullName: t.otherUser.fullName ?? t.otherUser.username ?? '',
      targetAvatarUrl: t.otherUser.avatarUrl ?? '',
      threadId: t.id,
    );
  }

  void _openMoreMenu() {
    final t = _thread;
    if (t == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF242526) : Colors.white;
    final sheetTextIconColor = isDark ? Colors.white : const Color(0xFF111827);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (t.isGroup)
                ListTile(
                  leading: Icon(Icons.group_add_outlined,
                      color: sheetTextIconColor),
                  title: Text(
                    'Add members',
                    style: TextStyle(
                      color: sheetTextIconColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openAddMembersSheet(t);
                  },
                ),
              if (t.isGroup)
                ListTile(
                  leading: Icon(Icons.people_outline_rounded,
                      color: sheetTextIconColor),
                  title: Text(
                    'Members (${t.members.length})',
                    style: TextStyle(
                      color: sheetTextIconColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openMembersList(t);
                  },
                ),
              ListTile(
                leading: Icon(Icons.palette_outlined,
                    color: sheetTextIconColor),
                title: Text(
                  'Change theme',
                  style: TextStyle(
                    color: sheetTextIconColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openThemePicker();
                },
              ),
              if (t.isActive)
                ListTile(
                  leading: Icon(Icons.archive_outlined,
                      color: sheetTextIconColor),
                  title: Text(
                    'Archive chat',
                    style: TextStyle(
                      color: sheetTextIconColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _archiveCurrentThread();
                  },
                ),
              if (t.isArchived)
                ListTile(
                  leading: Icon(Icons.unarchive_outlined,
                      color: sheetTextIconColor),
                  title: Text(
                    'Unarchive chat',
                    style: TextStyle(
                      color: sheetTextIconColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _unarchiveCurrentThread();
                  },
                ),
              if (!t.isGroup) ...[
                ListTile(
                  leading: Icon(
                    (_otherUserProfile?.isMuted == true)
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    color: const Color(0xFFDC2626),
                  ),
                  title: Text(
                    (_otherUserProfile?.isMuted == true)
                        ? 'Unmute @${t.otherUser.username}'
                        : 'Mute @${t.otherUser.username}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _toggleMuteUserFromChat(t.otherUser);
                  },
                ),
                ListTile(
                  leading: Icon(
                    (_otherUserProfile?.isBlocked == true)
                        ? Icons.lock_open_rounded
                        : Icons.block,
                    color: const Color(0xFFDC2626),
                  ),
                  title: Text(
                    (_otherUserProfile?.isBlocked == true)
                        ? 'Unblock @${t.otherUser.username}'
                        : 'Block @${t.otherUser.username}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _toggleBlockUserFromChat(t.otherUser);
                  },
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleBlockUserFromChat(User user) async {
    final username = user.username ?? '';
    final displayName = user.displayName;
    if (username.isEmpty) return;

    final isBlocked = _otherUserProfile?.isBlocked ?? false;
    final titleText = isBlocked ? 'Unblock $displayName?' : 'Block $displayName?';
    final contentText = isBlocked
        ? 'You will be able to message each other and see each other\'s posts again.'
        : 'They won\'t be able to message you, see your posts, or find your profile. You will not see their content either.';
    final actionText = isBlocked ? 'Unblock' : 'Block';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titleText),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: isBlocked ? null : const Color(0xFFDC2626),
              ),
              child: Text(actionText),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final ok = isBlocked
        ? await _feedService.unblockUser(username)
        : await _feedService.blockUser(username);

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not $actionText this user. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${isBlocked ? "Unblocked" : "Blocked"} $displayName.')),
    );

    if (!isBlocked) {
      if (widget.onBack != null) {
        widget.onBack!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      _loadOtherUserProfile(_thread!);
    }
  }

  Future<void> _toggleMuteUserFromChat(User user) async {
    final username = user.username ?? '';
    final displayName = user.displayName;
    if (username.isEmpty) return;

    final isMuted = _otherUserProfile?.isMuted ?? false;
    final titleText = isMuted ? 'Unmute $displayName?' : 'Mute $displayName?';
    final contentText = isMuted
        ? 'You will start seeing their posts in your feed again.'
        : 'KatsKlub won\'t let them know you muted them. You will stop seeing their posts in your feed.';
    final actionText = isMuted ? 'Unmute' : 'Mute';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titleText),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: isMuted ? null : const Color(0xFFDC2626),
              ),
              child: Text(actionText),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final ok = isMuted
        ? await _feedService.unmuteUser(username)
        : await _feedService.muteUser(username);

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not $actionText this user. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${isMuted ? "Unmuted" : "Muted"} $displayName.')),
    );

    _loadOtherUserProfile(_thread!);
  }

  Future<void> _openCreateGroupSheet() async {
    final created = await Navigator.of(context).push<MessageThread>(
      MaterialPageRoute(builder: (_) => const _CreateGroupScreen()),
    );
    if (!mounted) return;
    if (created != null) {
      await _loadThreads();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesScreen(initialThread: created),
        ),
      );
    }
  }

  Future<void> _openAddMembersSheet(MessageThread thread) async {
    final updated = await Navigator.of(context).push<MessageThread>(
      MaterialPageRoute(
        builder: (_) => _AddMembersScreen(thread: thread),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _thread = updated;
      final idx = _threads.indexWhere((t) => t.id == updated.id);
      if (idx >= 0) {
        _threads[idx] = updated;
      }
    });
  }

  void _openMembersList(MessageThread thread) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Members (${thread.members.length})',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: thread.members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = thread.members[i];
                      final avatarUrl = m.avatarUrl?.trim() ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(ApiConfig.assetUrl(avatarUrl))
                              : null,
                          child: avatarUrl.isEmpty
                              ? Text(m.initials,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))
                              : null,
                        ),
                        title: Text(m.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: m.handle != null ? Text(m.handle!) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openThemePicker() {
    final t = _thread;
    if (t == null) return;
    final current = ConversationThemeStore.themeFor(t.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final dragHandleColor = isDark ? const Color(0xFF4E4F51) : const Color(0xFFE5E7EB);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: dragHandleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Conversation theme',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final preset in ConversationTheme.presets) ...[
                      Expanded(
                        child: _ThemePreviewCard(
                          theme: preset,
                          selected: preset.id == current.id,
                          onTap: () async {
                            await ConversationThemeStore.setTheme(
                              t.id,
                              preset.id,
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                        ),
                      ),
                      if (preset.id != ConversationTheme.presets.last.id)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _findLastOwnIndex() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].sentByMe) return i;
    }
    return -1;
  }

  Widget _composer() {
    final theme = _getTheme();

    final isKatswipeBot = _thread?.otherUser.username?.toLowerCase() == 'katswipe';
    if (isKatswipeBot) {
      return SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is an automated system account. Replies are disabled.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isDarkComposer = Theme.of(context).brightness == Brightness.dark;
    final hasText = _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingTarget != null)
              _EditingMessageBar(
                target: _editingTarget!,
                accent: theme.accent,
                onClose: _isSending ? null : _clearEditTarget,
              ),
            if (_replyTarget != null)
              _ReplyingToBar(
                target: _replyTarget!,
                accent: theme.accent,
                onClose: _isSending ? null : _clearReplyTarget,
              ),
            if (_replyingGhostPost != null)
              _GhostPostReplyBar(
                post: _replyingGhostPost!,
                accent: theme.accent,
                onClose: _isSending
                    ? null
                    : () {
                        setState(() {
                          _replyingGhostPost = null;
                        });
                      },
              ),
            if (_pendingAttachments.isNotEmpty)
              _AttachmentPreviewStrip(
                attachments: _pendingAttachments,
                onRemove: _isSending
                    ? null
                    : (index) {
                        setState(() => _pendingAttachments.removeAt(index));
                      },
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkComposer
                          ? const Color(0xFF242535)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDarkComposer
                            ? const Color(0xFF32344A)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ComposerActionButton(
                          icon: Icons.add_circle_outline_rounded,
                          tooltip: 'Add file',
                          color: isDarkComposer
                              ? const Color(0xFFFF7A45)
                              : const Color(0xFF475569),
                          onPressed: _isSending ? null : _pickFiles,
                        ),
                        if (!hasText) ...[
                          _ComposerActionButton(
                            icon: Icons.image_outlined,
                            tooltip: 'Photos',
                            color: isDarkComposer
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF64748B),
                            onPressed: _isSending ? null : _pickGalleryImages,
                          ),
                          _ComposerActionButton(
                            icon: Icons.camera_alt_outlined,
                            tooltip: 'Camera',
                            color: isDarkComposer
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF64748B),
                            onPressed: _isSending ? null : _pickCameraImage,
                          ),
                          _ComposerActionButton(
                            icon: _isRecording
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_rounded,
                            tooltip: _isRecording ? 'Stop' : 'Record',
                            color: _isRecording
                                ? const Color(0xFFDC2626)
                                : (isDarkComposer
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF64748B)),
                            onPressed: _isSending ? null : _toggleRecording,
                          ),
                        ],
                        if (_isRecording) ...[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, color: Color(0xFFEF4444), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: isDarkComposer ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      height: 18,
                                      child: Row(
                                        children: List.generate(
                                          _liveAmplitudes.isEmpty ? 16 : _liveAmplitudes.length,
                                          (idx) {
                                            final h = _liveAmplitudes.isEmpty
                                                ? 6.0
                                                : (_liveAmplitudes[idx] * 18.0);
                                            return Expanded(
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                                                height: h,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                onChanged: (val) {
                                  _onComposerChanged(val);
                                  setState(() {});
                                },
                                inputFormatters: [EmojiPresentationFormatter()],
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14.5,
                                  height: 1.3,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Write a message...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: isDarkComposer
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF94A3B8),
                                  ),
                                  isDense: true,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A45), Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A45).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withOpacity(0.6),
                      fixedSize: const Size(44, 44),
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    for (final file in result.files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      await _addPendingAttachment(
        path: path,
        name: file.name,
        size: file.size,
        mime: lookupMimeType(path) ?? 'application/octet-stream',
        type: 'file',
      );
    }
  }

  Future<void> _pickCameraImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (image == null) return;
    await _addXFileAttachment(image, type: 'image');
  }

  Future<void> _pickGalleryImages() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 92);
    for (final image in images) {
      await _addXFileAttachment(image, type: 'image');
    }
  }

  bool _isRecordingLocked = false;
  double _recordingDragDx = 0.0;
  double _recordingDragDy = 0.0;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final List<double> _liveAmplitudes = <double>[];
  StreamSubscription<Amplitude>? _amplitudeSub;

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingSeconds = 0;
    _liveAmplitudes.clear();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _isRecording) {
        setState(() => _recordingSeconds++);
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final recSecs = _recordingSeconds;
      _stopRecordingTimer();
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _recordingDragDx = 0.0;
        _recordingDragDy = 0.0;
      });
      if (path == null || path.isEmpty) return;
      final file = File(path);
      final size = await file.length();
      final finalDurationSecs = recSecs > 0 ? recSecs : 1;
      await _addPendingAttachment(
        path: path,
        name: 'Voice message (${finalDurationSecs}s).m4a',
        size: size,
        mime: 'audio/mp4',
        type: 'audio',
      );
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showComposerMessage('Microphone permission is required.');
      return;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/katsklub-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _isRecordingLocked = false;
      _recordingDragDx = 0.0;
      _recordingDragDy = 0.0;
    });
    _startRecordingTimer();

    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((amp) {
      if (mounted && _isRecording) {
        final normalized = ((amp.current + 60.0) / 60.0).clamp(0.15, 1.0);
        setState(() {
          if (_liveAmplitudes.length >= 22) {
            _liveAmplitudes.removeAt(0);
          }
          _liveAmplitudes.add(normalized);
        });
      }
    });
  }

  Future<void> _addXFileAttachment(
    XFile file, {
    required String type,
  }) async {
    final size = await file.length();
    await _addPendingAttachment(
      path: file.path,
      name: file.name,
      size: size,
      mime: file.mimeType ??
          lookupMimeType(file.path) ??
          'application/octet-stream',
      type: type,
    );
  }

  Future<void> _addPendingAttachment({
    required String path,
    required String name,
    required int size,
    required String mime,
    required String type,
  }) async {
    if (size > _maxAttachmentBytes) {
      _showComposerMessage('Attachment must be 20MB or smaller.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingAttachments.add(
        _PendingMessageAttachment(
          path: path,
          name: name,
          size: size,
          mime: mime,
          type: type,
        ),
      );
    });
  }

  void _showComposerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _send() async {
    final thread = _thread;
    String body = _controller.text.trim();
    if (_replyingGhostPost != null) {
      final postText = _replyingGhostPost!.text;
      final textPreview = postText.length > 60
          ? '${postText.substring(0, 60)}...'
          : postText;
      body = '👻 Replied to ghost post: "$textPreview"\n\n$body';
    }
    final attachments =
        List<_PendingMessageAttachment>.from(_pendingAttachments);
    if (thread == null || _isSending || (body.isEmpty && attachments.isEmpty)) {
      return;
    }

    if (_isRecording) {
      await _toggleRecording();
      attachments
        ..clear()
        ..addAll(_pendingAttachments);
      if (body.isEmpty && attachments.isEmpty) {
        return;
      }
    }

    _typingStopDebounce?.cancel();
    if (_iAmTyping) {
      _iAmTyping = false;
      _feedService.emitTyping(thread.id, false);
    }

    setState(() {
      _isSending = true;
    });

    final sentMessages = <DirectMessage>[];
    bool failed = false;
    final replyToId = _replyTarget?.id;

    if (attachments.isEmpty) {
      final message = await _feedService.sendDirectMessage(
        thread.id,
        body,
        replyToMessageId: replyToId,
      );
      if (message != null) {
        sentMessages.add(message);
      } else {
        failed = true;
      }
    } else {
      final attachmentItems = <Map<String, String>>[];
      for (final attachment in attachments) {
        attachmentItems.add(await attachment.toRequestMap());
      }
      final message = await _feedService.sendDirectMessage(
        thread.id,
        body,
        attachmentItems: attachmentItems,
        replyToMessageId: replyToId,
      );
      if (message != null) {
        sentMessages.add(message);
      } else {
        failed = true;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (!failed) {
        for (final message in sentMessages) {
          if (!_messages.any((m) => m.id == message.id)) {
            _messages = [..._messages, message];
          }
        }
        _controller.clear();
        _pendingAttachments.clear();
        _replyTarget = null;
        _replyingGhostPost = null;
      }
    });

    if (sentMessages.isNotEmpty) {
      _scrollToBottomSoon();
      MessageSoundService.playOutgoing();
    }
    if (failed) {
      _showComposerMessage('Unable to send attachment.');
    }
  }
}

class _MessagesThreadListSkeleton extends StatelessWidget {
  const _MessagesThreadListSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          indent: 68,
          color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
        ),
        itemBuilder: (_, __) => const _MessagesThreadSkeletonTile(),
      ),
    );
  }
}

class _MessagesThreadSkeletonTile extends StatelessWidget {
  const _MessagesThreadSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SkeletonBox(width: 42, height: 42, radius: 21),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 126, height: 14, radius: 7),
                  SizedBox(height: 8),
                  SkeletonBox(width: 180, height: 12, radius: 6),
                ],
              ),
            ),
            SizedBox(width: 8),
            SkeletonBox(width: 18, height: 18, radius: 9),
          ],
        ),
      ),
    );
  }
}

class _MessageThreadSkeleton extends StatelessWidget {
  const _MessageThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: const [
        _IncomingMessageSkeleton(),
        SizedBox(height: 10),
        _OutgoingMessageSkeleton(),
        SizedBox(height: 10),
        _IncomingMessageSkeleton(short: true),
        SizedBox(height: 10),
        _OutgoingMessageSkeleton(short: true),
      ],
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: color,
        fixedSize: const Size(32, 38),
        minimumSize: const Size(32, 38),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 23),
    );
  }
}

class _PendingMessageAttachment {
  const _PendingMessageAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.mime,
    required this.type,
  });

  final String path;
  final String name;
  final int size;
  final String mime;
  final String type;

  bool get isImage => type == 'image' || mime.startsWith('image/');
  bool get isAudio => type == 'audio' || mime.startsWith('audio/');

  Future<String> toDataUrl() async {
    final bytes = await File(path).readAsBytes();
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<Map<String, String>> toRequestMap() async {
    return <String, String>{
      'dataUrl': await toDataUrl(),
      'type': type,
      'name': name,
      'mime': mime,
    };
  }
}

class _AttachmentPreviewStrip extends StatelessWidget {
  const _AttachmentPreviewStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<_PendingMessageAttachment> attachments;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _PendingAttachmentTile(
            attachment: attachment,
            onRemove: onRemove == null ? null : () => onRemove!(index),
          );
        },
      ),
    );
  }
}

class _PendingAttachmentTile extends StatelessWidget {
  const _PendingAttachmentTile({
    required this.attachment,
    required this.onRemove,
  });

  final _PendingMessageAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final label = attachment.isAudio ? 'Voice message' : attachment.name;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 132,
          height: 66,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: attachment.isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(attachment.path),
                    width: 116,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _AttachmentIconLabel(
                      icon: Icons.image_outlined,
                      label: 'Photo',
                    ),
                  ),
                )
              : _AttachmentIconLabel(
                  icon: attachment.isAudio
                      ? Icons.mic_none_rounded
                      : Icons.insert_drive_file_outlined,
                  label: label,
                ),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: IconButton(
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              fixedSize: const Size(24, 24),
              minimumSize: const Size(24, 24),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.close_rounded, size: 15),
          ),
        ),
      ],
    );
  }
}

class _AttachmentIconLabel extends StatelessWidget {
  const _AttachmentIconLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF374151), size: 22),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _IncomingMessageSkeleton extends StatelessWidget {
  const _IncomingMessageSkeleton({
    this.short = false,
  });

  final bool short;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SkeletonPulse(
        child: Container(
          width: short ? 134 : 224,
          height: short ? 42 : 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _OutgoingMessageSkeleton extends StatelessWidget {
  const _OutgoingMessageSkeleton({
    this.short = false,
  });

  final bool short;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SkeletonPulse(
        child: Container(
          width: short ? 120 : 210,
          height: short ? 42 : 54,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

/// Intro panel shown above the composer when a 1:1 conversation is opened
/// but no messages have been exchanged yet.
///
/// Layout (top to bottom):
///   * Large circular avatar of the other user
///   * Display name + @username
///   * Follow-state chip (Following / Mutual / Not following)
///   * Lock hint reminding both sides that the conversation is encrypted
///   * Follow-state hint (request / spam if you don't follow them)
class _NewConversationIntro extends StatelessWidget {
  const _NewConversationIntro({
    required this.thread,
    required this.accent,
  });

  final MessageThread thread;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Groups already have a dedicated intro inside the thread skeleton, so
    // this widget is targeted at 1:1 conversations.
    if (thread.isGroup) {
      return const SizedBox.shrink();
    }

    final other = thread.otherUser;
    final avatarUrl = other.avatarUrl?.trim() ?? '';
    final displayName = other.displayName;
    final username = (other.username ?? '').trim();
    final youFollow = other.isFollowing;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big circular avatar.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE5E7EB),
              border: Border.all(
                color: accent.withValues(alpha: 0.18),
                width: 2,
              ),
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(ApiConfig.assetUrl(avatarUrl)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarUrl.isEmpty
                ? Text(
                    other.initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          // Display name.
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '@$username',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Follow-state chip directly under the avatar block.
          _FollowStateChip(isFollowing: youFollow, accent: accent),
          const SizedBox(height: 18),
          // Encryption lock hint.
          _EncryptionHint(accent: accent),
          const SizedBox(height: 12),
          // Follow-state hint about delivery: inbox vs. request/spam.
          _DeliveryHint(isFollowing: youFollow, displayName: displayName),
        ],
      ),
    );
  }
}

class _FollowStateChip extends StatelessWidget {
  const _FollowStateChip({
    required this.isFollowing,
    required this.accent,
  });

  final bool isFollowing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = isFollowing ? 'You follow each other' : 'You don’t follow';
    final icon = isFollowing
        ? Icons.check_circle_rounded
        : Icons.person_add_alt_1_rounded;
    final fg = isFollowing ? accent : const Color(0xFF6B7280);
    final bg = isFollowing
        ? accent.withValues(alpha: 0.10)
        : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EncryptionHint extends StatelessWidget {
  const _EncryptionHint({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, size: 14, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Messages and calls are encrypted. Only you two can read what’s inside.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryHint extends StatelessWidget {
  const _DeliveryHint({
    required this.isFollowing,
    required this.displayName,
  });

  final bool isFollowing;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final text = isFollowing
        ? 'You’re connected with $displayName, so your messages land straight in their inbox.'
        : 'You don’t follow $displayName yet. Your first message may land in their request or spam folder until they accept.';
    final iconData = isFollowing
        ? Icons.mark_email_read_rounded
        : Icons.report_gmailerrorred_rounded;
    final iconColor =
        isFollowing ? const Color(0xFF10B981) : const Color(0xFFB45309);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(iconData, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({required this.thread});

  final MessageThread? thread;

  @override
  Widget build(BuildContext context) {
    if (thread?.isGroup == true) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(
          Icons.group_rounded,
          color: Color(0xFF111827),
          size: 20,
        ),
      );
    }

    final user = thread?.otherUser;
    final avatarUrl = user?.avatarUrl?.trim() ?? '';

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl.isNotEmpty
          ? NetworkImage(ApiConfig.assetUrl(avatarUrl))
          : null,
      child: avatarUrl.isEmpty
          ? Text(
              user?.initials ?? 'K',
              style: const TextStyle(fontWeight: FontWeight.w800),
            )
          : null,
    );

    return PresenceAvatarDot(
      userId: user?.id,
      size: 11,
      child: avatar,
    );
  }
}

class _ConversationPresenceLabel extends StatelessWidget {
  const _ConversationPresenceLabel({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    PresenceService.ensureLoaded(userId);

    return ValueListenableBuilder<Map<String, PresenceState>>(
      valueListenable: PresenceService.presenceNotifier,
      builder: (context, map, _) {
        final label = presenceLabel(map[userId]);
        if (label == null) {
          return const SizedBox.shrink();
        }

        return Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.previous,
    this.next,
    this.isLastOwn = false,
    this.seenByOther = false,
    this.theme = ConversationTheme.classic,
  });

  final DirectMessage message;
  final DirectMessage? previous;
  final DirectMessage? next;
  final bool isLastOwn;
  final bool seenByOther;
  final ConversationTheme theme;

  static const Duration _chainGap = Duration(minutes: 2);
  static const Duration _timeLabelGap = Duration(minutes: 10);
  static const double _avatarSlot = 30; // 22 avatar + 8 spacing
  static const double _bubbleRadius = 18;
  static const double _bubbleTightRadius = 6;

  DateTime? get _createdAt {
    final raw = message.body.isEmpty && message.attachment == null
        ? null
        : message.createdAt;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(message.createdAt)?.toLocal();
  }

  DateTime? get _prevCreatedAt {
    final p = previous;
    if (p == null) return null;
    return DateTime.tryParse(p.createdAt)?.toLocal();
  }

  bool get _continuesPrev {
    final p = previous;
    if (p == null) return false;
    if (p.sender.id != message.sender.id) return false;
    final a = _prevCreatedAt;
    final b = _createdAt;
    if (a == null || b == null) return true;
    return b.difference(a).abs() <= _chainGap;
  }

  bool get _continuesToNext {
    final n = next;
    if (n == null) return false;
    if (n.sender.id != message.sender.id) return false;
    final a = _createdAt;
    final b = DateTime.tryParse(n.createdAt)?.toLocal();
    if (a == null || b == null) return true;
    return b.difference(a).abs() <= _chainGap;
  }

  bool get _showTimeLabelAbove {
    final p = previous;
    final a = _prevCreatedAt;
    final b = _createdAt;
    if (p == null) return b != null;
    if (a == null || b == null) return false;
    return b.difference(a).abs() >= _timeLabelGap;
  }

  String _formatBubbleTime(DateTime t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = ((h + 11) % 12) + 1;
    return '$hour12:$m $period';
  }

  String _formatTimeLabel(DateTime t) {
    final now = DateTime.now();
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = ((h + 11) % 12) + 1;
    final hm = '$hour12:$m $period';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return hm;
    }
    final diffDays = now.difference(t).inDays;
    if (diffDays < 7) {
      const days = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      return '${days[t.weekday - 1]} $hm';
    }
    return '${t.month}/${t.day}/${t.year} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final sentByMe = message.sentByMe;
    final continuesPrev = _continuesPrev;
    final continuesNext = _continuesToNext;
    final showAvatar = !sentByMe && !continuesNext;
    final topGap = continuesPrev ? 2.0 : 8.0;

    final topRadius = continuesPrev ? _bubbleTightRadius : _bubbleRadius;
    final bottomRadius = continuesNext ? _bubbleTightRadius : _bubbleRadius;

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(sentByMe ? _bubbleRadius : topRadius),
      topRight: Radius.circular(sentByMe ? topRadius : _bubbleRadius),
      bottomLeft: Radius.circular(sentByMe ? _bubbleRadius : bottomRadius),
      bottomRight: Radius.circular(sentByMe ? bottomRadius : _bubbleRadius),
    );

    final useGradient = sentByMe && theme.ownBubbleGradient != null;
    final attachments = message.attachments;
    final body = message.body.trim();
    final imageOnly =
        attachments.length == 1 && attachments.first.isImage && body.isEmpty;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: imageOnly
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: useGradient
            ? null
            : (sentByMe ? theme.ownBubble : theme.otherBubble),
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.ownBubbleGradient!,
              )
            : null,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _QuotedReplyChip(
                reply: message.replyTo!,
                sentByMe: sentByMe,
                theme: theme,
              ),
            ),
          if (attachments.isNotEmpty)
            _MessageAttachmentsView(
              attachments: attachments,
              sentByMe: sentByMe,
              theme: theme,
            ),
          if (attachments.isNotEmpty && body.isNotEmpty)
            const SizedBox(height: 7),
          if (body.isNotEmpty) ...[
            if (body.startsWith('📞'))
              _CallLogChip(
                body: body,
                sentByMe: sentByMe,
                theme: theme,
              )
            else
              LinkifiedText(
                text: body,
                style: TextStyle(
                  color: sentByMe ? theme.ownBubbleText : theme.otherBubbleText,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
          ],
          if (_createdAt != null) ...[
            const SizedBox(height: 3),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final checkColor = seenByOther ? Colors.white : Colors.white70;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatBubbleTime(_createdAt!)}${message.isEdited ? " (edited)" : ""}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: sentByMe
                            ? Colors.white70
                            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                      ),
                    ),
                    if (sentByMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        seenByOther ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: checkColor,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );

    Widget row;
    if (sentByMe) {
      row = Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            bubble,
            _MessageReactionBadges(
              message: message,
              sentByMe: true,
            ),
          ],
        ),
      );
    } else {
      row = Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: _avatarSlot,
            child: showAvatar
                ? _SmallUserAvatar(
                    avatarUrl: message.sender.avatarUrl,
                    initials: message.sender.initials,
                  )
                : const SizedBox.shrink(),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                _MessageReactionBadges(
                  message: message,
                  sentByMe: false,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final children = <Widget>[];
    if (_showTimeLabelAbove) {
      final t = _createdAt;
      if (t != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Center(
              child: Text(
                _formatTimeLabel(t),
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }
    }
    children.add(Padding(
      padding: EdgeInsets.only(top: topGap),
      child: row,
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _CallLogChip extends StatelessWidget {
  const _CallLogChip({
    required this.body,
    required this.sentByMe,
    required this.theme,
  });

  final String body;
  final bool sentByMe;
  final ConversationTheme theme;

  @override
  Widget build(BuildContext context) {
    final isMissed = body.toLowerCase().contains('missed');
    final icon = isMissed ? Icons.phone_missed_rounded : Icons.phone_in_talk_rounded;
    final color = isMissed ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              body,
              style: TextStyle(
                color: sentByMe ? theme.ownBubbleText : theme.otherBubbleText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    required this.text,
    required this.style,
    super.key,
  });

  final String text;
  final TextStyle style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
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

  static final RegExp _urlPattern = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var currentIndex = 0;
    final text = ensureEmojiPresentation(widget.text);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.addAll(
          splitTextByEmoji(text.substring(currentIndex, match.start), widget.style),
        );
      }

      final url = match.group(0) ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (url.isNotEmpty) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              final pathSegments = uri.pathSegments;
              if (pathSegments.length >= 2 && pathSegments[0] == 'profile') {
                final username = pathSegments[1];
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(username: username),
                  ),
                );
                return;
              }
              if (pathSegments.length >= 2 && pathSegments[0] == 'post') {
                final postId = pathSegments[1];
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(postId: postId),
                  ),
                );
                return;
              }
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WebViewScreen(url: url, title: 'Web Link'),
              ),
            );
          }
        };
      _recognizers.add(recognizer);

      spans.addAll(
        splitTextByEmoji(
          url,
          widget.style.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
        ).map((s) => s is TextSpan ? TextSpan(text: s.text, style: s.style, recognizer: recognizer) : s),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.addAll(
        splitTextByEmoji(text.substring(currentIndex), widget.style),
      );
    }

    if (spans.isEmpty) {
      spans.addAll(splitTextByEmoji(text, widget.style));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: _buildSpans(),
        style: widget.style,
      ),
    );
  }
}

class _MessageAttachmentsView extends StatelessWidget {
  const _MessageAttachmentsView({
    required this.attachments,
    required this.sentByMe,
    required this.theme,
  });

  final List<DirectMessageAttachment> attachments;
  final bool sentByMe;
  final ConversationTheme theme;

  @override
  Widget build(BuildContext context) {
    if (attachments.length == 1) {
      return _SingleMessageAttachmentView(
        attachment: attachments.first,
        imageAttachments: attachments.first.isImage
            ? <DirectMessageAttachment>[attachments.first]
            : const <DirectMessageAttachment>[],
        imageIndex: 0,
        sentByMe: sentByMe,
        theme: theme,
      );
    }

    final allImages = attachments.every((attachment) => attachment.isImage);
    if (allImages) {
      return _MessageImageGallery(attachments: attachments);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          _SingleMessageAttachmentView(
            attachment: attachments[i],
            imageAttachments: attachments.where((a) => a.isImage).toList(),
            imageIndex: attachments
                .where((a) => a.isImage)
                .toList()
                .indexOf(attachments[i]),
            sentByMe: sentByMe,
            theme: theme,
          ),
          if (i != attachments.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _SingleMessageAttachmentView extends StatelessWidget {
  const _SingleMessageAttachmentView({
    required this.attachment,
    required this.imageAttachments,
    required this.imageIndex,
    required this.sentByMe,
    required this.theme,
  });

  final DirectMessageAttachment attachment;
  final List<DirectMessageAttachment> imageAttachments;
  final int imageIndex;
  final bool sentByMe;
  final ConversationTheme theme;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth.clamp(120.0, 160.0).toDouble()
              : 160.0;
          return _MessageImageTile(
            attachment: attachment,
            width: width,
            height: width * 0.9,
            borderRadius: 14,
            onTap: () => _openMessagePhotoViewer(
              context,
              imageAttachments,
              imageIndex < 0 ? 0 : imageIndex,
            ),
          );
        },
      );
    }

    if (attachment.isAudio) {
      return _VoiceNotePlayer(
        attachment: attachment,
        sentByMe: sentByMe,
        theme: theme,
      );
    }

    final icon = attachment.isVideo
        ? Icons.play_arrow_rounded
        : Icons.insert_drive_file_outlined;
    final title = attachment.name.isEmpty
        ? 'Attachment'
        : attachment.name;

    return _MessageAttachmentRow(
      icon: icon,
      title: title,
      subtitle: _formatAttachmentSize(attachment.size),
      sentByMe: sentByMe,
      theme: theme,
    );
  }
}

class _MessageImageGallery extends StatelessWidget {
  const _MessageImageGallery({required this.attachments});

  final List<DirectMessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final visible = attachments.take(4).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(140.0, 200.0).toDouble()
            : 200.0;
        final gap = 3.0;
        final tile = (width - gap) / 2;
        final threeUp = attachments.length == 3;
        final height = attachments.length == 2 ? tile : (tile * 2) + gap;
        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                for (var i = 0; i < visible.length; i++)
                  Positioned(
                    left: threeUp
                        ? (i == 0 ? 0 : tile + gap)
                        : (i % 2) * (tile + gap),
                    top: threeUp
                        ? (i == 0 ? 0 : (i - 1) * (tile + gap))
                        : (i ~/ 2) * (tile + gap),
                    width: tile,
                    height: threeUp && i == 0 ? height : tile,
                    child: _MessageImageTile(
                      attachment: visible[i],
                      width: tile,
                      height: threeUp && i == 0 ? height : tile,
                      borderRadius: 0,
                      onTap: () => _openMessagePhotoViewer(
                        context,
                        attachments,
                        i,
                      ),
                    ),
                  ),
                if (attachments.length > 4)
                  Positioned(
                    left: tile + gap,
                    top: tile + gap,
                    width: tile,
                    height: tile,
                    child: InkWell(
                      onTap: () =>
                          _openMessagePhotoViewer(context, attachments, 3),
                      child: ColoredBox(
                        color: const Color(0x88000000),
                        child: Center(
                          child: Text(
                            '+${attachments.length - 4}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageImageTile extends StatelessWidget {
  const _MessageImageTile({
    required this.attachment,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.onTap,
  });

  final DirectMessageAttachment attachment;
  final double width;
  final double height;
  final double borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (width * dpr).toInt();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: ApiConfig.assetUrl(attachment.url),
            width: width,
            height: height,
            memCacheWidth: cacheW > 0 ? cacheW : null,
            fit: BoxFit.cover,
            placeholder: (context, url) => _ImageTileSkeleton(
              width: width,
              height: height,
              borderRadius: borderRadius,
            ),
            errorWidget: (_, __, ___) => Container(
              width: width,
              height: height,
              color: const Color(0xFFF3F4F6),
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageTileSkeleton extends StatefulWidget {
  const _ImageTileSkeleton({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_ImageTileSkeleton> createState() => _ImageTileSkeletonState();
}

class _ImageTileSkeletonState extends State<_ImageTileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2B3D) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF383A52) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final color = Color.lerp(baseColor, highlightColor, _animController.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              color: isDark ? const Color(0xFF4B4D68) : const Color(0xFFCBD5E1),
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

void _openMessagePhotoViewer(
  BuildContext context,
  List<DirectMessageAttachment> attachments,
  int initialIndex,
) {
  if (attachments.isEmpty) return;
  final startIndex = initialIndex.clamp(0, attachments.length - 1).toInt();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _MessagePhotoViewer(
        attachments: attachments,
        initialIndex: startIndex,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _MessagePhotoViewer extends StatefulWidget {
  const _MessagePhotoViewer({
    required this.attachments,
    required this.initialIndex,
  });

  final List<DirectMessageAttachment> attachments;
  final int initialIndex;

  @override
  State<_MessagePhotoViewer> createState() => _MessagePhotoViewerState();
}

class _MessagePhotoViewerState extends State<_MessagePhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.attachments.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final attachment = widget.attachments[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      ApiConfig.assetUrl(attachment.url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x66000000),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (widget.attachments.length > 1)
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66000000),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.attachments.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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

class _MessageAttachmentRow extends StatelessWidget {
  const _MessageAttachmentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sentByMe,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool sentByMe;
  final ConversationTheme theme;

  @override
  Widget build(BuildContext context) {
    final textColor = sentByMe ? theme.ownBubbleText : theme.otherBubbleText;
    final background =
        sentByMe ? const Color(0x22FFFFFF) : const Color(0xFFF3F4F6);
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAttachmentSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
}

class _SmallUserAvatar extends StatelessWidget {
  const _SmallUserAvatar({
    required this.avatarUrl,
    required this.initials,
  });

  final String? avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return UserAvatarWithFrame(
      avatarUrl: avatarUrl ?? '',
      initials: initials,
      radius: 11,
      isAdmin: false,
    );
  }
}

class _TypingRow extends StatefulWidget {
  const _TypingRow({required this.otherUser});

  final User otherUser;

  @override
  State<_TypingRow> createState() => _TypingRowState();
}

class _TypingRowState extends State<_TypingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 30,
          child: _SmallUserAvatar(
            avatarUrl: widget.otherUser.avatarUrl,
            initials: widget.otherUser.initials,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF242526)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = ((_ctrl.value + (i * 0.15)) % 1.0);
                  final opacity = (0.35 + 0.65 * (1 - (t - 0.5).abs() * 2))
                      .clamp(0.35, 1.0);
                  return Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    child: Opacity(
                      opacity: opacity.toDouble(),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9CA3AF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessagesThreadList extends StatelessWidget {
  const _MessagesThreadList({
    required this.threads,
    required this.onOpenThread,
    this.typingThreadIds = const <int>{},
  });

  final List<MessageThread> threads;
  final ValueChanged<MessageThread> onOpenThread;
  final Set<int> typingThreadIds;

  String _previewFor(DirectMessage? message) {
    if (message == null) return 'No messages yet';
    final body = message.body.trim();
    if (body.isNotEmpty) return ensureEmojiPresentation(body);
    final attachments = message.attachments;
    if (attachments.isEmpty) return 'No messages yet';
    if (attachments.length > 1 && attachments.every((a) => a.isImage)) {
      return '${attachments.length} photos';
    }
    final attachment = attachments.first;
    if (attachment.isImage) return 'Photo';
    if (attachment.isAudio) return 'Voice message';
    if (attachment.isVideo) return 'Video';
    return attachment.name.isEmpty ? 'Attachment' : attachment.name;
  }

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: threads.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          indent: 68,
          color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
        ),
        itemBuilder: (context, index) {
            final thread = threads[index];
            final isTyping = typingThreadIds.contains(thread.id);
            final timeLabel = _formatRelativeTime(thread.lastMessage?.createdAt);

            return InkWell(
              onTap: () => onOpenThread(thread),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _MessagesThreadAvatar(thread: thread),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          thread.isGroup == true
                              ? Text(
                                  thread.name.isNotEmpty
                                      ? thread.name
                                      : 'Group chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : SpecialNameText(
                                  username: thread.otherUser.username ?? '',
                                  displayName: thread.otherUser.displayName,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                          const SizedBox(height: 3),
                          if (isTyping)
                            const _ThreadTypingPreview()
                          else
                            Text(
                              _previewFor(thread.lastMessage),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: thread.unreadCount > 0
                                    ? (isDark ? Colors.white : const Color(0xFF111827))
                                    : const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: thread.unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: thread.unreadCount > 0
                                  ? const Color(0xFFFF7A45)
                                  : const Color(0xFF9CA3AF),
                              fontSize: 11.5,
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (thread.unreadCount > 0)
                          _UnreadBadge(count: thread.unreadCount)
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
  }
}

class _MessagesThreadAvatar extends StatelessWidget {
  const _MessagesThreadAvatar({required this.thread});

  final MessageThread thread;

  @override
  Widget build(BuildContext context) {
    if (thread.isGroup) {
      return const CircleAvatar(
        radius: 21,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(
          Icons.group_rounded,
          color: Color(0xFF111827),
          size: 22,
        ),
      );
    }

    final avatarUrl = thread.otherUser.avatarUrl?.trim() ?? '';

    final avatar = CircleAvatar(
      radius: 21,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: avatarUrl.isNotEmpty
          ? NetworkImage(ApiConfig.assetUrl(avatarUrl))
          : null,
      child: avatarUrl.isEmpty
          ? Text(
              thread.otherUser.initials,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );

    return PresenceAvatarDot(
      userId: thread.otherUser.id,
      child: avatar,
    );
  }
}

class _MessagesInfoState extends StatelessWidget {
  const _MessagesInfoState({
    required this.icon,
    required this.title,
    required this.description,
    required this.emptyText,
  });

  final IconData icon;
  final String title;
  final String description;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF3F4F6),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF111827),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: Center(
            child: Text(
              emptyText,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadTypingPreview extends StatefulWidget {
  const _ThreadTypingPreview();

  @override
  State<_ThreadTypingPreview> createState() => _ThreadTypingPreviewState();
}

class _ThreadTypingPreviewState extends State<_ThreadTypingPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2563EB);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'typing',
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_ctrl.value + (i * 0.15)) % 1.0);
                final opacity =
                    (0.3 + 0.7 * (1 - (t - 0.5).abs() * 2)).clamp(0.3, 1.0);
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 3 : 0),
                  child: Opacity(
                    opacity: opacity.toDouble(),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A45), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A45).withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ConversationTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTheme = theme.resolveForBrightness(Theme.of(context).brightness);
    final useGradient = displayTheme.ownBubbleGradient != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? displayTheme.accent
                : (isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: displayTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 46,
                      height: 12,
                      decoration: BoxDecoration(
                        color: displayTheme.otherBubble,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 60,
                      height: 14,
                      decoration: BoxDecoration(
                        color: useGradient ? null : displayTheme.ownBubble,
                        gradient: useGradient
                            ? LinearGradient(
                                colors: displayTheme.ownBubbleGradient!,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayTheme.label,
              style: TextStyle(
                color: selected
                    ? displayTheme.accent
                    : (isDark ? Colors.white : const Color(0xFF111827)),
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

class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({
    required this.child,
    required this.onSwipeReply,
  });

  final Widget child;
  final VoidCallback onSwipeReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _triggerDx = 56;
  static const double _maxDx = 90;

  double _dx = 0;
  bool _triggered = false;
  late AnimationController _resetCtrl;
  Animation<double>? _resetAnim;

  @override
  void initState() {
    super.initState();
    _resetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        if (_resetAnim != null) {
          setState(() => _dx = _resetAnim!.value);
        }
      });
  }

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx == 0) return;
    final next = (_dx + details.delta.dx).clamp(0.0, _maxDx);
    if (!_triggered && next >= _triggerDx) {
      _triggered = true;
      HapticFeedback.mediumImpact();
      widget.onSwipeReply();
    }
    setState(() => _dx = next);
  }

  void _onDragEnd(DragEndDetails details) {
    _resetAnim = Tween<double>(begin: _dx, end: 0).animate(
      CurvedAnimation(parent: _resetCtrl, curve: Curves.easeOut),
    );
    _resetCtrl.forward(from: 0);
    _triggered = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _triggerDx).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () {
        _resetAnim = Tween<double>(begin: _dx, end: 0).animate(
          CurvedAnimation(parent: _resetCtrl, curve: Curves.easeOut),
        );
        _resetCtrl.forward(from: 0);
        _triggered = false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: progress,
                  child: Padding(
                    padding: EdgeInsets.only(left: (_dx / 2).clamp(0.0, 32.0)),
                    child: const Icon(
                      Icons.reply_rounded,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ReplyingToBar extends StatelessWidget {
  const _ReplyingToBar({
    required this.target,
    required this.accent,
    this.onClose,
  });

  final DirectMessage target;
  final Color accent;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final senderFull = target.sender.fullName ?? '';
    final senderUsername = target.sender.username ?? '';
    final senderName = target.sentByMe
        ? 'yourself'
        : (senderFull.isNotEmpty ? senderFull : senderUsername);
    final preview = target.body.trim().isEmpty
        ? (target.attachments.isNotEmpty ? '[attachment]' : '')
        : target.body.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFF6B7280),
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _GhostPostReplyBar extends StatelessWidget {
  const _GhostPostReplyBar({
    required this.post,
    required this.accent,
    this.onClose,
  });

  final Post post;
  final Color accent;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final authorName = post.authorFullName.isNotEmpty 
        ? post.authorFullName 
        : post.authorUsername;
    final preview = post.text.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1625)
            : const Color(0xFFF9F7FC),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: Color(0xFFFF7A59), width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '👻 ',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      "Replying to $authorName's ghost post",
                      style: const TextStyle(
                        color: Color(0xFFFF7A59),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFF6B7280),
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _QuotedReplyChip extends StatelessWidget {
  const _QuotedReplyChip({
    required this.reply,
    required this.sentByMe,
    required this.theme,
  });

  final MessageReplyRef reply;
  final bool sentByMe;
  final ConversationTheme theme;

  @override
  Widget build(BuildContext context) {
    final onOwn = sentByMe;
    final bg =
        onOwn ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFF3F4F6);
    final nameColor =
        onOwn ? Colors.white.withValues(alpha: 0.88) : theme.accent;
    final previewColor =
        onOwn ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF4B5563);
    final accentBar =
        onOwn ? Colors.white.withValues(alpha: 0.7) : theme.accent;
    final senderLabel = reply.sentByMe
        ? 'You'
        : (reply.senderDisplayName.isNotEmpty
            ? reply.senderDisplayName
            : 'User');
    final previewText =
        reply.body.trim().isEmpty ? '🎙️ Voice message' : reply.body.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accentBar, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderLabel,
            style: TextStyle(
              color: nameColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            previewText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: previewColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupButton extends StatelessWidget {
  const _CreateGroupButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF111827),
                child: Icon(Icons.add_rounded, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create new group',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF111827)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupScreen extends StatefulWidget {
  const _CreateGroupScreen();

  @override
  State<_CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<_CreateGroupScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<User> _selected = <User>[];
  List<User> _results = const <User>[];
  bool _searching = false;
  bool _submitting = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <User>[];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final results = await _feedService.searchUsers(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _searching = false);
      }
    });
  }

  void _toggle(User user) {
    final username = user.username;
    if (username == null || username.isEmpty) return;
    setState(() {
      final i = _selected.indexWhere((u) => u.username == username);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(user);
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name')),
      );
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one member')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final usernames = _selected
          .map((u) => u.username ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
      final thread = await _feedService.createGroupThread(
        name: name,
        usernames: usernames,
      );
      if (!mounted) return;
      if (thread != null) {
        Navigator.of(context).pop(thread);
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create group.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final inputBg = isDark ? const Color(0xFF242526) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF7F7F7),
        elevation: 0,
        title: Text('New group',
            style: TextStyle(
                color: primaryTextColor, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827)),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting ? 'Creating…' : 'Create',
              style: TextStyle(
                color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selected.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final u = _selected[i];
                    return Chip(
                      label: Text('@${u.username ?? ''}'),
                      onDeleted: () => _toggle(u),
                    );
                  },
                ),
              ),
            if (_selected.isNotEmpty) const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Search users by name or @username',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A45)))
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Type to search for members',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
                          itemBuilder: (_, i) {
                            final u = _results[i];
                            final picked = _selected
                                .any((s) => s.username == u.username);
                            final avatarUrl = u.avatarUrl?.trim() ?? '';
                            return ListTile(
                              tileColor: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE5E7EB),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(
                                        ApiConfig.assetUrl(avatarUrl))
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(u.initials,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black))
                                    : null,
                              ),
                              title: Text(u.displayName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor)),
                              subtitle: u.handle != null
                                  ? Text(u.handle!,
                                      style: TextStyle(
                                          color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280)))
                                  : null,
                              trailing: Icon(
                                picked
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: picked
                                    ? const Color(0xFFFF7A45)
                                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                              ),
                              onTap: () => _toggle(u),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMembersScreen extends StatefulWidget {
  const _AddMembersScreen({required this.thread});

  final MessageThread thread;

  @override
  State<_AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<_AddMembersScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _searchController = TextEditingController();
  final List<User> _selected = <User>[];
  List<User> _results = const <User>[];
  bool _searching = false;
  bool _submitting = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isExistingMember(User u) {
    final username = u.username ?? '';
    if (username.isEmpty) return false;
    return widget.thread.members.any((m) => m.username == username);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <User>[];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final results = await _feedService.searchUsers(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _searching = false);
      }
    });
  }

  void _toggle(User user) {
    final username = user.username;
    if (username == null || username.isEmpty) return;
    if (_isExistingMember(user)) return;
    setState(() {
      final i = _selected.indexWhere((u) => u.username == username);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(user);
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _submitting = true);
    try {
      final usernames = _selected
          .map((u) => u.username ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
      final updated = await _feedService.addMembersToGroup(
        threadId: widget.thread.id,
        usernames: usernames,
      );
      if (!mounted) return;
      if (updated != null) {
        Navigator.of(context).pop(updated);
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add members.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final inputBg = isDark ? const Color(0xFF242526) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF7F7F7),
        elevation: 0,
        title: Text('Add members',
            style: TextStyle(
                color: primaryTextColor, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827)),
        actions: [
          TextButton(
            onPressed: _submitting || _selected.isEmpty ? null : _submit,
            child: Text(
              _submitting ? 'Adding…' : 'Add',
              style: TextStyle(
                color: _selected.isEmpty
                    ? const Color(0xFF9CA3AF)
                    : (isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827)),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selected.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final u = _selected[i];
                    return Chip(
                      label: Text('@${u.username ?? ''}'),
                      onDeleted: () => _toggle(u),
                    );
                  },
                ),
              ),
            if (_selected.isNotEmpty) const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Search users by name or @username',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A45)))
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Type to search for users',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
                          itemBuilder: (_, i) {
                            final u = _results[i];
                            final already = _isExistingMember(u);
                            final picked = _selected
                                .any((s) => s.username == u.username);
                            final avatarUrl = u.avatarUrl?.trim() ?? '';
                            return ListTile(
                              tileColor: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                              enabled: !already,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE5E7EB),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(
                                        ApiConfig.assetUrl(avatarUrl))
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(u.initials,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black))
                                    : null,
                              ),
                              title: Text(u.displayName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: already ? const Color(0xFF9CA3AF) : primaryTextColor)),
                              subtitle: Text(
                                already
                                    ? 'Already in group'
                                    : (u.handle ?? ''),
                                style: TextStyle(
                                    color: already
                                        ? const Color(0xFF9CA3AF)
                                        : (isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280))),
                              ),
                              trailing: Icon(
                                already
                                    ? Icons.check_rounded
                                    : (picked
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded),
                                color: already
                                    ? const Color(0xFF9CA3AF)
                                    : (picked
                                        ? const Color(0xFFFF7A45)
                                        : (isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280))),
                              ),
                              onTap: already ? null : () => _toggle(u),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesRequestList extends StatelessWidget {
  const _MessagesRequestList({
    required this.threads,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final List<MessageThread> threads;
  final ValueChanged<MessageThread> onOpen;
  final Future<void> Function(MessageThread) onAccept;
  final Future<void> Function(MessageThread) onDecline;

  String _previewFor(DirectMessage? message) {
    if (message == null) return 'Wants to start a conversation';
    final body = message.body.trim();
    if (body.isNotEmpty) return ensureEmojiPresentation(body);
    return 'Sent an attachment';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: threads.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          indent: 14,
          endIndent: 14,
          color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
        ),
        itemBuilder: (context, index) {
            final thread = threads[index];
            return InkWell(
              onTap: () => onOpen(thread),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _MessagesThreadAvatar(thread: thread),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              thread.isGroup == true
                                  ? Text(
                                      thread.name.isNotEmpty
                                          ? thread.name
                                          : 'Group chat',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : SpecialNameText(
                                      username: thread.otherUser.username ?? '',
                                      displayName: thread.otherUser.displayName,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                              const SizedBox(height: 2),
                              Text(
                                _previewFor(thread.lastMessage),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => onDecline(thread),
                            child: const Text('Decline',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => onAccept(thread),
                            child: const Text('Accept',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
  }
}

class SfDirectChatMessage extends ChatMessage {
  SfDirectChatMessage({
    required this.directMessage,
    required super.text,
    required super.time,
    required super.author,
    this.seenByOther = false,
    this.isLastOwn = false,
    this.prevMessage,
    this.nextMessage,
  });

  final DirectMessage directMessage;
  final bool seenByOther;
  final bool isLastOwn;
  final DirectMessage? prevMessage;
  final DirectMessage? nextMessage;
}

class _MessengerOverlayContent extends StatefulWidget {
  const _MessengerOverlayContent({
    required this.message,
    required this.bubbleOffset,
    required this.bubbleSize,
    required this.previous,
    required this.next,
    required this.isLastOwn,
    required this.seenByOther,
    required this.theme,
    required this.onDismiss,
    required this.onSelectReaction,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onTranslate,
    this.onEdit,
    required this.onUnsend,
  });

  final DirectMessage message;
  final Offset bubbleOffset;
  final Size bubbleSize;
  final DirectMessage? previous;
  final DirectMessage? next;
  final bool isLastOwn;
  final bool seenByOther;
  final ConversationTheme theme;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelectReaction;
  final VoidCallback onReply;
  final VoidCallback? onCopy;
  final VoidCallback onForward;
  final VoidCallback onTranslate;
  final VoidCallback? onEdit;
  final VoidCallback? onUnsend;

  @override
  State<_MessengerOverlayContent> createState() => _MessengerOverlayContentState();
}

class _MessengerOverlayContentState extends State<_MessengerOverlayContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.04).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismissWithAction(VoidCallback action) async {
    await _animController.reverse();
    widget.onDismiss();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF242526) : Colors.white;
    final onSurfaceColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF050505);

    final overlayBorder = Border.all(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
      width: 1,
    );

    final overlayShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
    ];

    final spaceAbove = widget.bubbleOffset.dy - padding.top;
    final spaceBelow = screenSize.height - (widget.bubbleOffset.dy + widget.bubbleSize.height) - padding.bottom;

    // Reactions Pill Dimensions
    const reactionBarHeight = 52.0;
    const reactionBarWidth = 280.0;

    // Action Sheet Dimensions
    const actionSheetWidth = 230.0;
    int itemCount = 3; // Reply, Forward, Translate
    if (widget.onCopy != null) itemCount++;
    if (widget.onUnsend != null) itemCount++;
    final actionSheetHeight = (itemCount * 46.0) + 16.0;

    // Positioning Logic
    bool placeReactionsAbove = spaceAbove >= (reactionBarHeight + 12.0);
    if (!placeReactionsAbove && spaceBelow < (actionSheetHeight + reactionBarHeight + 20.0)) {
      placeReactionsAbove = true;
    }

    // Reaction Bar Y
    double reactionBarY;
    if (placeReactionsAbove) {
      reactionBarY = widget.bubbleOffset.dy - reactionBarHeight - 10.0;
    } else {
      reactionBarY = widget.bubbleOffset.dy + widget.bubbleSize.height + 10.0;
    }
    reactionBarY = reactionBarY.clamp(padding.top + 8.0, screenSize.height - padding.bottom - reactionBarHeight - 8.0);

    // Action Sheet Y
    double actionSheetY;
    if (placeReactionsAbove) {
      if (spaceBelow >= (actionSheetHeight + 12.0)) {
        actionSheetY = widget.bubbleOffset.dy + widget.bubbleSize.height + 10.0;
      } else {
        actionSheetY = reactionBarY - actionSheetHeight - 8.0;
      }
    } else {
      actionSheetY = reactionBarY + reactionBarHeight + 8.0;
    }
    actionSheetY = actionSheetY.clamp(padding.top + 8.0, screenSize.height - padding.bottom - actionSheetHeight - 8.0);

    // X Alignment based on sentByMe
    double reactionBarX;
    double actionSheetX;

    if (widget.message.sentByMe) {
      reactionBarX = (widget.bubbleOffset.dx + widget.bubbleSize.width - reactionBarWidth).clamp(12.0, screenSize.width - reactionBarWidth - 12.0);
      actionSheetX = (widget.bubbleOffset.dx + widget.bubbleSize.width - actionSheetWidth).clamp(12.0, screenSize.width - actionSheetWidth - 12.0);
    } else {
      reactionBarX = widget.bubbleOffset.dx.clamp(12.0, screenSize.width - reactionBarWidth - 12.0);
      actionSheetX = widget.bubbleOffset.dx.clamp(12.0, screenSize.width - actionSheetWidth - 12.0);
    }

    final quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Semi-transparent backdrop overlay with Fade
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: () => _dismissWithAction(() {}),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: screenSize.width,
                height: screenSize.height,
                color: isDark ? const Color(0x99000000) : const Color(0x66000000),
              ),
            ),
          ),

          // 2. Scaled Original Message Bubble at its exact screen position
          Positioned(
            left: widget.bubbleOffset.dx,
            top: widget.bubbleOffset.dy,
            width: widget.bubbleSize.width,
            height: widget.bubbleSize.height,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: IgnorePointer(
                child: _MessageBubble(
                  message: widget.message,
                  previous: widget.previous,
                  next: widget.next,
                  isLastOwn: widget.isLastOwn,
                  seenByOther: widget.seenByOther,
                  theme: widget.theme,
                ),
              ),
            ),
          ),

          // 3. Floating Reaction Bar Pill
          Positioned(
            left: reactionBarX,
            top: reactionBarY,
            width: reactionBarWidth,
            height: reactionBarHeight,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value * (placeReactionsAbove ? -1 : 1)),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: overlayBorder,
                  boxShadow: overlayShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: quickEmojis.map((emoji) {
                    final isSelected = widget.message.myReaction == emoji;
                    return _EmojiReactionButton(
                      emoji: emoji,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _dismissWithAction(() {
                          widget.onSelectReaction(emoji);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // 4. Separate Floating Action Sheet Card
          Positioned(
            left: actionSheetX,
            top: actionSheetY,
            width: actionSheetWidth,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value * (placeReactionsAbove ? 1 : -1)),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: overlayBorder,
                  boxShadow: overlayShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _OverlayActionTile(
                        icon: Icons.reply_rounded,
                        title: 'Reply',
                        textColor: onSurfaceColor,
                        iconColor: onSurfaceColor,
                        onTap: () => _dismissWithAction(widget.onReply),
                      ),
                      if (widget.onCopy != null) ...[
                        _OverlayTileDivider(isDark: isDark),
                        _OverlayActionTile(
                          icon: Icons.copy_rounded,
                          title: 'Copy',
                          textColor: onSurfaceColor,
                          iconColor: onSurfaceColor,
                          onTap: () => _dismissWithAction(widget.onCopy!),
                        ),
                      ],
                      _OverlayTileDivider(isDark: isDark),
                      _OverlayActionTile(
                        icon: Icons.shortcut_rounded,
                        title: 'Forward',
                        textColor: onSurfaceColor,
                        iconColor: onSurfaceColor,
                        onTap: () => _dismissWithAction(widget.onForward),
                      ),
                      _OverlayTileDivider(isDark: isDark),
                      _OverlayActionTile(
                        icon: Icons.translate_rounded,
                        title: 'Translate',
                        textColor: onSurfaceColor,
                        iconColor: onSurfaceColor,
                        onTap: () => _dismissWithAction(widget.onTranslate),
                      ),
                      if (widget.onEdit != null) ...[
                        _OverlayTileDivider(isDark: isDark),
                        _OverlayActionTile(
                          icon: Icons.edit_outlined,
                          title: 'Edit',
                          textColor: onSurfaceColor,
                          iconColor: onSurfaceColor,
                          onTap: () => _dismissWithAction(widget.onEdit!),
                        ),
                      ],
                      if (widget.onUnsend != null) ...[
                        _OverlayTileDivider(isDark: isDark),
                        _OverlayActionTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'Unsend',
                          textColor: Colors.redAccent,
                          iconColor: Colors.redAccent,
                          onTap: () => _dismissWithAction(widget.onUnsend!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiReactionButton extends StatefulWidget {
  const _EmojiReactionButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_EmojiReactionButton> createState() => _EmojiReactionButtonState();
}

class _EmojiReactionButtonState extends State<_EmojiReactionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 1.35 : (widget.isSelected ? 1.2 : 1.0),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

class _OverlayActionTile extends StatelessWidget {
  const _OverlayActionTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayTileDivider extends StatelessWidget {
  const _OverlayTileDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
    );
  }
}

class _MessageReactionBadges extends StatelessWidget {
  const _MessageReactionBadges({
    required this.message,
    required this.sentByMe,
  });

  final DirectMessage message;
  final bool sentByMe;

  @override
  Widget build(BuildContext context) {
    final summary = message.reactionSummary;
    final myReaction = message.myReaction;

    if (summary.isEmpty && (myReaction == null || myReaction.isEmpty)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF242526) : Colors.white;
    final textColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF050505);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    List<ReactionSummary> items = List<ReactionSummary>.from(summary);
    if (items.isEmpty && myReaction != null && myReaction.isNotEmpty) {
      items.add(ReactionSummary(emoji: myReaction, count: 1));
    }

    // Sorting: 1. Highest count descending, 2. My reaction first, 3. Emoji string order
    items.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) return countCompare;
      final aMine = a.emoji == myReaction;
      final bMine = b.emoji == myReaction;
      if (aMine && !bMine) return -1;
      if (!aMine && bMine) return 1;
      return a.emoji.compareTo(b.emoji);
    });

    const maxVisible = 3;
    final showOverflow = items.length > maxVisible;
    final visibleItems = showOverflow ? items.take(maxVisible).toList() : items;
    final overflowCount = items.length - maxVisible;

    return Transform.translate(
      offset: const Offset(0, -9),
      child: Padding(
        padding: EdgeInsets.only(
          left: sentByMe ? 0 : 10,
          right: sentByMe ? 10 : 0,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Wrap(
            spacing: -4, // Overlap chips slightly horizontally by -4dp like Messenger
            runSpacing: 4,
            clipBehavior: Clip.none,
            alignment: sentByMe ? WrapAlignment.end : WrapAlignment.start,
            children: [
              ...visibleItems.map((s) {
                final isMyReactionEmoji = myReaction == s.emoji;
                return _MessengerReactionChip(
                  key: ValueKey('chip_${message.id}_${s.emoji}'),
                  emoji: s.emoji,
                  count: s.count,
                  isMyReaction: isMyReactionEmoji,
                  isDark: isDark,
                  chipBg: chipBg,
                  textColor: textColor,
                  borderColor: borderColor,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final screenState = context.findAncestorStateOfType<_MessagesScreenState>();
                    if (screenState != null) {
                      screenState._showReactionsListModal(message, initialEmoji: s.emoji);
                    }
                  },
                );
              }),
              if (showOverflow)
                _MessengerReactionChip(
                  key: ValueKey('chip_${message.id}_plus_$overflowCount'),
                  emoji: '+$overflowCount',
                  count: 0,
                  isMyReaction: false,
                  isDark: isDark,
                  chipBg: chipBg,
                  textColor: textColor,
                  borderColor: borderColor,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final screenState = context.findAncestorStateOfType<_MessagesScreenState>();
                    if (screenState != null) {
                      screenState._showReactionsListModal(message, initialEmoji: 'All');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessengerReactionChip extends StatefulWidget {
  const _MessengerReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.isMyReaction,
    required this.isDark,
    required this.chipBg,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isMyReaction;
  final bool isDark;
  final Color chipBg;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  State<_MessengerReactionChip> createState() => _MessengerReactionChipState();
}

class _MessengerReactionChipState extends State<_MessengerReactionChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final chipBgColor = widget.isMyReaction
        ? (widget.isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB))
        : widget.chipBg;
    final chipBorderColor = widget.isMyReaction
        ? (widget.isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2))
        : widget.borderColor;

    final targetScale = _isPressed
        ? 0.97
        : (widget.isMyReaction ? 1.05 : 1.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 27,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: chipBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: chipBorderColor,
              width: widget.isMyReaction ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.12),
                blurRadius: 4,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.emoji,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.1,
                ),
              ),
              if (widget.count > 0) ...[
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Text(
                    '${widget.count}',
                    key: ValueKey('${widget.emoji}_${widget.count}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.textColor,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionsListModalContent extends StatefulWidget {
  const _ReactionsListModalContent({
    required this.message,
    required this.initialEmoji,
    required this.feedService,
  });

  final DirectMessage message;
  final String? initialEmoji;
  final FeedService feedService;

  @override
  State<_ReactionsListModalContent> createState() => _ReactionsListModalContentState();
}

class _ReactionsListModalContentState extends State<_ReactionsListModalContent> {
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialEmoji ?? 'All';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF050505);

    final summary = widget.message.reactionSummary;
    final tabs = ['All', ...summary.map((s) => s.emoji)];

    return FutureBuilder<Map<String, dynamic>>(
      future: widget.feedService.getMessageReactions(widget.message.id),
      builder: (context, snapshot) {
        final rawList = snapshot.hasData && snapshot.data!['reactions'] is List
            ? (snapshot.data!['reactions'] as List)
            : widget.message.reactions;

        final filteredList = _selectedTab == 'All'
            ? rawList
            : rawList.where((item) {
                final emoji = item is MessageReaction
                    ? item.emoji
                    : (item['emoji']?.toString() ?? '');
                return emoji == _selectedTab;
              }).toList();

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Reactions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: tabs.map((tab) {
                        final isSelected = tab == _selectedTab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tab),
                            selected: isSelected,
                            selectedColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                            backgroundColor: isDark ? const Color(0xFF18191A) : const Color(0xFFF0F2F5),
                            labelStyle: TextStyle(
                              color: isSelected ? textColor : textColor.withValues(alpha: 0.7),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedTab = tab);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(height: 1),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator.adaptive(),
                  )
                else if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No reactions yet',
                      style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        final emoji = item is MessageReaction
                            ? item.emoji
                            : (item['emoji']?.toString() ?? '');
                        final name = item is MessageReaction
                            ? 'User ${item.userId.substring(0, item.userId.length > 8 ? 8 : item.userId.length)}'
                            : (item['fullName']?.toString() ?? item['username']?.toString() ?? 'User');

                        return ListTile(
                          leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditingMessageBar extends StatelessWidget {
  const _EditingMessageBar({
    required this.target,
    required this.accent,
    required this.onClose,
  });

  final DirectMessage target;
  final Color accent;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing Message',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  target.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel edit',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFF6B7280),
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  const _VoiceNotePlayer({
    required this.attachment,
    required this.sentByMe,
    required this.theme,
  });

  final DirectMessageAttachment attachment;
  final bool sentByMe;
  final ConversationTheme theme;

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });

    _player.durationStream.listen((d) {
      if (mounted && d != null && d > Duration.zero) {
        setState(() => _duration = d);
      }
    });

    _player.positionStream.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });

    final regExp = RegExp(r'\((\d+)s\)');
    final match = regExp.firstMatch(widget.attachment.name);
    if (match != null) {
      final secs = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (secs > 0) {
        _duration = Duration(seconds: secs);
      }
    }

    if (widget.attachment.url.isNotEmpty) {
      try {
        final d = await _player.setUrl(widget.attachment.url);
        if (d != null && mounted) {
          setState(() => _duration = d);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      if (_player.duration == null) {
        await _player.setUrl(widget.attachment.url);
      }
      await _player.play();
    }
  }

  void _cycleSpeed() async {
    double nextSpeed = 1.0;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }
    setState(() => _playbackSpeed = nextSpeed);
    await _player.setSpeed(nextSpeed);
  }

  String _formatTime(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final onOwn = widget.sentByMe;
    final iconColor = onOwn ? Colors.white : widget.theme.accent;
    final textColor = onOwn ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF374151);
    final waveColor = onOwn ? Colors.white54 : Colors.grey[400]!;
    final activeWaveColor = onOwn ? Colors.white : widget.theme.accent;

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              size: 34,
              color: iconColor,
            ),
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (ctx) {
                    return GestureDetector(
                      onTapDown: (details) {
                        if (_duration.inMilliseconds > 0) {
                          final box = ctx.findRenderObject() as RenderBox?;
                          if (box != null) {
                            final fraction = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                            final seekTarget = Duration(milliseconds: (_duration.inMilliseconds * fraction).round());
                            _player.seek(seekTarget);
                          }
                        }
                      },
                      onHorizontalDragUpdate: (details) {
                        if (_duration.inMilliseconds > 0) {
                          final box = ctx.findRenderObject() as RenderBox?;
                          if (box != null) {
                            final fraction = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                            final seekTarget = Duration(milliseconds: (_duration.inMilliseconds * fraction).round());
                            _player.seek(seekTarget);
                          }
                        }
                      },
                      child: SizedBox(
                        height: 20,
                        child: Row(
                          children: List.generate(18, (index) {
                            final barProgress = index / 18.0;
                            final isActive = barProgress <= progress;
                            final heights = [10.0, 16.0, 8.0, 18.0, 12.0, 15.0, 7.0, 19.0, 11.0, 14.0, 9.0, 16.0, 8.0, 12.0, 15.0, 10.0, 14.0, 8.0];
                            final h = heights[index % heights.length];

                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                                height: h,
                                decoration: BoxDecoration(
                                  color: isActive ? activeWaveColor : waveColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying ? _formatTime(_position) : _formatTime(_duration),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: onOwn ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

