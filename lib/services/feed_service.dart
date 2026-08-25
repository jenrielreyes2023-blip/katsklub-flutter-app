import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../models/user_note.dart';
import 'auth_service.dart';
import 'message_sound_service.dart';
import 'presence_service.dart';

class HomeFeedData {
  const HomeFeedData({
    required this.posts,
    required this.stories,
    required this.unreadNotifications,
    this.postsOffset = 0,
    this.postsLimit = 0,
    this.postsHasMore = false,
  });

  final List<Post> posts;
  final List<Story> stories;
  final int unreadNotifications;
  final int postsOffset;
  final int postsLimit;
  final bool postsHasMore;
}

class SearchResults {
  const SearchResults({
    required this.people,
    required this.hashtags,
    required this.posts,
  });

  final List<User> people;
  final List<HashtagResult> hashtags;
  final List<Post> posts;
}

class HashtagResult {
  const HashtagResult({
    required this.name,
    required this.postCount,
  });

  final String name;
  final int postCount;

  factory HashtagResult.fromJson(Map<String, dynamic> json) {
    return HashtagResult(
      name: (json['name']?.toString().trim() ?? '')
          .replaceFirst(RegExp(r'^#'), ''),
      postCount: _readStaticInt(json['postCount'] ?? json['post_count']),
    );
  }
}

class HashtagFeedResult {
  const HashtagFeedResult({
    required this.hashtag,
    required this.posts,
  });

  final HashtagResult hashtag;
  final List<Post> posts;
}

class MusicSearchResult {
  const MusicSearchResult({
    required this.id,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.previewUrl,
    required this.source,
  });

  final String id;
  final String title;
  final String artist;
  final String artworkUrl;
  final String previewUrl;
  final String source;

  factory MusicSearchResult.fromJson(Map<String, dynamic> json) {
    return MusicSearchResult(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      artist: json['artist']?.toString().trim() ?? '',
      artworkUrl: json['artworkUrl']?.toString().trim() ?? '',
      previewUrl: json['previewUrl']?.toString().trim() ?? '',
      source: json['source']?.toString().trim() ?? '',
    );
  }
}

class FeedPageResult {
  const FeedPageResult({
    required this.posts,
    required this.offset,
    required this.limit,
    required this.hasMore,
    this.totalCount = 0,
  });

  final List<Post> posts;
  final int offset;
  final int limit;
  final bool hasMore;
  final int totalCount;
}

class CommentPageResult {
  const CommentPageResult({
    required this.comments,
    required this.totalCount,
    required this.hasMore,
    required this.nextBeforeId,
  });

  final List<PostComment> comments;
  final int totalCount;
  final bool hasMore;
  final int? nextBeforeId;
}

class CommentCreateResult {
  const CommentCreateResult({
    required this.comment,
    required this.commentCount,
    this.slideCommentCount,
  });

  final PostComment comment;
  final int commentCount;
  final int? slideCommentCount;
}

class MessageThread {
  const MessageThread({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastReadAt,
    this.otherLastReadAt,
    this.unreadCount = 0,
    this.isGroup = false,
    this.name = '',
    this.createdBy = '',
    this.members = const <User>[],
    this.state = 'active',
    this.wallpaperPath,
    this.wallpaperDim = 0.35,
    this.themeId,
  });

  final int id;
  final User otherUser;
  final DirectMessage? lastMessage;
  final String? lastReadAt;
  final String? otherLastReadAt;
  final int unreadCount;
  final bool isGroup;
  final String name;
  final String createdBy;
  final List<User> members;
  final String state;
  final String? wallpaperPath;
  final double wallpaperDim;
  final String? themeId;

  bool get isActive => state == 'active';
  bool get isRequested => state == 'requested';
  bool get isArchived => state == 'archived';

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    final otherUser = json['otherUser'];
    final lastMessage = json['lastMessage'];
    final rawMembers = json['members'];
    final members = rawMembers is List
        ? rawMembers
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList(growable: false)
        : const <User>[];

    return MessageThread(
      id: _readStaticInt(json['id']),
      otherUser: otherUser is Map<String, dynamic>
          ? User.fromJson(otherUser)
          : User.fromJson(const <String, dynamic>{}),
      lastMessage: lastMessage is Map<String, dynamic>
          ? DirectMessage.fromJson(lastMessage)
          : null,
      lastReadAt: json['lastReadAt']?.toString(),
      otherLastReadAt: json['otherLastReadAt']?.toString(),
      unreadCount: _readStaticInt(json['unreadCount']),
      isGroup: json['isGroup'] == true,
      name: json['name']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      members: members,
      state: json['state']?.toString() ?? 'active',
      wallpaperPath: json['wallpaperPath']?.toString(),
      wallpaperDim: json['wallpaperDim'] is num
          ? (json['wallpaperDim'] as num).toDouble()
          : (double.tryParse(json['wallpaperDim']?.toString() ?? '') ?? 0.35),
      themeId: json['themeId']?.toString(),
    );
  }

  MessageThread copyWith({
    int? id,
    User? otherUser,
    DirectMessage? lastMessage,
    String? lastReadAt,
    String? otherLastReadAt,
    int? unreadCount,
    bool? isGroup,
    String? name,
    String? createdBy,
    List<User>? members,
    String? state,
    String? wallpaperPath,
    double? wallpaperDim,
    String? themeId,
  }) {
    return MessageThread(
      id: id ?? this.id,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      otherLastReadAt: otherLastReadAt ?? this.otherLastReadAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      state: state ?? this.state,
      wallpaperPath: wallpaperPath ?? this.wallpaperPath,
      wallpaperDim: wallpaperDim ?? this.wallpaperDim,
      themeId: themeId ?? this.themeId,
    );
  }
}

class DirectMessageAttachment {
  const DirectMessageAttachment({
    required this.url,
    required this.type,
    required this.name,
    required this.mime,
    required this.size,
  });

  final String url;
  final String type;
  final String name;
  final String mime;
  final int size;

  bool get isImage => type == 'image' || mime.startsWith('image/');
  bool get isAudio {
    final t = type.toLowerCase().trim();
    final m = mime.toLowerCase().trim();
    final u = url.toLowerCase().trim();
    final n = name.toLowerCase().trim();
    return t == 'audio' ||
        t == 'voice' ||
        t == 'voice_note' ||
        t == 'voice-note' ||
        m.startsWith('audio/') ||
        u.endsWith('.m4a') ||
        u.endsWith('.mp3') ||
        u.endsWith('.aac') ||
        u.endsWith('.ogg') ||
        u.endsWith('.wav') ||
        n.endsWith('.m4a') ||
        n.endsWith('.mp3') ||
        n.endsWith('.aac') ||
        n.endsWith('.ogg') ||
        n.endsWith('.wav');
  }
  bool get isVideo => type == 'video' || mime.startsWith('video/');

  factory DirectMessageAttachment.fromJson(Map<String, dynamic> json) {
    return DirectMessageAttachment(
      url: _readStaticString(json['url'] ?? json['attachmentUrl']),
      type: _readStaticString(json['type'] ?? json['attachmentType']),
      name: _readStaticString(json['name'] ?? json['attachmentName']),
      mime: _readStaticString(json['mime'] ?? json['attachmentMime']),
      size: _readStaticInt(json['size'] ?? json['attachmentSize']),
    );
  }
}

class MessageReplyRef {
  const MessageReplyRef({
    required this.id,
    required this.body,
    required this.senderDisplayName,
    required this.sentByMe,
  });

  final int id;
  final String body;
  final String senderDisplayName;
  final bool sentByMe;

  static MessageReplyRef? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = _readStaticInt(raw['id']);
    if (id <= 0) return null;
    final sender = raw['sender'];
    String name = '';
    if (sender is Map) {
      name = (sender['fullName'] ?? sender['username'] ?? '').toString();
    }
    return MessageReplyRef(
      id: id,
      body: raw['body']?.toString() ?? '',
      senderDisplayName: name,
      sentByMe: raw['sentByMe'] == true,
    );
  }
}

class MessageReaction {
  const MessageReaction({
    required this.userId,
    required this.emoji,
  });

  final String userId;
  final String emoji;

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
    );
  }
}

class ReactionSummary {
  const ReactionSummary({
    required this.emoji,
    required this.count,
  });

  final String emoji;
  final int count;

  factory ReactionSummary.fromJson(Map<String, dynamic> json) {
    return ReactionSummary(
      emoji: json['emoji']?.toString() ?? '',
      count: _readStaticInt(json['count'] ?? json['cnt']),
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.createdAt,
    required this.sender,
    required this.sentByMe,
    this.attachment,
    this.attachments = const <DirectMessageAttachment>[],
    this.seenByOther = false,
    this.replyTo,
    this.myReaction,
    this.reactions = const <MessageReaction>[],
    this.reactionSummary = const <ReactionSummary>[],
    this.isEdited = false,
    this.editedAt,
  });

  final int id;
  final int conversationId;
  final String body;
  final String createdAt;
  final User sender;
  final bool sentByMe;
  final DirectMessageAttachment? attachment;
  final List<DirectMessageAttachment> attachments;
  final bool seenByOther;
  final MessageReplyRef? replyTo;
  final String? myReaction;
  final List<MessageReaction> reactions;
  final List<ReactionSummary> reactionSummary;
  final bool isEdited;
  final String? editedAt;

  DirectMessage copyWith({
    int? id,
    int? conversationId,
    String? body,
    String? createdAt,
    User? sender,
    bool? sentByMe,
    DirectMessageAttachment? attachment,
    List<DirectMessageAttachment>? attachments,
    bool? seenByOther,
    MessageReplyRef? replyTo,
    String? myReaction,
    List<MessageReaction>? reactions,
    List<ReactionSummary>? reactionSummary,
    bool? isEdited,
    String? editedAt,
  }) {
    return DirectMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      sentByMe: sentByMe ?? this.sentByMe,
      attachment: attachment ?? this.attachment,
      attachments: attachments ?? this.attachments,
      seenByOther: seenByOther ?? this.seenByOther,
      replyTo: replyTo ?? this.replyTo,
      myReaction: myReaction ?? this.myReaction,
      reactions: reactions ?? this.reactions,
      reactionSummary: reactionSummary ?? this.reactionSummary,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    final parsedAttachments = <DirectMessageAttachment>[];
    final attachmentItems = json['attachments'] ?? json['attachmentItems'];
    if (attachmentItems is List) {
      for (final item in attachmentItems) {
        if (item is Map<String, dynamic>) {
          final attachment = DirectMessageAttachment.fromJson(item);
          if (attachment.url.isNotEmpty) {
            parsedAttachments.add(attachment);
          }
        }
      }
    }

    final attachmentUrl = _readStaticString(
      json['attachmentUrl'] ?? json['attachment_url'],
    );
    if (parsedAttachments.isEmpty && attachmentUrl.isNotEmpty) {
      parsedAttachments.add(
        DirectMessageAttachment(
          url: attachmentUrl,
          type: _readStaticString(
            json['attachmentType'] ?? json['attachment_type'],
          ),
          name: _readStaticString(
            json['attachmentName'] ?? json['attachment_name'],
          ),
          mime: _readStaticString(
            json['attachmentMime'] ?? json['attachment_mime'],
          ),
          size: _readStaticInt(
            json['attachmentSize'] ?? json['attachment_size'],
          ),
        ),
      );
    }

    final parsedReactions = <MessageReaction>[];
    if (json['reactions'] is List) {
      for (final r in json['reactions']) {
        if (r is Map<String, dynamic>) {
          parsedReactions.add(MessageReaction.fromJson(r));
        }
      }
    }

    final parsedSummary = <ReactionSummary>[];
    final summaryRaw = json['reactionSummary'] ?? json['reaction_summary'];
    if (summaryRaw is List) {
      for (final s in summaryRaw) {
        if (s is Map<String, dynamic>) {
          parsedSummary.add(ReactionSummary.fromJson(s));
        }
      }
    }

    final myReaction = json['myReaction']?.toString() ?? json['my_reaction']?.toString() ?? json['reaction']?.toString();

    final myId = AuthService.currentUserIdSync;
    final senderId = (sender is Map<String, dynamic> ? sender['id']?.toString() : null) ??
        json['senderId']?.toString() ??
        json['sender_id']?.toString() ??
        '';

    final bool isSentByMe = (myId.isNotEmpty && senderId.isNotEmpty)
        ? (myId == senderId)
        : (json['sentByMe'] == true);

    return DirectMessage(
      id: _readStaticInt(json['id']),
      conversationId: _readStaticInt(json['conversationId']),
      body: json['body']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      sender: sender is Map<String, dynamic>
          ? User.fromJson(sender)
          : User.fromJson(const <String, dynamic>{}),
      sentByMe: isSentByMe,
      attachment: parsedAttachments.isEmpty ? null : parsedAttachments.first,
      attachments: List<DirectMessageAttachment>.unmodifiable(
        parsedAttachments,
      ),
      seenByOther: json['seenByOther'] == true,
      replyTo: MessageReplyRef.fromJson(json['replyTo']),
      myReaction: myReaction,
      reactions: List<MessageReaction>.unmodifiable(parsedReactions),
      reactionSummary: List<ReactionSummary>.unmodifiable(parsedSummary),
      isEdited: json['isEdited'] == true || json['is_edited'] == true,
      editedAt: json['editedAt']?.toString() ?? json['edited_at']?.toString(),
    );
  }
}

class MessageThreadPage {
  const MessageThreadPage({
    required this.thread,
    required this.messages,
  });

  final MessageThread thread;
  final List<DirectMessage> messages;
}

class CommentCountChange {
  const CommentCountChange({
    required this.postId,
    required this.commentCount,
  });

  final String postId;
  final int commentCount;
}

class ProfileStatsChange {
  const ProfileStatsChange({
    required this.username,
    this.followersCount,
    this.followingCount,
    this.isFollowing,
    this.user,
  });

  final String username;
  final int? followersCount;
  final int? followingCount;
  final bool? isFollowing;
  final User? user;
}

class DirectMessageEvent {
  const DirectMessageEvent({
    required this.threadId,
    required this.message,
    this.thread,
  });

  final int threadId;
  final DirectMessage message;
  final MessageThread? thread;
}

class DirectMessageReadEvent {
  const DirectMessageReadEvent({
    required this.threadId,
    required this.readerUserId,
    required this.readAt,
  });

  final int threadId;
  final String readerUserId;
  final String readAt;
}

class DirectTypingEvent {
  const DirectTypingEvent({
    required this.threadId,
    required this.userId,
    required this.typing,
  });

  final int threadId;
  final String userId;
  final bool typing;
}

class DirectMessageReactionEvent {
  const DirectMessageReactionEvent({
    required this.threadId,
    required this.messageId,
    required this.userId,
    this.myReaction,
    this.reactions = const <MessageReaction>[],
    this.reactionSummary = const <ReactionSummary>[],
  });

  final int threadId;
  final int messageId;
  final String userId;
  final String? myReaction;
  final List<MessageReaction> reactions;
  final List<ReactionSummary> reactionSummary;
}

class DirectMessageDeletedEvent {
  const DirectMessageDeletedEvent({
    required this.threadId,
    required this.messageId,
  });

  final int threadId;
  final int messageId;
}

class DirectMessageEditedEvent {
  const DirectMessageEditedEvent({
    required this.threadId,
    required this.messageId,
    required this.body,
    required this.isEdited,
    this.editedAt,
  });

  final int threadId;
  final int messageId;
  final String body;
  final bool isEdited;
  final String? editedAt;
}

class FeedService {
  static const String _cachedDiscoverPostsKey = 'cached_discover_posts';
  static const String _cachedHomePostsKey = 'cached_home_posts';
  static const String _cachedStoriesKey = 'cached_stories';
  static final StreamController<String> _postDeletedController =
      StreamController<String>.broadcast();
  static final StreamController<String> _postHiddenController =
      StreamController<String>.broadcast();
  static final StreamController<Post> _postCreatedController =
      StreamController<Post>.broadcast();
  static final StreamController<Post> _postUpdatedController =
      StreamController<Post>.broadcast();
  static final StreamController<CommentCountChange>
      _commentCountChangedController =
      StreamController<CommentCountChange>.broadcast();
  static final StreamController<ProfileStatsChange>
      _profileStatsChangedController =
      StreamController<ProfileStatsChange>.broadcast();
  static final StreamController<void> _postcardThemesResetController =
      StreamController<void>.broadcast();
  static final StreamController<void> _storyCreatedController =
      StreamController<void>.broadcast();
  static final StreamController<DirectMessageEvent> _dmMessageController =
      StreamController<DirectMessageEvent>.broadcast();
  static final StreamController<MessageThread> _dmThreadUpdatedController =
      StreamController<MessageThread>.broadcast();
  static final StreamController<DirectTypingEvent> _dmTypingController =
      StreamController<DirectTypingEvent>.broadcast();
  static final StreamController<DirectMessageReadEvent> _dmReadController =
      StreamController<DirectMessageReadEvent>.broadcast();
  static final StreamController<DirectMessageReactionEvent> _dmReactionController =
      StreamController<DirectMessageReactionEvent>.broadcast();
  static final StreamController<DirectMessageDeletedEvent>
      _dmDeletedController =
      StreamController<DirectMessageDeletedEvent>.broadcast();
  static final StreamController<DirectMessageEditedEvent>
      _dmEditedController =
      StreamController<DirectMessageEditedEvent>.broadcast();
  static final StreamController<void> _notesUpdatedController =
      StreamController<void>.broadcast();
  static final ValueNotifier<int> unreadNotificationsNotifier =
      ValueNotifier<int>(0);
  static final ValueNotifier<int> unreadMessagesNotifier =
      ValueNotifier<int>(0);
  static final Map<int, int> _unreadByThread = <int, int>{};

  static void _recomputeUnreadMessagesTotal() {
    int total = 0;
    for (final n in _unreadByThread.values) {
      if (n > 0) total += n;
    }
    if (unreadMessagesNotifier.value != total) {
      unreadMessagesNotifier.value = total;
    }
  }

  static final ValueNotifier<List<Map<String, dynamic>>> notificationsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>(const []);
  static io.Socket? _socket;
  static bool _realtimeInitialized = false;
  static String? _realtimeAuthToken;
  static Timer? _notificationsPollTimer;

  final http.Client _client;
  final AuthService _authService;

  FeedService({http.Client? client, AuthService? authService})
      : _client = client ?? http.Client(),
        _authService = authService ?? AuthService();

  static Stream<String> get postDeletedStream => _postDeletedController.stream;
  static Stream<String> get postHiddenStream => _postHiddenController.stream;
  static Stream<Post> get postCreatedStream => _postCreatedController.stream;
  static Stream<Post> get postUpdatedStream => _postUpdatedController.stream;
  static Stream<CommentCountChange> get commentCountChangedStream =>
      _commentCountChangedController.stream;
  static Stream<ProfileStatsChange> get profileStatsChangedStream =>
      _profileStatsChangedController.stream;
  static Stream<void> get postcardThemesResetStream =>
      _postcardThemesResetController.stream;
  static Stream<void> get storyCreatedStream => _storyCreatedController.stream;
  static Stream<DirectMessageEvent> get dmMessageStream =>
      _dmMessageController.stream;
  static Stream<MessageThread> get dmThreadUpdatedStream =>
      _dmThreadUpdatedController.stream;
  static Stream<DirectTypingEvent> get dmTypingStream =>
      _dmTypingController.stream;
  static Stream<DirectMessageReadEvent> get dmReadStream =>
      _dmReadController.stream;
  static Stream<DirectMessageReactionEvent> get dmReactionStream =>
      _dmReactionController.stream;
  static  Stream<DirectMessageDeletedEvent> get onDmMessageDeleted =>
      _dmDeletedController.stream;
  Stream<DirectMessageEditedEvent> get onDmMessageEdited =>
      _dmEditedController.stream;
  static Stream<void> get notesUpdatedStream => _notesUpdatedController.stream;

  static void notifyPostcardThemesReset() {
    _postcardThemesResetController.add(null);
  }

  static void notifyStoryCreated() {
    _storyCreatedController.add(null);
  }

  static void notifyPostDeleted(String postId) {
    final cleanPostId = postId.trim();
    if (cleanPostId.isNotEmpty) {
      _postDeletedController.add(cleanPostId);
    }
  }

  static void notifyPostHidden(String postId) {
    final cleanPostId = postId.trim();
    if (cleanPostId.isNotEmpty) {
      _postHiddenController.add(cleanPostId);
    }
  }

  static void notifyPostCreated(Post post) {
    if (post.id.trim().isNotEmpty) {
      _postCreatedController.add(post);
    }
  }

  static void notifyPostUpdated(Post post) {
    if (post.id.trim().isNotEmpty) {
      _postUpdatedController.add(post);
    }
  }

  static void notifyCommentCountChanged({
    required String postId,
    required int commentCount,
  }) {
    final cleanPostId = postId.trim();
    if (cleanPostId.isNotEmpty) {
      _commentCountChangedController.add(
        CommentCountChange(
          postId: cleanPostId,
          commentCount: commentCount,
        ),
      );
    }
  }

  static io.Socket? getSocket() => _socket;

  static void notifyProfileStatsChanged({
    required String username,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    User? user,
  }) {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return;
    }

    _profileStatsChangedController.add(
      ProfileStatsChange(
        username: cleanUsername,
        followersCount: followersCount,
        followingCount: followingCount,
        isFollowing: isFollowing,
        user: user,
      ),
    );
  }

  static Future<void> ensureRealtimeSync() async {
    final service = FeedService();
    final token = await service._authService.getToken();

    if (token == null || token.isEmpty) {
      await resetRealtimeSync();
      return;
    }

    if (_realtimeInitialized &&
        _socket != null &&
        _realtimeAuthToken == token) {
      return;
    }

    await resetRealtimeSync(clearNotifiers: false);

    _realtimeInitialized = true;
    _realtimeAuthToken = token;

    // Pre-load message ping sounds so the first message doesn't miss the cue.
    MessageSoundService.ensureInitialized();

    final socket = io.io(
      ApiConfig.apiBaseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': true,
        'extraHeaders': {
          'Authorization': 'Bearer $token',
        },
      },
    );

    socket.onConnect((_) async {
      await service.refreshUnreadNotificationsCount();
      if (notificationsNotifier.value.isNotEmpty) {
        await service.loadNotifications();
      }
      // Seed unread DM count
      try {
        await service.loadMessageThreads();
      } catch (_) {}
    });

    socket.on('notification:new', (payload) {
      if (payload is! Map) {
        return;
      }

      final notification = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      _upsertNotification(notification);
      if (notification['isRead'] != true) {
        unreadNotificationsNotifier.value =
            unreadNotificationsNotifier.value + 1;
        MessageSoundService.playNotification();
      }
    });

    socket.on('notification:unread-count', (payload) {
      if (payload is! Map) {
        return;
      }

      final count = _readStaticInt(payload['unreadCount']);
      unreadNotificationsNotifier.value = count < 0 ? 0 : count;
    });

    socket.on('dm:message', (payload) {
      if (payload is! Map) {
        return;
      }

      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final messageJson = map['message'];
      if (messageJson is! Map) {
        return;
      }

      final threadId = _readStaticInt(map['threadId']);
      final message = DirectMessage.fromJson(
        Map<String, dynamic>.from(
          messageJson.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );

      MessageThread? thread;
      final threadJson = map['thread'];
      if (threadJson is Map) {
        thread = MessageThread.fromJson(
          Map<String, dynamic>.from(
            threadJson.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
        _unreadByThread[thread.id] = thread.unreadCount;
        _recomputeUnreadMessagesTotal();
        _dmThreadUpdatedController.add(thread);
      } else if (!message.sentByMe) {
        final tid = threadId > 0 ? threadId : message.conversationId;
        if (tid > 0) {
          _unreadByThread[tid] = (_unreadByThread[tid] ?? 0) + 1;
          _recomputeUnreadMessagesTotal();
        }
      }

      _dmMessageController.add(
        DirectMessageEvent(
          threadId: threadId > 0 ? threadId : message.conversationId,
          message: message,
          thread: thread,
        ),
      );

      if (!message.sentByMe) {
        MessageSoundService.playIncoming();
      }
    });

    socket.on('dm:thread-updated', (payload) {
      if (payload is! Map) {
        return;
      }

      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final threadJson = map['thread'];
      if (threadJson is! Map) {
        return;
      }

      final thread = MessageThread.fromJson(
        Map<String, dynamic>.from(
          threadJson.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
      _unreadByThread[thread.id] = thread.unreadCount;
      _recomputeUnreadMessagesTotal();
      _dmThreadUpdatedController.add(thread);
    });

    socket.on('dm:message-reaction', (payload) {
      if (payload is! Map) return;
      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final threadId = _readStaticInt(map['threadId']);
      final messageId = _readStaticInt(map['messageId']);
      final userId = map['userId']?.toString() ?? '';
      final myReaction = map['myReaction']?.toString() ?? map['emoji']?.toString();

      final parsedReactions = <MessageReaction>[];
      if (map['reactions'] is List) {
        for (final r in map['reactions']) {
          if (r is Map<String, dynamic>) {
            parsedReactions.add(MessageReaction.fromJson(r));
          }
        }
      }

      final parsedSummary = <ReactionSummary>[];
      if (map['reactionSummary'] is List) {
        for (final s in map['reactionSummary']) {
          if (s is Map<String, dynamic>) {
            parsedSummary.add(ReactionSummary.fromJson(s));
          }
        }
      }

      print('[Reactions Socket Client] Received dm:message-reaction for messageId: $messageId, myReaction: "$myReaction", summaryCount: ${parsedSummary.length}');

      _dmReactionController.add(
        DirectMessageReactionEvent(
          threadId: threadId,
          messageId: messageId,
          userId: userId,
          myReaction: myReaction,
          reactions: parsedReactions,
          reactionSummary: parsedSummary,
        ),
      );
    });

    socket.on('dm:message-deleted', (payload) {
      if (payload is! Map) return;
      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final threadId = _readStaticInt(map['threadId']);
      final messageId = _readStaticInt(map['messageId']);

      _dmDeletedController.add(
        DirectMessageDeletedEvent(
          threadId: threadId,
          messageId: messageId,
        ),
      );
    });

    socket.on('dm:message-edited', (payload) {
      if (payload is! Map) return;
      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final threadId = _readStaticInt(map['conversationId'] ?? map['threadId']);
      final messageId = _readStaticInt(map['messageId']);
      final body = map['body']?.toString() ?? '';
      final isEdited = map['isEdited'] == true;
      final editedAt = map['editedAt']?.toString();

      _dmEditedController.add(
        DirectMessageEditedEvent(
          threadId: threadId,
          messageId: messageId,
          body: body,
          isEdited: isEdited,
          editedAt: editedAt,
        ),
      );
    });

    socket.on('dm:typing', (payload) {
      if (payload is! Map) {
        return;
      }

      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final threadId = _readStaticInt(map['threadId']);
      final user = map['user'];
      final userId = (user is Map ? user['id']?.toString() : null) ??
          map['userId']?.toString() ??
          '';
      if (threadId <= 0 || userId.isEmpty) {
        return;
      }

      _dmTypingController.add(
        DirectTypingEvent(
          threadId: threadId,
          userId: userId,
          typing: map['typing'] == true,
        ),
      );
    });

    socket.on('dm:read', (payload) {
      if (payload is! Map) return;
      final map = Map<String, dynamic>.from(
        payload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final threadId = _readStaticInt(map['threadId']);
      final readerUserId = map['readerUserId']?.toString() ??
          map['userId']?.toString() ??
          '';
      final readAt =
          map['readAt']?.toString() ?? DateTime.now().toIso8601String();
      if (threadId <= 0) return;

      _dmReadController.add(
        DirectMessageReadEvent(
          threadId: threadId,
          readerUserId: readerUserId,
          readAt: readAt,
        ),
      );
    });

    socket.on('note:updated', (_) {
      _notesUpdatedController.add(null);
    });

    socket.connect();
    _socket = socket;
    PresenceService.attach(socket);

    _notificationsPollTimer?.cancel();
    _notificationsPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        await service.refreshUnreadNotificationsCount();
      },
    );
  }

  static Future<void> resetRealtimeSync({bool clearNotifiers = true}) async {
    _notificationsPollTimer?.cancel();
    _notificationsPollTimer = null;

    final socket = _socket;
    _socket = null;
    _realtimeInitialized = false;
    _realtimeAuthToken = null;
    PresenceService.detach();

    if (socket != null) {
      socket.dispose();
      socket.disconnect();
    }

    if (clearNotifiers) {
      notificationsNotifier.value = const <Map<String, dynamic>>[];
      unreadNotificationsNotifier.value = 0;
      _unreadByThread.clear();
      unreadMessagesNotifier.value = 0;
      await clearUserFeedCache();
    }
  }

  static Future<void> clearUserFeedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedHomePostsKey);
      await prefs.remove(_cachedDiscoverPostsKey);
      await prefs.remove(_cachedStoriesKey);
    } catch (_) {}
  }

  Future<HomeFeedData> loadHomeFeed() async {
    return _loadHomeData();
  }

  Future<FeedPageResult> loadHomePosts({
    required int offset,
    required int limit,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const FeedPageResult(
        posts: [],
        offset: 0,
        limit: 0,
        hasMore: false,
      );
    }

    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1 ? 10 : limit;
    final data = await _getJson(
      ApiConfig.uri('/api/posts?offset=$cleanOffset&limit=$cleanLimit'),
      _authHeaders(token),
    );
    final posts = _readPosts(data);

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
    );
  }

  Future<FeedPageResult> loadFeed({
    int offset = 0,
    int limit = 10,
  }) async {
    return loadFeedPage(offset: offset, limit: limit);
  }

  Future<FeedPageResult> loadReels({
    int offset = 0,
    int limit = 20,
  }) async {
    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1 ? 20 : limit;
    final data = await _authenticatedGet(
      '/api/reels?offset=$cleanOffset&limit=$cleanLimit',
    );
    final posts = _readPosts(data);

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
      totalCount: _readInt(data['totalCount']),
    );
  }

  Future<FeedPageResult> loadFeedPage({
    required int offset,
    required int limit,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const FeedPageResult(
        posts: [],
        offset: 0,
        limit: 0,
        hasMore: false,
      );
    }

    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1 ? 10 : limit;
    final data = await _getJson(
      ApiConfig.uri(
          '${ApiConfig.feedPath}?offset=$cleanOffset&limit=$cleanLimit'),
      _authHeaders(token),
    );
    final posts = _readPosts(data);
    if (cleanOffset == 0 && posts.isNotEmpty) {
      await _saveCachedPosts(_cachedDiscoverPostsKey, posts);
    }

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
      totalCount: _readInt(data['totalCount']),
    );
  }

  Future<List<Post>> loadCachedFeedPosts() async {
    return _loadCachedPosts(_cachedDiscoverPostsKey);
  }

  Future<List<Post>> loadCachedHomePosts() async {
    return _loadCachedPosts(_cachedHomePostsKey);
  }

  Future<List<Story>> loadCachedStories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedStoriesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Story.fromJson)
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCachedStories(List<Story> stories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalized = stories.take(20).map((story) {
        return {
          'id': story.id,
          'authorFullName': story.authorFullName,
          'authorUsername': story.authorUsername,
          'authorAvatarUrl': story.authorAvatarUrl,
          'ownedByMe': story.ownedByMe,
          'text': story.text,
          'imageUrl': story.imageUrl,
          'videoUrl': story.videoUrl,
          'videoPosterUrl': story.videoPosterUrl,
          'createdAt': story.createdAt,
          'backgroundStartColor': story.backgroundStartColor,
          'backgroundEndColor': story.backgroundEndColor,
          'musicTitle': story.musicTitle,
          'musicArtist': story.musicArtist,
          'musicArtworkUrl': story.musicArtworkUrl,
          'musicPreviewUrl': story.musicPreviewUrl,
          'musicSource': story.musicSource,
          'isSensitive': story.isSensitive,
        };
      }).toList();
      await prefs.setString(_cachedStoriesKey, jsonEncode(normalized));
    } catch (_) {}
  }

  Future<Post?> loadPost(String postId) async {
    final data = await _authenticatedGet('/api/posts/$postId');
    final post = data['post'];
    if (post is Map<String, dynamic>) {
      return Post.fromJson(post);
    }

    return null;
  }

  Future<Post> toggleLike(Post post) async {
    final data = await _authenticatedPost('/api/posts/${post.id}/like');
    if (data['ok'] != true) {
      throw StateError('Failed to toggle like.');
    }
    final likeCount = _readInt(data['likeCount']);
    final liked = data['liked'] == true;
    final updatedPost = post.copyWith(
      likeCount: likeCount,
      likedByMe: liked,
    );
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<Post> toggleSlideLike({required Post post, required int slideId}) async {
    final data = await _authenticatedPost('/api/posts/${post.id}/slides/$slideId/like');
    if (data['ok'] != true) {
      throw StateError('Failed to toggle slide like.');
    }
    final likeCount = _readInt(data['likeCount']);
    final liked = data['liked'] == true;

    final updatedSlides = post.slides.map((slide) {
      if (slide.id == slideId) {
        return slide.copyWith(
          likeCount: likeCount,
          likedByMe: liked,
        );
      }
      return slide;
    }).toList();

    final updatedPost = post.copyWith(slides: updatedSlides);
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<List<Map<String, dynamic>>> loadSlideComments(String postId, int slideId) async {
    final data = await _authenticatedGet('/api/posts/$postId/slides/$slideId/comments');
    final comments = data['comments'];
    if (comments is! List) {
      return [];
    }
    return comments.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> postSlideComment(String postId, int slideId, String body) async {
    final data = await _authenticatedPost(
      '/api/posts/$postId/slides/$slideId/comments',
      body: {'body': body},
    );
    if (data['ok'] != true) {
      throw StateError('Failed to post slide comment.');
    }
    return data;
  }

  Future<Post> votePoll(Post post, int optionIndex) async {
    final data = await _authenticatedPost(
      '/api/posts/${post.id}/poll-vote',
      body: {'optionIndex': optionIndex},
    );
    if (data['ok'] != true) {
      throw StateError('Failed to vote in poll.');
    }

    final postJson = data['post'];
    if (postJson is! Map<String, dynamic>) {
      throw StateError('Updated poll was not returned.');
    }

    final updatedPost = Post.fromJson(postJson);
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<Post> toggleBookmark(Post post) async {
    final data = await _authenticatedPost('/api/posts/${post.id}/bookmark');
    if (data['ok'] != true) {
      throw StateError('Failed to toggle bookmark.');
    }
    final bookmarked = data['bookmarked'] == true;
    final updatedPost = post.copyWith(
      bookmarkedByMe: bookmarked,
    );
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<Post> pinPost(Post post) async {
    final data = await _authenticatedPost('/api/posts/${post.id}/pin');
    if (data['ok'] != true) {
      throw StateError(data['error'] ?? 'Failed to pin post.');
    }
    final updatedPost = post.copyWith(isPinned: true);
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<Post> unpinPost(Post post) async {
    final data = await _authenticatedPost('/api/posts/${post.id}/unpin');
    if (data['ok'] != true) {
      throw StateError(data['error'] ?? 'Failed to unpin post.');
    }
    final updatedPost = post.copyWith(isPinned: false);
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<List<Post>> getBookmarkedPosts() async {
    final data = await _authenticatedGet('/api/bookmarks');
    final postsList = data['posts'] as List?;
    if (postsList == null) return [];
    return postsList
        .map((p) => Post.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<Post> repostPost({
    required String originalPostId,
    required String text,
    required String visibility,
  }) async {
    final cleanOriginalPostId = originalPostId.trim();
    if (cleanOriginalPostId.isEmpty) {
      throw StateError('Original post id is required.');
    }

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('You need to sign in again.');
    }

    final response = await _client.post(
      ApiConfig.uri('/api/posts'),
      headers: _authHeaders(token, includeJsonContentType: true),
      body: jsonEncode({
        'text': text,
        'visibility': visibility,
        'repostOriginalPostId': cleanOriginalPostId,
      }),
    );

    final decodedBody = jsonDecode(response.body);
    final decoded =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _readErrorMessage(decoded) ?? 'Failed to repost post.',
      );
    }

    final postJson = decoded['post'];
    if (postJson is! Map<String, dynamic>) {
      throw StateError('Reposted post was not returned.');
    }

    final repostedPost = Post.fromJson(postJson);
    await prependCachedHomePost(repostedPost);
    notifyPostCreated(repostedPost);

    final updatedOriginalPost = repostedPost.originalPost;
    if (updatedOriginalPost != null &&
        updatedOriginalPost.id.trim().isNotEmpty) {
      await _replaceCachedPost(updatedOriginalPost);
      notifyPostUpdated(updatedOriginalPost);
    }

    return repostedPost;
  }

  Future<Post> updatePost({
    required String postId,
    required String text,
    required String visibility,
    bool removeMedia = false,
    List<String> withUserIds = const <String>[],
    String? location,
    String? feeling,
  }) async {
    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      throw StateError('Post id is required.');
    }

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('You need to sign in again.');
    }

    final response = await _client.put(
      ApiConfig.uri('/api/posts/$cleanPostId'),
      headers: _authHeaders(token, includeJsonContentType: true),
      body: jsonEncode({
        'text': text,
        'visibility': visibility,
        'removeMedia': removeMedia,
        'withUserIds': withUserIds,
        if (location != null) 'location': location,
        if (feeling != null) 'feeling': feeling,
      }),
    );

    final decodedBody = jsonDecode(response.body);
    final decoded =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _readErrorMessage(decoded) ?? 'Failed to update post.',
      );
    }

    final postJson = decoded['post'];
    if (postJson is! Map<String, dynamic>) {
      throw StateError('Updated post was not returned.');
    }

    final updatedPost = Post.fromJson(postJson);
    await _replaceCachedPost(updatedPost);
    notifyPostUpdated(updatedPost);
    return updatedPost;
  }

  Future<void> deletePost(String postId) async {
    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      throw StateError('Post id is required.');
    }

    final data = await _authenticatedDelete('/api/posts/$cleanPostId');
    if (data['ok'] != true) {
      throw StateError('Failed to delete post.');
    }

    await _removeCachedPostById(cleanPostId);
    notifyPostDeleted(cleanPostId);
  }

  Future<void> hidePost(String postId) async {
    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      throw StateError('Post id is required.');
    }

    final data = await _authenticatedPost('/api/posts/$cleanPostId/hide');
    if (data['ok'] != true) {
      throw StateError('Failed to hide post.');
    }

    await _removeCachedPostById(cleanPostId);
    notifyPostHidden(cleanPostId);
  }

  Future<CommentPageResult> loadComments(
    String postId, {
    int limit = 15,
    int? beforeId,
  }) async {
    final cleanPostId = postId.trim();
    if (cleanPostId.isEmpty) {
      return const CommentPageResult(
        comments: [],
        totalCount: 0,
        hasMore: false,
        nextBeforeId: null,
      );
    }

    final cleanLimit = limit < 1
        ? 15
        : limit > 50
            ? 50
            : limit;
    final query =
        StringBuffer('/api/posts/$cleanPostId/comments?limit=$cleanLimit');
    if (beforeId != null && beforeId > 0) {
      query.write('&beforeId=$beforeId');
    }

    final data = await _authenticatedGet(query.toString());
    final comments = data['comments'];
    final pagination = data['pagination'];

    return CommentPageResult(
      comments: comments is List
          ? comments
              .whereType<Map<String, dynamic>>()
              .map(PostComment.fromJson)
              .where((comment) => comment.id > 0)
              .toList()
          : [],
      totalCount: _readInt(data['totalCount']),
      hasMore:
          pagination is Map<String, dynamic> && pagination['hasMore'] == true,
      nextBeforeId: pagination is Map<String, dynamic>
          ? _readNullableInt(pagination['nextBeforeId'])
          : null,
    );
  }

  Future<CommentCreateResult> createComment(
    String postId,
    String body, {
    int? parentCommentId,
    String? replyToUserId,
  }) async {
    final cleanPostId = postId.trim();
    final cleanBody = body.trim();
    if (cleanPostId.isEmpty || cleanBody.isEmpty) {
      throw StateError('Comment body is required.');
    }

    final data = await _authenticatedPost(
      '/api/posts/$cleanPostId/comments',
      body: {
        'body': cleanBody,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
        if (replyToUserId != null && replyToUserId.trim().isNotEmpty)
          'replyToUserId': replyToUserId.trim(),
      },
    );
    final comment = data['comment'];
    if (data['ok'] != true || comment is! Map<String, dynamic>) {
      throw StateError('Failed to create comment.');
    }

    final commentCount = _readInt(data['commentCount']);

    await _updateCachedCommentCount(cleanPostId, commentCount);
    notifyCommentCountChanged(
      postId: cleanPostId,
      commentCount: commentCount,
    );

    return CommentCreateResult(
      comment: PostComment.fromJson(comment),
      commentCount: commentCount,
    );
  }

  Future<List<PostComment>> loadCommentReplies(int commentId) async {
    if (commentId <= 0) {
      return const <PostComment>[];
    }

    final data = await _authenticatedGet('/api/comments/$commentId/replies');
    final replies = data['replies'];
    if (replies is! List) {
      return const <PostComment>[];
    }

    return replies
        .whereType<Map<String, dynamic>>()
        .map(PostComment.fromJson)
        .where((comment) => comment.id > 0)
        .toList();
  }

  Future<User?> loadUserProfile(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedGet('/api/users/$cleanUsername');
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      return User.fromJson(user);
    }

    return null;
  }

  Future<List<User>> loadLeaderboard({String period = 'all-time'}) async {
    try {
      final data = await _authenticatedGet('/api/users/leaderboard?limit=50&period=$period');
      final list = data['leaderboard'];
      if (list is List) {
        return list
            .map((item) => User.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<List<User>> loadProfileVisitors() async {
    try {
      final data = await _authenticatedGet('/api/me/visitors');
      final list = data['visitors'];
      if (list is List) {
        return list
            .map((item) => User.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<User> updateCurrentUserPostcardTheme(String postcardTheme) async {
    final normalizedTheme = postcardTheme.trim().toLowerCase();
    final data = await _authenticatedPatch(
      '/api/me/postcard-theme',
      body: {'postcardTheme': normalizedTheme},
    );
    final user = data['user'];
    if (data['ok'] != true || user is! Map<String, dynamic>) {
      throw StateError(
        _readErrorMessage(data) ?? 'Failed to update postcard theme.',
      );
    }

    final updatedUser = User.fromJson(user);
    await _authService.saveCurrentUser(updatedUser);

    final username = updatedUser.username?.trim().toLowerCase() ?? '';
    if (username.isNotEmpty) {
      await _replaceCachedAuthorPostcardTheme(
        username,
        updatedUser.postcardTheme ?? '',
      );
      notifyProfileStatsChanged(username: username, user: updatedUser);
    }

    return updatedUser;
  }

  Future<User> updateCurrentUserBubbleTheme(String bubbleTheme) async {
    final normalizedTheme = bubbleTheme.trim().toLowerCase();
    final data = await _authenticatedPatch(
      '/api/me/bubble-theme',
      body: {'bubbleTheme': normalizedTheme},
    );
    final user = data['user'];
    if (data['ok'] != true || user is! Map<String, dynamic>) {
      throw StateError(
        _readErrorMessage(data) ?? 'Failed to update bubble theme.',
      );
    }

    final updatedUser = User.fromJson(user);
    await _authService.saveCurrentUser(updatedUser);

    final username = updatedUser.username?.trim().toLowerCase() ?? '';
    if (username.isNotEmpty) {
      notifyProfileStatsChanged(username: username, user: updatedUser);
    }

    return updatedUser;
  }

  Future<User?> followUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedPost('/api/users/$cleanUsername/follow');
    final user = data['user'];
    if (data['ok'] == true && user is Map<String, dynamic>) {
      final updatedUser = User.fromJson(user);
      await _applyFollowStateUpdate(updatedUser);
      return updatedUser;
    }

    return null;
  }

  Future<User?> unfollowUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedDelete('/api/users/$cleanUsername/follow');
    final user = data['user'];
    if (data['ok'] == true && user is Map<String, dynamic>) {
      final updatedUser = User.fromJson(user);
      await _applyFollowStateUpdate(updatedUser);
      return updatedUser;
    }

    return null;
  }

  /// Toggle the current user's private-account setting. Returns the updated
  /// User on success, or null on failure.
  Future<User?> setPrivateAccount(bool isPrivate) async {
    final data = await _authenticatedPatch(
      '/api/me/private',
      body: {'isPrivate': isPrivate},
    );
    final user = data['user'];
    if (data['ok'] == true && user is Map<String, dynamic>) {
      return User.fromJson(user);
    }
    return null;
  }

  /// Fetch pending follow requests addressed to the current user.
  Future<List<User>> fetchFollowRequests() async {
    final data = await _authenticatedGet('/api/me/follow-requests');
    final requests = data['requests'];
    if (data['ok'] == true && requests is List) {
      return requests
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList(growable: false);
    }
    return const <User>[];
  }

  /// Accept a pending follow request from [username].
  Future<bool> acceptFollowRequest(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }
    final data = await _authenticatedPost(
      '/api/me/follow-requests/$cleanUsername/accept',
    );
    return data['ok'] == true;
  }

  /// Reject a pending follow request from [username].
  Future<bool> rejectFollowRequest(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }
    final data = await _authenticatedPost(
      '/api/me/follow-requests/$cleanUsername/reject',
    );
    return data['ok'] == true;
  }

  Future<bool> blockUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }

    final data = await _authenticatedPost('/api/users/$cleanUsername/block');
    return data['ok'] == true;
  }

  Future<bool> unblockUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }

    final data = await _authenticatedDelete('/api/users/$cleanUsername/block');
    return data['ok'] == true;
  }

  Future<bool> muteUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }

    final data = await _authenticatedPost('/api/users/$cleanUsername/mute');
    return data['ok'] == true;
  }

  Future<bool> unmuteUser(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }

    final data = await _authenticatedDelete('/api/users/$cleanUsername/mute');
    return data['ok'] == true;
  }

  Future<bool> reportPost(int postId, String reason) async {
    final data = await _authenticatedPost(
      '/api/posts/$postId/report',
      body: {'reason': reason},
    );
    return data['ok'] == true;
  }

  Future<bool> reportStory(int storyId, String reason) async {
    final data = await _authenticatedPost(
      '/api/stories/$storyId/report',
      body: {'reason': reason},
    );
    return data['ok'] == true;
  }

  Future<bool> deleteStory(String storyId) async {
    final data = await _authenticatedDelete('/api/stories/$storyId');
    return data['ok'] == true;
  }

  Future<bool> recordStoryView(String storyId) async {
    final data = await _authenticatedPost('/api/stories/$storyId/view');
    return data['ok'] == true;
  }

  Future<Map<String, dynamic>> reactToStory(String storyId, {String reaction = 'heart'}) async {
    return await _authenticatedPost(
      '/api/stories/$storyId/react',
      body: {'reaction': reaction},
    );
  }

  Future<bool> replyToStory(String storyId, String text) async {
    final data = await _authenticatedPost(
      '/api/stories/$storyId/reply',
      body: {'text': text},
    );
    return data['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
    final data = await _authenticatedGet('/api/stories/$storyId/viewers');
    if (data['ok'] == true && data['viewers'] is List) {
      return List<Map<String, dynamic>>.from(data['viewers']);
    }
    return [];
  }

  Future<bool> reportUser(String username, String reason) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return false;
    }
    final data = await _authenticatedPost(
      '/api/users/$cleanUsername/report',
      body: {'reason': reason},
    );
    return data['ok'] == true;
  }

  Future<bool> reportComment(int commentId, String reason) async {
    final data = await _authenticatedPost(
      '/api/comments/$commentId/report',
      body: {'reason': reason},
    );
    return data['ok'] == true;
  }

  Future<PostComment> toggleCommentLike(PostComment comment) async {
    try {
      final data = await _authenticatedPost('/api/comments/${comment.id}/like');
      if (data['ok'] == true) {
        final likeCount = _readInt(data['likeCount'] ?? data['like_count']);
        final liked = data['liked'] == true || data['liked_by_me'] == true;
        return comment.copyWith(
          likeCount: likeCount,
          likedByMe: liked,
        );
      }
    } catch (_) {}

    final newLiked = !comment.likedByMe;
    final newCount = comment.likeCount + (newLiked ? 1 : -1);
    return comment.copyWith(
      likeCount: newCount < 0 ? 0 : newCount,
      likedByMe: newLiked,
    );
  }

  Future<void> _applyFollowStateUpdate(User targetUser) async {
    final targetUsername = targetUser.username?.trim().toLowerCase() ?? '';
    if (targetUsername.isEmpty) {
      return;
    }

    notifyProfileStatsChanged(
      username: targetUsername,
      followersCount:
          targetUser.followersCount < 0 ? 0 : targetUser.followersCount,
      isFollowing: targetUser.isFollowing,
      user: targetUser,
    );

    final currentUser = await _authService.getSavedUser();
    final currentUsername = currentUser?.username?.trim().toLowerCase() ?? '';
    if (currentUser == null ||
        currentUsername.isEmpty ||
        currentUsername == targetUsername) {
      return;
    }

    final delta = targetUser.isFollowing ? 1 : -1;
    final nextFollowingCount =
        (currentUser.followingCount + delta).clamp(0, 1 << 31);
    final updatedCurrentUser = currentUser.copyWith(
      followingCount: nextFollowingCount,
    );
    await _authService.saveCurrentUser(updatedCurrentUser);
    notifyProfileStatsChanged(
      username: currentUsername,
      followingCount: nextFollowingCount,
      user: updatedCurrentUser,
    );
  }

  Future<MessageThread?> startMessageThread(String username) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return null;
    }

    final data = await _authenticatedPost(
      '/api/messages/start',
      body: {'username': cleanUsername},
    );
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }

    return null;
  }

  Future<MessageThread?> createGroupThread({
    required String name,
    required List<String> usernames,
  }) async {
    final cleanName = name.trim();
    final cleanUsernames = usernames
        .map((u) => u.trim().replaceFirst(RegExp(r'^@'), ''))
        .where((u) => u.isNotEmpty)
        .toList();
    if (cleanName.isEmpty || cleanUsernames.isEmpty) {
      return null;
    }

    final data = await _authenticatedPost(
      '/api/messages/groups',
      body: {'name': cleanName, 'usernames': cleanUsernames},
    );
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<MessageThread?> addMembersToGroup({
    required int threadId,
    required List<String> usernames,
  }) async {
    if (threadId <= 0) return null;
    final cleanUsernames = usernames
        .map((u) => u.trim().replaceFirst(RegExp(r'^@'), ''))
        .where((u) => u.isNotEmpty)
        .toList();
    if (cleanUsernames.isEmpty) return null;

    final data = await _authenticatedPost(
      '/api/messages/threads/$threadId/members',
      body: {'usernames': cleanUsernames},
    );
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<bool> removeGroupMember({
    required int threadId,
    required String userId,
  }) async {
    if (threadId <= 0 || userId.isEmpty) return false;
    final data = await _authenticatedDelete(
      '/api/messages/threads/$threadId/members/$userId',
    );
    return data['ok'] == true;
  }

  Future<MessageThread?> acceptMessageThread(int threadId) async {
    if (threadId <= 0) return null;
    final data = await _authenticatedPost('/api/messages/threads/$threadId/accept');
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<bool> declineMessageThread(int threadId) async {
    if (threadId <= 0) return false;
    final data = await _authenticatedPost('/api/messages/threads/$threadId/decline');
    return data['ok'] == true;
  }

  Future<Map<String, dynamic>> getMessageReactions(int messageId) async {
    if (messageId <= 0) return const {'ok': false, 'reactions': []};
    try {
      final res = await _authenticatedGet('/api/messages/$messageId/reactions');
      return res;
    } catch (_) {
      return const {'ok': false, 'reactions': []};
    }
  }

  Future<bool> editDirectMessage(int messageId, String newBody) async {
    if (messageId <= 0 || newBody.trim().isEmpty) return false;
    try {
      final res = await _authenticatedPut('/api/messages/$messageId', body: {'body': newBody.trim()});
      return res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<MessageThread?> archiveMessageThread(int threadId) async {
    if (threadId <= 0) return null;
    final data = await _authenticatedPost('/api/messages/threads/$threadId/archive');
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<MessageThread?> unarchiveMessageThread(int threadId) async {
    if (threadId <= 0) return null;
    final data = await _authenticatedPost('/api/messages/threads/$threadId/unarchive');
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<MessageThread?> updateThreadWallpaper(
    int threadId, {
    String? wallpaperPath,
    double wallpaperDim = 0.35,
    String? dataUrl,
    String? mime,
  }) async {
    if (threadId <= 0) return null;
    final payload = <String, dynamic>{
      'wallpaperPath': wallpaperPath ?? 'none',
      'wallpaperDim': wallpaperDim,
    };
    if (dataUrl != null && dataUrl.isNotEmpty) {
      payload['dataUrl'] = dataUrl;
      payload['mime'] = mime ?? 'image/jpeg';
    }
    final data = await _authenticatedPut(
      '/api/messages/threads/$threadId/wallpaper',
      body: payload,
    );
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<MessageThread?> updateThreadTheme(int threadId, String themeId) async {
    if (threadId <= 0) return null;
    final data = await _authenticatedPut(
      '/api/messages/threads/$threadId/theme',
      body: {'themeId': themeId},
    );
    final thread = data['thread'];
    if (data['ok'] == true && thread is Map<String, dynamic>) {
      return MessageThread.fromJson(thread);
    }
    return null;
  }

  Future<List<MessageThread>> loadMessageThreads() async {
    final data = await _authenticatedGet('/api/messages/threads');
    final threads = data['threads'];
    if (threads is! List) {
      return [];
    }

    final parsed = threads
        .whereType<Map<String, dynamic>>()
        .map(MessageThread.fromJson)
        .where((thread) => thread.id > 0)
        .toList();

    _unreadByThread
      ..clear()
      ..addEntries(parsed.map((t) => MapEntry(t.id, t.unreadCount)));
    _recomputeUnreadMessagesTotal();

    return parsed;
  }

  Future<MessageThreadPage?> loadMessageThread(int threadId, {int? beforeId, int limit = 30}) async {
    if (threadId <= 0) {
      return null;
    }

    String path = '/api/messages/threads/$threadId?limit=$limit';
    if (beforeId != null) {
      path += '&beforeId=$beforeId';
    }

    final data = await _authenticatedGet(path);
    final thread = data['thread'];
    final messages = data['messages'];
    if (data['ok'] != true || thread is! Map<String, dynamic>) {
      return null;
    }

    return MessageThreadPage(
      thread: MessageThread.fromJson(thread),
      messages: messages is List
          ? messages
              .whereType<Map<String, dynamic>>()
              .map(DirectMessage.fromJson)
              .where((message) => message.id > 0)
              .toList()
          : [],
    );
  }

  Future<bool> deleteMessage(int messageId) async {
    if (messageId <= 0) return false;
    try {
      final res = await _authenticatedDelete('/api/messages/$messageId');
      return res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reactToMessage(int messageId, String emoji) async {
    if (messageId <= 0) return false;
    print('[Reactions Log] Step 1 & 2: Sending API request POST /api/messages/$messageId/reactions with emoji: "$emoji"');
    try {
      final res = await _authenticatedPost('/api/messages/$messageId/reactions', body: {
        'emoji': emoji,
      });
      print('[Reactions Log] Step 3: API response received: $res');
      return res['ok'] == true;
    } catch (e) {
      print('[Reactions Log] API Error in reactToMessage: $e');
      return false;
    }
  }

  Future<DirectMessage?> sendDirectMessage(
    int threadId,
    String body, {
    String? attachmentDataUrl,
    String? attachmentType,
    String? attachmentName,
    String? attachmentMime,
    List<Map<String, String>> attachmentItems = const <Map<String, String>>[],
    int? replyToMessageId,
  }) async {
    final cleanBody = body.trim();
    final cleanAttachmentDataUrl = attachmentDataUrl?.trim() ?? '';
    final cleanAttachmentItems = attachmentItems
        .map(
          (item) => <String, String>{
            'dataUrl': item['dataUrl']?.trim() ?? '',
            'type': item['type']?.trim() ?? '',
            'name': item['name']?.trim() ?? '',
            'mime': item['mime']?.trim() ?? '',
          },
        )
        .where((item) => item['dataUrl']!.isNotEmpty)
        .toList();
    if (threadId <= 0 ||
        (cleanBody.isEmpty &&
            cleanAttachmentDataUrl.isEmpty &&
            cleanAttachmentItems.isEmpty)) {
      return null;
    }

    final payload = <String, dynamic>{'body': cleanBody};
    if (cleanAttachmentItems.isNotEmpty) {
      payload['attachments'] = cleanAttachmentItems;
    } else if (cleanAttachmentDataUrl.isNotEmpty) {
      payload['attachmentDataUrl'] = cleanAttachmentDataUrl;
      payload['attachmentType'] = attachmentType?.trim() ?? '';
      payload['attachmentName'] = attachmentName?.trim() ?? '';
      payload['attachmentMime'] = attachmentMime?.trim() ?? '';
    }
    if (replyToMessageId != null && replyToMessageId > 0) {
      payload['replyToMessageId'] = replyToMessageId;
    }

    final data = await _authenticatedPost(
      '/api/messages/threads/$threadId/messages',
      body: payload,
    );
    final message = data['message'];
    if (data['ok'] == true && message is Map<String, dynamic>) {
      return DirectMessage.fromJson(message);
    }

    return null;
  }

  void joinThread(int threadId) {
    if (threadId <= 0) return;
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('dm:join', {'threadId': threadId});
    }
  }

  void leaveThread(int threadId) {
    if (threadId <= 0) return;
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('dm:leave', {'threadId': threadId});
    }
  }

  Future<void> markThreadRead(int threadId) async {
    if (threadId <= 0) {
      return;
    }
    try {
      await _authenticatedPost('/api/messages/threads/$threadId/read');
    } catch (_) {
      // best-effort; UI will reconverge on next dm:thread-updated
    }
  }

  void emitTyping(int threadId, bool typing) {
    if (threadId <= 0) {
      return;
    }
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }
    final user = AuthService.currentMemoryUser;
    socket.emit('dm:typing', {
      'threadId': threadId,
      'typing': typing,
      'userId': user?.id?.toString() ?? '',
      'user': {
        'id': user?.id?.toString() ?? '',
        'username': user?.username ?? '',
        'fullName': user?.fullName ?? user?.username ?? '',
        'avatarUrl': user?.avatarUrl ?? '',
      },
    });
  }

  Future<FeedPageResult> loadUserPosts(
    String username, {
    int offset = 0,
    int limit = 20,
  }) async {
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (cleanUsername.isEmpty) {
      return const FeedPageResult(
        posts: [],
        offset: 0,
        limit: 0,
        hasMore: false,
      );
    }

    final cleanOffset = offset < 0 ? 0 : offset;
    final cleanLimit = limit < 1
        ? 20
        : limit > 20
            ? 20
            : limit;
    final encodedUsername = Uri.encodeComponent(cleanUsername);
    final data = await _authenticatedGet(
      '/api/users/$encodedUsername/posts?offset=$cleanOffset&limit=$cleanLimit',
    );
    final posts = _readPosts(data);

    return FeedPageResult(
      posts: posts,
      offset: _readInt(data['offset']),
      limit:
          _readInt(data['limit']) == 0 ? cleanLimit : _readInt(data['limit']),
      hasMore: data['hasMore'] == true,
      totalCount: _readInt(data['totalCount'] ?? data['postCount']),
    );
  }

  Future<SearchResults> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      return const SearchResults(people: [], hashtags: [], posts: []);
    }

    final encodedQuery = Uri.encodeQueryComponent(cleanQuery);
    final data = await _authenticatedGet('/api/search?q=$encodedQuery');
    final people = data['people'];
    final hashtags = data['hashtags'];
    final posts = data['posts'];

    return SearchResults(
      people: people is List
          ? people.whereType<Map<String, dynamic>>().map(User.fromJson).toList()
          : [],
      hashtags: hashtags is List
          ? hashtags
              .whereType<Map<String, dynamic>>()
              .map(HashtagResult.fromJson)
              .toList()
          : [],
      posts: posts is List
          ? posts.whereType<Map<String, dynamic>>().map(Post.fromJson).toList()
          : [],
    );
  }

  Future<List<User>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const <User>[];
    }

    final encodedQuery = Uri.encodeQueryComponent(cleanQuery);
    final data = await _authenticatedGet('/api/users/search?q=$encodedQuery');
    final users = data['users'];
    if (users is! List) {
      return const <User>[];
    }

    return users
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => User.fromJson({
            ...json,
            'fullName': json['displayName'] ?? json['fullName'],
          }),
        )
        .toList();
  }

  Future<List<User>> loadFollowSuggestions() async {
    final data = await _authenticatedGet('/api/users/suggestions');
    final users = data['users'];
    if (users is! List) {
      return const <User>[];
    }

    return users
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => User.fromJson({
            ...json,
            'fullName': json['displayName'] ?? json['fullName'],
          }),
        )
        .toList();
  }

  Future<List<MusicSearchResult>> searchAppleMusic(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      return const <MusicSearchResult>[];
    }

    final encodedQuery = Uri.encodeQueryComponent(cleanQuery);
    final data =
        await _authenticatedGet('/api/music/apple/search?q=$encodedQuery');
    final songs = data['songs'];
    if (songs is! List) {
      return const <MusicSearchResult>[];
    }

    return songs
        .whereType<Map<String, dynamic>>()
        .map(MusicSearchResult.fromJson)
        .where((song) => song.title.isNotEmpty && song.previewUrl.isNotEmpty)
        .toList();
  }

  Future<HashtagFeedResult> loadHashtag(String tag) async {
    final cleanTag = tag.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
    final encodedTag = Uri.encodeComponent(cleanTag);
    final data = await _authenticatedGet('/api/hashtags/$encodedTag');
    final hashtagJson = data['hashtag'];
    final postsJson = data['posts'];

    return HashtagFeedResult(
      hashtag: hashtagJson is Map<String, dynamic>
          ? HashtagResult.fromJson(hashtagJson)
          : HashtagResult(name: cleanTag, postCount: 0),
      posts: postsJson is List
          ? postsJson
              .whereType<Map<String, dynamic>>()
              .map(Post.fromJson)
              .toList()
          : const [],
    );
  }

  Future<List<Map<String, dynamic>>> loadNotifications() async {
    final data =
        await _authenticatedGet('/api/notifications?status=unread&limit=50');
    final notifications = data['notifications'];
    if (notifications is! List) {
      return [];
    }

    final list = notifications.whereType<Map<String, dynamic>>().toList();
    notificationsNotifier.value = List<Map<String, dynamic>>.unmodifiable(list);
    unreadNotificationsNotifier.value = list.length;
    return list;
  }

  Future<Set<String>> loadFriendUsernames() async {
    final data = await _authenticatedGet('/api/me/friends');
    final friends = data['friends'];
    if (friends is! List) {
      return <String>{};
    }

    return friends
        .whereType<Map<String, dynamic>>()
        .map((friend) =>
            friend['username']?.toString().trim().toLowerCase() ?? '')
        .where((username) => username.isNotEmpty)
        .toSet();
  }

  Future<void> markNotificationRead(String id) async {
    if (id.trim().isEmpty) {
      return;
    }

    await markNotificationsRead([id]);
  }

  Future<void> markNotificationsRead(List<String> ids) async {
    final cleanIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (cleanIds.isEmpty) {
      return;
    }

    await _authenticatedPatch(
      '/api/notifications/read',
      body: {
        'notificationIds': cleanIds,
      },
    );

    notificationsNotifier.value = List<Map<String, dynamic>>.unmodifiable(
      notificationsNotifier.value
          .where((notification) =>
              !cleanIds.contains(notification['id']?.toString()))
          .toList(),
    );
    final nextCount = unreadNotificationsNotifier.value - cleanIds.length;
    unreadNotificationsNotifier.value = nextCount < 0 ? 0 : nextCount;
  }

  Future<HomeFeedData> _loadHomeData() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const HomeFeedData(
        posts: [],
        stories: [],
        unreadNotifications: 0,
      );
    }

    final headers = _authHeaders(token);

    // ── Step 1: fetch posts first so the feed can render immediately ──
    final feedData =
        await _getJson(ApiConfig.uri('/api/posts'), headers);

    final posts = _readPosts(feedData);
    final offset = _readInt(feedData['offset']);
    final limit = _readInt(feedData['limit']);
    final hasMore = feedData['hasMore'] == true;

    if (posts.isNotEmpty) {
      // fire-and-forget cache save — don't block the return
      _saveCachedPosts(_cachedHomePostsKey, posts);
    }

    // ── Step 2: fetch stories + unread count in parallel (background) ──
    // These are secondary data — we return posts immediately and let the
    // caller update stories/notifs when this resolves.
    final secondaryResults = await Future.wait([
      _getJson(ApiConfig.uri(ApiConfig.storiesPath), headers),
      _getJson(ApiConfig.uri(ApiConfig.notificationsUnreadCountPath), headers),
    ]);

    final storiesData = secondaryResults[0];
    final unreadData = secondaryResults[1];
    final unreadCount = _readInt(unreadData['unreadCount']);

    unreadNotificationsNotifier.value = unreadCount;

    final stories = _readStories(storiesData);
    if (stories.isNotEmpty) {
      saveCachedStories(stories);
    }

    return HomeFeedData(
      posts: posts,
      stories: stories,
      unreadNotifications: unreadCount,
      postsOffset: offset,
      postsLimit: limit,
      postsHasMore: hasMore,
    );
  }

  Future<int> refreshUnreadNotificationsCount() async {
    final data =
        await _authenticatedGet(ApiConfig.notificationsUnreadCountPath);
    final unreadCount = _readInt(data['unreadCount']);
    unreadNotificationsNotifier.value = unreadCount < 0 ? 0 : unreadCount;
    return unreadNotificationsNotifier.value;
  }

  Future<List<Post>> _loadCachedPosts(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .where((post) => post.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedPosts(String key, List<Post> posts) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = posts.take(10).map((post) => post.toJson()).toList();
    await prefs.setString(key, jsonEncode(normalized));
  }

  Future<void> prependCachedHomePost(Post createdPost) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedHomePostsKey);
    final nextItems = <dynamic>[createdPost.toJson()];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          nextItems.addAll(
            decoded.where((item) {
              if (item is! Map<String, dynamic>) {
                return false;
              }
              return item['id']?.toString() != createdPost.id;
            }),
          );
        }
      } catch (_) {
        // Ignore cache parse failures and just overwrite with the new post.
      }
    }

    await prefs.setString(
      _cachedHomePostsKey,
      jsonEncode(nextItems.take(10).toList()),
    );
  }

  Future<void> _removeCachedPostById(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [_cachedDiscoverPostsKey, _cachedHomePostsKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        final filtered = decoded.where((item) {
          if (item is! Map<String, dynamic>) {
            return true;
          }
          return item['id']?.toString() != postId;
        }).toList();
        await prefs.setString(key, jsonEncode(filtered));
      } catch (_) {
        // Ignore cache cleanup failures so hide-post still succeeds.
      }
    }
  }

  Future<void> _replaceCachedPost(Post updatedPost) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [_cachedDiscoverPostsKey, _cachedHomePostsKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        final replaced = decoded.map((item) {
          if (item is! Map<String, dynamic>) {
            return item;
          }
          if (item['id']?.toString() == updatedPost.id) {
            return updatedPost.toJson();
          }

          final originalPost = item['originalPost'];
          if (originalPost is Map<String, dynamic> &&
              originalPost['id']?.toString() == updatedPost.id) {
            return {
              ...item,
              'originalPost': updatedPost.toJson(),
            };
          }

          return item;
        }).toList();
        await prefs.setString(key, jsonEncode(replaced));
      } catch (_) {
        // Ignore cache update failures so post edit still succeeds.
      }
    }
  }

  Future<void> _updateCachedCommentCount(
    String postId,
    int commentCount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [_cachedDiscoverPostsKey, _cachedHomePostsKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        final replaced = decoded.map((item) {
          if (item is! Map<String, dynamic>) {
            return item;
          }
          if (item['id']?.toString() != postId) {
            return item;
          }
          return {
            ...item,
            'commentCount': commentCount,
          };
        }).toList();
        await prefs.setString(key, jsonEncode(replaced));
      } catch (_) {
        // Ignore cache update failures so comment sync still succeeds.
      }
    }
  }

  Future<void> _replaceCachedAuthorPostcardTheme(
    String username,
    String postcardTheme,
  ) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    for (final key in const [_cachedDiscoverPostsKey, _cachedHomePostsKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          continue;
        }

        final replaced = decoded.map((item) {
          if (item is! Map<String, dynamic>) {
            return item;
          }
          return _replacePostcardThemeInCachedPost(
            item,
            cleanUsername,
            postcardTheme,
          );
        }).toList();
        await prefs.setString(key, jsonEncode(replaced));
      } catch (_) {
        // Ignore cache update failures so profile theme sync still succeeds.
      }
    }
  }

  Future<void> clearAllCachedPostcardThemes() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [_cachedDiscoverPostsKey, _cachedHomePostsKey]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;

        final replaced = decoded.map((item) {
          if (item is! Map<String, dynamic>) return item;
          final updated = Map<String, dynamic>.from(item);
          updated['authorPostcardTheme'] = '';
          updated['author_postcard_theme'] = '';

          final original = updated['originalPost'] ?? updated['original_post'];
          if (original is Map<String, dynamic>) {
            final updatedOriginal = Map<String, dynamic>.from(original);
            updatedOriginal['authorPostcardTheme'] = '';
            updatedOriginal['author_postcard_theme'] = '';
            updated['originalPost'] = updatedOriginal;
            if (updated.containsKey('original_post')) {
              updated['original_post'] = updatedOriginal;
            }
          }
          return updated;
        }).toList();

        await prefs.setString(key, jsonEncode(replaced));
      } catch (_) {
        // Ignore cache errors
      }
    }
  }

  static Map<String, dynamic> _replacePostcardThemeInCachedPost(
    Map<String, dynamic> item,
    String username,
    String postcardTheme,
  ) {
    final updated = Map<String, dynamic>.from(item);
    final authorUsername =
        ((updated['authorUsername'] ?? updated['author_username'])
                    ?.toString() ??
                '')
            .trim()
            .toLowerCase();
    if (authorUsername == username) {
      updated['authorPostcardTheme'] = postcardTheme;
      updated['author_postcard_theme'] = postcardTheme;
    }

    final originalPost = updated['originalPost'] ?? updated['original_post'];
    if (originalPost is Map<String, dynamic>) {
      final replacedOriginal = _replacePostcardThemeInCachedPost(
        originalPost,
        username,
        postcardTheme,
      );
      updated['originalPost'] = replacedOriginal;
      if (updated.containsKey('original_post')) {
        updated['original_post'] = replacedOriginal;
      }
    }

    return updated;
  }

  Future<List<Story>> loadStories() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return [];
    try {
      final headers = _authHeaders(token);
      final data = await _getJson(ApiConfig.uri(ApiConfig.storiesPath), headers);
      return _readStories(data);
    } catch (_) {
      return [];
    }
  }

  Future<List<UserNote>> loadUserNotes() async {
    final data = await _authenticatedGet('/api/notes');
    final notes = data['notes'];
    if (notes is! List) {
      return [];
    }
    return notes
        .whereType<Map<String, dynamic>>()
        .map(UserNote.fromJson)
        .toList();
  }

  Future<UserNote?> saveUserNote(String text) async {
    final data = await _authenticatedPost('/api/notes', body: {'text': text});
    if (data['ok'] != true || data['note'] is! Map<String, dynamic>) {
      return null;
    }
    return UserNote.fromJson(data['note'] as Map<String, dynamic>);
  }

  Future<bool> deleteUserNote() async {
    final data = await _authenticatedDelete('/api/notes');
    return data['ok'] == true;
  }

  Future<Map<String, dynamic>> _authenticatedGet(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    return _getJson(ApiConfig.uri(path), _authHeaders(token));
  }

  Future<Map<String, dynamic>> _authenticatedPost(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.post(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: body != null),
        body: body == null ? null : jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _authenticatedPut(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.put(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: body != null),
        body: body == null ? null : jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _authenticatedPatch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.patch(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: true),
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _readErrorMessage(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    return null;
  }

  Future<Map<String, dynamic>> _authenticatedDelete(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.delete(
        ApiConfig.uri(path),
        headers: _authHeaders(token),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static void _upsertNotification(Map<String, dynamic> notification) {
    final id = notification['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }

    final existing = notificationsNotifier.value;
    final filtered =
        existing.where((item) => item['id']?.toString() != id).toList();
    notificationsNotifier.value = List<Map<String, dynamic>>.unmodifiable(
      [notification, ...filtered],
    );
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{};
  }

  List<Post> _readPosts(Map<String, dynamic> data) {
    final posts = data['posts'] ?? data['reels'];
    if (posts is! List) {
      return [];
    }

    final list = <Post>[];
    for (final json in posts) {
      if (json is! Map) continue;
      try {
        final post = Post.fromJson(Map<String, dynamic>.from(json));
        if (post.id.isNotEmpty) {
          list.add(post);
        }
      } catch (e, stack) {
        print('DEBUG: Error parsing post JSON: $e');
        print(stack);
      }
    }
    return list;
  }

  List<Story> _readStories(Map<String, dynamic> data) {
    final stories = data['stories'];
    if (stories is! List) {
      return [];
    }

    final list = <Story>[];
    for (final json in stories) {
      if (json is! Map) continue;
      try {
        final story = Story.fromJson(Map<String, dynamic>.from(json));
        if (story.id.isNotEmpty) {
          list.add(story);
        }
      } catch (e, stack) {
        print('DEBUG: Error parsing story JSON: $e');
        print(stack);
      }
    }
    return list;
  }

  int _readInt(Object? value) {
    return _readStaticInt(value);
  }

  int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  Map<String, String> _authHeaders(
    String token, {
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  Future<List<User>> getUserFollowers(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return [];
      final response = await _client.get(
        ApiConfig.uri('/api/users/$cleanUsername/followers'),
        headers: _authHeaders(token),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((item) => User.fromJson(item)).toList();
      } else if (decoded is Map<String, dynamic>) {
        final list = decoded['users'] ?? decoded['followers'] ?? decoded['data'];
        if (list is List) {
          return list.map((item) => User.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<User>> getUserFollowing(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return [];
      final response = await _client.get(
        ApiConfig.uri('/api/users/$cleanUsername/following'),
        headers: _authHeaders(token),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((item) => User.fromJson(item)).toList();
      } else if (decoded is Map<String, dynamic>) {
        final list = decoded['users'] ?? decoded['following'] ?? decoded['data'];
        if (list is List) {
          return list.map((item) => User.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

String _readStaticString(Object? value) {
  final stringValue = value?.toString().trim() ?? '';
  return stringValue;
}

int _readStaticInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
