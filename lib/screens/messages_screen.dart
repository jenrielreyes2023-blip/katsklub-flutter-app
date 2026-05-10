import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/feed_service.dart';

enum _MessagesPageState { general, groups, requests, archived }

class _MessagesPageHeader extends StatelessWidget {
  const _MessagesPageHeader({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      height: 54,
      child: Row(
        children: [
          IconButton(
            padding: const EdgeInsets.only(left: 14),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF111827),
              size: 26,
            ),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Messages',
                style: TextStyle(
                  color: Color(0xFF111827),
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
    this.onBack,
    super.key,
  });

  final MessageThread? initialThread;
  final VoidCallback? onBack;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _controller = TextEditingController();
  late Future<MessageThreadPage?>? _threadFuture;
  late Future<List<MessageThread>> _threadsFuture;
  MessageThread? _thread;
  List<DirectMessage> _messages = [];
  bool _isSending = false;
  _MessagesPageState _state = _MessagesPageState.general;

  @override
  void initState() {
    super.initState();
    _thread = widget.initialThread;
    _threadFuture = widget.initialThread == null
        ? null
        : _feedService.loadMessageThread(widget.initialThread!.id);
    _threadsFuture = _feedService.loadMessageThreads();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadFuture = _threadFuture;
    if (threadFuture == null) {
      return _messagesHomePage(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _ThreadAvatar(thread: _thread),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _thread?.otherUser.displayName ?? 'Messages',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<MessageThreadPage?>(
        future: threadFuture,
        builder: (context, snapshot) {
          final page = snapshot.data;
          if (page != null && _messages.isEmpty) {
            _thread = page.thread;
            _messages = page.messages;
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              _messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Center(child: Text('No messages yet. Say hi.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _MessageBubble(message: _messages[index]),
                      ),
              ),
              _composer(),
            ],
          );
        },
      ),
    );
  }

  Widget _messagesHomePage(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            _MessagesPageHeader(onBack: widget.onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                children: [
                  _statePicker(),
                  const SizedBox(height: 14),
                  _body(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statePicker() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _stateButton('Chats', _MessagesPageState.general),
          _stateButton('Groups', _MessagesPageState.groups),
          _stateButton('Requests', _MessagesPageState.requests),
          _stateButton('Archived', _MessagesPageState.archived),
        ],
      ),
    );
  }

  Widget _stateButton(String label, _MessagesPageState state) {
    final selected = _state == state;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _state = state),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case _MessagesPageState.groups:
        return const _MessagesInfoState(
          icon: Icons.group_outlined,
          title: 'Groups',
          description:
              'Create or join groups to chat with multiple people at once. Share moments and stay connected.',
          emptyText: 'No groups yet',
        );
      case _MessagesPageState.requests:
        return const _MessagesInfoState(
          icon: Icons.info_outline_rounded,
          title: 'Requests',
          description:
              'Request from people to join to some groups or chats. You can accept or decline them at any time.',
          emptyText: 'No requests yet',
        );
      case _MessagesPageState.archived:
        return const _MessagesInfoState(
          icon: Icons.archive_outlined,
          title: 'Archived chats',
          description:
              'Here you can find all your archived chats. You can unarchive them at any time.',
          emptyText: 'No archived chats',
        );
      case _MessagesPageState.general:
        return FutureBuilder<List<MessageThread>>(
          future: _threadsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final threads = snapshot.data ?? [];
            if (threads.isEmpty) {
              return const SizedBox(
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
              );
            }

            return _MessagesThreadList(
              threads: threads,
              onOpenThread: (thread) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MessagesScreen(initialThread: thread),
                  ),
                );
              },
            );
          },
        );
    }
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSending ? null : _send,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final thread = _thread;
    final body = _controller.text.trim();
    if (thread == null || body.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final message = await _feedService.sendDirectMessage(thread.id, body);
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (message != null) {
        _messages = [..._messages, message];
        _controller.clear();
      }
    });
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({required this.thread});

  final MessageThread? thread;

  @override
  Widget build(BuildContext context) {
    final user = thread?.otherUser;
    final avatarUrl = user?.avatarUrl?.trim() ?? '';

    return CircleAvatar(
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
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final DirectMessage message;

  @override
  Widget build(BuildContext context) {
    final sentByMe = message.sentByMe;

    return Align(
      alignment: sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: sentByMe ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.body,
          style: TextStyle(
            color: sentByMe ? Colors.white : const Color(0xFF111827),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _MessagesThreadList extends StatelessWidget {
  const _MessagesThreadList({
    required this.threads,
    required this.onOpenThread,
  });

  final List<MessageThread> threads;
  final ValueChanged<MessageThread> onOpenThread;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: Color(0xFFE5E7EB),
          ),
          itemBuilder: (context, index) {
            final thread = threads[index];
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
                          Text(
                            thread.otherUser.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            thread.lastMessage?.body ?? 'No messages yet',
                            maxLines: 1,
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
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF111827),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MessagesThreadAvatar extends StatelessWidget {
  const _MessagesThreadAvatar({required this.thread});

  final MessageThread thread;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = thread.otherUser.avatarUrl?.trim() ?? '';

    return CircleAvatar(
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
