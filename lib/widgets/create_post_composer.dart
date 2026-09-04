import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../services/post_service.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../services/youtube_service.dart';
import '../screens/youtube_search_screen.dart';
import '../utils/emoji_presentation.dart';
import 'post_with_users_picker.dart';
import 'special_name_text.dart';
import 'user_avatar_with_frame.dart';

enum _CreateMode {
  post,
  discussion,
  album,
  poll,
  reel,
}

class CreatePostComposer extends StatefulWidget {
  const CreatePostComposer({
    required this.user,
    required this.onPostCreated,
    this.initialYouTubeVideo,
    super.key,
  });

  final User user;
  final VoidCallback onPostCreated;
  final YouTubeVideoItem? initialYouTubeVideo;

  @override
  State<CreatePostComposer> createState() => _CreatePostComposerState();
}

class _CreatePostComposerState extends State<CreatePostComposer> {
  final _controller = TextEditingController();
  final _titleController = TextEditingController();
  final _canPostNotifier = ValueNotifier<bool>(false);
  final _postService = PostService();

  _CreateMode _mode = _CreateMode.post;
  String _visibility = 'public';
  bool _isSensitive = false;
  bool _isGhost = false;
  List<SelectedPostImage> _images = [];
  List<User> _withUsers = [];
  String _location = '';
  String _feeling = '';
  bool _isDetectingLocation = false;
  List<String> _pollOptions = ['', ''];
  int _pollDurationHours = 24;
  SelectedPostImage? _discussionCover;
  List<SelectedPostImage> _reelImages = [];
  PreparedVideo? _selectedVideo;
  YouTubeVideoItem? _attachedYouTubeVideo;
  _SelectedComposerMusic? _selectedMusic;
  _SelectedComposerMusic? _selectedReelMusic;
  bool _isPickingImages = false;
  bool _isPickingVideo = false;
  bool _isPosting = false;
  String? _errorMessage;
  String? _progressMessage;
  double? _progressValue;
  bool _isGeneratingCaption = false;
  final _geminiService = GeminiService();

  static const _audienceOptions = [
    _AudienceOption(
      value: 'public',
      label: 'Public',
      description: 'Anyone can see this post.',
      icon: Icons.public,
    ),
    _AudienceOption(
      value: 'friends',
      label: 'Friends',
      description: 'People who follow you can see this post.',
      icon: Icons.group_outlined,
    ),
    _AudienceOption(
      value: 'only_me',
      label: 'Only me',
      description: 'Only you can see this post.',
      icon: Icons.lock_outline,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _attachedYouTubeVideo = widget.initialYouTubeVideo;
    _controller.addListener(_syncCanPostState);
    _titleController.addListener(_syncCanPostState);
    if (_attachedYouTubeVideo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncCanPostState();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncCanPostState);
    _titleController.removeListener(_syncCanPostState);
    _controller.dispose();
    _titleController.dispose();
    _canPostNotifier.dispose();
    super.dispose();
  }

  void _syncCanPostState() {
    final imagesReady = _images.every((image) => image.isReady);
    final body = _controller.text.trim();
    final title = _titleController.text.trim();
    final canPost = switch (_mode) {
      _CreateMode.post => (body.isNotEmpty ||
              _images.any((image) => image.isReady) ||
              _selectedVideo != null ||
              _attachedYouTubeVideo != null) &&
          imagesReady,
      _CreateMode.discussion => title.isNotEmpty &&
          body.isNotEmpty &&
          (_discussionCover == null || _discussionCover!.isReady),
      _CreateMode.album => imagesReady &&
          _images.where((image) => image.isReady).length >= 2,
      _CreateMode.poll => body.isNotEmpty && _cleanPollOptions().length >= 2,
      _CreateMode.reel => _reelImages.every((image) => image.isReady) &&
          (_reelImages.any((image) => image.isReady) ||
              _selectedVideo != null),
    };
    if (_canPostNotifier.value != canPost) {
      _canPostNotifier.value = canPost;
    }
  }

  String get _bodyPlaceholder {
    return switch (_mode) {
      _CreateMode.post => 'Share your thoughts...',
      _CreateMode.discussion => 'Write your topic, blog, or announcement...',
      _CreateMode.album => 'Add a caption for your carousel...',
      _CreateMode.poll => 'Ask a poll question...',
      _CreateMode.reel => 'Add a caption for your reel...',
    };
  }

  String get _headerTitle {
    return switch (_mode) {
      _CreateMode.post => 'Create a post',
      _CreateMode.discussion => 'Create Discussion',
      _CreateMode.album => 'Create carousel',
      _CreateMode.poll => 'Create poll',
      _CreateMode.reel => 'Add Reels',
    };
  }

  String get _submitLabel {
    if (_isPickingImages) {
      return 'Preparing images...';
    }
    if (_isPickingVideo) {
      return 'Preparing video...';
    }
    if (_isPosting) {
      return 'Posting...';
    }

    return switch (_mode) {
      _CreateMode.post => 'Post',
      _CreateMode.discussion => 'Publish',
      _CreateMode.album => 'Post carousel',
      _CreateMode.poll => 'Post poll',
      _CreateMode.reel => 'Post Reel',
    };
  }

  void _setMode(_CreateMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _progressMessage = null;
      _progressValue = null;
      _controller.clear();
      _titleController.clear();
      _images = [];
      _pollOptions = ['', ''];
      _pollDurationHours = 24;
      _discussionCover = null;
      _reelImages = [];
      _selectedVideo = null;
      _attachedYouTubeVideo = null;
      _selectedMusic = null;
      _selectedReelMusic = null;
      _isSensitive = false;
      _isGhost = false;
      if (mode == _CreateMode.discussion || mode == _CreateMode.reel) {
        _visibility = 'public';
      }
    });
    _syncCanPostState();
  }

  void _handleProgress(CreatePostProgress progress) {
    if (!mounted) return;
    setState(() {
      _progressMessage = progress.message;
      _progressValue = progress.progress;
    });
  }

  List<String> _cleanPollOptions() {
    return _pollOptions
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
  }

  void _setPollOption(int index, String value) {
    if (index < 0 || index >= _pollOptions.length) return;
    _pollOptions[index] = value;
    _syncCanPostState();
  }

  void _addPollOption() {
    if (_pollOptions.length >= 6) return;
    setState(() {
      _pollOptions = [..._pollOptions, ''];
    });
    _syncCanPostState();
  }

  void _removePollOption(int index) {
    if (_pollOptions.length <= 2 || index < 0 || index >= _pollOptions.length) {
      return;
    }
    setState(() {
      _pollOptions = [
        for (var i = 0; i < _pollOptions.length; i++)
          if (i != index) _pollOptions[i],
      ];
    });
    _syncCanPostState();
  }

  Future<void> _openMusicPicker() async {
    final selected = await _showComposerMusicPicker(
      context,
      currentSelection: _selectedMusic,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedMusic = selected;
      _errorMessage = null;
    });
    _syncCanPostState();
  }

  Future<void> _pickImages() async {
    setState(() {
      _isPickingImages = true;
      _errorMessage = null;
      _progressMessage = 'Preparing selected images...';
      _progressValue = null;
    });

    try {
      await _postService.pickImages(
        onProgress: _handleProgress,
        onImageSelected: (image) {
          if (!mounted) return;
          setState(() {
            _images = [..._images, image].take(10).toList();
          });
          _syncCanPostState();
        },
        onImageUpdated: (image) {
          if (!mounted) return;
          setState(() {
            _images = _images
                .map((current) => current.id == image.id ? image : current)
                .toList();
          });
          _syncCanPostState();
        },
      );
      if (!mounted) return;
      _syncCanPostState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to select images: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
          _progressMessage = null;
          _progressValue = null;
        });
      }
    }
  }

  Future<void> _pickDiscussionCover() async {
    setState(() {
      _isPickingImages = true;
      _errorMessage = null;
      _progressMessage = 'Preparing cover image...';
      _progressValue = null;
    });

    try {
      await _postService.pickSinglePreparedImage(
        onProgress: _handleProgress,
        onImageSelected: (image) {
          if (!mounted) return;
          setState(() {
            _discussionCover = image;
          });
          _syncCanPostState();
        },
        onImageUpdated: (image) {
          if (!mounted) return;
          setState(() {
            _discussionCover = image;
          });
          _syncCanPostState();
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to select cover image: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
          _progressMessage = null;
          _progressValue = null;
        });
      }
    }
  }

  Future<void> _pickReelImages() async {
    setState(() {
      _isPickingImages = true;
      _errorMessage = null;
      _progressMessage = 'Preparing reel images...';
      _progressValue = null;
      _selectedVideo = null;
    });

    try {
      await _postService.pickImages(
        onProgress: _handleProgress,
        onImageSelected: (image) {
          if (!mounted) return;
          setState(() {
            _reelImages = [..._reelImages, image].take(10).toList();
          });
          _syncCanPostState();
        },
        onImageUpdated: (image) {
          if (!mounted) return;
          setState(() {
            _reelImages = _reelImages
                .map((current) => current.id == image.id ? image : current)
                .toList();
          });
          _syncCanPostState();
        },
      );
      if (!mounted) return;
      _syncCanPostState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to select reel images: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
          _progressMessage = null;
          _progressValue = null;
        });
      }
    }
  }

  void _removeReelImage(int index) {
    setState(() {
      _reelImages = [
        for (var i = 0; i < _reelImages.length; i++)
          if (i != index) _reelImages[i],
      ];
    });
    _syncCanPostState();
  }

  Future<void> _openReelMusicPicker() async {
    final selected = await _showComposerMusicPicker(
      context,
      currentSelection: _selectedReelMusic,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedReelMusic = selected;
      _errorMessage = null;
    });
    _syncCanPostState();
  }

  Future<void> _pickVideo() async {
    setState(() {
      _isPickingVideo = true;
      _errorMessage = null;
      _progressMessage = 'Preparing video...';
      _progressValue = null;
    });

    try {
      final video = await _postService.pickVideo(onProgress: _handleProgress);
      if (!mounted) return;
      if (video != null) {
        setState(() {
          _selectedVideo = video;
          if (_mode == _CreateMode.reel) {
            _reelImages = [];
          }
        });
      }
      _syncCanPostState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to select video: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingVideo = false;
          _progressMessage = null;
          _progressValue = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    var text = _controller.text.trim();
    if (_attachedYouTubeVideo != null) {
      final ytUrl =
          'https://www.youtube.com/watch?v=${_attachedYouTubeVideo!.id}';
      if (text.isEmpty) {
        text = ytUrl;
      } else if (!text.contains(_attachedYouTubeVideo!.id)) {
        text = '$text\n\n$ytUrl';
      }
    }
    final title = _titleController.text.trim();

    if (_mode == _CreateMode.poll &&
        (text.isEmpty || _cleanPollOptions().length < 2)) {
      setState(() {
        _errorMessage = 'Add a poll question and at least two options.';
      });
      return;
    }

    if (_mode == _CreateMode.album &&
        _images.where((image) => image.isReady).length < 2) {
      setState(() {
        _errorMessage = 'Add at least two photos for a carousel.';
      });
      return;
    }

    if (_images.any((image) => !image.isReady) ||
        (_discussionCover != null && !_discussionCover!.isReady) ||
        _reelImages.any((image) => !image.isReady)) {
      setState(() {
        _errorMessage =
            'Please remove failed images or wait until all media is ready.';
      });
      return;
    }

    setState(() {
      _isPosting = true;
      _errorMessage = null;
      _progressMessage = 'Posting...';
      _progressValue = null;
    });

    final result = await _postService.createPost(
      CreatePostRequest(
        text: text,
        visibility: _visibility,
        images: _images,
        isSensitive: _isSensitive,
        isGhost: _isGhost,
        onProgress: _handleProgress,
        withUserIds: _withUsers.map((u) => u.id!).toList(),
        location: _location,
        feeling: _feeling,
        albumTitle: _mode == _CreateMode.album ? 'Carousel' : null,
        isDiscussion: _mode == _CreateMode.discussion,
        discussionTitle: _mode == _CreateMode.discussion ? title : null,
        discussionCoverDataUrl:
            _mode == _CreateMode.discussion && _discussionCover?.isReady == true
                ? _discussionCover!.dataUrl
                : null,
        isPoll: _mode == _CreateMode.poll,
        pollQuestion: _mode == _CreateMode.poll ? text : null,
        pollOptions:
            _mode == _CreateMode.poll ? _cleanPollOptions() : const <String>[],
        pollDurationHours: _mode == _CreateMode.poll ? _pollDurationHours : 24,
        isReel: _mode == _CreateMode.reel,
        reelImages: _mode == _CreateMode.reel ? _reelImages : const [],
        videoDataUrl:
            _mode == _CreateMode.album ? null : _selectedVideo?.dataUrl,
        videoTitle: _mode == _CreateMode.album
            ? null
            : (_selectedVideo?.name ?? _attachedYouTubeVideo?.title),
        musicTitle: _mode == _CreateMode.album
            ? _selectedMusic?.title
            : _mode == _CreateMode.reel
                ? _selectedReelMusic?.title
                : null,
        musicArtist: _mode == _CreateMode.album
            ? _selectedMusic?.artist
            : _mode == _CreateMode.reel
                ? _selectedReelMusic?.artist
                : null,
        musicArtworkUrl: _mode == _CreateMode.album
            ? _selectedMusic?.artworkUrl
            : _mode == _CreateMode.reel
                ? _selectedReelMusic?.artworkUrl
                : null,
        musicPreviewUrl: _mode == _CreateMode.album
            ? _selectedMusic?.previewUrl
            : _mode == _CreateMode.reel
                ? _selectedReelMusic?.previewUrl
                : null,
        musicSource: _mode == _CreateMode.album
            ? _selectedMusic?.source
            : _mode == _CreateMode.reel
                ? _selectedReelMusic?.source
                : null,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isPosting = false;
      _errorMessage = result.error;
      _progressMessage = null;
      _progressValue = null;
    });

    if (result.ok) {
      // Calculate charm points before state is cleared
      int pointsGained = 2;
      String postType = 'Normal Post';
      if (_mode == _CreateMode.discussion) {
        pointsGained = 5;
        postType = 'Discussion';
      } else if (_mode == _CreateMode.reel) {
        pointsGained = 3;
        postType = 'Reel';
      } else if (_mode == _CreateMode.poll) {
        pointsGained = 2;
        postType = 'Poll';
      } else if (_images.length > 1) {
        pointsGained = 3;
        postType = 'Carousel Post';
      }

      // Add points to current user session
      unawaited(() async {
        try {
          final authService = AuthService();
          final currentUser = await authService.getSavedUser();
          if (currentUser != null) {
            final oldPoints = currentUser.charmPoints;
            final newPoints = oldPoints + pointsGained;
            final updatedUser = currentUser.copyWith(charmPoints: newPoints);
            await authService.saveCurrentUser(updatedUser);

            final oldLevel = currentUser.charmLevel;
            final newLevel = updatedUser.charmLevel;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFFF7A45),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          newLevel > oldLevel
                              ? 'LEVEL UP! You reached Lv.$newLevel! 🎉'
                              : 'Earned +$pointsGained Charm Points for $postType! ✨ (Total: $newPoints CP)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Notify streams
            FeedService.notifyProfileStatsChanged(
              username: updatedUser.username!,
              user: updatedUser,
            );
          }
        } catch (_) {}
      }());

      _controller.clear();
      setState(() {
        _titleController.clear();
        _images = [];
        _pollOptions = ['', ''];
        _pollDurationHours = 24;
        _discussionCover = null;
        _reelImages = [];
        _selectedVideo = null;
        _attachedYouTubeVideo = null;
        _selectedMusic = null;
        _selectedReelMusic = null;
        _visibility = 'public';
        _isSensitive = false;
        _isGhost = false;
        _withUsers = [];
        _location = '';
        _feeling = '';
      });
      _syncCanPostState();
      widget.onPostCreated();
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images = [
        for (var i = 0; i < _images.length; i++)
          if (i != index) _images[i],
      ];
    });
    _syncCanPostState();
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
      backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
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
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
                        leading: Text(emoji, style: TextStyle(fontSize: 22.sp)),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
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
      });
    }
  }

  Future<void> _handleLocationTap() async {
    if (_location.isNotEmpty) {
      final newLoc = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(text: _location);
          return AlertDialog(
            title: const Text('Edit Location'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter city, country',
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
          });
        } else if (city.isNotEmpty) {
          setState(() {
            _location = city;
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
    showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Location'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g. Manila, Philippines',
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
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAudience = _mode == _CreateMode.post ||
        _mode == _CreateMode.album ||
        _mode == _CreateMode.poll;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _canPostNotifier,
              builder: (context, canPost, _) {
                return _ComposerHeader(
                  title: _headerTitle,
                  isPosting: _isPosting || _isPickingImages || _isPickingVideo,
                  canPost: canPost,
                  onPost: _submit,
                  submitLabel: _submitLabel,
                );
              },
            ),
            _ModeSelector(
              value: _mode,
              onChanged: _isPosting || _isPickingImages || _isPickingVideo
                  ? null
                  : _setMode,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            UserAvatarWithFrame(
                              avatarUrl: widget.user.avatarUrl ?? '',
                              initials: widget.user.initials,
                              radius: 20.r,
                              isAdmin: widget.user.isAdmin,
                            ),
                            SizedBox(height: 6.h),
                            Expanded(
                              child: Container(
                                width: 2.w,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2D2E30)
                                      : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(1.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6.w,
                                runSpacing: 4.h,
                                children: [
                                  SpecialNameText(
                                    username: widget.user.username ?? '',
                                    displayName: widget.user.displayName,
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5.sp,
                                    ),
                                  ),
                                  if (_withUsers.isNotEmpty) ...[
                                    Text(
                                      'with',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Rounded',
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final selected = await showPostWithUsersPicker(
                                          context: context,
                                          initialSelected: _withUsers,
                                          currentUserId: widget.user.id,
                                        );
                                        if (selected != null) {
                                          setState(() => _withUsers = selected);
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _withUsers.length == 1
                                                ? _withUsers.first.displayName
                                                : '${_withUsers.first.displayName} and ${_withUsers.length - 1} other${_withUsers.length > 2 ? "s" : ""}',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Rounded',
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          GestureDetector(
                                            onTap: () => setState(() => _withUsers.clear()),
                                            behavior: HitTestBehavior.opaque,
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 13.r,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_feeling.isNotEmpty) ...[
                                    Text(
                                      'is feeling',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Rounded',
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _selectFeeling,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _feeling,
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Rounded',
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          GestureDetector(
                                            onTap: () => setState(() => _feeling = ''),
                                            behavior: HitTestBehavior.opaque,
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 13.r,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_location.isNotEmpty) ...[
                                    Text(
                                      'at',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Rounded',
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _handleLocationTap,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _location,
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Rounded',
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          GestureDetector(
                                            onTap: () => setState(() => _location = ''),
                                            behavior: HitTestBehavior.opaque,
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 13.r,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (showAudience)
                                    _AudienceDropdown(
                                      value: _visibility,
                                      options: _audienceOptions,
                                      onChanged: (val) => setState(() => _visibility = val),
                                    ),
                                  if (_isGhost && _mode == _CreateMode.post)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(10.r),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '👻 Ghost post',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Rounded',
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                          SizedBox(width: 3.w),
                                          GestureDetector(
                                            onTap: () => setState(() => _isGhost = false),
                                            behavior: HitTestBehavior.opaque,
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 12.r,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              if (_mode == _CreateMode.discussion) ...[
                                TextField(
                                  controller: _titleController,
                                  enabled: !_isPosting,
                                  maxLength: 200,
                                  cursorColor: const Color(0xFFFF7A45),
                                  inputFormatters: [EmojiPresentationFormatter()],
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Discussion Title...',
                                    hintStyle: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    counterText: '',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                              ],
                              if (_mode != _CreateMode.poll)
                                (_isGhost && _mode == _CreateMode.post)
                                    ? CustomPaint(
                                        painter: _GhostInputBubblePainter(
                                          color: isDark ? const Color(0xFF2B211E) : const Color(0xFFFFF3F0),
                                          borderColor: const Color(0xFFFF7A59),
                                          borderRadius: 16.r,
                                          strokeWidth: 1.5,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                          child: TextField(
                                            controller: _controller,
                                            enabled: !_isPosting,
                                            inputFormatters: [EmojiPresentationFormatter()],
                                            maxLines: null,
                                            minLines: 3,
                                            maxLength: 10000,
                                            cursorColor: const Color(0xFFFF7A45),
                                            textInputAction: TextInputAction.newline,
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Rounded',
                                              fontSize: 15.sp,
                                              height: 1.35,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: _bodyPlaceholder,
                                              hintStyle: TextStyle(
                                                fontFamily: 'SF Pro Rounded',
                                                color: const Color(0xFF9CA3AF),
                                                fontSize: 15.sp,
                                              ),
                                              counterText: '',
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                                            ),
                                          ),
                                        ),
                                      )
                                    : TextField(
                                        controller: _controller,
                                        enabled: !_isPosting,
                                        inputFormatters: [EmojiPresentationFormatter()],
                                        maxLines: null,
                                        minLines: 3,
                                        maxLength: 10000,
                                        cursorColor: const Color(0xFFFF7A45),
                                        textInputAction: TextInputAction.newline,
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Rounded',
                                          fontSize: 15.sp,
                                          height: 1.35,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _bodyPlaceholder,
                                          hintStyle: TextStyle(
                                            fontFamily: 'SF Pro Rounded',
                                            color: const Color(0xFF9CA3AF),
                                            fontSize: 15.sp,
                                          ),
                                          counterText: '',
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                                        ),
                                      ),
                              _buildAiSuggestionButton(),
                              if (_mode == _CreateMode.poll) ...[
                                _PollFields(
                                  questionController: _controller,
                                  options: _pollOptions,
                                  durationHours: _pollDurationHours,
                                  enabled: !_isPosting,
                                  onOptionChanged: _setPollOption,
                                  onAddOption: _pollOptions.length >= 6 ? null : _addPollOption,
                                  onRemoveOption: _pollOptions.length <= 2 ? null : _removePollOption,
                                  onDurationChanged: (val) => setState(() => _pollDurationHours = val),
                                ),
                              ],
                              if (_mode == _CreateMode.discussion && _discussionCover != null) ...[
                                SizedBox(height: 8.h),
                                _SingleImageCard(
                                  image: _discussionCover!,
                                  onRemove: _isPosting ? null : () {
                                    setState(() => _discussionCover = null);
                                    _syncCanPostState();
                                  },
                                ),
                              ],
                              if (_mode == _CreateMode.post && _images.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                _SelectedImageGrid(
                                  images: _images,
                                  onRemove: _isPosting ? null : _removeImage,
                                ),
                              ],
                              if (_mode == _CreateMode.album && (_images.isNotEmpty || _selectedMusic != null)) ...[
                                SizedBox(height: 8.h),
                                _ComposerCarouselPreview(
                                  images: _images,
                                  music: _selectedMusic,
                                  onRemoveImage: _isPosting ? null : _removeImage,
                                  onRemoveMusic: _isPosting ? null : () {
                                    setState(() => _selectedMusic = null);
                                    _syncCanPostState();
                                  },
                                ),
                              ],
                              if (_mode == _CreateMode.reel && (_reelImages.isNotEmpty || _selectedReelMusic != null)) ...[
                                SizedBox(height: 8.h),
                                _ReelsImagesPreview(
                                  images: _reelImages,
                                  music: _selectedReelMusic,
                                  onRemoveImage: _isPosting ? null : _removeReelImage,
                                  onRemoveMusic: _isPosting ? null : () {
                                    setState(() => _selectedReelMusic = null);
                                    _syncCanPostState();
                                  },
                                ),
                              ],
                              if ((_mode == _CreateMode.post || _mode == _CreateMode.album || _mode == _CreateMode.reel) && _selectedVideo != null) ...[
                                SizedBox(height: 8.h),
                                _VideoCard(
                                  video: _selectedVideo!,
                                  onRemove: _isPosting ? null : () {
                                    setState(() => _selectedVideo = null);
                                    _syncCanPostState();
                                  },
                                ),
                              ],
                              if (_mode == _CreateMode.post && _attachedYouTubeVideo != null) ...[
                                SizedBox(height: 8.h),
                                _AttachedYouTubePreviewCard(
                                  video: _attachedYouTubeVideo!,
                                  onRemove: _isPosting
                                      ? null
                                      : () {
                                          setState(() => _attachedYouTubeVideo = null);
                                          _syncCanPostState();
                                        },
                                ),
                              ],
                              if (_progressMessage != null) ...[
                                SizedBox(height: 12.h),
                                _ComposerProgress(
                                  message: _progressMessage!,
                                  value: _progressValue,
                                ),
                              ],
                              if (_errorMessage != null) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: const Color(0xFFDC2626),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                if (_errorMessage!.contains('AI Suggestion failed')) ...[
                                  SizedBox(height: 4.h),
                                  TextButton.icon(
                                    onPressed: _showGeminiKeyDialog,
                                    icon: const Icon(Icons.vpn_key_outlined, size: 14),
                                    label: const Text(
                                      'Update / Reset API Key',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF7A59),
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomAttachmentToolbar(
              mode: _mode,
              isPosting: _isPosting || _isPickingVideo,
              isPickingImages: _isPickingImages,
              isDetectingLocation: _isDetectingLocation,
              isGhost: _isGhost,
              hasLocation: _location.isNotEmpty,
              hasFeeling: _feeling.isNotEmpty,
              hasTaggedUsers: _withUsers.isNotEmpty,
              hasMusic: _mode == _CreateMode.reel ? _selectedReelMusic != null : _selectedMusic != null,
              hasImages: _images.isNotEmpty || _discussionCover != null || _reelImages.isNotEmpty,
              hasVideo: _selectedVideo != null,
              hasYouTube: _attachedYouTubeVideo != null,
              onPickImages: (_mode == _CreateMode.post || _mode == _CreateMode.album)
                  ? _pickImages
                  : _mode == _CreateMode.discussion
                      ? _pickDiscussionCover
                      : _pickReelImages,
              onPickVideo: (_mode == _CreateMode.post || _mode == _CreateMode.reel) ? _pickVideo : null,
              onPickYouTube: _mode == _CreateMode.post ? _pickYouTubeVideo : null,
              onPickMusic: _mode == _CreateMode.album
                  ? _openMusicPicker
                  : _mode == _CreateMode.reel
                      ? _openReelMusicPicker
                      : null,
              onTagFriends: () async {
                final selected = await showPostWithUsersPicker(
                  context: context,
                  initialSelected: _withUsers,
                  currentUserId: widget.user.id,
                );
                if (selected != null) {
                  setState(() => _withUsers = selected);
                }
              },
              onPickLocation: _handleLocationTap,
              onPickFeeling: _selectFeeling,
              onToggleGhost: _mode == _CreateMode.post
                  ? () => setState(() => _isGhost = !_isGhost)
                  : null,
              onAiSuggest: _onAiSuggestPressed,
              isGeneratingCaption: _isGeneratingCaption,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickYouTubeVideo() async {
    final video = await Navigator.of(context).push<YouTubeVideoItem?>(
      YouTubeSearchScreen.route(
        onVideoSelected: (selected) {},
      ),
    );
    if (!mounted || video == null) return;
    setState(() {
      _attachedYouTubeVideo = video;
      _errorMessage = null;
    });
    _syncCanPostState();
  }

  // AI SUGGESTION CAPTION HELPER METHODS

  Widget _buildAiSuggestionButton() {
    final hasMedia = _images.isNotEmpty ||
        _reelImages.isNotEmpty ||
        _discussionCover != null ||
        _selectedVideo != null;

    if (!hasMedia) return const SizedBox.shrink();

    final isMediaPreparing = (_images.isNotEmpty && _images.any((img) => img.isPreparing)) ||
        (_reelImages.isNotEmpty && _reelImages.any((img) => img.isPreparing)) ||
        (_discussionCover != null && _discussionCover!.isPreparing);

    if (isMediaPreparing) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9CA3AF)),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Preparing media...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: _isGeneratingCaption
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI is thinking...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6D28D9), // Violet
                      Color(0xFFDB2777), // Pink
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x336D28D9),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _onAiSuggestPressed,
                  onLongPress: _showGeminiKeyDialog,
                  icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                  label: const Text(
                    'Suggest Caption',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _onAiSuggestPressed() async {
    final apiKey = await _geminiService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showGeminiKeyDialog();
      return;
    }

    final isMediaPreparing = (_images.isNotEmpty && _images.any((img) => img.isPreparing)) ||
        (_reelImages.isNotEmpty && _reelImages.any((img) => img.isPreparing)) ||
        (_discussionCover != null && _discussionCover!.isPreparing);

    if (isMediaPreparing) {
      setState(() {
        _errorMessage = 'Please wait for the media to finish preparing.';
      });
      return;
    }

    setState(() {
      _isGeneratingCaption = true;
      _errorMessage = null;
    });

    try {
      String? imageBase64;
      String? imageMime;
      String? videoPath;
      String? videoMime;
      String? fallbackTitle;

      if (_images.isNotEmpty) {
        if (!_images[0].isReady) {
          setState(() {
            _errorMessage = _images[0].errorMessage ?? 'Selected image is not ready.';
          });
          return;
        }
        imageBase64 = _images[0].dataUrl;
        imageMime = _images[0].mimeType;
      } else if (_reelImages.isNotEmpty) {
        if (!_reelImages[0].isReady) {
          setState(() {
            _errorMessage = _reelImages[0].errorMessage ?? 'Selected reel image is not ready.';
          });
          return;
        }
        imageBase64 = _reelImages[0].dataUrl;
        imageMime = _reelImages[0].mimeType;
      } else if (_discussionCover != null) {
        if (!_discussionCover!.isReady) {
          setState(() {
            _errorMessage = _discussionCover!.errorMessage ?? 'Selected cover image is not ready.';
          });
          return;
        }
        imageBase64 = _discussionCover!.dataUrl;
        imageMime = _discussionCover!.mimeType;
      } else if (_selectedVideo != null) {
        videoPath = _selectedVideo!.previewPath;
        videoMime = _selectedVideo!.mimeType;
        fallbackTitle = _selectedVideo!.name;
      }

      final suggestions = await _geminiService.generateSuggestions(
        apiKey: apiKey,
        imageBase64: imageBase64,
        imageMime: imageMime,
        videoPath: videoPath,
        videoMime: videoMime,
        fallbackTitle: fallbackTitle,
      );

      if (!mounted) return;
      _showSuggestionsBottomSheet(suggestions);
    } catch (e) {
      setState(() {
        _errorMessage = 'AI Suggestion failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingCaption = false;
        });
      }
    }
  }

  void _showGeminiKeyDialog() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
              SizedBox(width: 8),
              Text(
                'Gemini API Key Required',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Gemini API key to enable caption suggestions. Your key is stored safely on your device.',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
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
              onPressed: () async {
                final key = keyController.text.trim();
                if (key.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  await _geminiService.saveApiKey(key);
                  navigator.pop();
                  _onAiSuggestPressed(); // Retry generating caption
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save & Suggest'),
            ),
          ],
        );
      },
    );
  }

  void _showSuggestionsBottomSheet(GeminiCaptionSuggestions suggestions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.paddingOf(sheetContext).bottom;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(sheetContext).colorScheme.surface : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E4042) : const Color(0xFF9CA3AF),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 18.r),
                  SizedBox(width: 6.w),
                  Text(
                    'Gemini Caption Suggestions',
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              _buildSuggestionCard(
                title: '😎 Casual / Chill',
                text: suggestions.casual,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                textColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
              SizedBox(height: 8.h),
              _buildSuggestionCard(
                title: '✨ Creative / Aesthetic',
                text: suggestions.creative,
                color: isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF),
                borderColor: isDark ? const Color(0xFF4C1D95) : const Color(0xFFDDD6FE),
                textColor: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
              ),
              SizedBox(height: 8.h),
              _buildSuggestionCard(
                title: '💬 Engaging (invites replies)',
                text: suggestions.engaging,
                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                borderColor: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                textColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionCard({
    required String title,
    required String text,
    required Color color,
    required Color borderColor,
    required Color textColor,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.all(12.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  _controller.text = text;
                  _syncCanPostState();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Use Caption'),
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerHeader extends StatelessWidget {
  const _ComposerHeader({
    required this.title,
    required this.isPosting,
    required this.canPost,
    required this.onPost,
    required this.submitLabel,
  });

  final String title;
  final bool isPosting;
  final bool canPost;
  final VoidCallback onPost;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top + 6;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, topPadding, 16.w, 10.h),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 2.w),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'New $title',
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 15.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: isPosting || !canPost ? null : onPost,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: canPost
                    ? const Color(0xFFFF7A45)
                    : (isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: canPost
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: isPosting
                  ? SizedBox(
                      height: 14.r,
                      width: 14.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      submitLabel,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: canPost
                            ? Colors.white
                            : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.value,
    required this.onChanged,
  });

  final _CreateMode value;
  final ValueChanged<_CreateMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 29.h,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _CreateMode.values.map((mode) {
          final isSelected = mode == value;
          return Padding(
            padding: EdgeInsets.only(right: 5.w),
            child: InkWell(
              onTap: onChanged == null ? null : () => onChanged!(mode),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF7A45)
                      : (isDark ? const Color(0xFF222325) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF7A45)
                        : (isDark ? const Color(0xFF2E3032) : const Color(0xFFE5E7EB)),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForMode(mode),
                      size: 12.r,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _labelForMode(mode),
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 11.5.sp,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFE4E6EB) : const Color(0xFF4B5563)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _labelForMode(_CreateMode mode) {
    return switch (mode) {
      _CreateMode.post => 'Post',
      _CreateMode.discussion => 'Discussion',
      _CreateMode.album => 'Carousel',
      _CreateMode.poll => 'Poll',
      _CreateMode.reel => 'Reels',
    };
  }

  IconData _iconForMode(_CreateMode mode) {
    return switch (mode) {
      _CreateMode.post => Icons.edit_note_rounded,
      _CreateMode.discussion => Icons.forum_outlined,
      _CreateMode.album => Icons.view_carousel_outlined,
      _CreateMode.poll => Icons.poll_outlined,
      _CreateMode.reel => Icons.movie_creation_outlined,
    };
  }
}



class _AudienceDropdown extends StatelessWidget {
  const _AudienceDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<_AudienceOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentOption = options.firstWhere(
      (o) => o.value == value,
      orElse: () => options.first,
    );

    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      color: isDark ? const Color(0xFF242526) : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: onChanged,
      itemBuilder: (context) {
        return options.map((option) {
          final isSelected = option.value == value;
          return PopupMenuItem<String>(
            value: option.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  option.icon,
                  size: 16.r,
                  color: isSelected
                      ? const Color(0xFFFF7A45)
                      : (isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280)),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13.sp,
                      ),
                    ),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentOption.icon,
              size: 11.r,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
            SizedBox(width: 4.w),
            Text(
              currentOption.label,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14.r,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}



class _ComposerCarouselPreview extends StatefulWidget {
  const _ComposerCarouselPreview({
    required this.images,
    required this.music,
    required this.onRemoveImage,
    required this.onRemoveMusic,
  });

  final List<SelectedPostImage> images;
  final _SelectedComposerMusic? music;
  final ValueChanged<int>? onRemoveImage;
  final VoidCallback? onRemoveMusic;

  @override
  State<_ComposerCarouselPreview> createState() =>
      _ComposerCarouselPreviewState();
}

class _ComposerCarouselPreviewState extends State<_ComposerCarouselPreview> {
  final PageController _pageController = PageController();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  int _activeIndex = 0;
  String? _loadedUrl;
  bool _isPlaying = false;
  bool _audioUnavailable = false;

  @override
  void didUpdateWidget(_ComposerCarouselPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeIndex >= widget.images.length) {
      _activeIndex = widget.images.isEmpty ? 0 : widget.images.length - 1;
    }
    if (oldWidget.music?.previewUrl != widget.music?.previewUrl) {
      _audioUnavailable = false;
      _isPlaying = false;
      unawaited(_disposePlayer());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_disposePlayer());
    super.dispose();
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

  String _resolveAudioUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return ApiConfig.assetUrl(url);
  }

  Future<bool> _ensurePlayer() async {
    final rawUrl = widget.music?.previewUrl.trim() ?? '';
    if (rawUrl.isEmpty || _audioUnavailable) return false;
    final url = _resolveAudioUrl(rawUrl);
    if (_loadedUrl == url && _player != null) return true;

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
      await player.setSourceUrl(url, mimeType: 'audio/mp4');
      return true;
    } catch (_) {
      await _disposePlayer();
      if (!mounted) return false;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
      return false;
    }
  }

  Future<void> _toggleMusicPreview() async {
    final player = _player;
    if (player?.state == PlayerState.playing) {
      await player!.pause();
      return;
    }

    final ready = await _ensurePlayer();
    final activePlayer = _player;
    if (!ready || activePlayer == null) return;
    try {
      await activePlayer.resume();
    } catch (_) {
      await _disposePlayer();
      if (!mounted) return;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final music = widget.music;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (images.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (music == null)
                    CarouselView.weighted(
                      flexWeights: const [7, 1],
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      children: [
                        for (int i = 0; i < images.length; i++)
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                images[i].previewBytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                              if (widget.onRemoveImage != null)
                                Positioned(
                                  top: 10,
                                  left: 12,
                                  child: _ComposerCarouselIconButton(
                                    icon: Icons.close_rounded,
                                    onTap: () => widget.onRemoveImage?.call(i),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    )
                  else ...[
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (index) {
                        setState(() {
                          _activeIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return Image.memory(
                          image.previewBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        );
                      },
                    ),
                    Positioned(
                      top: 10,
                      right: 12,
                      child: _ComposerCarouselCountPill(
                        current: _activeIndex + 1,
                        total: images.length,
                      ),
                    ),
                    if (widget.onRemoveImage != null)
                      Positioned(
                        top: 10,
                        left: 12,
                        child: _ComposerCarouselIconButton(
                          icon: Icons.close_rounded,
                          onTap: () => widget.onRemoveImage?.call(_activeIndex),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _ComposerCarouselIconButton(
                        icon: _audioUnavailable
                            ? Icons.music_off_rounded
                            : _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                        onTap: _audioUnavailable
                            ? null
                            : () => unawaited(_toggleMusicPreview()),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: _ComposerCarouselDots(
                          count: images.length,
                          activeIndex: _activeIndex,
                        ),
                      ),
                  ],
                ],
              ),
            )
          else
            Container(
              height: 180,
              alignment: Alignment.center,
              color: const Color(0xFFF3F4F6),
              child: const Icon(
                Icons.view_carousel_outlined,
                size: 34,
                color: Color(0xFF6B7280),
              ),
            ),
          if (music != null)
            _CarouselMusicMetadata(
              music: music,
              isPlaying: _isPlaying,
              isUnavailable: _audioUnavailable,
              onTogglePreview: () => unawaited(_toggleMusicPreview()),
              onRemove: widget.onRemoveMusic,
            )
          else
            const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.queue_music_outlined, color: Color(0xFF6B7280)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose music to enable carousel playback.',
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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

class _CarouselMusicMetadata extends StatelessWidget {
  const _CarouselMusicMetadata({
    required this.music,
    required this.isPlaying,
    required this.isUnavailable,
    required this.onTogglePreview,
    required this.onRemove,
  });

  final _SelectedComposerMusic music;
  final bool isPlaying;
  final bool isUnavailable;
  final VoidCallback onTogglePreview;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final sourceLabel =
        music.source.trim().isEmpty ? 'Music preview' : music.source.trim();

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: music.artworkUrl.trim().isEmpty
                ? Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF111827),
                    ),
                  )
                : Image.network(
                    music.artworkUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  music.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  music.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isUnavailable ? null : onTogglePreview,
            icon: Icon(
              isUnavailable
                  ? Icons.music_off_rounded
                  : isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
            ),
            color: const Color(0xFF111827),
            disabledColor: const Color(0xFF9CA3AF),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              color: const Color(0xFF6B7280),
            ),
        ],
      ),
    );
  }
}

class _ComposerCarouselIconButton extends StatelessWidget {
  const _ComposerCarouselIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.68),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _ComposerCarouselCountPill extends StatelessWidget {
  const _ComposerCarouselCountPill(
      {required this.current, required this.total});

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
            decoration: TextDecoration.none,
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ComposerCarouselDots extends StatelessWidget {
  const _ComposerCarouselDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == activeIndex ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _ReelsImagesPreview extends StatefulWidget {
  const _ReelsImagesPreview({
    required this.images,
    required this.music,
    required this.onRemoveImage,
    required this.onRemoveMusic,
  });

  final List<SelectedPostImage> images;
  final _SelectedComposerMusic? music;
  final ValueChanged<int>? onRemoveImage;
  final VoidCallback? onRemoveMusic;

  @override
  State<_ReelsImagesPreview> createState() => _ReelsImagesPreviewState();
}

class _ReelsImagesPreviewState extends State<_ReelsImagesPreview> {
  final PageController _pageController = PageController();
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  int _activeIndex = 0;
  String? _loadedUrl;
  bool _isPlaying = false;
  bool _audioUnavailable = false;

  @override
  void didUpdateWidget(_ReelsImagesPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeIndex >= widget.images.length) {
      _activeIndex = widget.images.isEmpty ? 0 : widget.images.length - 1;
    }
    if (oldWidget.music?.previewUrl != widget.music?.previewUrl) {
      _audioUnavailable = false;
      _isPlaying = false;
      unawaited(_disposePlayer());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_disposePlayer());
    super.dispose();
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

  String _resolveAudioUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return ApiConfig.assetUrl(url);
  }

  Future<bool> _ensurePlayer() async {
    final rawUrl = widget.music?.previewUrl.trim() ?? '';
    if (rawUrl.isEmpty || _audioUnavailable) return false;
    final url = _resolveAudioUrl(rawUrl);
    if (_loadedUrl == url && _player != null) return true;

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
      await player.setSourceUrl(url, mimeType: 'audio/mp4');
      return true;
    } catch (_) {
      await _disposePlayer();
      if (!mounted) return false;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
      return false;
    }
  }

  Future<void> _toggleMusicPreview() async {
    final player = _player;
    if (player?.state == PlayerState.playing) {
      await player!.pause();
      return;
    }

    final ready = await _ensurePlayer();
    final activePlayer = _player;
    if (!ready || activePlayer == null) return;
    try {
      await activePlayer.resume();
    } catch (_) {
      await _disposePlayer();
      if (!mounted) return;
      setState(() {
        _audioUnavailable = true;
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final music = widget.music;

    if (images.isEmpty && music != null) {
      return _ReelsMusicOnlyCard(
        music: music,
        isPlaying: _isPlaying,
        isUnavailable: _audioUnavailable,
        onTogglePreview: () => unawaited(_toggleMusicPreview()),
        onRemove: widget.onRemoveMusic,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF0B0B10)),
            PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _activeIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final image = images[index];
                return Image.memory(
                  image.previewBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xAA000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Reels',
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onRemoveImage != null)
              Positioned(
                top: 12,
                left: 12,
                child: _ReelsIconButton(
                  icon: Icons.close_rounded,
                  onTap: () => widget.onRemoveImage?.call(_activeIndex),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: music != null ? 86 : 14,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_activeIndex + 1}/${images.length}',
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (music != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _ReelsMusicStrip(
                  music: music,
                  isPlaying: _isPlaying,
                  isUnavailable: _audioUnavailable,
                  onTogglePreview: () => unawaited(_toggleMusicPreview()),
                  onRemove: widget.onRemoveMusic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReelsIconButton extends StatelessWidget {
  const _ReelsIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _ReelsMusicStrip extends StatelessWidget {
  const _ReelsMusicStrip({
    required this.music,
    required this.isPlaying,
    required this.isUnavailable,
    required this.onTogglePreview,
    required this.onRemove,
  });

  final _SelectedComposerMusic music;
  final bool isPlaying;
  final bool isUnavailable;
  final VoidCallback onTogglePreview;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: music.artworkUrl.trim().isEmpty
                ? Container(
                    width: 34,
                    height: 34,
                    color: const Color(0xFF1F2937),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  )
                : Image.network(
                    music.artworkUrl,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 34,
                      height: 34,
                      color: const Color(0xFF1F2937),
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  music.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  music.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: Color(0xFFD1D5DB),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: isUnavailable ? null : onTogglePreview,
            icon: Icon(
              isUnavailable
                  ? Icons.music_off_rounded
                  : isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
              size: 20,
            ),
            color: Colors.white,
            disabledColor: const Color(0xFF9CA3AF),
          ),
          if (onRemove != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: const Color(0xFFE5E7EB),
            ),
        ],
      ),
    );
  }
}

class _ReelsMusicOnlyCard extends StatelessWidget {
  const _ReelsMusicOnlyCard({
    required this.music,
    required this.isPlaying,
    required this.isUnavailable,
    required this.onTogglePreview,
    required this.onRemove,
  });

  final _SelectedComposerMusic music;
  final bool isPlaying;
  final bool isUnavailable;
  final VoidCallback onTogglePreview;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _ReelsMusicStrip(
        music: music,
        isPlaying: isPlaying,
        isUnavailable: isUnavailable,
        onTogglePreview: onTogglePreview,
        onRemove: onRemove,
      ),
    );
  }
}

class _SelectedImageGrid extends StatelessWidget {
  const _SelectedImageGrid({
    required this.images,
    required this.onRemove,
  });

  final List<SelectedPostImage> images;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: images.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return Stack(
          key: ValueKey(images[index].id),
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                images[index].previewBytes,
                key: ValueKey('preview-${images[index].id}'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => onRemove?.call(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatImageSize(images[index]),
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatImageSize(SelectedPostImage image) {
    if (image.isPreparing) {
      return 'Preparing...';
    }
    if (image.isFailed) {
      return 'Failed';
    }

    final sizeMb = image.uploadByteCount / (1024 * 1024);
    final label = sizeMb >= 1
        ? '${sizeMb.toStringAsFixed(1)} MB'
        : '${(image.uploadByteCount / 1024).round()} KB';
    return image.optimized ? '$label WebP' : '$label ready';
  }
}

class _SingleImageCard extends StatelessWidget {
  const _SingleImageCard({
    required this.image,
    required this.onRemove,
  });

  final SelectedPostImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            image.previewBytes,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _statusLabel(image),
              style: const TextStyle(
                decoration: TextDecoration.none,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: 8,
            top: 8,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  String _statusLabel(SelectedPostImage image) {
    if (image.isPreparing) return 'Preparing...';
    if (image.isFailed) return 'Failed';
    return image.optimized ? 'Ready / WebP' : 'Ready';
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    required this.video,
    required this.onRemove,
  });

  final PreparedVideo video;
  final VoidCallback? onRemove;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initController());
  }

  Future<void> _initController() async {
    final path = widget.video.previewPath;
    if (kIsWeb || path == null || path.isEmpty) {
      return;
    }
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      setState(() {
        _controller = controller;
        _initialized = true;
      });
    } catch (_) {
      // Fallback rendering will be used.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = widget.video.byteCount / (1024 * 1024);
    final hasFrame = _initialized && _controller != null;
    final aspectRatio = hasFrame ? _controller!.value.aspectRatio : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: aspectRatio <= 0 ? 16 / 9 : aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasFrame)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                const ColoredBox(color: Color(0xFF111827)),
              const IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 56,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: Text(
                    '${widget.video.name}  ·  ${sizeMb.toStringAsFixed(1)} MB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (widget.onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
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

class _ComposerProgress extends StatelessWidget {
  const _ComposerProgress({
    required this.message,
    required this.value,
  });

  final String message;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: value),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              decoration: TextDecoration.none,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedComposerMusic {
  const _SelectedComposerMusic({
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.previewUrl,
    required this.source,
  });

  final String title;
  final String artist;
  final String artworkUrl;
  final String previewUrl;
  final String source;

  factory _SelectedComposerMusic.fromResult(MusicSearchResult result) {
    return _SelectedComposerMusic(
      title: result.title,
      artist: result.artist,
      artworkUrl: result.artworkUrl,
      previewUrl: result.previewUrl,
      source: result.source,
    );
  }
}

Future<_SelectedComposerMusic?> _showComposerMusicPicker(
  BuildContext context, {
  _SelectedComposerMusic? currentSelection,
}) {
  return showModalBottomSheet<_SelectedComposerMusic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      return _ComposerMusicPickerSheet(currentSelection: currentSelection);
    },
  );
}

class _ComposerMusicPickerSheet extends StatefulWidget {
  const _ComposerMusicPickerSheet({this.currentSelection});

  final _SelectedComposerMusic? currentSelection;

  @override
  State<_ComposerMusicPickerSheet> createState() =>
      _ComposerMusicPickerSheetState();
}

class _ComposerMusicPickerSheetState extends State<_ComposerMusicPickerSheet> {
  final FeedService _feedService = FeedService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MusicSearchResult> _results = const <MusicSearchResult>[];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();

    if (query.length < 2) {
      setState(() {
        _results = const <MusicSearchResult>[];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 280), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _feedService.searchAppleMusic(query);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _results = const <MusicSearchResult>[];
        _isLoading = false;
        _error = 'Unable to search music right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F7F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add carousel music',
                    style: TextStyle(
                      decoration: TextDecoration.none,
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onChanged,
                    autofocus: true,
                    cursorColor: const Color(0xFF111827),
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search Apple Music',
                      hintStyle: TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF9CA3AF),
                      ),
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: _buildResults(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          style: const TextStyle(
            decoration: TextDecoration.none,
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_searchController.text.trim().length < 2) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Search for a song title or artist.',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No previewable tracks found.',
          style: TextStyle(
            decoration: TextDecoration.none,
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemBuilder: (context, index) {
        final song = _results[index];
        return _MusicResultTile(
          song: song,
          onTap: () => Navigator.of(context).pop(
            _SelectedComposerMusic.fromResult(song),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _results.length,
    );
  }
}

class _MusicResultTile extends StatelessWidget {
  const _MusicResultTile({required this.song, required this.onTap});

  final MusicSearchResult song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: song.artworkUrl.isEmpty
                    ? Container(
                        width: 54,
                        height: 54,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.music_note,
                          color: Color(0xFF6B7280),
                        ),
                      )
                    : Image.network(
                        song.artworkUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 54,
                          height: 54,
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(
                            Icons.music_note,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add_circle_outline, color: Color(0xFF111827)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollFields extends StatelessWidget {
  const _PollFields({
    required this.questionController,
    required this.options,
    required this.durationHours,
    required this.enabled,
    required this.onOptionChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onDurationChanged,
  });

  final TextEditingController questionController;
  final List<String> options;
  final int durationHours;
  final bool enabled;
  final void Function(int index, String value) onOptionChanged;
  final VoidCallback? onAddOption;
  final void Function(int index)? onRemoveOption;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final wrapperBg = isDark ? const Color(0xFF242526) : const Color(0xFFF8FAFC);
    final textStyleColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: wrapperBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: questionController,
              enabled: enabled,
              maxLength: 280,
              cursorColor: const Color(0xFFFF7A45),
              inputFormatters: [EmojiPresentationFormatter()],
              textInputAction: TextInputAction.next,
              style: TextStyle(
                decoration: TextDecoration.none,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textStyleColor,
              ),
              decoration: const InputDecoration(
                hintText: 'Ask a poll question...',
                hintStyle: TextStyle(
                  decoration: TextDecoration.none,
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++) ...[
            _PollOptionInput(
              key: ValueKey('poll-option-$index-${options.length}'),
              index: index,
              initialValue: options[index],
              enabled: enabled,
              canRemove: enabled && options.length > 2,
              onChanged: (value) => onOptionChanged(index, value),
              onRemove:
                  onRemoveOption == null ? null : () => onRemoveOption!(index),
            ),
            if (index != options.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: enabled ? onAddOption : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Option'),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: durationHours,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(10),
                items: const [
                  DropdownMenuItem(value: 24, child: Text('24h')),
                  DropdownMenuItem(value: 72, child: Text('3d')),
                  DropdownMenuItem(value: 168, child: Text('7d')),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) onDurationChanged(value);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOptionInput extends StatelessWidget {
  const _PollOptionInput({
    required this.index,
    required this.initialValue,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final String initialValue;
  final bool enabled;
  final bool canRemove;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wrapperBg = isDark ? const Color(0xFF242526) : const Color(0xFFF8FAFC);
    final textStyleColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: wrapperBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        initialValue: initialValue,
        enabled: enabled,
        maxLength: 120,
        cursorColor: const Color(0xFFFF7A45),
        textInputAction: TextInputAction.next,
        onChanged: onChanged,
        style: TextStyle(
          decoration: TextDecoration.none,
          fontSize: 14,
          color: textStyleColor,
        ),
        decoration: InputDecoration(
          hintText: 'Option ${index + 1}',
          hintStyle: const TextStyle(
            decoration: TextDecoration.none,
            color: Color(0xFF9CA3AF),
          ),
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          suffixIcon: canRemove
              ? IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remove option',
                )
              : null,
        ),
      ),
    );
  }
}



class _BottomAttachmentToolbar extends StatelessWidget {
  const _BottomAttachmentToolbar({
    required this.mode,
    required this.isPosting,
    required this.isPickingImages,
    required this.isDetectingLocation,
    required this.isGhost,
    required this.hasLocation,
    required this.hasFeeling,
    required this.hasTaggedUsers,
    required this.hasMusic,
    required this.hasImages,
    required this.hasVideo,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onPickMusic,
    this.onPickYouTube,
    this.hasYouTube = false,
    required this.onTagFriends,
    required this.onPickLocation,
    required this.onPickFeeling,
    required this.onToggleGhost,
    required this.onAiSuggest,
    required this.isGeneratingCaption,
  });

  final _CreateMode mode;
  final bool isPosting;
  final bool isPickingImages;
  final bool isDetectingLocation;
  final bool isGhost;
  final bool hasLocation;
  final bool hasFeeling;
  final bool hasTaggedUsers;
  final bool hasMusic;
  final bool hasImages;
  final bool hasVideo;
  final VoidCallback onPickImages;
  final VoidCallback? onPickVideo;
  final VoidCallback? onPickMusic;
  final VoidCallback? onPickYouTube;
  final bool hasYouTube;
  final VoidCallback onTagFriends;
  final VoidCallback onPickLocation;
  final VoidCallback onPickFeeling;
  final VoidCallback? onToggleGhost;
  final VoidCallback onAiSuggest;
  final bool isGeneratingCaption;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12.w,
        8.h,
        12.w,
        8.h + (bottomInset > 0 ? bottomInset : bottomPadding),
      ),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarIconButton(
              icon: Icons.image_outlined,
              tooltip: 'Add photos',
              active: hasImages,
              busy: isPickingImages,
              onTap: (isPosting || isPickingImages) ? null : onPickImages,
            ),
            if (onPickVideo != null) ...[
              SizedBox(width: 4.w),
              _ToolbarIconButton(
                icon: Icons.videocam_outlined,
                tooltip: 'Add video',
                active: hasVideo,
                onTap: isPosting ? null : onPickVideo,
              ),
            ],
            if (onPickMusic != null) ...[
              SizedBox(width: 4.w),
              _ToolbarIconButton(
                icon: Icons.music_note_rounded,
                tooltip: 'Add music',
                active: hasMusic,
                onTap: isPosting ? null : onPickMusic,
              ),
            ],
            if (onPickYouTube != null) ...[
              SizedBox(width: 4.w),
              _ToolbarIconButton(
                icon: Icons.smart_display_rounded,
                tooltip: 'Attach YouTube',
                active: hasYouTube,
                accentColor: const Color(0xFFFF0000),
                onTap: isPosting ? null : onPickYouTube,
              ),
            ],
            SizedBox(width: 4.w),
            _ToolbarIconButton(
              icon: Icons.alternate_email_rounded,
              tooltip: 'Tag friends',
              active: hasTaggedUsers,
              onTap: isPosting ? null : onTagFriends,
            ),
            SizedBox(width: 4.w),
            _ToolbarIconButton(
              icon: Icons.location_on_outlined,
              tooltip: 'Add location',
              active: hasLocation,
              busy: isDetectingLocation,
              onTap: isPosting ? null : onPickLocation,
            ),
            SizedBox(width: 4.w),
            _ToolbarIconButton(
              icon: Icons.sentiment_satisfied_alt_outlined,
              tooltip: 'Add feeling',
              active: hasFeeling,
              onTap: isPosting ? null : onPickFeeling,
            ),
            SizedBox(width: 4.w),
            _ToolbarIconButton(
              icon: Icons.auto_awesome_rounded,
              tooltip: 'AI Caption',
              accentColor: Colors.deepPurpleAccent,
              busy: isGeneratingCaption,
              onTap: isPosting ? null : onAiSuggest,
            ),
            if (onToggleGhost != null) ...[
              SizedBox(width: 4.w),
              _ToolbarIconButton(
                icon: Icons.visibility_off_outlined,
                tooltip: 'Ghost Mode',
                active: isGhost,
                accentColor: const Color(0xFFFF5722),
                onTap: isPosting ? null : onToggleGhost,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.busy = false,
    this.tooltip = '',
    this.accentColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool busy;
  final String tooltip;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final activeColor = accentColor ?? const Color(0xFFFF7A45);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.all(7.r),
          decoration: active
              ? BoxDecoration(
                  color: activeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                )
              : null,
          child: busy
              ? SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  ),
                )
              : Icon(
                  icon,
                  size: 21.r,
                  color: active ? activeColor : defaultColor,
                ),
        ),
      ),
    );
  }
}

class _AudienceOption {
  const _AudienceOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}



class _GhostInputBubblePainter extends CustomPainter {
  _GhostInputBubblePainter({
    required this.color,
    required this.borderColor,
    this.strokeWidth = 1.5,
    this.borderRadius = 22.0,
  });

  final Color color;
  final Color borderColor;
  final double strokeWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw bubble background fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(rrect, fillPaint);

    // 2. Draw dashed outline
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()..addRRect(rrect);

    final dashWidth = 6.0;
    final dashSpace = 4.0;

    final pms = path.computeMetrics();
    for (final pm in pms) {
      double distance = 0.0;
      while (distance < pm.length) {
        final len = dashWidth;
        canvas.drawPath(
          pm.extractPath(distance, distance + len),
          borderPaint,
        );
        distance += len + dashSpace;
      }
    }

    // 3. Draw cute floating bubble accent circles at the borders
    final bubblesPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final bubblesBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top-right floating bubbles
    canvas.drawCircle(Offset(size.width - 5, -8), 8, bubblesPaint);
    canvas.drawCircle(Offset(size.width - 5, -8), 8, bubblesBorderPaint);

    canvas.drawCircle(Offset(size.width + 6, -3), 4, bubblesPaint);
    canvas.drawCircle(Offset(size.width + 6, -3), 4, bubblesBorderPaint);

    // Bottom-left floating bubble
    canvas.drawCircle(Offset(-6, size.height + 6), 6, bubblesPaint);
    canvas.drawCircle(Offset(-6, size.height + 6), 6, bubblesBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _GhostInputBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _AttachedYouTubePreviewCard extends StatelessWidget {
  const _AttachedYouTubePreviewCard({
    required this.video,
    required this.onRemove,
  });

  final YouTubeVideoItem video;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail preview
              ClipRRect(
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(15.r)),
                child: SizedBox(
                  width: 120.w,
                  height: 75.h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (video.thumbnail.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: video.thumbnail,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.black12,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF0000)),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.black12,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                        )
                      else
                        Container(
                          color: Colors.black12,
                          child: const Icon(Icons.video_library,
                              color: Colors.grey),
                        ),
                      Container(color: Colors.black26),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Color(0xFFFF0000),
                          size: 32,
                        ),
                      ),
                      if (video.duration.isNotEmpty)
                        Positioned(
                          bottom: 4.h,
                          right: 4.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              video.duration,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 32.w, 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0000),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'YouTube',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (video.author.isNotEmpty) ...[
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                video.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color:
                              isDark ? Colors.white : const Color(0xFF1C1E21),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (onRemove != null)
            Positioned(
              top: 6.h,
              right: 6.w,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: Padding(
                    padding: EdgeInsets.all(4.r),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16.r,
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
