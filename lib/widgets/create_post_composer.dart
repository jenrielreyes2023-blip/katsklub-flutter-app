import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/post_service.dart';

enum _CreateMode {
  post,
  discussion,
  album,
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
  List<SelectedPostImage> _images = [];
  SelectedPostImage? _discussionCover;
  SelectedPostImage? _reelImage;
  PreparedVideo? _selectedVideo;
  bool _isPickingImages = false;
  bool _isPickingVideo = false;
  bool _isPosting = false;
  String? _errorMessage;
  String? _progressMessage;
  double? _progressValue;

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
      _CreateMode.post =>
        (body.isNotEmpty || _images.any((image) => image.isReady)) && imagesReady,
      _CreateMode.discussion =>
        title.isNotEmpty &&
            body.isNotEmpty &&
            (_discussionCover == null || _discussionCover!.isReady),
      _CreateMode.album =>
        title.isNotEmpty &&
            imagesReady &&
            (_images.any((image) => image.isReady) || _selectedVideo != null),
      _CreateMode.reel =>
        (_reelImage == null || _reelImage!.isReady) &&
            (body.isNotEmpty || _reelImage?.isReady == true || _selectedVideo != null),
    };
    if (_canPostNotifier.value != canPost) {
      _canPostNotifier.value = canPost;
    }
  }

  String get _bodyPlaceholder {
    return switch (_mode) {
      _CreateMode.post => 'Share your thoughts...',
      _CreateMode.discussion => 'Write your topic, blog, or announcement...',
      _CreateMode.album => 'Add a caption for your album...',
      _CreateMode.reel => 'Add a caption for your reel...',
    };
  }

  String get _headerTitle {
    return switch (_mode) {
      _CreateMode.post => 'Create a post',
      _CreateMode.discussion => 'Create Discussion',
      _CreateMode.album => 'Upload album',
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
      _CreateMode.album => 'Post album',
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
      _discussionCover = null;
      _reelImage = null;
      _selectedVideo = null;
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

  Future<void> _pickReelImage() async {
    setState(() {
      _isPickingImages = true;
      _errorMessage = null;
      _progressMessage = 'Preparing reel image...';
      _progressValue = null;
    });

    try {
      await _postService.pickSinglePreparedImage(
        onProgress: _handleProgress,
        onImageSelected: (image) {
          if (!mounted) return;
          setState(() {
            _reelImage = image;
            _selectedVideo = null;
          });
          _syncCanPostState();
        },
        onImageUpdated: (image) {
          if (!mounted) return;
          setState(() {
            _reelImage = image;
          });
          _syncCanPostState();
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to select reel image: $error';
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
            _reelImage = null;
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

    if (_images.any((image) => !image.isReady) ||
        (_discussionCover != null && !_discussionCover!.isReady) ||
        (_reelImage != null && !_reelImage!.isReady)) {
      setState(() {
        _errorMessage = 'Please remove failed images or wait until all media is ready.';
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
        onProgress: _handleProgress,
        albumTitle: _mode == _CreateMode.album ? title : null,
        isDiscussion: _mode == _CreateMode.discussion,
        discussionTitle: _mode == _CreateMode.discussion ? title : null,
        discussionCoverDataUrl:
            _mode == _CreateMode.discussion && _discussionCover?.isReady == true
                ? _discussionCover!.dataUrl
                : null,
        isReel: _mode == _CreateMode.reel,
        reelImage: _mode == _CreateMode.reel ? _reelImage : null,
        videoDataUrl: _selectedVideo?.dataUrl,
        videoTitle: _selectedVideo?.name,
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
      _controller.clear();
      setState(() {
        _titleController.clear();
        _images = [];
        _discussionCover = null;
        _reelImage = null;
        _selectedVideo = null;
        _visibility = 'public';
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

  @override
  Widget build(BuildContext context) {
    final showAudience = _mode == _CreateMode.post || _mode == _CreateMode.album;

    return Container(
      color: const Color(0xFFF7F8FA),
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
              padding: const EdgeInsets.all(16),
              children: [
                _ModeSelector(
                  value: _mode,
                  onChanged: _isPosting || _isPickingImages || _isPickingVideo
                      ? null
                      : _setMode,
                ),
                const SizedBox(height: 14),
                _UserRow(user: widget.user),
                if (showAudience) ...[
                  const SizedBox(height: 14),
                  _AudienceSelector(
                    value: _visibility,
                    options: _audienceOptions,
                    onChanged: (value) {
                      setState(() {
                        _visibility = value;
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 14),
                if (_mode == _CreateMode.discussion || _mode == _CreateMode.album)
                  TextField(
                    controller: _titleController,
                    enabled: !_isPosting,
                    maxLength: _mode == _CreateMode.discussion ? 200 : 120,
                    decoration: InputDecoration(
                      hintText: _mode == _CreateMode.discussion
                          ? 'Discussion title'
                          : 'Album title',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                TextField(
                  controller: _controller,
                  enabled: !_isPosting,
                  maxLines: _mode == _CreateMode.reel ? 5 : 8,
                  minLines: _mode == _CreateMode.reel ? 3 : 5,
                  maxLength: 10000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _bodyPlaceholder,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_mode == _CreateMode.discussion && _discussionCover != null) ...[
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
                if ((_mode == _CreateMode.post || _mode == _CreateMode.album) &&
                    _images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SelectedImageGrid(
                    images: _images,
                    onRemove: _isPosting ? null : _removeImage,
                  ),
                ],
                if (_mode == _CreateMode.reel && _reelImage != null) ...[
                  const SizedBox(height: 8),
                  _SingleImageCard(
                    image: _reelImage!,
                    onRemove: _isPosting
                        ? null
                        : () {
                            setState(() {
                              _reelImage = null;
                            });
                            _syncCanPostState();
                          },
                  ),
                ],
                if ((_mode == _CreateMode.album || _mode == _CreateMode.reel) &&
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _AttachmentBar(
                  isPickingImages: _isPickingImages,
                  isPosting: _isPosting || _isPickingVideo,
                  mode: _mode,
                  onPickImages: (_mode == _CreateMode.post || _mode == _CreateMode.album)
                      ? _pickImages
                      : _mode == _CreateMode.discussion
                          ? _pickDiscussionCover
                          : _pickReelImage,
                  onPickVideo: (_mode == _CreateMode.album || _mode == _CreateMode.reel)
                      ? _pickVideo
                      : null,
                ),
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          FilledButton(
            onPressed: isPosting || !canPost ? null : onPost,
            child: isPosting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(submitLabel),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: _CreateMode.values
            .map(
              (mode) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FilledButton.tonal(
                    onPressed: onChanged == null ? null : () => onChanged!(mode),
                    style: FilledButton.styleFrom(
                      backgroundColor: value == mode
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF3F4F6),
                      foregroundColor: value == mode
                          ? Colors.white
                          : const Color(0xFF111827),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_labelForMode(mode)),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _labelForMode(_CreateMode mode) {
    return switch (mode) {
      _CreateMode.post => 'Post',
      _CreateMode.discussion => 'Discussion',
      _CreateMode.album => 'Album',
      _CreateMode.reel => 'Reels',
    };
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          child: Text(user.initials),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (user.handle != null)
                Text(
                  user.handle!,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudienceSelector extends StatelessWidget {
  const _AudienceSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<_AudienceOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options
          .map(
            (option) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(option.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: value == option.value
                          ? const Color(0xFF2563EB)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          option.icon,
                          color: value == option.value
                              ? Colors.white
                              : const Color(0xFF4B5563),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.label,
                          style: TextStyle(
                            color: value == option.value
                                ? Colors.white
                                : const Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            option.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: value == option.value
                                  ? Colors.white70
                                  : const Color(0xFF6B7280),
                              fontSize: 9,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
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

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.onRemove,
  });

  final PreparedVideo video;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final sizeMb = video.byteCount / (1024 * 1024);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sizeMb.toStringAsFixed(1)} MB ready',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
        ],
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

class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({
    required this.isPickingImages,
    required this.isPosting,
    required this.mode,
    required this.onPickImages,
    required this.onPickVideo,
  });

  final bool isPickingImages;
  final bool isPosting;
  final _CreateMode mode;
  final VoidCallback onPickImages;
  final VoidCallback? onPickVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isPickingImages || isPosting ? null : onPickImages,
              icon: isPickingImages
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(_imageLabel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  onPickVideo == null || isPickingImages || isPosting ? null : onPickVideo,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(mode == _CreateMode.album ? 'Add video' : 'Video'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.queue_music_outlined),
              label: const Text('Music'),
            ),
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
      _CreateMode.reel => 'Image reel',
    };
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
