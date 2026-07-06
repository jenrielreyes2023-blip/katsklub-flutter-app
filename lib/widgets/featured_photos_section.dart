import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

String _mimeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

Future<String> _fileToDataUrl(File file) async {
  final bytes = await file.readAsBytes();
  final mime = _mimeFromPath(file.path);
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

class FeaturedPhotosSection extends StatefulWidget {
  final User user;
  final bool isOwnProfile;
  final ValueChanged<User>? onUpdated;

  const FeaturedPhotosSection({
    required this.user,
    required this.isOwnProfile,
    this.onUpdated,
    super.key,
  });

  @override
  State<FeaturedPhotosSection> createState() => _FeaturedPhotosSectionState();
}

class _FeaturedPhotosSectionState extends State<FeaturedPhotosSection> {
  final AuthService _authService = AuthService();
  bool _isMutating = false;

  List<FeaturedPhoto> get _photos => widget.user.featuredPhotos;

  Future<void> _addPhoto({
    String? imageDataUrl,
    String? imageUrl,
    required String caption,
  }) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final result = await _authService.addFeaturedPhoto(
        imageDataUrl: imageDataUrl,
        imageUrl: imageUrl,
        caption: caption,
      );
      if (!mounted) return;
      if (result.ok && result.user != null) {
        widget.onUpdated?.call(result.user!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to add featured photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _removePhoto(int photoId) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final result = await _authService.removeFeaturedPhoto(photoId);
      if (!mounted) return;
      if (result.ok && result.user != null) {
        widget.onUpdated?.call(result.user!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to remove featured photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _showAddOptions() async {
    if (_photos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 5 featured photos allowed.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AddPhotoBottomSheet(
          onPhotoSelected: (dataUrl, url, caption) {
            _addPhoto(imageDataUrl: dataUrl, imageUrl: url, caption: caption);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A00), Color(0xFFFF5E3A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8A00).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Featured Photos',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1E21),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              if (widget.isOwnProfile)
                GestureDetector(
                  onTap: _showAddOptions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _photos.length >= 5
                          ? Colors.grey.withValues(alpha: 0.1)
                          : const Color(0xFFFF8A00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: _photos.length >= 5 ? Colors.grey : const Color(0xFFFF8A00),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _photos.length >= 5 ? Colors.grey : const Color(0xFFFF8A00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + (widget.isOwnProfile && _photos.length < 5 ? 1 : 0),
            itemBuilder: (context, index) {
              if (widget.isOwnProfile && index == _photos.length) {
                return _buildAddPlaceholderCard();
              }

              final photo = _photos[index];
              return _buildPhotoCard(photo, index);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddPlaceholderCard() {
    return GestureDetector(
      onTap: _showAddOptions,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: Color(0xFFFF8A00),
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add New',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(FeaturedPhoto photo, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black.withValues(alpha: 0.9),
            pageBuilder: (context, animation, secondaryAnimation) {
              return _FeaturedPhotoViewer(
                photos: _photos,
                initialIndex: index,
                isOwnProfile: widget.isOwnProfile,
                onDelete: _removePhoto,
              );
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: ApiConfig.assetUrl(photo.photoUrl),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                ),
              ),
              if (photo.caption.isNotEmpty)
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      photo.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (_isMutating)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageFeaturedPhotosSheet extends StatefulWidget {
  final User user;
  final ValueChanged<User> onUpdated;

  const ManageFeaturedPhotosSheet({
    required this.user,
    required this.onUpdated,
    super.key,
  });

  @override
  State<ManageFeaturedPhotosSheet> createState() => _ManageFeaturedPhotosSheetState();
}

class _ManageFeaturedPhotosSheetState extends State<ManageFeaturedPhotosSheet> {
  final AuthService _authService = AuthService();
  bool _isMutating = false;
  late List<FeaturedPhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<FeaturedPhoto>.from(widget.user.featuredPhotos);
  }

  Future<void> _addPhoto({
    String? imageDataUrl,
    String? imageUrl,
    required String caption,
  }) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final result = await _authService.addFeaturedPhoto(
        imageDataUrl: imageDataUrl,
        imageUrl: imageUrl,
        caption: caption,
      );
      if (!mounted) return;
      if (result.ok && result.user != null) {
        setState(() {
          _photos = List<FeaturedPhoto>.from(result.user!.featuredPhotos);
        });
        widget.onUpdated(result.user!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to add featured photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _removePhoto(int photoId) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final result = await _authService.removeFeaturedPhoto(photoId);
      if (!mounted) return;
      if (result.ok && result.user != null) {
        setState(() {
          _photos = List<FeaturedPhoto>.from(result.user!.featuredPhotos);
        });
        widget.onUpdated(result.user!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to remove featured photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _showAddOptions() async {
    if (_photos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 5 featured photos allowed.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AddPhotoBottomSheet(
          onPhotoSelected: (dataUrl, url, caption) {
            _addPhoto(imageDataUrl: dataUrl, imageUrl: url, caption: caption);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 18 + bottomPadding),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Featured Photos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isMutating
                ? null
                : (_photos.length >= 5
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maximum of 5 featured photos allowed.')),
                        );
                      }
                    : _showAddOptions),
            style: ElevatedButton.styleFrom(
              backgroundColor: _photos.length >= 5
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFFFF7A45), // Premium orange
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 44),
            ),
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(
              _photos.length >= 5 ? 'Limit Reached (5/5)' : 'Add Featured Photo',
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_outline_rounded,
                          size: 48,
                          color: const Color(0xFF9CA3AF).withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No featured photos yet',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add photos to display them on your profile.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    itemCount: _photos.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: ApiConfig.assetUrl(photo.photoUrl),
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(color: const Color(0xFFF3F4F6)),
                                errorWidget: (c, u, e) => Container(
                                  color: const Color(0xFFF3F4F6),
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: _isMutating ? null : () => _removePhoto(photo.id),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (photo.caption.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Text(
                                  photo.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (_isMutating)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

typedef _PhotoSelectedCallback = void Function(
  String? imageDataUrl,
  String? imageUrl,
  String caption,
);

class _AddPhotoBottomSheet extends StatefulWidget {
  final _PhotoSelectedCallback onPhotoSelected;

  const _AddPhotoBottomSheet({required this.onPhotoSelected});

  @override
  State<_AddPhotoBottomSheet> createState() => _AddPhotoBottomSheetState();
}

class _AddPhotoBottomSheetState extends State<_AddPhotoBottomSheet> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  String? _selectedPresetUrl;
  String? _selectedLocalPath;
  bool _isURLMode = false;
  bool _isPresetMode = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _presets = [
    {
      'title': 'Sunset Beach 🌅',
      'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop',
    },
    {
      'title': 'Alpine Peak 🏔️',
      'url': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop',
    },
    {
      'title': 'Cosmic Night 🌌',
      'url': 'https://images.unsplash.com/photo-1506318137071-a8e063b4bec0?w=800&auto=format&fit=crop',
    },
    {
      'title': 'Cozy Café ☕',
      'url': 'https://images.unsplash.com/photo-1453614512568-c4024d13c247?w=800&auto=format&fit=crop',
    },
    {
      'title': 'Forest Path 🌲',
      'url': 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=800&auto=format&fit=crop',
    },
    {
      'title': 'Sakura Cherry 🌸',
      'url': 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&auto=format&fit=crop',
    },
  ];

  @override
  void dispose() {
    _captionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked != null) {
        setState(() {
          _selectedLocalPath = picked.path;
          _selectedPresetUrl = null;
          _isURLMode = false;
          _isPresetMode = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    String? dataUrl;
    String? remoteUrl;

    if (_selectedLocalPath != null) {
      setState(() => _isSubmitting = true);
      try {
        dataUrl = await _fileToDataUrl(File(_selectedLocalPath!));
      } catch (e) {
        debugPrint('Error encoding image: $e');
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read selected image.')),
        );
        return;
      }
    } else if (_isURLMode && _urlController.text.trim().isNotEmpty) {
      remoteUrl = _urlController.text.trim();
    } else if (_isPresetMode && _selectedPresetUrl != null) {
      remoteUrl = _selectedPresetUrl;
    }

    if (dataUrl == null && remoteUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a photo first.')),
      );
      return;
    }

    widget.onPhotoSelected(
      dataUrl,
      remoteUrl,
      _captionController.text.trim(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedLocalPath != null ||
        (_isURLMode && _urlController.text.trim().isNotEmpty) ||
        (_isPresetMode && _selectedPresetUrl != null);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Featured Photo',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),

            if (!hasSelection) ...[
              _buildOptionRow(
                icon: Icons.photo_library_outlined,
                title: 'Choose from Gallery',
                subtitle: 'Pick a photo from your local device storage',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6)),
              _buildOptionRow(
                icon: Icons.camera_alt_outlined,
                title: 'Take a Photo',
                subtitle: 'Use camera to snap a featured photo',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6)),
              _buildOptionRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Choose from Aesthetic Presets',
                subtitle: 'Select from our beautiful curated stock scenes',
                onTap: () {
                  setState(() {
                    _isPresetMode = true;
                    _isURLMode = false;
                  });
                },
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6)),
              _buildOptionRow(
                icon: Icons.link_outlined,
                title: 'Enter Image Web URL',
                subtitle: 'Paste any image address directly from the web',
                onTap: () {
                  setState(() {
                    _isURLMode = true;
                    _isPresetMode = false;
                  });
                },
              ),
            ] else ...[
              Center(
                child: Container(
                  height: 160,
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildPreviewThumbnail(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
               Center(
                child: TextButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _selectedLocalPath = null;
                            _selectedPresetUrl = null;
                            _isURLMode = false;
                            _isPresetMode = false;
                          });
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFFF7A45)),
                  label: const Text(
                    'Change Photo',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7A45),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Caption (Optional)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: 'e.g. Vacation vibes... 🏖️',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  counterText: '',
                ),
                style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A45), // Premium orange
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Done',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],

            if (_isURLMode && !hasSelection) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFFF7A45)),
                    onPressed: () {
                      if (_urlController.text.trim().isNotEmpty) {
                        setState(() {});
                      }
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 13, fontFamily: 'Inter', color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
            ],

            if (_isPresetMode && !hasSelection) ...[
              const SizedBox(height: 12),
              Text(
                'Select a Preset:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presets.length,
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPresetUrl = preset['url'];
                        });
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: preset['url']!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                              ),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    preset['title']!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewThumbnail() {
    if (_selectedLocalPath != null) {
      return Image.file(
        File(_selectedLocalPath!),
        fit: BoxFit.cover,
      );
    } else if (_selectedPresetUrl != null) {
      return CachedNetworkImage(
        imageUrl: _selectedPresetUrl!,
        fit: BoxFit.cover,
      );
    } else if (_urlController.text.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _urlController.text.trim(),
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
        ),
      );
    }
    return Container(color: Colors.grey);
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDark ? const Color(0xFFFF7A45) : const Color(0xFF4B5563), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}

class _FeaturedPhotoViewer extends StatefulWidget {
  final List<FeaturedPhoto> photos;
  final int initialIndex;
  final bool isOwnProfile;
  final Future<void> Function(int photoId) onDelete;

  const _FeaturedPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.isOwnProfile,
    required this.onDelete,
  });

  @override
  State<_FeaturedPhotoViewer> createState() => _FeaturedPhotoViewerState();
}

class _FeaturedPhotoViewerState extends State<_FeaturedPhotoViewer> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    final photo = widget.photos[_currentIndex];
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Delete Photo?',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: const Text(
            'Are you sure you want to remove this photo from your featured section?',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4B5563)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.onDelete(photo.id);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return _ZoomableImageItem(photoUrl: photo.photoUrl);
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
                if (widget.isOwnProfile)
                  IconButton(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.photos[_currentIndex].caption.isNotEmpty) ...[
                    Text(
                      widget.photos[_currentIndex].caption,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    'Photo ${_currentIndex + 1} of ${widget.photos.length}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImageItem extends StatefulWidget {
  final String photoUrl;

  const _ZoomableImageItem({required this.photoUrl});

  @override
  State<_ZoomableImageItem> createState() => _ZoomableImageItemState();
}

class _ZoomableImageItemState extends State<_ZoomableImageItem> {
  late TransformationController _transformationController;
  bool _panEnabled = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final pan = scale > 1.0;
    if (_panEnabled != pan) {
      setState(() {
        _panEnabled = pan;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: _panEnabled,
        scaleEnabled: true,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: ApiConfig.assetUrl(widget.photoUrl),
            fit: BoxFit.contain,
            useOldImageOnUrlChange: true,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            imageBuilder: (context, imageProvider) => Image(
              image: imageProvider,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
