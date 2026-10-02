import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/voice_room.dart';
import '../theme/app_text_styles.dart';
import '../models/user.dart';
import '../screens/edit_post_screen.dart';
import '../screens/youtube_player_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/shop_screen.dart';
import '../config/postcard_nameplates_data.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/feed_service.dart';
import 'expandable_post_text.dart';
import 'media_post_load_registry.dart';
import 'post_image_grid.dart';
import 'custom_icons.dart';
import 'repost_source_preview.dart';
import 'sensitive_content_wrapper.dart';
import 'smooth_bottom_sheet.dart';
import 'user_avatar_with_frame.dart';
import 'post_poll.dart';
import 'music_photo_carousel.dart';
import 'video_preview_card.dart';
import 'floating_friend_reaction_overlay.dart';
import 'post_link_preview.dart';
import 'post_header.dart';
import 'reaction_row.dart';
import 'post_card_painters.dart';

export 'post_poll.dart';
export 'music_photo_carousel.dart';
export 'video_preview_card.dart';
export 'post_link_preview.dart';
export 'post_header.dart';
export 'reaction_row.dart';
export 'post_card_painters.dart';



class PostCard extends StatefulWidget {
  const PostCard({
    required this.post,
    this.onOpenPost,
    this.onOpenImages,
    this.onOpenAuthor,
    this.onComment,
    this.onShare,
    this.onRepost,
    this.onBookmark,
    this.onLike,
    this.onPollVote,
    this.onDelete,
    this.onHide,
    this.onUpdate,
    this.showAuthorFollowButton = false,
    this.isAuthorFollowPending = false,
    this.onAuthorFollow,
    this.showPinnedBadge = false,
    this.isHomeFeed = false,
    this.onOpenVoiceRoom,
    super.key,
  });

  final Post post;
  final ValueChanged<Post>? onOpenPost;
  final void Function(Post post, int index)? onOpenImages;
  final ValueChanged<Post>? onOpenAuthor;
  final ValueChanged<Post>? onComment;
  final ValueChanged<Post>? onShare;
  final ValueChanged<Post>? onRepost;
  final ValueChanged<Post>? onBookmark;
  final Future<Post> Function(Post post)? onLike;
  final Future<Post> Function(Post post, int optionIndex)? onPollVote;
  final Future<void> Function(Post post)? onDelete;
  final Future<void> Function(Post post)? onHide;
  final ValueChanged<Post>? onUpdate;
  final bool showAuthorFollowButton;
  final bool isAuthorFollowPending;
  final VoidCallback? onAuthorFollow;
  final bool showPinnedBadge;
  final bool isHomeFeed;
  final ValueChanged<VoiceRoom>? onOpenVoiceRoom;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post _post;
  bool _isLiking = false;
  bool _isHiding = false;
  bool _isDeleting = false;
  bool _isVotingPoll = false;
  bool _isTextExpanded = false;
  int _musicCarouselIndex = 0;
  DateTime? _lastInteractiveSurfaceTapAt;

  User? _targetProfileUser;
  bool _isLoadingTargetProfile = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    if (_post.isPromotion && _post.imageUrls.isEmpty) {
      MediaPostLoadRegistry.markReady(_post.id);
    }
    if (_post.isPromotion && _post.promotionTargetUsername.isNotEmpty) {
      _loadTargetProfile();
    }
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isTextExpanded = false;
      _musicCarouselIndex = 0;
      _targetProfileUser = null;
    }
    _post = widget.post;
    if (_post.imageUrls.isNotEmpty &&
        _musicCarouselIndex >= _post.imageUrls.length) {
      _musicCarouselIndex = _post.imageUrls.length - 1;
    }
    if (_post.isPromotion && _post.promotionTargetUsername.isNotEmpty && _targetProfileUser == null && !_isLoadingTargetProfile) {
      _loadTargetProfile();
    }
  }

  Future<void> _loadTargetProfile() async {
    final username = _post.promotionTargetUsername;
    if (username.isEmpty) return;
    setState(() {
      _isLoadingTargetProfile = true;
    });
    try {
      final user = await FeedService().loadUserProfile(username);
      if (user != null && mounted && _post.promotionTargetUsername == username) {
        setState(() {
          _targetProfileUser = user;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingTargetProfile = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final onLike = widget.onLike;
    if (onLike == null || _isLiking) {
      return;
    }

    setState(() {
      _isLiking = true;
    });

    final previous = _post;
    setState(() {
      _post = _post.copyWith(
        likedByMe: !_post.likedByMe,
        likeCount: (_post.likeCount + (_post.likedByMe ? -1 : 1))
            .clamp(0, 1 << 31)
            .toInt(),
      );
    });

    try {
      final updated = await onLike(previous);
      if (!mounted) return;
      setState(() {
        _post = updated;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = previous;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLiking = false;
      });
    }
  }

  Future<void> _votePoll(int optionIndex) async {
    final onPollVote = widget.onPollVote;
    if (onPollVote == null || _isVotingPoll) {
      return;
    }

    setState(() {
      _isVotingPoll = true;
    });

    try {
      final updated = await onPollVote(_post, optionIndex);
      if (!mounted) return;
      setState(() {
        _post = updated;
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to vote right now.');
    } finally {
      if (mounted) {
        setState(() {
          _isVotingPoll = false;
        });
      }
    }
  }

  Future<void> _hidePost() async {
    final onHide = widget.onHide;
    if (onHide == null || _isHiding || _post.ownedByMe) {
      return;
    }

    setState(() {
      _isHiding = true;
    });

    try {
      await onHide(_post);
    } finally {
      if (!mounted) return;
      setState(() {
        _isHiding = false;
      });
    }
  }

  Future<void> _showReportPostDialog() async {
    final postId = int.tryParse(_post.id) ?? 0;
    if (postId == 0) return;

    final reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Nudity or sexual content',
      'Violence or dangerous content',
      'Something else',
    ];

    String? selectedReason = reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Report Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(reason, style: TextStyle(fontFamily: 'SF Pro Rounded', fontSize: 12.sp)),
                      value: reason,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedReason == null || !mounted) {
      return;
    }

    final ok = await FeedService().reportPost(postId, selectedReason!);
    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit report. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you for reporting this post. We will review it shortly.')),
    );
  }

  Future<void> _openMoreOptions() async {
    await SmoothBottomSheetRoute.show<void>(
      context,
      builder: (context) => PostOptionsSheet(
        groups: _buildPostActionGroups(context),
      ),
    );
  }

  List<PostActionGroup> _buildPostActionGroups(BuildContext context) {
    if (_post.ownedByMe) {
      return [
        // Group 1: Hero AI Card
        PostActionGroup(
          actions: [
            PostActionItem(
              icon: Icons.auto_awesome,
              label: 'Ask Kats AI',
              subtitle: 'Analyze engagement & insights',
              badgeText: 'NEW',
              isHero: true,
              onTap: () async => _showKatsAiSheet(),
            ),
          ],
        ),

        // Group 2: Quick Action / Sharing
        PostActionGroup(
          actions: [
            PostActionItem(
              icon: Icons.link_rounded,
              label: 'Copy link',
              onTap: _copyPostLink,
            ),
          ],
        ),

        // Group 3: Post Preferences
        PostActionGroup(
          actions: [
            PostActionItem(
              icon: _post.bookmarkedByMe
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: _post.bookmarkedByMe ? 'Remove from saved' : 'Save',
              onTap: _toggleBookmark,
            ),
            PostActionItem(
              icon: Icons.notifications_off_outlined,
              label: 'Turn off notifications',
              onTap: () async => _showMessage('Notifications turned off.'),
            ),
          ],
        ),

        // Group 4: Post Management & Moderation
        PostActionGroup(
          actions: [
            PostActionItem(
              icon: _post.isPinned
                  ? Icons.pin_end_outlined
                  : Icons.push_pin_outlined,
              label: _post.isPinned ? 'Unpin from profile' : 'Pin to profile',
              onTap: () async {
                try {
                  final updated = _post.isPinned
                      ? await FeedService().unpinPost(_post)
                      : await FeedService().pinPost(_post);
                  if (mounted) {
                    setState(() {
                      _post = updated;
                    });
                    widget.onUpdate?.call(updated);
                    _showMessage(updated.isPinned
                        ? 'Post pinned to profile.'
                        : 'Post unpinned from profile.');
                  }
                } catch (e) {
                  _showMessage(e.toString().replaceAll('StateError: ', ''));
                }
              },
            ),
            PostActionItem(
              icon: Icons.edit_outlined,
              label: 'Edit post',
              onTap: _editPost,
            ),
            PostActionItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Edit Privacy',
              onTap: () async => _showMessage('Privacy edit coming soon.'),
            ),
            PostActionItem(
              icon: Icons.archive_outlined,
              label: 'Move to archive',
              onTap: () async => _showMessage('Archive coming soon.'),
            ),
            PostActionItem(
              icon: Icons.delete_outline_rounded,
              label: 'Move to trash',
              isDestructive: true,
              onTap: _confirmDeletePost,
            ),
          ],
        ),
      ];
    }

    return [
      // Group 1: Hero AI Card
      PostActionGroup(
        actions: [
          PostActionItem(
            icon: Icons.auto_awesome,
            label: 'Ask Kats AI',
            subtitle: 'Ask questions about this post',
            badgeText: 'NEW',
            isHero: true,
            onTap: () async => _showKatsAiSheet(),
          ),
        ],
      ),

      // Group 2: Quick Action / Sharing
      PostActionGroup(
        actions: [
          PostActionItem(
            icon: Icons.link_rounded,
            label: 'Copy link',
            onTap: _copyPostLink,
          ),
        ],
      ),

      // Group 3: Feed Curation (Threads-style)
      PostActionGroup(
        actions: [
          PostActionItem(
            icon: _post.bookmarkedByMe
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _post.bookmarkedByMe ? 'Remove from saved' : 'Save',
            onTap: _toggleBookmark,
          ),
          PostActionItem(
            icon: Icons.visibility_outlined,
            label: 'Interested',
            onTap: () async => _showMessage('Thanks! We\'ll show more posts like this.'),
          ),
          PostActionItem(
            icon: Icons.visibility_off_outlined,
            label: 'Not interested',
            onTap: _hidePost,
          ),
        ],
      ),

      // Group 4: Safety & Moderation
      PostActionGroup(
        actions: [
          PostActionItem(
            icon: Icons.volume_off_outlined,
            label: 'Mute @${_post.authorUsername}',
            onTap: () async => _showMessage('@${_post.authorUsername} has been muted.'),
          ),
          PostActionItem(
            icon: Icons.block_flipped,
            label: 'Block @${_post.authorUsername}',
            onTap: () async => _showMessage('@${_post.authorUsername} has been blocked.'),
          ),
          PostActionItem(
            icon: Icons.error_outline_rounded,
            label: 'Report',
            isDestructive: true,
            onTap: () async => _showReportPostDialog(),
          ),
        ],
      ),
    ];
  }

  Future<void> _toggleBookmark() async {
    try {
      final updated = await FeedService().toggleBookmark(_post);
      if (mounted) {
        setState(() {
          _post = updated;
        });
        widget.onUpdate?.call(updated);
        _showMessage(updated.bookmarkedByMe
            ? 'Added to Bookmarks.'
            : 'Removed from Bookmarks.');
      }
    } catch (_) {
      _showMessage('Failed to update bookmark.');
    }
  }

  void _showKatsAiSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF111827);
    final subFg = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);

    final cleanContent = _post.text.trim();
    final summaryText = cleanContent.isNotEmpty
        ? (cleanContent.length > 140
            ? '${cleanContent.substring(0, 140)}...'
            : cleanContent)
        : 'This post features media shared by @${_post.authorUsername}.';

    SmoothBottomSheetRoute.show<void>(
      context,
      builder: (sheetCtx) => SmoothSheetContainer(
        maxHeightFraction: 0.70,
        backgroundColor:
            isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7),
        padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7.r),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0095F6), Color(0xFF9B51E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.auto_awesome, color: Colors.white, size: 16.r),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kats AI Assistant',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: fg,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Powered by Gemini AI',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: subFg,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  icon: Icon(Icons.close, color: subFg, size: 18.r),
                  splashRadius: 18.r,
                ),
              ],
            ),
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: ColoredBox(
                color: cardBg,
                child: Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POST INSIGHT',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: const Color(0xFF0095F6),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        summaryText,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          color: fg,
                          fontSize: 12.5.sp,
                          height: 1.35,
                        ),
                      ),
                      if (_post.location.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13.r, color: subFg),
                            SizedBox(width: 4.w),
                            Text(
                              _post.location,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: subFg,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: ColoredBox(
                color: cardBg,
                child: InkWell(
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Clipboard.setData(ClipboardData(text: summaryText));
                    _showMessage('AI summary copied to clipboard.');
                  },
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Copy summary',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: fg,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.copy_rounded, color: fg, size: 16.r),
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

  Future<void> _confirmDeletePost() async {
    final shouldDelete = await SmoothBottomSheetRoute.show<bool>(
      context,
      builder: (context) => const DeletePostSheet(),
    );

    if (shouldDelete == true) {
      await _deletePost();
    }
  }

  Future<void> _deletePost() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await onDelete(_post);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to delete post.');
    } finally {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _copyPostLink() async {
    final baseUrl = ApiConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final link = '$baseUrl/post/${_post.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _showMessage('Link copied.');
  }

  Future<void> _openLinkPreview({String? streamUrl}) async {
    final preview = _post.resolvedLinkPreview;
    if (preview == null) {
      return;
    }

    final ytId = _post.youtubeVideoId.trim().isNotEmpty
        ? _post.youtubeVideoId.trim()
        : RegExp(
            r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
            caseSensitive: false,
          ).firstMatch(preview.url)?.group(1);

    if (ytId != null && ytId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YouTubePlayerScreen(
            videoId: ytId,
            title: preview.title,
            streamUrl: streamUrl,
          ),
        ),
      );
      return;
    }

    if (preview.url.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: preview.url.trim()));
    if (!mounted) return;
    _showMessage('Link copied.');
  }

  Future<void> _editPost() async {
    final updatedPost = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => EditPostScreen(post: _post),
      ),
    );

    if (!mounted || updatedPost == null) {
      return;
    }

    setState(() {
      _post = updatedPost;
    });
    widget.onUpdate?.call(updatedPost);
  }

  Future<void> _openDMWithAuthor() async {
    final authorUsername = _post.authorUsername.trim();
    if (authorUsername.isEmpty) return;
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF7A59),
        ),
      ),
    );
    
    try {
      final thread = await FeedService().startMessageThread(authorUsername);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      if (thread != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessagesScreen(
              initialThread: thread,
              initialGhostPost: _post,
            ),
          ),
        );
      } else {
        _showMessage('Unable to open messages with $authorUsername.');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showMessage('Error opening messages.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _markInteractiveSurfaceTap() {
    _lastInteractiveSurfaceTapAt = DateTime.now();
  }

  bool _shouldSuppressOpenPostTap() {
    final tappedAt = _lastInteractiveSurfaceTapAt;
    if (tappedAt == null) {
      return false;
    }

    return DateTime.now().difference(tappedAt) <
        const Duration(milliseconds: 300);
  }

  void _openOriginalPost() {
    final originalPost = _post.originalPost;
    if (originalPost == null) {
      return;
    }

    _markInteractiveSurfaceTap();
    widget.onOpenPost?.call(originalPost);
  }

  String _getUserInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'K';
    }
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _buildPromotionCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF242526) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1E21);
    final subtitleColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);
    final borderColor = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);

    final bool hasTargetProfile = _post.promotionTargetUsername.isNotEmpty && _targetProfileUser != null;
    final String displayHeaderName = hasTargetProfile
        ? (_targetProfileUser!.fullName ?? _post.promotionTargetUsername)
        : _post.authorFullName;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            GestureDetector(
              onTap: () {
                if (_post.promotionTargetUsername.isNotEmpty) {
                  widget.onOpenAuthor?.call(_post);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Row(
                  children: [
                    // Avatar Image
                    if (hasTargetProfile)
                      UserAvatarWithFrame(
                        avatarUrl: _targetProfileUser?.avatarUrl ?? '',
                        initials: _getUserInitials(displayHeaderName),
                        radius: 18,
                        isAdmin: _targetProfileUser?.isAdmin ?? false,
                      )
                    else if (_post.promotionTargetUsername.isNotEmpty)
                      // Loader or general icon during loading
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A00).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00))),
                          ),
                        ),
                      )
                    else
                      // Sponsored Star Badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A00), Color(0xFFFF5E3A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayHeaderName,
                                style: TextStyle(fontFamily: 'SF Pro Rounded',
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              if (_post.promotionTargetUsername.isNotEmpty) ...[
                                SizedBox(width: 4.w),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: Color(0xFFFF8A00),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8A00).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SPONSORED',
                                  style: TextStyle(fontFamily: 'SF Pro Rounded',
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFFF8A00),
                                    letterSpacing: 0.5,
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
              ),
            ),
            // Text Content (Title & Description)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // If we are showing target profile name at top, show promotion title here in body!
                  if (hasTargetProfile && _post.authorFullName.isNotEmpty) ...[
                    Text(
                      _post.authorFullName,
                      style: KatsText.postAuthor(context),
                    ),
                    SizedBox(height: 4.h),
                  ],
                  if (_post.text.isNotEmpty)
                    Text(
                      _post.text,
                      style: KatsText.postBody(context),
                    ),
                ],
              ),
            ),
            // Image Content
            if (_post.imageUrls.isNotEmpty) ...[
              SizedBox(height: 8.h),
              CachedNetworkImage(
                imageUrl: _post.imageUrls.first,
                height: 180,
                width: double.infinity,
                memCacheWidth: 800,
                maxWidthDiskCache: 800,
                imageBuilder: (context, imageProvider) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    MediaPostLoadRegistry.markReady(_post.id);
                  });
                  return Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
                placeholder: (context, url) => Container(
                  height: 180,
                  color: isDark ? const Color(0xFF18191A) : const Color(0xFFF3F4F6),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    MediaPostLoadRegistry.markReady(_post.id);
                  });
                  return const SizedBox.shrink();
                },
              ),
            ],
            // CTA Button / Action Row
            if (_post.promotionUrl.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(12.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ads: ${_post.promotionUrl}',
                        style: TextStyle(fontFamily: 'SF Pro Rounded',
                          fontSize: 11.5.sp,
                          color: subtitleColor.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      ),
                      onPressed: () => _handlePromotionTap(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _post.promotionButtonText.isNotEmpty
                                ? _post.promotionButtonText
                                : 'Learn More',
                            style: TextStyle(fontFamily: 'SF Pro Rounded',
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          const Icon(Icons.arrow_forward_rounded, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  void _handlePromotionTap(BuildContext context) async {
    final url = _post.promotionUrl;
    if (url.isEmpty) return;

    if (url == 'katsklub://shop') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShopScreen()),
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_post.isPromotion) {
      return _buildPromotionCard(context);
    }

    final isGlobalDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = _post.displayTitle;
    final shouldUseMusicCarousel = _post.imageUrls.length > 1 &&
        (_post.hasMusicPreview || _post.isAlbum);
    final musicCarouselIndex = _post.imageUrls.isEmpty
        ? 0
        : _musicCarouselIndex.clamp(0, _post.imageUrls.length - 1).toInt();
    final showPostText =
        !(_post.isPoll && _post.text.trim() == _post.pollQuestion.trim());
    final postcardTheme =
        (_post.authorPostcardTheme ?? '').trim().toLowerCase();
    final animatedPostcardUrl = PostcardThemeConfig.resolveUrl(postcardTheme);
    final isPostCardDark = isGlobalDark;

    final isGhost = _post.isGhost;
    final ghostBgColor = Theme.of(context).colorScheme.surface;
    final ghostBorderColor = const Color(0xFFFF7A59);

    final cardBody = Padding(
      padding: EdgeInsets.fromLTRB(0, 2.h, 0, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    if (widget.showPinnedBadge && _post.isPinned) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 6.h),
                        child: Row(
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Pinned Post',
                              style: TextStyle(fontFamily: 'SF Pro Rounded',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_post.repostedByText != null &&
                        _post.repostedByText!.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 6.h),
                        child: Row(
                          children: [
                            CustomIcons.repost(
                              size: 13,
                              color: Colors.grey[600]!,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                '${_post.repostedByText} reposted this',
                                style: TextStyle(fontFamily: 'SF Pro Rounded',
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: PostHeader(
                        post: _post,
                        onOpenAuthor: () => widget.onOpenAuthor?.call(_post),
                        onHide: widget.onHide == null || _post.ownedByMe
                            ? null
                            : _hidePost,
                        isHiding: _isHiding,
                        onMore: _openMoreOptions,
                        showFollowButton: widget.showAuthorFollowButton,
                        isFollowPending: widget.isAuthorFollowPending,
                        onFollow: widget.onAuthorFollow,
                        isHomeFeed: widget.isHomeFeed,
                        onOpenVoiceRoom: widget.onOpenVoiceRoom,
                      ),
                    ),
                    if (displayTitle.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Text(
                          displayTitle,
                          style: TextStyle(fontFamily: 'SF Pro Rounded',
                            fontSize: 16.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isPostCardDark ? Colors.white : const Color(0xFF1C1E21),
                          ),
                        ),
                      ),
                    ],
                    if (showPostText && _post.cleanText.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      isGhost
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: CustomPaint(
                                painter: DottedChatBubblePainter(
                                  fillColor: ghostBgColor,
                                  dotColor: ghostBorderColor,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 14.h),
                                  child: ExpandablePostText(
                                    text: _post.cleanText,
                                    expanded: _isTextExpanded,
                                    onToggle: () {
                                      setState(() {
                                        _isTextExpanded = !_isTextExpanded;
                                      });
                                    },
                                    onInteractiveTap: _markInteractiveSurfaceTap,
                                  ),
                                ),
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: ExpandablePostText(
                                text: _post.cleanText,
                                expanded: _isTextExpanded,
                                onToggle: () {
                                  setState(() {
                                    _isTextExpanded = !_isTextExpanded;
                                  });
                                },
                                onInteractiveTap: _markInteractiveSurfaceTap,
                              ),
                            ),
                    ],
                    if (_post.isPoll) ...[
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: PostPoll(
                          post: _post,
                          isBusy: _isVotingPoll,
                          onVote: _votePoll,
                        ),
                      ),
                    ],
                    if (_post.originalPost != null) ...[
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: RepostSourcePreview(
                          post: _post.originalPost!,
                          onTap: _openOriginalPost,
                        ),
                      ),
                    ],
                    if (_post.resolvedLinkPreview != null &&
                        _post.imageUrls.isEmpty) ...[
                      SizedBox(height: 12.h),
                      if (_post.youtubeVideoId.trim().isNotEmpty)
                        YouTubePreviewCard(
                          preview: _post.resolvedLinkPreview!,
                          videoId: _post.youtubeVideoId.trim(),
                          onTap: ({streamUrl}) =>
                              _openLinkPreview(streamUrl: streamUrl),
                          onTapDown: _markInteractiveSurfaceTap,
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: LinkPreviewCard(
                            preview: _post.resolvedLinkPreview!,
                            isYouTube: false,
                            onTap: _openLinkPreview,
                            onTapDown: _markInteractiveSurfaceTap,
                          ),
                        ),
                    ],
                    if (_post.imageUrls.isNotEmpty || _post.hasVideo) ...[
                      SizedBox(height: 12.h),
                      SensitiveContentWrapper(
                        isSensitive: _post.isSensitive,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_post.imageUrls.isNotEmpty) ...[
                              if (shouldUseMusicCarousel)
                                MusicPhotoCarousel(
                                  post: _post,
                                  activeIndex: musicCarouselIndex,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _musicCarouselIndex = index;
                                    });
                                  },
                                  onImageTap: null,
                                  onMediaReady: () =>
                                      MediaPostLoadRegistry.markReady(_post.id),
                                )
                              else
                                PostImageGrid(
                                  imageUrls: _post.imageUrls,
                                  initialAspectRatios: _post.imageAspectRatios,
                                  postId: _post.id,
                                  fit: _post.isDiscussion ? BoxFit.contain : null,
                                  onImageTap: (index) =>
                                      widget.onOpenImages?.call(_post, index),
                                  onMediaReady: () =>
                                      MediaPostLoadRegistry.markReady(_post.id),
                                ),
                            ],
                             if (_post.hasVideo) ...[
                               if (_post.imageUrls.isNotEmpty)
                                 SizedBox(height: 12.h),
                               if (_post.isReel)
                                 Stack(
                                   clipBehavior: Clip.none,
                                   children: [
                                     VideoPreviewCard(post: _post),
                                     if (_getReelFriendActivities(_post).isNotEmpty)
                                       FloatingFriendReactionOverlay(
                                         activities: _getReelFriendActivities(_post),
                                       ),
                                   ],
                                 )
                               else
                                 VideoPreviewCard(post: _post),
                             ],
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: ReactionRow(
                        post: _post,
                        onLike: _toggleLike,
                        onComment: () => isGhost ? _openDMWithAuthor() : widget.onComment?.call(_post),
                        onShare: () => widget.onShare?.call(_post),
                        onRepost: () {
                          final handler = widget.onRepost;
                          if (handler != null) {
                            handler(_post);
                          } else {
                            _showMessage('Repost coming soon.');
                          }
                        },
                        onBookmark: () => widget.onBookmark?.call(_post),
                      ),
                    ),
                  ],
                ),
              );

      final Widget cardInner;
      if (animatedPostcardUrl != null) {
        cardInner = Stack(
          children: [
            cardBody,
            Positioned(
              right: 0,
              top: 0,
              height: 36.h,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CachedNetworkImage(
                    imageUrl: animatedPostcardUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.topRight,
                    memCacheHeight: (36.h * 2).round().clamp(60, 120),
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => const SizedBox(),
                    errorWidget: (context, url, error) => const SizedBox(),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        cardInner = cardBody;
      }

      final mainCard = Container(
        margin: EdgeInsets.zero,
        decoration: isGhost
            ? BoxDecoration(
                color: ghostBgColor,
                borderRadius: BorderRadius.circular(20),
              )
            : BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2F3031)
                        : const Color(0xFFD1D5DB),
                    width: 2.5,
                  ),
                ),
              ),
        child: isGhost
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: cardInner,
              )
            : cardInner,
      );

      Widget wrappedCard = mainCard;


      return GestureDetector(
        onTap: () {
          if (_post.imageUrls.isNotEmpty && shouldUseMusicCarousel) {
            return;
          }
          if (_shouldSuppressOpenPostTap()) {
            return;
          }
          if (isGhost) {
            _openDMWithAuthor();
            return;
          }
          widget.onOpenPost?.call(_post);
        },
        child: RepaintBoundary(
          child: wrappedCard,
        ),
      );
  }

  List<FriendPostActivity> _getReelFriendActivities(Post post) {
    final isRepost = post.originalPost != null ||
        post.repostOriginalPostId.isNotEmpty ||
        (post.repostedByText != null && post.repostedByText!.isNotEmpty);
    final isLiked = post.likeCount > 0 || post.likedByMe;

    final activities = <FriendPostActivity>[];
    final authorName = post.authorUsername.trim().toLowerCase();
    final currentUserName = (AuthService().currentUser?.username ?? '').trim().toLowerCase();

    bool isSelf(String name) {
      final clean = name.trim().toLowerCase();
      if (clean.isEmpty) return true;
      if (clean == authorName) return true;
      if (currentUserName.isNotEmpty && clean == currentUserName) return true;
      return false;
    }

    bool isFriend(String name) {
      final clean = name.trim().toLowerCase();
      if (clean.isEmpty) return false;
      return FeedService.isUserFollowed(clean);
    }

    // 1. Real Likers from backend likePreview (ONLY followed friends!)
    if (post.likePreview.isNotEmpty) {
      for (final liker in post.likePreview) {
        if (activities.length >= 3) break;
        final name = (liker.username.isNotEmpty ? liker.username : liker.fullName).trim();
        if (isSelf(name)) continue;
        if (!isFriend(name)) continue;
        activities.add(
          FriendPostActivity(
            username: name,
            avatarUrl: liker.avatarUrl,
            isLiked: true,
            isReposted: false,
          ),
        );
      }
    }

    // 2. Tagged / Mentioned Friends (ONLY followed friends!)
    if (activities.length < 3 && post.withUsers.isNotEmpty) {
      for (final user in post.withUsers) {
        if (activities.length >= 3) break;
        final name = (user.username ?? user.fullName ?? '').trim();
        if (isSelf(name)) continue;
        if (!isFriend(name)) continue;
        activities.add(
          FriendPostActivity(
            username: name,
            avatarUrl: user.avatarUrl ?? '',
            isLiked: isLiked,
            isReposted: isRepost,
          ),
        );
      }
    }

    // 3. Poll Voters (ONLY followed friends!)
    if (activities.length < 3 && post.pollVoters.isNotEmpty) {
      for (final voter in post.pollVoters) {
        if (activities.length >= 3) break;
        final name = voter.username.trim();
        if (isSelf(name)) continue;
        if (!isFriend(name)) continue;
        activities.add(
          FriendPostActivity(
            username: name,
            avatarUrl: voter.avatarUrl,
            isLiked: isLiked,
            isReposted: isRepost,
          ),
        );
      }
    }

    // 4. Repost Author (ONLY followed friends!)
    if (activities.length < 3 && isRepost && post.repostedByText != null) {
      final reposter = post.repostedByText!.trim();
      if (!isSelf(reposter) && isFriend(reposter)) {
        activities.add(
          FriendPostActivity(
            username: reposter,
            avatarUrl: '',
            isLiked: isLiked,
            isReposted: true,
          ),
        );
      }
    }

    return activities;
  }
}

