import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/post_service.dart';

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
  final _canPostNotifier = ValueNotifier<bool>(false);
  final _postService = PostService();

  String _visibility = 'public';
  List<SelectedPostImage> _images = [];
  bool _isPickingImages = false;
  bool _isPosting = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _controller.removeListener(_syncCanPostState);
    _controller.dispose();
    _canPostNotifier.dispose();
    super.dispose();
  }

  void _syncCanPostState() {
    final canPost = _controller.text.trim().isNotEmpty || _images.isNotEmpty;
    if (_canPostNotifier.value != canPost) {
      _canPostNotifier.value = canPost;
    }
  }

  Future<void> _pickImages() async {
    setState(() {
      _isPickingImages = true;
      _errorMessage = null;
    });

    try {
      final pickedImages = await _postService.pickImages();
      if (!mounted) return;
      setState(() {
        _images = [..._images, ...pickedImages].take(10).toList();
      });
      _syncCanPostState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to select images: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isPickingImages = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      setState(() {
        _errorMessage = 'Write something or attach an image before posting.';
      });
      return;
    }

    setState(() {
      _isPosting = true;
      _errorMessage = null;
    });

    final result = await _postService.createPost(
      CreatePostRequest(
        text: text,
        visibility: _visibility,
        images: _images,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isPosting = false;
      _errorMessage = result.error;
    });

    if (result.ok) {
      _controller.clear();
      setState(() {
        _images = [];
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
    return Container(
      color: const Color(0xFFF7F8FA),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _canPostNotifier,
            builder: (context, canPost, _) {
              return _ComposerHeader(
                isPosting: _isPosting,
                canPost: canPost,
                onPost: _submit,
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _UserRow(user: widget.user),
                const SizedBox(height: 14),
                _AudienceSelector(
                  value: _visibility,
                  options: _audienceOptions,
                  onChanged: (value) {
                    setState(() {
                      _visibility = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  enabled: !_isPosting,
                  maxLines: 8,
                  minLines: 5,
                  maxLength: 10000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SelectedImageGrid(
                    images: _images,
                    onRemove: _isPosting ? null : _removeImage,
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
                  isPosting: _isPosting,
                  onPickImages: _pickImages,
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
    required this.isPosting,
    required this.canPost,
    required this.onPost,
  });

  final bool isPosting;
  final bool canPost;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Create a post',
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
                : const Text('Post'),
          ),
        ],
      ),
    );
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
          ],
        );
      },
    );
  }
}

class _AttachmentBar extends StatelessWidget {
  const _AttachmentBar({
    required this.isPickingImages,
    required this.isPosting,
    required this.onPickImages,
  });

  final bool isPickingImages;
  final bool isPosting;
  final VoidCallback onPickImages;

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
              label: Text(isPickingImages ? 'Preparing...' : 'Image'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Video'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.music_note_outlined),
              label: const Text('Audio'),
            ),
          ),
        ],
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
