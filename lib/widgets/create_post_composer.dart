import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../services/post_service.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../utils/emoji_presentation.dart';
import 'post_with_users_picker.dart';
import 'special_name_text.dart';

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
    super.key,
  });

  final User user;
  final VoidCallback onPostCreated;

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
    _controller.addListener(_syncCanPostState);
    _titleController.addListener(_syncCanPostState);
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
              _selectedVideo != null) &&
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
    final text = _controller.text.trim();
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
        videoTitle: _mode == _CreateMode.album ? null : _selectedVideo?.name,
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
                  fontSize: 16,
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
                        leading: Text(emoji, style: const TextStyle(fontSize: 22)),
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

    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _UserRow(
                    user: widget.user,
                    showAudience: showAudience,
                    audienceValue: _visibility,
                    audienceOptions: _audienceOptions,
                    onAudienceChanged: (value) {
                      setState(() {
                        _visibility = value;
                        _errorMessage = null;
                      });
                    },
                    feeling: _feeling,
                  ),
                  if (_withUsers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _withUsers.map((u) {
                        return InputChip(
                          avatar: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                    ApiConfig.assetUrl(u.avatarUrl!),
                                  ),
                                )
                              : null,
                          label: Text(
                            u.displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          onDeleted: () {
                            setState(() {
                              _withUsers.remove(u);
                            });
                          },
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          backgroundColor: const Color(0xFFE5E7EB),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _handleLocationTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                  decoration: TextDecoration.none,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit, color: Colors.blue, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ModeSelector(
                    value: _mode,
                    onChanged: _isPosting || _isPickingImages || _isPickingVideo
                        ? null
                        : _setMode,
                  ),
                  const SizedBox(height: 14),
                  if (_mode == _CreateMode.discussion)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E1F20)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2D2E30)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: TextField(
                        controller: _titleController,
                        enabled: !_isPosting,
                        maxLength: _mode == _CreateMode.discussion ? 200 : 120,
                        cursorColor: const Color(0xFFFF7A45),
                        inputFormatters: [EmojiPresentationFormatter()],
                        style: TextStyle(
                          decoration: TextDecoration.none,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Title',
                          hintStyle: TextStyle(
                            decoration: TextDecoration.none,
                            color: Color(0xFF9CA3AF),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  if (_mode != _CreateMode.poll) ...[
                    Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final bodyTextField = TextField(
                          controller: _controller,
                          enabled: !_isPosting,
                          inputFormatters: [EmojiPresentationFormatter()],
                          maxLines: _mode == _CreateMode.reel ||
                                  _mode == _CreateMode.poll
                              ? 5
                              : 8,
                          minLines: _mode == _CreateMode.reel ||
                                  _mode == _CreateMode.poll
                              ? 3
                              : 5,
                          maxLength: 10000,
                          cursorColor: const Color(0xFFFF7A45),
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: _bodyPlaceholder,
                            hintStyle: const TextStyle(
                              decoration: TextDecoration.none,
                              color: Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        );

                        if (_isGhost) {
                          final bubbleFill = isDark ? const Color(0xFF2B211E) : const Color(0xFFFFF3F0);
                          final bubbleBorder = const Color(0xFFFF7A59);
                          return CustomPaint(
                            painter: _GhostInputBubblePainter(
                              color: bubbleFill,
                              borderColor: bubbleBorder,
                              borderRadius: 22,
                              strokeWidth: 1.5,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.transparent),
                              child: bodyTextField,
                            ),
                          );
                        } else {
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1F20) : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: bodyTextField,
                          );
                        }
                      },
                    ),
                    _buildAiSuggestionButton(),
                  ],
                  if (_mode == _CreateMode.poll) ...[
                    const SizedBox(height: 8),
                    _PollFields(
                      questionController: _controller,
                      options: _pollOptions,
                      durationHours: _pollDurationHours,
                      enabled: !_isPosting,
                      onOptionChanged: _setPollOption,
                      onAddOption:
                          _pollOptions.length >= 6 ? null : _addPollOption,
                      onRemoveOption:
                          _pollOptions.length <= 2 ? null : _removePollOption,
                      onDurationChanged: (value) {
                        setState(() {
                          _pollDurationHours = value;
                        });
                      },
                    ),
                  ],
                  if (_mode == _CreateMode.discussion &&
                      _discussionCover != null) ...[
                    const SizedBox(height: 8),
                    _SingleImageCard(
                      image: _discussionCover!,
                      onRemove: _isPosting
                          ? null
                          : () {
                              setState(() {
                                _discussionCover = null;
                              });
                              _syncCanPostState();
                            },
                    ),
                  ],
                  if (_mode == _CreateMode.post && _images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SelectedImageGrid(
                      images: _images,
                      onRemove: _isPosting ? null : _removeImage,
                    ),
                  ],
                  if (_mode == _CreateMode.album &&
                      (_images.isNotEmpty || _selectedMusic != null)) ...[
                    const SizedBox(height: 8),
                    _ComposerCarouselPreview(
                      images: _images,
                      music: _selectedMusic,
                      onRemoveImage: _isPosting ? null : _removeImage,
                      onRemoveMusic: _isPosting
                          ? null
                          : () {
                              setState(() {
                                _selectedMusic = null;
                              });
                              _syncCanPostState();
                            },
                    ),
                  ],
                  if (_mode == _CreateMode.reel &&
                      (_reelImages.isNotEmpty ||
                          _selectedReelMusic != null)) ...[
                    const SizedBox(height: 8),
                    _ReelsImagesPreview(
                      images: _reelImages,
                      music: _selectedReelMusic,
                      onRemoveImage: _isPosting ? null : _removeReelImage,
                      onRemoveMusic: _isPosting
                          ? null
                          : () {
                              setState(() {
                                _selectedReelMusic = null;
                              });
                              _syncCanPostState();
                            },
                    ),
                  ],
                  if ((_mode == _CreateMode.post ||
                          _mode == _CreateMode.album ||
                          _mode == _CreateMode.reel) &&
                      _selectedVideo != null) ...[
                    const SizedBox(height: 8),
                    _VideoCard(
                      video: _selectedVideo!,
                      onRemove: _isPosting
                          ? null
                          : () {
                              setState(() {
                                _selectedVideo = null;
                              });
                              _syncCanPostState();
                            },
                    ),
                  ],
                  if (_progressMessage != null) ...[
                    const SizedBox(height: 12),
                    _ComposerProgress(
                      message: _progressMessage!,
                      value: _progressValue,
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (_errorMessage!.contains('AI Suggestion failed')) ...[
                      const SizedBox(height: 4),
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
                          foregroundColor: const Color(0xFFFF7A59), // Elegant Light Orange
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  if (_mode != _CreateMode.poll)
                    _AttachmentBar(
                      isPickingImages: _isPickingImages,
                      isPosting: _isPosting || _isPickingVideo,
                      mode: _mode,
                      onPickImages: (_mode == _CreateMode.post ||
                              _mode == _CreateMode.album)
                          ? _pickImages
                          : _mode == _CreateMode.discussion
                              ? _pickDiscussionCover
                              : _pickReelImages,
                      onPickVideo: (_mode == _CreateMode.post ||
                              _mode == _CreateMode.reel)
                          ? _pickVideo
                          : null,
                      onPickMusic: _mode == _CreateMode.album
                          ? _openMusicPicker
                          : _mode == _CreateMode.reel
                              ? _openReelMusicPicker
                              : null,
                      hasMusic: _mode == _CreateMode.reel
                          ? _selectedReelMusic != null
                          : _selectedMusic != null,
                      onTagFriends: () async {
                        final selected = await showPostWithUsersPicker(
                          context: context,
                          initialSelected: _withUsers,
                          currentUserId: widget.user.id,
                        );
                        if (selected != null) {
                          setState(() {
                            _withUsers = selected;
                          });
                        }
                      },
                      onPickLocation: _handleLocationTap,
                      onPickFeeling: _selectFeeling,
                      isDetectingLocation: _isDetectingLocation,
                    ),
                  if (_mode == _CreateMode.post) ...[
                    const SizedBox(height: 14),
                    _GhostPostToggle(
                      isGhost: _isGhost,
                      onChanged: (value) {
                        setState(() {
                          _isGhost = value;
                        });
                      },
                    ),
                  ],
                  if (showAudience) ...[
                    const SizedBox(height: 14),
                    _AudienceHint(audienceValue: _visibility),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Gemini Caption Suggestions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSuggestionCard(
                title: '😎 Casual / Chill',
                text: suggestions.casual,
                color: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                textColor: const Color(0xFF1D4ED8),
              ),
              const SizedBox(height: 12),
              _buildSuggestionCard(
                title: '✨ Creative / Aesthetic',
                text: suggestions.creative,
                color: const Color(0xFFF5F3FF),
                borderColor: const Color(0xFFDDD6FE),
                textColor: const Color(0xFF6D28D9),
              ),
              const SizedBox(height: 12),
              _buildSuggestionCard(
                title: '💬 Engaging (invites replies)',
                text: suggestions.engaging,
                color: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
                textColor: const Color(0xFF047857),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
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
    final topPadding = MediaQuery.paddingOf(context).top + 8;
    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: TextDecoration.none,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'KatsKlub',
                  style: TextStyle(
                    decoration: TextDecoration.none,
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isPosting || !canPost ? null : onPost,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A45),
              disabledBackgroundColor: isDark ? const Color(0xFF2D2E30) : const Color(0xFFD1D5DB),
              disabledForegroundColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              minimumSize: const Size(64, 40),
            ),
            child: isPosting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    submitLabel,
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827),
            size: 22,
          ),
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = constraints.maxWidth;
        final columns = width >= 460 ? 5 : 3;
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _CreateMode.values.map((mode) {
            return SizedBox(
              width: itemWidth,
              child: _ModeChip(
                label: _labelForMode(mode),
                icon: _iconForMode(mode),
                selected: value == mode,
                onTap: onChanged == null ? null : () => onChanged!(mode),
              ),
            );
          }).toList(),
        );
      },
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final activeBg = const Color(0xFFFF7A45); // Premium Orange
    final inactiveBg = isDark ? const Color(0xFF242526) : Colors.white;
    
    final activeBorder = const Color(0xFFFF7A45);
    final inactiveBorder = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB);
    
    final activeFg = Colors.white;
    final inactiveFg = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151);

    final foreground = selected ? activeFg : inactiveFg;

    return Material(
      color: selected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? activeBorder : inactiveBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    decoration: TextDecoration.none,
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.showAudience,
    required this.audienceValue,
    required this.audienceOptions,
    required this.onAudienceChanged,
    required this.feeling,
  });

  final User user;
  final bool showAudience;
  final String audienceValue;
  final List<_AudienceOption> audienceOptions;
  final ValueChanged<String> onAudienceChanged;
  final String feeling;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final rowBorder = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);
    final textStyleColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rowBorder),
      ),
      child: Row(
        children: [
          _AuthorAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: SpecialNameText(
                        username: user.username ?? '',
                        displayName: user.displayName,
                        style: TextStyle(
                          decoration: TextDecoration.none,
                          color: textStyleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                if (feeling.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    'is feeling',
                    style: TextStyle(
                      decoration: TextDecoration.none,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      feeling,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: textStyleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
                if (user.handle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.handle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showAudience) ...[
            const SizedBox(width: 8),
            _AudienceDropdown(
              value: audienceValue,
              options: audienceOptions,
              onChanged: onAudienceChanged,
            ),
          ],
        ],
      ),
    );
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
    final currentOption = options.firstWhere(
      (o) => o.value == value,
      orElse: () => options.first,
    );

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: Colors.white,
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
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF111827)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      option.description,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentOption.icon,
              size: 15,
              color: const Color(0xFF111827),
            ),
            const SizedBox(width: 6),
            Text(
              currentOption.label,
              style: const TextStyle(
                decoration: TextDecoration.none,
                color: Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Color(0xFF111827),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim() ?? '';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE5E7EB),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isEmpty
          ? Center(
              child: Text(
                user.initials,
                style: const TextStyle(
                  decoration: TextDecoration.none,
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: ApiConfig.assetUrl(avatarUrl),
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
                    user.initials,
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      color: Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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

class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({
    required this.isPickingImages,
    required this.isPosting,
    required this.mode,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onPickMusic,
    required this.hasMusic,
    required this.onTagFriends,
    required this.onPickLocation,
    required this.onPickFeeling,
    required this.isDetectingLocation,
  });

  final bool isPickingImages;
  final bool isPosting;
  final _CreateMode mode;
  final VoidCallback onPickImages;
  final VoidCallback? onPickVideo;
  final VoidCallback? onPickMusic;
  final bool hasMusic;
  final VoidCallback onTagFriends;
  final VoidCallback onPickLocation;
  final VoidCallback onPickFeeling;
  final bool isDetectingLocation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final barBorder = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: barBorder),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _AttachmentAction(
            enabled: !(isPickingImages || isPosting),
            onPressed: onPickImages,
            icon: Icons.image_outlined,
            busy: isPickingImages,
            label: _imageLabel,
            iconColor: const Color(0xFF4CAF50),
          ),
          if (onPickVideo != null)
            _AttachmentAction(
              enabled: !(isPickingImages || isPosting),
              onPressed: onPickVideo!,
              icon: Icons.videocam_outlined,
              label: 'Video',
              iconColor: const Color(0xFF2196F3),
            ),
          if (onPickMusic != null)
            _AttachmentAction(
              enabled: !isPosting,
              onPressed: onPickMusic!,
              icon: hasMusic ? Icons.music_note : Icons.queue_music_outlined,
              label: hasMusic ? 'Change music' : 'Music',
              iconColor: const Color(0xFF9C27B0),
            ),
          _AttachmentAction(
            enabled: !isPosting,
            onPressed: onTagFriends,
            icon: Icons.person_add_alt_1_outlined,
            label: 'With',
            iconColor: const Color(0xFFE91E63),
          ),
          _AttachmentAction(
            enabled: !isPosting,
            onPressed: onPickLocation,
            icon: Icons.location_on_outlined,
            busy: isDetectingLocation,
            label: 'Location',
            iconColor: const Color(0xFFFF5722),
          ),
          _AttachmentAction(
            enabled: !isPosting,
            onPressed: onPickFeeling,
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: 'Feeling',
            iconColor: const Color(0xFFFFC107),
          ),
        ],
      ),
    );
  }

  String get _imageLabel {
    if (isPickingImages) {
      return 'Preparing...';
    }
    return switch (mode) {
      _CreateMode.post => 'Image',
      _CreateMode.discussion => 'Cover',
      _CreateMode.album => 'Add photos',
      _CreateMode.poll => 'Image',
      _CreateMode.reel => 'Photos',
    };
  }
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    required this.enabled,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.iconColor,
    this.busy = false,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? iconColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledBg = isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB);
    final disabledBg = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF3F4F6);
    final actionBorder = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);
    
    final enabledFg = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827);
    final disabledFg = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    final bg = enabled ? enabledBg : disabledBg;
    final fg = enabled ? (iconColor ?? enabledFg) : disabledFg;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: actionBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: fg,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  decoration: TextDecoration.none,
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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

class _AudienceHint extends StatelessWidget {
  const _AudienceHint({required this.audienceValue});

  final String audienceValue;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (audienceValue) {
      'public' => (
          Icons.public_rounded,
          'Your post is set to Public. Anyone on or off KatsKlub can see your post, images, and other media.',
        ),
      'friends' => (
          Icons.group_rounded,
          'Your post is set to Friends. Only your followers can see this post and media.',
        ),
      _ => (
          Icons.lock_rounded,
          'Your post is set to Only Me. Only you can see and access this post.',
        ),
    };

    const bgColor = Color(0xFFF3F4F6);
    const borderColor = Color(0xFFE5E7EB);
    const textColor = Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostPostToggle extends StatelessWidget {
  const _GhostPostToggle({
    required this.isGhost,
    required this.onChanged,
  });

  final bool isGhost;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final activeBg = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFF5F3FF);
    const activeBorderColor = Color(0xFFFF7A59);
    final inactiveBg = isDark ? const Color(0xFF18191A) : Colors.white;
    final inactiveBorderColor = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);
    
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final cardContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGhost
                  ? (isDark ? const Color(0xFF312E81) : const Color(0xFFDDD6FE))
                  : (isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6)),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '👻',
              style: TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ghost Post',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Disappears in 24h. Replies go to DMs.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isGhost,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFF7A59),
            activeTrackColor: const Color(0xFFFF7A59).withValues(alpha: 0.3),
          ),
        ],
      ),
    );

    return isGhost
        ? CustomPaint(
            painter: _DashedBorderPainter(
              color: activeBorderColor,
              borderRadius: 16,
              strokeWidth: 1.5,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: activeBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: cardContent,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: inactiveBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: inactiveBorderColor),
            ),
            child: cardContent,
          );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.borderRadius = 12.0,
  });

  final Color color;
  final double strokeWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashWidth = 5.0;
    final dashSpace = 3.0;
    
    final pms = path.computeMetrics();
    for (final pm in pms) {
      double distance = 0.0;
      while (distance < pm.length) {
        final len = dashWidth;
        canvas.drawPath(
          pm.extractPath(distance, distance + len),
          paint,
        );
        distance += len + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
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
