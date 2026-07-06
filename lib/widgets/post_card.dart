import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../screens/edit_post_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/youtube_player_screen.dart';
import '../services/normal_video_playback_session.dart';
import '../services/normal_video_inline_controls.dart';
import '../services/normal_video_overlay_controller.dart';
import '../services/feed_service.dart';
import 'expandable_post_text.dart';
import 'loading_skeletons.dart';
import 'media_post_load_registry.dart';
import 'post_image_grid.dart';
import 'custom_icons.dart';
import 'repost_source_preview.dart';
import 'post_with_users_line.dart';
import 'sensitive_content_wrapper.dart';

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

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isTextExpanded = false;
      _musicCarouselIndex = 0;
    }
    _post = widget.post;
    if (_post.imageUrls.isNotEmpty &&
        _musicCarouselIndex >= _post.imageUrls.length) {
      _musicCarouselIndex = _post.imageUrls.length - 1;
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

  Future<void> _openMoreOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (context) => _PostOptionsSheet(
        actions: _buildPostActions(context),
      ),
    );
  }

  List<_PostActionItem> _buildPostActions(BuildContext context) {
    if (_post.ownedByMe) {
      return [
        _PostActionItem(
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
        _PostActionItem(
          icon: Icons.bookmark_border_rounded,
          label: 'Save post',
          subtitle: 'Add this to your saved items.',
          onTap: () async => _showMessage('Post saved.'),
        ),
        _PostActionItem(
          icon: Icons.edit_outlined,
          label: 'Edit post',
          onTap: _editPost,
        ),
        _PostActionItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Edit Privacy',
          onTap: () async => _showMessage('Privacy edit coming soon.'),
        ),
        _PostActionItem(
          icon: Icons.camera_alt_outlined,
          label: 'Share to Instagram',
          onTap: () async => _showMessage('Share to Instagram coming soon.'),
        ),
        _PostActionItem(
          icon: Icons.archive_outlined,
          label: 'Move to archive',
          onTap: () async => _showMessage('Archive coming soon.'),
        ),
        _PostActionItem(
          icon: Icons.delete_outline_rounded,
          label: 'Move to trash',
          isDestructive: true,
          onTap: _confirmDeletePost,
        ),
        _PostActionItem(
          icon: Icons.notifications_off_outlined,
          label: 'Turn off notifications for this post',
          onTap: () async => _showMessage('Notifications turned off.'),
        ),
        _PostActionItem(
          icon: Icons.link_rounded,
          label: 'Copy link',
          onTap: _copyPostLink,
        ),
      ];
    }

    return [
      _PostActionItem(
        icon: Icons.bookmark_border_rounded,
        label: 'Save post',
        subtitle: 'Add this to your saved items.',
        onTap: () async => _showMessage('Post saved.'),
      ),
      _PostActionItem(
        icon: Icons.visibility_off_outlined,
        label: 'Hide post',
        onTap: _hidePost,
      ),
      _PostActionItem(
        icon: Icons.flag_outlined,
        label: 'Report post',
        onTap: () async => _showMessage('Report coming soon.'),
      ),
      _PostActionItem(
        icon: Icons.link_rounded,
        label: 'Copy link',
        onTap: _copyPostLink,
      ),
    ];
  }

  Future<void> _confirmDeletePost() async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      isScrollControlled: true,
      builder: (context) => const _DeletePostSheet(),
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

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(
      onTap: () {
        if (_post.imageUrls.isNotEmpty && shouldUseMusicCarousel) {
          return;
        }
        if (_shouldSuppressOpenPostTap()) {
          return;
        }
        widget.onOpenPost?.call(_post);
      },
      child: RepaintBoundary(
        child: Container(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
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
                  child: _CuteHeartWingBadge(
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
                      child: _PostHeader(
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
                      Padding(
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
                        child: _PostPoll(
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
                        _YouTubePreviewCard(
                          preview: _post.resolvedLinkPreview!,
                          onTap: _openLinkPreview,
                          onTapDown: _markInteractiveSurfaceTap,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _LinkPreviewCard(
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
                                _MusicPhotoCarousel(
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
                                  onImageTap: (index) =>
                                      widget.onOpenImages?.call(_post, index),
                                  onMediaReady: () =>
                                      MediaPostLoadRegistry.markReady(_post.id),
                                ),
                            ],
                            if (_post.hasVideo) ...[
                              if (_post.imageUrls.isNotEmpty)
                                const SizedBox(height: 12),
                              VideoPreviewCard(post: _post),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ReactionRow(
                        post: _post,
                        onLike: _toggleLike,
                        onComment: () => widget.onComment?.call(_post),
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
      ),
    );
  }
}

class _PostPoll extends StatelessWidget {
  const _PostPoll({
    required this.post,
    required this.isBusy,
    required this.onVote,
  });

  final Post post;
  final bool isBusy;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final options = post.pollOptions;
    if (options.length < 2) {
      return const SizedBox.shrink();
    }

    final votes = [
      for (var index = 0; index < options.length; index++)
        index < post.pollOptionVotes.length ? post.pollOptionVotes[index] : 0,
    ];
    final totalVotes = post.pollVotes > 0
        ? post.pollVotes
        : votes.fold<int>(0, (sum, count) => sum + count);
    final hasEnded =
        post.pollEndTime != null && !post.pollEndTime!.isAfter(DateTime.now());
    final showResults = post.hasVoted || hasEnded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            post.pollQuestion.isNotEmpty ? post.pollQuestion : 'Poll',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++) ...[
            _PostPollOption(
              label: options[index],
              votes: votes[index],
              totalVotes: totalVotes,
              selected: post.selectedOptionIndex == index,
              showResults: showResults,
              voters: post.pollVoters
                  .where((voter) => voter.optionIndex == index)
                  .toList(growable: false),
              enabled: !isBusy && !hasEnded,
              onTap: () => onVote(index),
            ),
            if (index != options.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Text(
            _pollMetaText(totalVotes, hasEnded),
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _pollMetaText(int totalVotes, bool hasEnded) {
    final voteText = totalVotes == 1 ? '1 vote' : '$totalVotes votes';
    if (hasEnded) {
      return '$voteText - Poll ended';
    }
    final endTime = post.pollEndTime;
    if (endTime == null) {
      return voteText;
    }
    final remaining = endTime.difference(DateTime.now());
    if (remaining.inDays >= 1) {
      return '$voteText - ${remaining.inDays}d left';
    }
    if (remaining.inHours >= 1) {
      return '$voteText - ${remaining.inHours}h left';
    }
    final minutes = remaining.inMinutes.clamp(1, 59);
    return '$voteText - ${minutes}m left';
  }
}

class _PostPollOption extends StatelessWidget {
  const _PostPollOption({
    required this.label,
    required this.votes,
    required this.totalVotes,
    required this.selected,
    required this.showResults,
    required this.voters,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int votes;
  final int totalVotes;
  final bool selected;
  final bool showResults;
  final List<PollVoterPreview> voters;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = totalVotes <= 0 ? 0.0 : (votes / totalVotes).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: showResults && voters.isNotEmpty ? 66 : 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
              width: selected ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: showResults ? ratio : 0,
                child: ColoredBox(
                  color: selected
                      ? const Color(0x332563EB)
                      : const Color(0xFFEFF4FF),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 0, 12, showResults && voters.isNotEmpty ? 18 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.12, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: showResults
                          ? Padding(
                              key: const ValueKey('poll-percent'),
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '$percent%',
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('poll-percent-hidden'),
                            ),
                    ),
                  ],
                ),
              ),
              if (showResults && voters.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 7,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _PollVoterAvatarStack(
                      key: ValueKey('poll-voters-${voters.length}'),
                      voters: voters,
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

class _PollVoterAvatarStack extends StatelessWidget {
  const _PollVoterAvatarStack({required this.voters, super.key});

  final List<PollVoterPreview> voters;

  @override
  Widget build(BuildContext context) {
    final visible = voters.take(5).toList(growable: false);
    final extra = voters.length - visible.length;
    const avatarSize = 22.0;
    const overlap = 14.0;
    final width = visible.isEmpty
        ? 0.0
        : avatarSize + ((visible.length - 1) * overlap) + (extra > 0 ? 30 : 0);

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * overlap,
              child: _PollVoterAvatar(voter: visible[index], size: avatarSize),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * overlap,
              child: Container(
                width: 28,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PollVoterAvatar extends StatelessWidget {
  const _PollVoterAvatar({required this.voter, required this.size});

  final PollVoterPreview voter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = voter.avatarUrl.trim();
    return Tooltip(
      message: voter.displayName,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE5E7EB),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl.isEmpty
            ? Center(
                child: Text(
                  voter.initials,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                ApiConfig.assetUrl(avatarUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    voter.initials,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MusicPhotoCarousel extends StatefulWidget {
  const _MusicPhotoCarousel({
    required this.post,
    required this.activeIndex,
    required this.onPageChanged,
    this.onImageTap,
    this.onMediaReady,
  });

  final Post post;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onImageTap;
  final VoidCallback? onMediaReady;

  @override
  State<_MusicPhotoCarousel> createState() => _MusicPhotoCarouselState();
}

class _MusicPhotoCarouselState extends State<_MusicPhotoCarousel> {
  static const String _swipeHintSeenKey = 'seen_carousel_swipe_hint_v1';
  final Map<int, double> _loadedAspectRatios = {};

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _loadedUrl;
  bool _hasUserRequestedPlay = false;
  bool _isPlaying = false;
  bool _audioUnavailable = false;
  bool _userPaused = false;
  bool _showSwipeHint = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.activeIndex,
      keepPage: false,
    );
    _maybeShowSwipeHint();
  }

  Future<void> _maybeShowSwipeHint() async {
    if (widget.post.imageUrls.length <= 1) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_swipeHintSeenKey) == true) return;
      if (!mounted) return;
      setState(() => _showSwipeHint = true);
    } catch (_) {}
  }

  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    if (mounted) {
      setState(() => _showSwipeHint = false);
    }
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_swipeHintSeenKey, true))
        .catchError((_) => false);
  }

  @override
  void didUpdateWidget(_MusicPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.musicPreviewUrl.trim() !=
        widget.post.musicPreviewUrl.trim()) {
      _hasUserRequestedPlay = false;
      _isPlaying = false;
      _audioUnavailable = false;
      _userPaused = false;
      unawaited(_disposePlayer());
    }
    if (widget.activeIndex != oldWidget.activeIndex &&
        _pageController.hasClients &&
        _pageController.page?.round() != widget.activeIndex) {
      _pageController.jumpToPage(widget.activeIndex);
    }
  }

  Future<bool> _ensurePlayer() async {
    final rawUrl = widget.post.musicPreviewUrl.trim();
    if (rawUrl.isEmpty) {
      await _disposePlayer();
      return false;
    }

    final url = _resolveAudioUrl(rawUrl);
    if (_loadedUrl == url && _player != null) {
      return true;
    }

    await _disposePlayer();
    final player = AudioPlayer();
    _player = player;
    _loadedUrl = url;
    _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    try {
      await player.setReleaseMode(ReleaseMode.loop);
      // Force audio/mp4 mime hint so MediaPlayer ignores Apple's misleading
      // "audio/x-m4p" Content-Type and picks the correct AAC extractor.
      await player.setSourceUrl(url, mimeType: 'audio/mp4');
      return true;
    } catch (error, stackTrace) {
      debugPrint('MusicPhotoCarousel: failed to load $url -> $error');
      debugPrintStack(stackTrace: stackTrace);
      await _disposePlayer();
      if (!mounted) return false;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
      return false;
    }
  }

  String _resolveAudioUrl(String rawUrl) {
    if (!kIsWeb &&
        (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
      return rawUrl;
    }
    return ApiConfig.assetUrl(rawUrl);
  }

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    _loadedUrl = null;
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      unawaited(player.dispose());
    }
  }

  void _handleVisibility(VisibilityInfo info) {
    final player = _player;
    if (info.visibleFraction >= 0.55) {
      // Autoplay on mobile when the carousel scrolls into view, unless the
      // user explicitly paused it. Web browsers block autoplay-with-sound
      // until a user gesture, so there we keep the original tap-to-play.
      final shouldAutoplay = !kIsWeb && !_userPaused && !_audioUnavailable;
      if ((_hasUserRequestedPlay || shouldAutoplay) &&
          player?.state != PlayerState.playing) {
        unawaited(_playPlayer());
      }
    } else if (info.visibleFraction <= 0.05) {
      if (player != null && player.state == PlayerState.playing) {
        unawaited(player.pause());
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _playPlayer() async {
    if (_audioUnavailable) return;
    final isReady = await _ensurePlayer();
    final player = _player;
    if (!isReady || player == null) return;
    try {
      await player.resume();
    } catch (_) {
      await _disposePlayer();
      if (!mounted) return;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
    }
  }

  Future<void> _toggleAudio() async {
    if (_audioUnavailable) return;
    final player = _player;
    if (player?.state == PlayerState.playing) {
      _hasUserRequestedPlay = false;
      _userPaused = true;
      await player!.pause();
      return;
    }

    _hasUserRequestedPlay = true;
    _userPaused = false;
    await _playPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final images = post.imageUrls;
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final ratio = _carouselAspectRatio();
        final height = width / ratio;

        return VisibilityDetector(
          key: ValueKey('music-carousel-${post.id}'),
          onVisibilityChanged: _handleVisibility,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    _dismissSwipeHint();
                    widget.onPageChanged(index);
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onImageTap?.call(index),
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.assetUrl(images[index]),
                        fit: BoxFit.contain,
                        imageBuilder: (context, provider) {
                          widget.onMediaReady?.call();
                          _resolveImageRatio(index, provider);
                          return Image(
                            image: provider,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                        placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFEDEFF3),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF8A8D91),
                            size: 34,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: _CarouselCountPill(
                    current: widget.activeIndex + 1,
                    total: images.length,
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: _CarouselDots(
                      count: images.length,
                      activeIndex: widget.activeIndex,
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: _CarouselMusicButton(
                    isPlaying: _isPlaying,
                    isUnavailable: _audioUnavailable,
                    onTap: _toggleAudio,
                  ),
                ),
                if (_showSwipeHint && images.length > 1)
                  Positioned.fill(
                    child: _CarouselSwipeHint(onDismiss: _dismissSwipeHint),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resolveImageRatio(int index, ImageProvider provider) {
    if (_loadedAspectRatios.containsKey(index)) return;

    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      final double width = info.image.width.toDouble();
      final double height = info.image.height.toDouble();
      if (width > 0 && height > 0) {
        final double ratio = width / height;
        if (_loadedAspectRatios[index] != ratio) {
          setState(() {
            _loadedAspectRatios[index] = ratio;
          });
        }
      }
      stream.removeListener(listener);
    }, onError: (exception, stackTrace) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  double _carouselAspectRatio() {
    final activeIndex = widget.activeIndex.clamp(0, widget.post.imageUrls.length - 1);
    if (activeIndex < 0) return 1.0;

    // First check if we have a dynamically loaded aspect ratio
    if (_loadedAspectRatios.containsKey(activeIndex)) {
      return _loadedAspectRatios[activeIndex]!;
    }

    // Fallback to database aspect ratio
    if (widget.post.imageAspectRatios.length > activeIndex) {
      final dbRatio = widget.post.imageAspectRatios[activeIndex];
      if (dbRatio != null && dbRatio > 0) {
        return dbRatio.toDouble();
      }
    }

    return 1.0;
  }
}

class _CarouselSwipeHint extends StatefulWidget {
  const _CarouselSwipeHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_CarouselSwipeHint> createState() => _CarouselSwipeHintState();
}

class _CarouselSwipeHintState extends State<_CarouselSwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _fadeTimer;
  Timer? _dismissTimer;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
    _fadeTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _opacity = 0);
    });
    _dismissTimer = Timer(const Duration(milliseconds: 3500), widget.onDismiss);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 400),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(-20 * t, 0),
                child: child,
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.swipe_left_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Swipe to see more',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselMusicButton extends StatelessWidget {
  const _CarouselMusicButton({
    required this.isPlaying,
    required this.isUnavailable,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isUnavailable;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final icon = isUnavailable
        ? Icons.music_off_rounded
        : isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;
    final tooltip = isUnavailable
        ? 'Music unavailable'
        : isPlaying
            ? 'Pause music'
            : 'Play music';

    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            isUnavailable ? const Color(0x66000000) : const Color(0xB3000000),
        shape: const CircleBorder(),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          iconSize: 23,
          color: Colors.white,
          disabledColor: const Color(0x99FFFFFF),
          onPressed: isUnavailable ? null : () => unawaited(onTap()),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _CarouselCountPill extends StatelessWidget {
  const _CarouselCountPill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$current/$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == activeIndex ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _CuteHeartWingBadge extends StatelessWidget {
  const _CuteHeartWingBadge({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final heartSize = large ? 34.0 : 24.0;
    final wingHeight = large ? 18.0 : 13.0;
    final wingWidth = large ? 14.0 : 10.0;
    final sparkleSize = large ? 8.0 : 6.0;

    Widget wing({required bool left}) {
      final feathers = [0.0, 5.0, 10.0];
      return SizedBox(
        width: wingWidth + 10,
        height: wingHeight + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final offset in feathers)
              Positioned(
                left: left ? null : offset,
                right: left ? offset : null,
                top: offset * 0.35,
                child: Transform.rotate(
                  angle: left ? -0.55 : 0.55,
                  child: Container(
                    width: wingWidth,
                    height: wingHeight - (offset * 0.22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFF0C8DA),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: large ? 84 : 62,
      height: large ? 54 : 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            left: large ? 0 : 2,
            top: large ? 9 : 7,
            child: wing(left: true),
          ),
          Positioned(
            right: large ? 18 : 12,
            top: large ? 9 : 7,
            child: wing(left: false),
          ),
          Positioned(
            right: 0,
            top: large ? 8 : 6,
            child: Container(
              width: large ? 42 : 30,
              height: large ? 42 : 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF0C5D7),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: const Color(0xFFF472B6),
                size: heartSize,
              ),
            ),
          ),
          Positioned(
            right: large ? 34 : 25,
            top: 0,
            child: Icon(
              Icons.auto_awesome,
              color: const Color(0xFFF9A8D4),
              size: sparkleSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _YouTubePreviewCard extends StatelessWidget {
  const _YouTubePreviewCard({
    required this.preview,
    required this.onTap,
    this.onTapDown,
  });

  final LinkPreview preview;
  final Future<void> Function() onTap;
  final VoidCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : 'YouTube video';
    final description = preview.description.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown?.call(),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    memCacheWidth: 800,
                    maxWidthDiskCache: 800,
                    placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                else
                  _fallback(),
                Container(
                  color: Colors.black.withValues(alpha: 0.22),
                ),
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCCDC2626),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B3B8)
                      : const Color(0xFF65676B),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Color(0xFF65676B),
          size: 44,
        ),
      ),
    );
  }
}

class _LinkPreviewCard extends StatelessWidget {
  const _LinkPreviewCard({
    required this.preview,
    required this.onTap,
    this.onTapDown,
    this.isYouTube = false,
  });

  final LinkPreview preview;
  final Future<void> Function() onTap;
  final VoidCallback? onTapDown;
  final bool isYouTube;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : preview.domain.trim();
    final description = preview.description.trim();
    final domain = preview.domain.trim().isNotEmpty
        ? preview.domain.trim()
        : preview.url.trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTapDown: (_) => onTapDown?.call(),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 1.91,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: 800,
                      maxWidthDiskCache: 800,
                      placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) => _linkFallback(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isYouTube) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'YouTube',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                          fontSize: 13,
                          height: 1.3,
                        ),
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

  Widget _linkFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(
          isYouTube ? Icons.play_circle_outline_rounded : Icons.link_rounded,
          color: const Color(0xFF65676B),
          size: 34,
        ),
      ),
    );
  }
}

class VideoPreviewCard extends StatefulWidget {
  const VideoPreviewCard({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  State<VideoPreviewCard> createState() => VideoPreviewCardState();
}

class VideoPreviewCardState extends State<VideoPreviewCard> {
  bool _wasMostlyVisible = false;

  @override
  void initState() {
    super.initState();
    normalVideoPlaybackSession.addListener(_handleSessionChanged);
  }

  @override
  void dispose() {
    normalVideoPlaybackSession.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.6;
    final hidden = info.visibleFraction <= 0.05;
    final session = normalVideoPlaybackSession;

    if (hidden) {
      _wasMostlyVisible = false;
      if (session.isActivePost(widget.post.id) &&
          !session.viewerOpen &&
          session.controller != null &&
          session.controller!.value.isInitialized) {
        session.pause();
      }
      return;
    }

    if (visible && !_wasMostlyVisible) {
      _wasMostlyVisible = true;

      // The fullscreen viewer owns playback while it is open.
      if (session.viewerOpen) {
        return;
      }

      final alreadyActive = session.isActivePost(widget.post.id) &&
          session.controller != null &&
          session.controller!.value.isInitialized;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || session.viewerOpen) return;
        if (alreadyActive) {
          // Resume the already-loaded inline video.
          normalVideoPlaybackSession.play(muted: normalVideoMuted());
        } else {
          // FB-style: autoplay the video that scrolls into view. Muted on web
          // (browser autoplay policy), with sound on mobile.
          normalVideoPlaybackSession.activate(
            widget.post,
            play: true,
            muted: normalVideoMuted(),
            reason: 'feed inline autoplay',
          );
        }
      });
    }
  }

  bool _isInlineVideoEnded(VideoPlayerController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return false;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;

    if (duration <= Duration.zero) {
      return false;
    }

    return position >= duration - const Duration(milliseconds: 350);
  }

  Future<void> _playInlineAgain() async {
    await normalVideoPlaybackSession.seek(Duration.zero);
    await normalVideoPlaybackSession.play(muted: normalVideoMuted());
  }

  void _shareInlineVideo(Post post) {
    final url = post.videoUrl.trim();
    if (url.isEmpty) {
      return;
    }

    Clipboard.setData(
      ClipboardData(text: ApiConfig.assetUrl(url)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video link copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildInlineEndedOverlay(Post post) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.38),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InlineEndActionButton(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  onTap: () => normalVideoOverlayController.open(
                    post,
                    initialPosition: normalVideoPlaybackSession.position,
                  ),
                ),
                _InlineEndActionButton(
                  icon: Icons.replay_rounded,
                  label: 'Play again',
                  onTap: _playInlineAgain,
                  isPrimary: true,
                ),
                _InlineEndActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _shareInlineVideo(post),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final posterUrl = post.primaryVideoPosterUrl;
    final rawRatio = post.mediaAspectRatio ??
        post.aspectRatio ??
        ((post.videoWidth != null &&
                post.videoHeight != null &&
                post.videoHeight! > 0)
            ? post.videoWidth! / post.videoHeight!
            : 1.0);

    final previewRatio = rawRatio < 1 ? 4 / 5 : rawRatio.clamp(1.0, 1.91);

    final session = normalVideoPlaybackSession;
    final controller = session.controller;
    final showInlineVideo = session.isActivePost(post.id) &&
        !session.viewerOpen &&
        controller != null &&
        controller.value.isInitialized;
    final isEnded = showInlineVideo && _isInlineVideoEnded(controller);
    if (showInlineVideo) {
      MediaPostLoadRegistry.markReady(post.id);
    }

    return VisibilityDetector(
      key: ValueKey('normal-video-${post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isEnded) {
            return;
          }

          if (showInlineVideo && !session.isPlaying) {
            normalVideoPlaybackSession.play(muted: normalVideoMuted());
            return;
          }

          normalVideoOverlayController.open(
            post,
            initialPosition: showInlineVideo ? session.position : Duration.zero,
          );
        },
        child: AspectRatio(
          aspectRatio: previewRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showInlineVideo)
                IgnorePointer(
                  ignoring: true,
                  child: _InlineVideoCover(controller: controller),
                )
              else if (posterUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: ApiConfig.assetUrl(posterUrl),
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  memCacheWidth: 800,
                  maxWidthDiskCache: 800,
                  imageBuilder: (context, imageProvider) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      MediaPostLoadRegistry.markReady(post.id);
                    });
                    return Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    );
                  },
                  placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                  errorWidget: (_, __, ___) => _videoFallback(),
                )
              else
                _videoFallback(),
              if (!showInlineVideo)
                Container(
                  color: Colors.black.withOpacity(0.18),
                ),
              if ((!showInlineVideo || !session.isPlaying) && !isEnded)
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              if (isEnded) _buildInlineEndedOverlay(post),
              if (showInlineVideo && !isEnded)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: normalVideoMutedNotifier,
                    builder: (context, muted, __) {
                      return _InlineSoundButton(
                        muted: muted,
                        onTap: () => setNormalVideoMuted(!muted),
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

  Widget _videoFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Icon(
        Icons.videocam_outlined,
        color: Color(0xFF65676B),
        size: 42,
      ),
    );
  }
}

class _InlineEndActionButton extends StatelessWidget {
  const _InlineEndActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isPrimary ? 62 : 52,
            height: isPrimary ? 62 : 52,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.white : Colors.black.withOpacity(0.58),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.72),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.black : Colors.white,
              size: isPrimary ? 34 : 28,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineVideoCover extends StatelessWidget {
  const _InlineVideoCover({
    required this.controller,
  });

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return VideoPlayer(controller);
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _InlineSoundButton extends StatelessWidget {
  const _InlineSoundButton({
    required this.muted,
    required this.onTap,
  });

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      shape: muted ? const StadiumBorder() : const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: muted ? 12 : 8,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
              if (muted) ...[
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Text(
                    'Tap for sound',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onOpenAuthor,
    required this.onMore,
    this.showFollowButton = false,
    this.isFollowPending = false,
    this.onFollow,
    this.onHide,
    this.isHiding = false,
  });

  final Post post;
  final VoidCallback onOpenAuthor;
  final VoidCallback onMore;
  final bool showFollowButton;
  final bool isFollowPending;
  final VoidCallback? onFollow;
  final VoidCallback? onHide;
  final bool isHiding;

  @override
  Widget build(BuildContext context) {
    final themeKey = (post.authorPostcardTheme ?? '').trim().toLowerCase();

    // Determine if the applied theme is a dark background theme.
    final isDarkTheme = themeKey == 'ocean' ||
        (Theme.of(context).brightness == Brightness.dark && themeKey.isEmpty);

    // Text and icon colors
    final nameColor = isDarkTheme ? Colors.white : const Color(0xFF1C1E21);
    final metaColor = isDarkTheme
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF65676B);
    final verifiedIconColor = const Color(0xFF1D9BF0);
    final followColor = const Color(0xFFFF7A45);
    final actionIconColor =
        isDarkTheme ? Colors.white : const Color(0xFF374151);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onOpenAuthor,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: post.authorAvatarUrl.trim().isEmpty
                ? null
                : CachedNetworkImageProvider(
                    ApiConfig.assetUrl(post.authorAvatarUrl)),
            child: post.authorAvatarUrl.trim().isEmpty
                ? Text(
                    post.authorInitials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1E21),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: onOpenAuthor,
                            child: Text(
                              post.authorFullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                  color: nameColor),
                            ),
                          ),
                        ),
                        if (post.feeling.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            'is feeling',
                            style: TextStyle(
                              fontSize: 13,
                              color: metaColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.feeling,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: nameColor,
                            ),
                          ),
                        ],
                        if (post.authorIsVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            color: verifiedIconColor,
                            size: 16,
                          ),
                        ],
                        if (showFollowButton && onFollow != null) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: isFollowPending ? null : onFollow,
                            child: SizedBox(
                              height: 16,
                              child: Center(
                                child: isFollowPending
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: followColor,
                                        ),
                                      )
                                    : Text(
                                        'Follow',
                                        style: TextStyle(
                                          color: followColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.0,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (post.withUsers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      PostWithUsersLine(
                        users: post.withUsers,
                        prefix: 'is — with ',
                        prefixHighlight: '— with',
                        prefixHighlightStyle: TextStyle(
                          color: nameColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        linkStyle: TextStyle(
                          color: nameColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        onUserTap: (username) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(username: username),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _formatTimestamp(post.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '·',
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(
                          _privacyIcon(post.visibility),
                          color: metaColor,
                          size: 13,
                        ),
                        if (post.location.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: Colors.red.shade400,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              post.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (post.hasMusicPreview &&
                            post.musicTitle.trim().isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.music_note_rounded,
                            color: metaColor,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              post.musicTitle.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (post.originalPost != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          CustomIcons.repost(size: 12, color: metaColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              post.originalPost!.authorFullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          if (post.originalPost!.authorIsVerified) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.verified,
                              color: verifiedIconColor,
                              size: 13,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onHide != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: isHiding ? null : onHide,
                        iconSize: 18,
                        color: actionIconColor,
                        icon: isHiding
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: actionIconColor,
                                ),
                              )
                            : const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onMore,
                      iconSize: 18,
                      color: actionIconColor,
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Now';
    }

    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) {
      return 'Now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthLabel = monthNames[createdAt.month - 1];
    final sameYear = createdAt.year == DateTime.now().year;

    if (sameYear) {
      return '$monthLabel ${createdAt.day}';
    }

    return '$monthLabel ${createdAt.day}, ${createdAt.year}';
  }

  IconData _privacyIcon(String visibility) {
    switch (visibility) {
      case 'friends':
        return Icons.people_alt_rounded;
      case 'only_me':
        return Icons.lock_rounded;
      default:
        return Icons.public_rounded;
    }
  }
}

class _PostActionItem {
  const _PostActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Future<void> Function() onTap;
  final bool isDestructive;
}

class _PostOptionsSheet extends StatelessWidget {
  const _PostOptionsSheet({
    required this.actions,
  });

  final List<_PostActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF7F7F7),
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
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      _PostOptionsRow(action: actions[index]),
                      if (index != actions.length - 1)
                        Divider(
                          height: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2F3031)
                              : const Color(0xFFE5E7EB),
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
  }
}

class _PostOptionsRow extends StatelessWidget {
  const _PostOptionsRow({
    required this.action,
  });

  final _PostActionItem action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive
        ? const Color(0xFFDC2626)
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        await action.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(action.icon, color: color, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (action.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle!,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B3B8)
                            : const Color(0xFF65676B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletePostSheet extends StatelessWidget {
  const _DeletePostSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF7F7F7);
    final handleBg = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final innerBg = isDark ? const Color(0xFF242526) : Colors.white;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final bodyColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B);
    final cancelFg = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF1C1E21);
    final cancelBorder = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: containerBg,
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
                color: handleBg,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: innerBg,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete post?',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This post will be permanently deleted. This can\'t be undone.',
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cancelFg,
                                side: BorderSide(color: cancelBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Delete'),
                            ),
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
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onRepost,
    required this.onBookmark,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onRepost;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFF65676B);
    const likedColor = Color(0xFFE11D48);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionIcon(
          icon: post.likedByMe
              ? CustomIcons.heartFilled(color: likedColor, size: 23)
              : CustomIcons.heart(color: inactiveColor, size: 23),
          count: post.likeCount,
          color: post.likedByMe ? likedColor : inactiveColor,
          onTap: onLike,
        ),
        const SizedBox(width: 24),
        _ActionIcon(
          icon: CustomIcons.comment(color: inactiveColor, size: 23),
          count: post.commentCount,
          onTap: onComment,
        ),
        const SizedBox(width: 24),
        _ActionIcon(
          icon: CustomIcons.repost(color: inactiveColor, size: 23),
          count: post.repostCount,
          onTap: onRepost,
        ),
        const SizedBox(width: 24),
        _ActionIcon(
          icon: CustomIcons.share(color: inactiveColor, size: 23),
          count: 0,
          onTap: onShare,
        ),
        const Spacer(),
        _ActionIcon(
          icon: CustomIcons.bookmark(
            color: post.bookmarkedByMe
                ? Theme.of(context).colorScheme.primary
                : inactiveColor,
            size: 23,
            isFilled: post.bookmarkedByMe,
          ),
          count: 0,
          onTap: onBookmark,
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
    this.color = const Color(0xFF65676B),
    this.onTap,
  });

  final Widget icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  String _formatCount(int value) {
    if (value >= 1000000) {
      double val = value / 1000000.0;
      String str = val.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}M';
    }
    if (value >= 1000) {
      double val = value / 1000.0;
      String str = val.toStringAsFixed(1);
      if (str.endsWith('.0')) str = str.substring(0, str.length - 2);
      return '${str}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: ColoredBox(
        color: Color(0xFFE6EBF2),
        child: SizedBox.expand(),
      ),
    );
  }
}
