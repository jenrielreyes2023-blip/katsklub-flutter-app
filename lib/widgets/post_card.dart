import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../screens/edit_post_screen.dart';
import '../screens/youtube_player_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/shop_screen.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/feed_service.dart';
import 'expandable_post_text.dart';
import 'media_post_load_registry.dart';
import 'post_image_grid.dart';
import 'custom_icons.dart';
import 'repost_source_preview.dart';
import 'sensitive_content_wrapper.dart';
import 'share_post_sheet.dart';
import 'smooth_bottom_sheet.dart';
import 'special_name_text.dart';
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
              title: const Text('Report Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
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
        actions: _buildPostActions(context),
      ),
    );
  }

  List<PostActionItem> _buildPostActions(BuildContext context) {
    if (_post.ownedByMe) {
      return [
        PostActionItem(
          icon: _post.isPinned ? Icons.pin_end_outlined : Icons.push_pin_outlined,
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
                _showMessage(updated.isPinned ? 'Post pinned to profile.' : 'Post unpinned from profile.');
              }
            } catch (e) {
              _showMessage(e.toString().replaceAll('StateError: ', ''));
            }
          },
        ),
        PostActionItem(
          icon: Icons.bookmark_border_rounded,
          label: 'Save post',
          subtitle: 'Add this to your saved items.',
          onTap: () async => _showMessage('Post saved.'),
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
          icon: Icons.camera_alt_outlined,
          label: 'Share to Instagram',
          onTap: () async => _showMessage('Share to Instagram coming soon.'),
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
        PostActionItem(
          icon: Icons.notifications_off_outlined,
          label: 'Turn off notifications for this post',
          onTap: () async => _showMessage('Notifications turned off.'),
        ),
        PostActionItem(
          icon: Icons.link_rounded,
          label: 'Copy link',
          onTap: _copyPostLink,
        ),
      ];
    }

    return [
      PostActionItem(
        icon: Icons.bookmark_border_rounded,
        label: 'Save post',
        subtitle: 'Add this to your saved items.',
        onTap: () async => _showMessage('Post saved.'),
      ),
      PostActionItem(
        icon: Icons.visibility_off_outlined,
        label: 'Hide post',
        onTap: _hidePost,
      ),
      PostActionItem(
        icon: Icons.flag_outlined,
        label: 'Report post',
        onTap: () async {
          _showReportPostDialog();
        },
      ),
      PostActionItem(
        icon: Icons.link_rounded,
        label: 'Copy link',
        onTap: _copyPostLink,
      ),
    ];
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

  Future<void> _openLinkPreview() async {
    final preview = _post.resolvedLinkPreview;
    if (preview == null) {
      return;
    }

    if (_post.youtubeVideoId.trim().isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => YouTubePlayerScreen(
            videoId: _post.youtubeVideoId.trim(),
            title: preview.title,
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
      Navigator.of(context).pop(); // Close loading dialog
      if (!mounted) return;
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
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar Image
                    if (hasTargetProfile)
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE5E7EB),
                        backgroundImage: _targetProfileUser!.avatarUrl == null || _targetProfileUser!.avatarUrl!.trim().isEmpty
                            ? null
                            : CachedNetworkImageProvider(ApiConfig.assetUrl(_targetProfileUser!.avatarUrl!)),
                        child: _targetProfileUser!.avatarUrl == null || _targetProfileUser!.avatarUrl!.trim().isEmpty
                            ? Text(
                                _getUserInitials(displayHeaderName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1C1E21),
                                  fontSize: 12,
                                ),
                              )
                            : null,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayHeaderName,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              if (_post.promotionTargetUsername.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: Color(0xFFFF8A00),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8A00).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SPONSORED',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF8A00),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // If we are showing target profile name at top, show promotion title here in body!
                  if (hasTargetProfile && _post.authorFullName.isNotEmpty) ...[
                    Text(
                      _post.authorFullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_post.text.isNotEmpty)
                    Text(
                      _post.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            // Image Content
            if (_post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Ads: ${_post.promotionUrl}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: subtitleColor.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _handlePromotionTap(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _post.promotionButtonText.isNotEmpty
                                ? _post.promotionButtonText
                                : 'Learn More',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 12),
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
    final shouldUseMusicCarousel =
        _post.hasMusicPreview && _post.imageUrls.length > 1 && !_post.isAlbum;
    final musicCarouselIndex = _post.imageUrls.isEmpty
        ? 0
        : _musicCarouselIndex.clamp(0, _post.imageUrls.length - 1).toInt();
    final showPostText =
        !(_post.isPoll && _post.text.trim() == _post.pollQuestion.trim());
    final isGemini = _post.authorUsername.toLowerCase() == 'gemini';
    final isDaisy = _post.authorUsername.toLowerCase() == 'daisy';
    final double gradientHeight = _post.isDiscussion ? 140.0 : 75.0;
    final double daisyStickerHeight = _post.isDiscussion ? 140.0 : 75.0;
    final double daisyStickerTop = 0.0;
    final double hunterStickerHeight = _post.isDiscussion ? 128.0 : 78.0;
    final double wolfStickerHeight = _post.isDiscussion ? 124.0 : 76.0;
    final Alignment bunnyStickerAlignment = _post.isDiscussion
        ? Alignment.centerRight
        : const Alignment(1.0, -0.16);
    final Alignment elsaStickerAlignment = _post.isDiscussion
        ? Alignment.centerRight
        : const Alignment(1.0, -0.16);
    final Alignment ghostStickerAlignment = _post.isDiscussion
        ? Alignment.centerRight
        : const Alignment(1.0, -0.14);
    final Alignment princeStickerAlignment = _post.isDiscussion
        ? Alignment.centerRight
        : const Alignment(1.0, -0.18);
    final postcardTheme =
        (_post.authorPostcardTheme ?? '').trim().toLowerCase();
    final showSunrise =
        postcardTheme == 'sunrise' || (postcardTheme.isEmpty && isDaisy);
    final showOcean = postcardTheme == 'ocean';
    final showBee = postcardTheme == 'bee';
    final showEagle = postcardTheme == 'eagle';
    final showPinkSwan = postcardTheme == 'pinkswan';
    final showDandelion = postcardTheme == 'dandelion';
    final showGtaPastel = postcardTheme == 'gta_pastel';
    final showSharinganEyes = postcardTheme == 'sharingan_eyes';
    final showPastel = postcardTheme == 'pastel';
    final showLavender = postcardTheme == 'lavender';
    final showPhFlag = postcardTheme == 'ph_flag';
    final showXmasCozy = postcardTheme == 'xmas_cozy';
    final showXmasSnowy = postcardTheme == 'xmas_snowy';
    final showBunny = postcardTheme == 'bunny';
    final showGhost = postcardTheme == 'ghost';
    final showPrince = postcardTheme == 'prince';
    final showCuteHeart = postcardTheme == 'cute_heart';
    final showElsa = postcardTheme == 'elsa';
    final showGeminiRogerHunter =
        isGemini && postcardTheme == 'gemini_roger_hunter';
    final showGeminiRogerWolf =
        isGemini && postcardTheme == 'gemini_roger_wolf';
    final isPostCardDark = showOcean || (isGlobalDark && postcardTheme.isEmpty);
    final showThemeBackdrop = showGeminiRogerHunter ||
        showGeminiRogerWolf ||
        showSunrise ||
        showOcean ||
        showBee ||
        showEagle ||
        showPinkSwan ||
        showDandelion ||
        showGtaPastel ||
        showSharinganEyes ||
        showPastel ||
        showLavender ||
        showPhFlag ||
        showXmasCozy ||
        showXmasSnowy ||
        showBunny ||
        showGhost ||
        showPrince ||
        showElsa;
    final activeBackdropHeight = showGeminiRogerHunter
        ? hunterStickerHeight
        : showGeminiRogerWolf
            ? wolfStickerHeight
            : (showSunrise ||
                    showOcean ||
                    showBee ||
                    showEagle ||
                    showPinkSwan ||
                    showDandelion ||
                    showGtaPastel ||
                    showSharinganEyes ||
                    showPastel ||
                    showLavender ||
                    showPhFlag ||
                    showXmasCozy ||
                    showXmasSnowy ||
                    showBunny ||
                    showGhost ||
                    showPrince ||
                    showElsa)
                ? daisyStickerHeight
                : gradientHeight;
    final backdropFadeTop = (activeBackdropHeight - 14).clamp(0.0, 10000.0);

    final isGhost = _post.isGhost;
    final ghostBgColor = Theme.of(context).colorScheme.surface;
    final ghostBorderColor = const Color(0xFFFF7A59);

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
      child: ClipRRect(
        borderRadius: isGhost ? BorderRadius.circular(20) : BorderRadius.zero,
        child: Stack(
          children: [

              if (showGeminiRogerHunter) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF8FAFC),
                          Color(0xFFE2E8F0),
                          Color(0xFFDCE7F2),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.62, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: hunterStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.56,
                          0.86,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/gemini_roger_hunter_v1.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.4, -0.2),
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showGeminiRogerWolf) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF8FAFC),
                          Color(0xFFDBEAFE),
                          Color(0xFFD9EAFE),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.62, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: wolfStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.56,
                          0.86,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/gemini_roger_wolf_v1.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.7, -0.05),
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showSunrise) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFB3E5FC), // Light Blue (top sky)
                          Color(
                              0xFFFFE082), // Warm Sunrise Gold (mid sky/sun glow)
                          Color(0xFFFFF9C4), // Soft Yellow
                          Colors.white, // Fades smoothly to white at the bottom
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/sunrise_sticker.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showOcean) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0F3D6E),
                          Color(0xFF1D6FA5),
                          Color(0xFFBFEAF2),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.38, 0.68, 0.88, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.7,
                          1.0,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/ocean_sticker_v3.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showBee) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFCF0),
                          Color(0xFFFFF7D6),
                          Color(0xFFFFF4CC),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/bee_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showEagle) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFCF6),
                          Color(0xFFF6E9D1),
                          Color(0xFFEFD7B0),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/eagle_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showPinkSwan) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFCFD),
                          Color(0xFFFCE7F3),
                          Color(0xFFFBCFE8),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/pinkswan_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showDandelion) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFDF7),
                          Color(0xFFFEF9C3),
                          Color(0xFFECFCCB),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/dandelion_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showGtaPastel) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFCF8),
                          Color(0xFFFCE7F3),
                          Color(0xFFCCFBF1),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/gta_pastel_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showSharinganEyes) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFCFD),
                          Color(0xFFFDE2E8),
                          Color(0xFFFECACA),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/sharingan_eyes_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showPastel) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFBF8),
                          Color(0xFFF8E8F7),
                          Color(0xFFEAF7F3),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/pastel_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showLavender) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFAF8FF),
                          Color(0xFFF1E9FF),
                          Color(0xFFE3D3FF),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.34, 0.64, 0.86, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/lavender_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showPhFlag) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFF9FAFB), // left: softest off-white
                          Color(0xFFEFF6FF), // soft blue
                          Color(0xFFDBEAFE), // stronger blue
                          Color(0xFFFEE2E2), // stronger red
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/ph_flag_sticker_v1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showXmasCozy) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFCFBF7), // left: soft warm white
                          Color(0xFFFDF4F4), // soft warm red tint
                          Color(0xFFFCA5A5), // stronger red
                          Color(0xFFFEF08A), // strong gold/yellow
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/xmas_cozy_sticker.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showXmasSnowy) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFF8FAFC), // left: soft ice white
                          Color(0xFFF0F9FF), // soft blue tint
                          Color(0xFFBAE6FD), // stronger frosty blue
                          Color(0xFF7DD3FC), // strong winter blue
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/xmas_snowy_sticker.png',
                      fit: BoxFit.cover,
                      alignment: bunnyStickerAlignment,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showBunny) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFFFDFB),
                          Color(0xFFFFF5F7),
                          Color(0xFFFCE7F3),
                          Color(0xFFFBCFE8),
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/bunny_sticker_v1.png',
                      fit: BoxFit.cover,
                      alignment: bunnyStickerAlignment,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showGhost) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFAF9FD),
                          Color(0xFFF3F0FA),
                          Color(0xFFE9E3F8),
                          Color(0xFFDCD3F5),
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/ghost_sticker_v1.png',
                      fit: BoxFit.cover,
                      alignment: ghostStickerAlignment,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showPrince) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFF0F7FF),
                          Color(0xFFE0EFFF),
                          Color(0xFFBAE0FF),
                          Color(0xFF7DD3FC),
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/prince_sticker_v1.png',
                      fit: BoxFit.cover,
                      alignment: princeStickerAlignment,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ] else if (showCuteHeart) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFBFD),
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFF7D4E3),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: _post.isDiscussion ? 8 : 6,
                  child: CuteHeartWingBadge(
                    large: _post.isDiscussion,
                  ),
                ),
              ] else if (showElsa) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: gradientHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFE0F2FE),
                          Color(0xFFBAE6FD),
                          Color(0xFFF3E8FF),
                          Color(0xFFE9D5FF),
                        ],
                        stops: [0.0, 0.33, 0.66, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: daisyStickerTop,
                  height: daisyStickerHeight,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.62,
                          0.9,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/elsa_sticker.png',
                      fit: BoxFit.cover,
                      alignment: elsaStickerAlignment,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ],
              if (showThemeBackdrop)
                Positioned(
                  left: 0,
                  right: 0,
                  top: backdropFadeTop,
                  height: 28,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.82),
                            Colors.white,
                          ],
                          stops: const [0.0, 0.58, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showPinnedBadge && _post.isPinned) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Pinned Post',
                              style: TextStyle(
                                fontSize: 13,
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Row(
                          children: [
                            CustomIcons.repost(
                              size: 13,
                              color: Colors.grey[600]!,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_post.repostedByText} reposted this',
                                style: TextStyle(
                                  fontSize: 12,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),
                    ),
                    if (displayTitle.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isPostCardDark ? Colors.white : const Color(0xFF1C1E21),
                          ),
                        ),
                      ),
                    ],
                    if (showPostText && _post.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      isGhost
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: CustomPaint(
                                painter: DottedChatBubblePainter(
                                  fillColor: ghostBgColor,
                                  dotColor: ghostBorderColor,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                                  child: ExpandablePostText(
                                    text: _post.text,
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: ExpandablePostText(
                                text: _post.text,
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
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PostPoll(
                          post: _post,
                          isBusy: _isVotingPoll,
                          onVote: _votePoll,
                        ),
                      ),
                    ],
                    if (_post.originalPost != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RepostSourcePreview(
                          post: _post.originalPost!,
                          onTap: _openOriginalPost,
                        ),
                      ),
                    ],
                    if (_post.resolvedLinkPreview != null &&
                        _post.imageUrls.isEmpty) ...[
                      const SizedBox(height: 12),
                      if (_post.youtubeVideoId.trim().isNotEmpty)
                        YouTubePreviewCard(
                          preview: _post.resolvedLinkPreview!,
                          onTap: _openLinkPreview,
                          onTapDown: _markInteractiveSurfaceTap,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: LinkPreviewCard(
                            preview: _post.resolvedLinkPreview!,
                            isYouTube: false,
                            onTap: _openLinkPreview,
                            onTapDown: _markInteractiveSurfaceTap,
                          ),
                        ),
                    ],
                    if (_post.imageUrls.isNotEmpty || _post.hasVideo) ...[
                      const SizedBox(height: 12),
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
                                 const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              ),
            ],
          ),
        ),
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

    // 1. Real Likers from backend likePreview (excluding post author & current user)
    if (post.likePreview.isNotEmpty) {
      for (final liker in post.likePreview) {
        if (activities.length >= 3) break;
        final name = (liker.username.isNotEmpty ? liker.username : liker.fullName).trim();
        if (isSelf(name)) continue;
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

    // 2. Tagged / Mentioned Friends (excluding post author & current user)
    if (activities.length < 3 && post.withUsers.isNotEmpty) {
      for (final user in post.withUsers) {
        if (activities.length >= 3) break;
        final name = (user.username ?? user.fullName ?? '').trim();
        if (isSelf(name)) continue;
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

    // 3. Poll Voters (excluding post author & current user)
    if (activities.length < 3 && post.pollVoters.isNotEmpty) {
      for (final voter in post.pollVoters) {
        if (activities.length >= 3) break;
        final name = voter.username.trim();
        if (isSelf(name)) continue;
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

    // 4. Repost Author (excluding post author & current user)
    if (activities.length < 3 && isRepost && post.repostedByText != null) {
      final reposter = post.repostedByText!.trim();
      if (!isSelf(reposter)) {
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

