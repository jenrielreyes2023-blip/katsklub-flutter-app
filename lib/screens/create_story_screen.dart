import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:video_player/video_player.dart';

import '../config/api_config.dart';
import '../models/story.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../services/auth_service.dart';
import '../utils/emoji_presentation.dart';
import 'story_viewer_screen.dart';

class _OptimizedImage {
  const _OptimizedImage({required this.bytes, required this.mime});
  final Uint8List bytes;
  final String mime;
}

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    required this.user,
    super.key,
  });

  final User user;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ImageStoryEditorScreen(
          user: widget.user,
          imageBytes: bytes,
        ),
      ),
    );
  }

  Future<void> _pickVideoFromGallery() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoStoryEditorScreen(
          user: widget.user,
          videoFile: picked,
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ImageStoryEditorScreen(
          user: widget.user,
          imageBytes: bytes,
        ),
      ),
    );
  }

  Future<void> _captureVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.camera);
    if (picked == null || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoStoryEditorScreen(
          user: widget.user,
          videoFile: picked,
        ),
      ),
    );
  }

  void _openTextEditor() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StoryEditorScreen(user: widget.user),
      ),
    );
  }

  void _showGallerySelector() {
    _showSelectionBottomSheet(
      title: 'Upload from Gallery',
      onPhoto: _pickImageFromGallery,
      onVideo: _pickVideoFromGallery,
    );
  }

  void _showCameraSelector() {
    _showSelectionBottomSheet(
      title: 'Record with Camera',
      onPhoto: _capturePhoto,
      onVideo: _captureVideo,
    );
  }

  void _showSelectionBottomSheet({
    required String title,
    required VoidCallback onPhoto,
    required VoidCallback onVideo,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF1F1F23),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                title,
                style: TextStyle(fontFamily: 'SF Pro Rounded', 
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: _BottomSheetOption(
                      icon: Icons.photo_outlined,
                      label: 'Photo',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onPhoto();
                      },
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _BottomSheetOption(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onVideo();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create story',
          style: TextStyle(fontFamily: 'SF Pro Rounded', 
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 16.h),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24.r),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF8A65), // Warm coral
                            Color(0xFFE53935), // KatsKlub primary red/orange
                            Color(0xFF8E24AA), // Elegant Purple
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24.r),
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.r),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(height: 24.h),
                                  Text(
                                    'Share your moment',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                      color: Colors.white,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w800,
                                      ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'Post a photo, record a video, or write a thought for your followers.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                      color: Colors.white.withValues(alpha: 0.72),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 24, top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StudioOptionButton(
                    icon: Icons.text_fields,
                    label: 'Text',
                    onTap: _openTextEditor,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF36D1DC), Color(0xFF5B86E5)],
                    ),
                  ),
                  _StudioCenterShutterButton(
                    onTap: _showCameraSelector,
                  ),
                  _StudioOptionButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: _showGallerySelector,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioCenterShutterButton extends StatelessWidget {
  const _StudioCenterShutterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: EdgeInsets.all(4.r),
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFFF7A59), // Primary brand accent color
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.camera_alt,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _StudioOptionButton extends StatelessWidget {
  const _StudioOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gradient,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(fontFamily: 'SF Pro Rounded', 
            color: Colors.white70,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            ),
        ),
      ],
    );
  }
}

class _BottomSheetOption extends StatelessWidget {
  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFFF7A59), size: 36),
              SizedBox(height: 12.h),
              Text(
                label,
                style: TextStyle(fontFamily: 'SF Pro Rounded', 
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SelectedStoryMusic {
  const _SelectedStoryMusic({
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

  factory _SelectedStoryMusic.fromResult(MusicSearchResult result) {
    return _SelectedStoryMusic(
      title: result.title,
      artist: result.artist,
      artworkUrl: result.artworkUrl,
      previewUrl: result.previewUrl,
      source: result.source,
    );
  }
}

Future<_SelectedStoryMusic?> _showStoryMusicPicker(
  BuildContext context, {
  _SelectedStoryMusic? currentSelection,
}) {
  return showModalBottomSheet<_SelectedStoryMusic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) {
      return _StoryMusicPickerSheet(currentSelection: currentSelection);
    },
  );
}

class _StoryMusicPickerSheet extends StatefulWidget {
  const _StoryMusicPickerSheet({this.currentSelection});

  final _SelectedStoryMusic? currentSelection;

  @override
  State<_StoryMusicPickerSheet> createState() => _StoryMusicPickerSheetState();
}

class _StoryMusicPickerSheetState extends State<_StoryMusicPickerSheet> {
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
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
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
    final current = widget.currentSelection;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF1C1E21) : const Color(0xFFF7F7F7);
    final titleColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final inputFillColor = isDark ? const Color(0xFF2D2E30) : Colors.white;
    final dragHandleColor = isDark ? const Color(0xFF4E4F51) : const Color(0xFFD1D5DB);
    final secondaryColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: dragHandleColor,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    Text(
                      'Add music',
                      style: TextStyle(fontFamily: 'SF Pro Rounded', 
                        color: titleColor,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onChanged,
                  autofocus: true,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Search Apple Music',
                    hintStyle: TextStyle(color: secondaryColor),
                    prefixIcon: Icon(Icons.search, color: secondaryColor),
                    filled: true,
                    fillColor: inputFillColor,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (current != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0.h),
                  child: _StorySelectedMusicChip(
                    music: current,
                    onRemove: () => Navigator.of(context).pop(current),
                    removeLabel: 'Keep current music',
                    compact: false,
                  ),
                ),
              SizedBox(height: 12.h),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 420),
                  child: _isLoading
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.r),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _error != null
                          ? Padding(
                              padding: EdgeInsets.all(24.r),
                              child: Text(
                                _error!,
                                style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                  color: Color(0xFF6B7280),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : _searchController.text.trim().length < 2
                              ? Padding(
                                  padding: EdgeInsets.all(24.r),
                                  child: Text(
                                    'Search for a song title or artist.',
                                    style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                      color: Color(0xFF6B7280),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : _results.isEmpty
                                  ? Padding(
                                      padding: EdgeInsets.all(24.r),
                                      child: Text(
                                        'No previewable tracks found.',
                                        style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                          color: Color(0xFF6B7280),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.fromLTRB(16.w, 0.h, 16.w, 16.h),
                                      itemBuilder: (context, index) {
                                        final song = _results[index];
                                        return _StoryMusicResultTile(
                                          song: song,
                                          onTap: () => Navigator.of(context).pop(
                                            _SelectedStoryMusic.fromResult(song),
                                          ),
                                        );
                                      },
                                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                                      itemCount: _results.length,
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

class _StoryMusicResultTile extends StatelessWidget {
  const _StoryMusicResultTile({
    required this.song,
    required this.onTap,
  });

  final MusicSearchResult song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242526) : Colors.white;
    final titleColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final secondaryColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);
    final placeholderBg = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: song.artworkUrl.isEmpty
                    ? Container(
                        width: 54,
                        height: 54,
                        color: placeholderBg,
                        child: Icon(Icons.music_note, color: secondaryColor),
                      )
                    : Image.network(
                        song.artworkUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 54,
                          height: 54,
                          color: placeholderBg,
                          child: Icon(Icons.music_note, color: secondaryColor),
                        ),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'SF Pro Rounded', 
                        color: titleColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'SF Pro Rounded', 
                        color: secondaryColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              const Icon(
                Icons.add_circle_outline,
                color: Color(0xFFFF7A45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorySelectedMusicChip extends StatelessWidget {
  const _StorySelectedMusicChip({
    required this.music,
    required this.onRemove,
    this.removeLabel = 'Remove',
    this.compact = true,
  });

  final _SelectedStoryMusic music;
  final VoidCallback onRemove;
  final String removeLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nonCompactBg = isDark ? const Color(0xFF242526) : Colors.white;
    final nonCompactBorder = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);
    final nonCompactTitle = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
    final nonCompactArtist = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: compact ? Colors.white.withValues(alpha: 0.16) : nonCompactBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: compact ? Colors.white.withValues(alpha: 0.25) : nonCompactBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note,
            size: 18,
            color: compact ? Colors.white : const Color(0xFFFF7A45),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  music.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'SF Pro Rounded', 
                    color: compact ? Colors.white : nonCompactTitle,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  music.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'SF Pro Rounded', 
                    color: compact ? Colors.white.withValues(alpha: 0.72) : nonCompactArtist,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onRemove,
            child: Text(
              removeLabel,
              style: TextStyle(fontFamily: 'SF Pro Rounded', 
                color: compact ? Colors.white : const Color(0xFFFF7A45),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({
    required this.user,
    super.key,
  });

  final User user;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final _textController = TextEditingController();
  final _bgColors = const [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
    Color(0xFFF093FB),
    Color(0xFFF5576C),
    Color(0xFF4FACFE),
    Color(0xFF00F2FE),
    Color(0xFF43E97B),
    Color(0xFF38F9D7),
    Color(0xFFFA709A),
    Color(0xFFFEE140),
  ];
  final List<_StoryTextStylePreset> _textPresets = [
    _StoryTextStylePreset(
      label: 'Classic',
      textStyle: TextStyle(fontFamily: 'SF Pro Rounded', 
        color: Colors.white,
        fontSize: 34.sp,
        fontWeight: FontWeight.w700,
        height: 1.2,
        shadows: [
          Shadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
    ),
    _StoryTextStylePreset(
      label: 'Outline',
      textStyle: TextStyle(fontFamily: 'SF Pro Rounded', 
        color: Colors.black,
        fontSize: 34.sp,
        fontWeight: FontWeight.w800,
        height: 1.18,
      ),
      backgroundColor: Colors.white,
      borderColor: Colors.black,
      horizontalPadding: 18,
      verticalPadding: 12,
      borderRadius: 18,
    ),
    _StoryTextStylePreset(
      label: 'Soft',
      textStyle: TextStyle(fontFamily: 'SF Pro Rounded', 
        color: Colors.white,
        fontSize: 32.sp,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        height: 1.24,
      ),
      backgroundColor: Color(0x33000000),
      horizontalPadding: 16,
      verticalPadding: 12,
      borderRadius: 22,
    ),
    _StoryTextStylePreset(
      label: 'Bold',
      textStyle: TextStyle(fontFamily: 'SF Pro Rounded', 
        color: Colors.white,
        fontSize: 38.sp,
        fontWeight: FontWeight.w900,
        height: 1.1,
        letterSpacing: -0.3,
      ),
      backgroundColor: Color(0xCC000000),
      horizontalPadding: 18,
      verticalPadding: 10,
      borderRadius: 14,
    ),
  ];

  int _colorIndex = 0;
  int _textPresetIndex = 0;
  bool _isSharing = false;
  _SelectedStoryMusic? _selectedMusic;
  Offset _textOffset = Offset.zero;
  double _textScale = 1.0;
  double _scaleStart = 1.0;

  LinearGradient get _currentGradient {
    final color1 = _bgColors[_colorIndex % _bgColors.length];
    final color2 = _bgColors[(_colorIndex + 1) % _bgColors.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color1, color2],
    );
  }

  _StoryTextStylePreset get _activePreset => _textPresets[_textPresetIndex % _textPresets.length];

  void _cycleBackground() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _bgColors.length;
    });
  }

  void _cycleTextStyle() {
    setState(() {
      _textPresetIndex = (_textPresetIndex + 1) % _textPresets.length;
    });
  }

  void _resetTextTransform() {
    setState(() {
      _textOffset = Offset.zero;
      _textScale = 1.0;
      _textPresetIndex = 0;
    });
  }

  Future<void> _pickMusic() async {
    final selected = await _showStoryMusicPicker(
      context,
      currentSelection: _selectedMusic,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedMusic = selected;
    });
  }

  void _removeMusic() {
    setState(() {
      _selectedMusic = null;
    });
  }

  Future<void> _shareStory() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some text first')),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas not found');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to export story');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final optimized = await _optimizeImage(pngBytes, 'image/png');
      final dataUrl = 'data:${optimized.mime};base64,${base64Encode(optimized.bytes)}';
      final result = await _uploadImageStory(dataUrl);

      if (!mounted) {
        return;
      }

      if (result.ok) {
        FeedService.notifyStoryCreated();
        if (result.story != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                storyGroups: [
                  [result.story!],
                ],
                initialGroupIndex: 0,
                initialStoryIndex: 0,
              ),
            ),
            result: true,
          );
        } else {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story shared!')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to share story')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<_OptimizedImage> _optimizeImage(Uint8List bytes, String mime) async {
    try {
      if (mime == 'image/gif') {
        return _OptimizedImage(bytes: bytes, mime: mime);
      }

      final webpBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.webp,
      );

      if (webpBytes.isNotEmpty && webpBytes.length < bytes.length * 0.95) {
        return _OptimizedImage(bytes: webpBytes, mime: 'image/webp');
      }

      return _OptimizedImage(bytes: bytes, mime: mime);
    } catch (_) {
      return _OptimizedImage(bytes: bytes, mime: mime);
    }
  }

  Future<_StoryUploadResult> _uploadImageStory(String imageDataUrl) async {
    final token = await _readAuthToken();
    if (token == null) {
      return const _StoryUploadResult(ok: false, error: 'Not authenticated');
    }

    io.Socket? socket;
    try {
      final socketOptions = io.OptionBuilder()
          .setPath('/socket.io/')
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .disableMultiplex()
          .enableReconnection()
          .setReconnectionAttempts(2)
          .setReconnectionDelay(500)
          .setTimeout(20000)
          .setAckTimeout(60000)
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build();

      socket = io.io(ApiConfig.apiBaseUrl, socketOptions);

      final completer = _StoryUploadCompleter();
      var emitSent = false;

      socket.onConnect((_) {
        debugPrint('story upload: socket connected');
        socket?.on('story:new', (payload) {
          debugPrint('story upload: story:new received');
          final storyMap = _readAckMap(payload);
          if (!emitSent || !_storyBelongsToUser(storyMap, widget.user)) {
            return;
          }
          debugPrint('story upload: completed by story:new');
          completer.complete(_StoryUploadResult(ok: true, story: _storyFromPayload(payload)));
        });
        emitSent = true;
        debugPrint('story upload: emit sent');
        socket?.emitWithAck(
          'story:create',
          {
            'imageDataUrl': imageDataUrl,
            'authToken': token,
            if (_selectedMusic != null) 'musicTitle': _selectedMusic!.title,
            if (_selectedMusic != null) 'musicArtist': _selectedMusic!.artist,
            if (_selectedMusic != null) 'musicArtworkUrl': _selectedMusic!.artworkUrl,
            if (_selectedMusic != null) 'musicPreviewUrl': _selectedMusic!.previewUrl,
            if (_selectedMusic != null) 'musicSource': _selectedMusic!.source,
          },
          ack: (response) {
            debugPrint('story upload: ack received');
            final ackMap = _readAckMap(response);
            if (ackMap?['ok'] == true) {
              debugPrint('story upload: completed by ack');
              completer.complete(
                _StoryUploadResult(
                  ok: true,
                  story: _storyFromPayload(ackMap?['story']) ?? _storyFromPayload(response),
                ),
              );
            } else {
              final error = ackMap?['error']?.toString() ?? 'Failed to create story';
              completer.complete(_StoryUploadResult(ok: false, error: error));
            }
          },
        );
      });

      socket.onConnectError((error) {
        completer.complete(_StoryUploadResult(ok: false, error: error.toString()));
      });

      socket.onError((error) {
        completer.complete(_StoryUploadResult(ok: false, error: error.toString()));
      });

      socket.connect();

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('story upload: completed by timeout');
          return const _StoryUploadResult(ok: false, error: 'Upload timeout');
        },
      );
    } catch (error) {
      return _StoryUploadResult(ok: false, error: error.toString());
    } finally {
      socket?.dispose();
    }
  }

  Future<String?> _readAuthToken() async {
    return AuthService().getToken();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.queue_music_outlined, color: Colors.white),
                    onPressed: _pickMusic,
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_fields, color: Colors.white),
                    onPressed: () => _showTextDialog(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: _cycleBackground,
                            child: DecoratedBox(
                              decoration: BoxDecoration(gradient: _currentGradient),
                            ),
                          ),
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.18),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.14),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!hasText)
                            Center(
                              child: GestureDetector(
                                onTap: () => _showTextDialog(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(24.r),
                                  ),
                                  child: Text(
                                    'Tap to add text',
                                    style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                      color: Colors.white,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Center(
                              child: Transform.translate(
                                offset: _textOffset,
                                child: Transform.scale(
                                  scale: _textScale,
                                  child: GestureDetector(
                                    onTap: () => _showTextDialog(context),
                                    onScaleStart: (details) {
                                      _scaleStart = _textScale;
                                    },
                                    onScaleUpdate: (details) {
                                      setState(() {
                                        _textScale = (_scaleStart * details.scale).clamp(0.7, 3.2);
                                        _textOffset += details.focalPointDelta;
                                      });
                                    },
                                    child: _StoryCanvasText(
                                      text: _textController.text,
                                      preset: _activePreset,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedMusic != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _StorySelectedMusicChip(
                        music: _selectedMusic!,
                        onRemove: _removeMusic,
                      ),
                    ),
                  if (hasText)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Drag to move. Pinch to zoom. Tap background to change color.',
                              style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            _activePreset.label,
                            style: TextStyle(fontFamily: 'SF Pro Rounded', 
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasText)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cycleTextStyle,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(23.r),
                                ),
                              ),
                              child: Text(
                                'Text style',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resetTextTransform,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(23.r),
                                ),
                              ),
                              child: Text(
                                'Reset text',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSharing ? null : _shareStory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isSharing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              'Your story',
                              style: TextStyle(fontFamily: 'SF Pro Rounded', 
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _textController.text);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
        final textColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
        final secondaryColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Add text',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 200,
            autofocus: true,
            style: TextStyle(color: textColor),
            inputFormatters: [EmojiPresentationFormatter()],
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: TextStyle(color: secondaryColor),
              border: InputBorder.none,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: secondaryColor),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _textController.text = controller.text;
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'Done',
                style: TextStyle(
                  color: Color(0xFFFF7A45),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StoryTextStylePreset {
  const _StoryTextStylePreset({
    required this.label,
    required this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.horizontalPadding = 0,
    this.verticalPadding = 0,
    this.borderRadius = 0,
  });

  final String label;
  final TextStyle textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
}

class _StoryCanvasText extends StatelessWidget {
  const _StoryCanvasText({
    required this.text,
    required this.preset,
  });

  final String text;
  final _StoryTextStylePreset preset;

  @override
  Widget build(BuildContext context) {
    final hasContainer = preset.backgroundColor != null || preset.borderColor != null;
    final textWidget = Text(
      text,
      textAlign: TextAlign.center,
      style: preset.textStyle,
    );

    if (!hasContainer) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: textWidget,
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 300),
      padding: EdgeInsets.symmetric(
        horizontal: preset.horizontalPadding,
        vertical: preset.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: preset.backgroundColor,
        borderRadius: BorderRadius.circular(preset.borderRadius),
        border: preset.borderColor == null ? null : Border.all(color: preset.borderColor!, width: 1.5),
      ),
      child: textWidget,
    );
  }
}

class _StoryUploadResult {
  const _StoryUploadResult({
    required this.ok,
    this.error,
    this.story,
  });

  final bool ok;
  final String? error;
  final Story? story;
}

class _StoryUploadCompleter {
  final _completer = Completer<_StoryUploadResult>();

  void complete(_StoryUploadResult result) {
    if (_completer.isCompleted) return;
    _completer.complete(result);
  }

  Future<_StoryUploadResult> get future => _completer.future;
}

Map<String, dynamic>? _readAckMap(dynamic response) {
  if (response is Map) {
    return response.map((key, value) => MapEntry(key.toString(), value));
  }
  if (response is List && response.isNotEmpty && response.first is Map) {
    final first = response.first as Map;
    return first.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

bool _looksLikeStoryMap(Map<String, dynamic>? map) {
  if (map == null) {
    return false;
  }

  return map.containsKey('id') &&
      (map.containsKey('authorUsername') ||
          map.containsKey('author_username') ||
          map.containsKey('userId') ||
          map.containsKey('user_id'));
}

Story? _storyFromPayload(dynamic payload) {
  if (payload is Story) {
    return payload;
  }

  final map = _readAckMap(payload);
  if (_looksLikeStoryMap(map)) {
    return Story.fromJson(map!);
  }

  if (map != null && map['story'] != null) {
    final nestedStory = _readAckMap(map['story']);
    if (_looksLikeStoryMap(nestedStory)) {
      return Story.fromJson(nestedStory!);
    }
  }

  return null;
}

String _normalizeComparableValue(Object? value) {
  return value?.toString().trim().toLowerCase() ?? '';
}

bool _storyBelongsToUser(Map<String, dynamic>? story, User user) {
  if (story == null) {
    return false;
  }

  final storyUserId = _normalizeComparableValue(story['userId'] ?? story['user_id']);
  final storyAuthorUsername = _normalizeComparableValue(
    story['authorUsername'] ?? story['author_username'],
  );
  final userId = _normalizeComparableValue(user.id);
  final username = _normalizeComparableValue(user.username);

  if (userId.isNotEmpty && storyUserId == userId) {
    return true;
  }

  if (username.isNotEmpty && storyAuthorUsername == username) {
    return true;
  }

  return false;
}

class ImageStoryEditorScreen extends StatefulWidget {
  const ImageStoryEditorScreen({
    required this.user,
    required this.imageBytes,
    super.key,
  });

  final User user;
  final Uint8List imageBytes;

  @override
  State<ImageStoryEditorScreen> createState() => _ImageStoryEditorScreenState();
}

class _ImageStoryEditorScreenState extends State<ImageStoryEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  final List<_TextOverlay> _textOverlays = [];
  bool _isSharing = false;
  _SelectedStoryMusic? _selectedMusic;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  void _addText() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
        final textColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
        final secondaryColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Add text',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 100,
            autofocus: true,
            style: TextStyle(color: textColor),
            inputFormatters: [EmojiPresentationFormatter()],
            decoration: InputDecoration(
              hintText: 'Type something...',
              hintStyle: TextStyle(color: secondaryColor),
              border: InputBorder.none,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: secondaryColor),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _textOverlays.add(_TextOverlay(text: text));
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text(
                'Add',
                style: TextStyle(
                  color: Color(0xFFFF7A45),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickMusic() async {
    final selected = await _showStoryMusicPicker(
      context,
      currentSelection: _selectedMusic,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedMusic = selected;
    });
  }

  void _removeMusic() {
    setState(() {
      _selectedMusic = null;
    });
  }

  Future<void> _shareStory() async {
    setState(() {
      _isSharing = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Preparing story...';
    });

    Timer? progressTimer;
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas not found');
      }

      setState(() {
        _uploadProgress = 0.15;
        _uploadStatus = 'Optimizing media...';
      });

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to export image');
      }

      final pngBytes = byteData.buffer.asUint8List();
      
      final optimized = await _optimizeImage(pngBytes, 'image/png');
      final base64Data = base64Encode(optimized.bytes);
      final dataUrl = 'data:${optimized.mime};base64,$base64Data';

      setState(() {
        _uploadProgress = 0.35;
        _uploadStatus = 'Uploading to server...';
      });

      progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted || !_isSharing) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_uploadProgress < 0.85) {
            _uploadProgress += 0.04;
          } else if (_uploadProgress < 0.95) {
            _uploadProgress += 0.01;
          }
        });
      });

      final result = await _uploadImageStory(dataUrl);

      progressTimer?.cancel();
      setState(() {
        _uploadProgress = 0.98;
        _uploadStatus = 'Saving story...';
      });

      if (!mounted) return;

      if (result.ok) {
        FeedService.notifyStoryCreated();
        setState(() {
          _uploadProgress = 1.0;
          _uploadStatus = 'Success!';
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        if (result.story != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                storyGroups: [
                  [result.story!],
                ],
                initialGroupIndex: 0,
                initialStoryIndex: 0,
              ),
            ),
            result: true,
          );
        } else {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story shared!')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to share story')),
        );
      }
    } catch (error) {
      progressTimer?.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<_OptimizedImage> _optimizeImage(Uint8List bytes, String mime) async {
    try {
      if (mime == 'image/gif') {
        return _OptimizedImage(bytes: bytes, mime: mime);
      }
      
      final webpBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.webp,
      );
      
      if (webpBytes.isNotEmpty && webpBytes.length < bytes.length * 0.95) {
        return _OptimizedImage(bytes: webpBytes, mime: 'image/webp');
      }
      
      return _OptimizedImage(bytes: bytes, mime: mime);
    } catch (_) {
      return _OptimizedImage(bytes: bytes, mime: mime);
    }
  }

  Future<_StoryUploadResult> _uploadImageStory(String imageDataUrl) async {
    final token = await AuthService().getToken();
    if (token == null) {
      return const _StoryUploadResult(ok: false, error: 'Not authenticated');
    }

    io.Socket? socket;
    try {
      final socketOptions = io.OptionBuilder()
          .setPath('/socket.io/')
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .disableMultiplex()
          .enableReconnection()
          .setReconnectionAttempts(2)
          .setReconnectionDelay(500)
          .setTimeout(20000)
          .setAckTimeout(60000)
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build();

      socket = io.io(ApiConfig.apiBaseUrl, socketOptions);

      final completer = _StoryUploadCompleter();
      var emitSent = false;

      socket.onConnect((_) {
        debugPrint('story upload: socket connected');
        socket?.on('story:new', (payload) {
          debugPrint('story upload: story:new received');
          final storyMap = _readAckMap(payload);
          if (!emitSent || !_storyBelongsToUser(storyMap, widget.user)) {
            return;
          }
          debugPrint('story upload: completed by story:new');
          completer.complete(_StoryUploadResult(ok: true, story: _storyFromPayload(payload)));
        });
        emitSent = true;
        debugPrint('story upload: emit sent');
        socket?.emitWithAck(
          'story:create',
          {
            'imageDataUrl': imageDataUrl,
            'authToken': token,
            if (_selectedMusic != null) 'musicTitle': _selectedMusic!.title,
            if (_selectedMusic != null) 'musicArtist': _selectedMusic!.artist,
            if (_selectedMusic != null) 'musicArtworkUrl': _selectedMusic!.artworkUrl,
            if (_selectedMusic != null) 'musicPreviewUrl': _selectedMusic!.previewUrl,
            if (_selectedMusic != null) 'musicSource': _selectedMusic!.source,
          },
          ack: (response) {
            debugPrint('story upload: ack received');
            final ackMap = _readAckMap(response);
            if (ackMap?['ok'] == true) {
              debugPrint('story upload: completed by ack');
              completer.complete(
                _StoryUploadResult(
                  ok: true,
                  story: _storyFromPayload(ackMap?['story']) ?? _storyFromPayload(response),
                ),
              );
            } else {
              final error = ackMap?['error']?.toString() ?? 'Failed to create story';
              completer.complete(_StoryUploadResult(ok: false, error: error));
            }
          },
        );
      });

      socket.onConnectError((error) {
        completer.complete(_StoryUploadResult(ok: false, error: error.toString()));
      });

      socket.onError((error) {
        completer.complete(_StoryUploadResult(ok: false, error: error.toString()));
      });

      socket.connect();

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('story upload: completed by timeout');
          return const _StoryUploadResult(ok: false, error: 'Upload timeout');
        },
      );
    } catch (error) {
      return _StoryUploadResult(ok: false, error: error.toString());
    } finally {
      socket?.dispose();
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Edit story',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSharing ? null : _shareStory,
                        child: Text(
                          'Share',
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: RepaintBoundary(
                        key: _canvasKey,
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: 0.18),
                              ),
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.all(14.r),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return InteractiveViewer(
                                        transformationController: _transformController,
                                        minScale: 1.0,
                                        maxScale: 8.0,
                                        boundaryMargin: EdgeInsets.all(280.r),
                                        clipBehavior: Clip.none,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          height: constraints.maxHeight,
                                          child: Image.memory(
                                            widget.imageBytes,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              ..._textOverlays.map((overlay) {
                                return Positioned(
                                  left: overlay.position.dx,
                                  top: overlay.position.dy,
                                  child: Draggable(
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: _TextOverlayWidget(text: overlay.text),
                                    ),
                                    childWhenDragging: SizedBox.shrink(),
                                    onDragEnd: (details) {
                                      setState(() {
                                        final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                        if (renderBox != null) {
                                          final localPosition = renderBox.globalToLocal(details.offset);
                                          overlay.position = localPosition;
                                        }
                                      });
                                    },
                                    child: _TextOverlayWidget(text: overlay.text),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedMusic != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _StorySelectedMusicChip(
                            music: _selectedMusic!,
                            onRemove: _removeMusic,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _pickMusic,
                            icon: const Icon(Icons.queue_music_outlined, color: Colors.white, size: 30),
                          ),
                          SizedBox(width: 8.w),
                          IconButton(
                            onPressed: _addText,
                            icon: const Icon(Icons.text_fields, color: Colors.white, size: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSharing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.82),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF7A59),
                              strokeWidth: 4,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          _uploadStatus,
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            ),
                        ),
                        SizedBox(height: 16.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: SizedBox(
                            width: 240,
                            height: 8,
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF7A59)),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white70,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            ),
                        ),
                      ],
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

class _TextOverlay {
  _TextOverlay({required this.text, Offset? position})
      : position = position ?? const Offset(50, 100);

  final String text;
  Offset position;
}

class _TextOverlayWidget extends StatelessWidget {
  const _TextOverlayWidget({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'SF Pro Rounded', 
          color: Colors.white,
          fontSize: 24.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class VideoStoryEditorScreen extends StatefulWidget {
  const VideoStoryEditorScreen({
    required this.user,
    required this.videoFile,
    super.key,
  });

  final User user;
  final XFile videoFile;

  @override
  State<VideoStoryEditorScreen> createState() => _VideoStoryEditorScreenState();
}

class _VideoStoryEditorScreenState extends State<VideoStoryEditorScreen> {
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  final List<_TextOverlay> _textOverlays = [];
  bool _isSharing = false;
  _SelectedStoryMusic? _selectedMusic;
  final GlobalKey _canvasKey = GlobalKey();
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoFile.path));
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
        await _videoController.play();
      }
    } catch (e) {
      debugPrint('Error initializing video in story editor: $e');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _addText() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
        final textColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);
        final secondaryColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Add text',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 100,
            autofocus: true,
            style: TextStyle(color: textColor),
            inputFormatters: [EmojiPresentationFormatter()],
            decoration: InputDecoration(
              hintText: 'Type something...',
              hintStyle: TextStyle(color: secondaryColor),
              border: InputBorder.none,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: secondaryColor),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _textOverlays.add(_TextOverlay(text: text));
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text(
                'Add',
                style: TextStyle(
                  color: Color(0xFFFF7A45),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickMusic() async {
    final selected = await _showStoryMusicPicker(
      context,
      currentSelection: _selectedMusic,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedMusic = selected;
    });
  }

  void _removeMusic() {
    setState(() {
      _selectedMusic = null;
    });
  }

  Future<void> _shareStory() async {
    setState(() {
      _isSharing = true;
      _uploadProgress = 0.05;
      _uploadStatus = 'Preparing video...';
    });

    Timer? progressTimer;
    try {
      final videoBytes = await widget.videoFile.readAsBytes();
      
      setState(() {
        _uploadProgress = 0.20;
        _uploadStatus = 'Encoding media...';
      });

      final extension = widget.videoFile.path.split('.').last.toLowerCase();
      String mime = 'video/mp4';
      if (extension == 'mov') {
        mime = 'video/quicktime';
      } else if (extension == 'webm') {
        mime = 'video/webm';
      } else if (extension == '3gp') {
        mime = 'video/3gpp';
      }

      final base64Data = base64Encode(videoBytes);
      final dataUrl = 'data:$mime;base64,$base64Data';

      // Gather text overlays joined by newlines
      final overlayText = _textOverlays.map((to) => to.text).join('\n');

      setState(() {
        _uploadProgress = 0.35;
        _uploadStatus = 'Uploading to server...';
      });

      progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (!mounted || !_isSharing) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_uploadProgress < 0.85) {
            _uploadProgress += 0.03;
          } else if (_uploadProgress < 0.95) {
            _uploadProgress += 0.005; // slow down while server processes/transcodes video
          }
        });
      });

      final result = await _uploadVideoStory(dataUrl, overlayText.isEmpty ? null : overlayText);

      progressTimer?.cancel();
      setState(() {
        _uploadProgress = 0.98;
        _uploadStatus = 'Processing on server...';
      });

      if (!mounted) return;

      if (result.ok) {
        FeedService.notifyStoryCreated();
        setState(() {
          _uploadProgress = 1.0;
          _uploadStatus = 'Success!';
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        if (result.story != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                storyGroups: [
                  [result.story!],
                ],
                initialGroupIndex: 0,
                initialStoryIndex: 0,
              ),
            ),
            result: true,
          );
        } else {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story shared!')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to share story')),
        );
      }
    } catch (error) {
      progressTimer?.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<_StoryUploadResult> _uploadVideoStory(String videoDataUrl, String? text) async {
    final token = await AuthService().getToken();
    if (token == null) {
      return const _StoryUploadResult(ok: false, error: 'Not authenticated');
    }

    io.Socket? socket;
    try {
      final socketOptions = io.OptionBuilder()
          .setPath('/socket.io/')
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .disableMultiplex()
          .enableReconnection()
          .setReconnectionAttempts(2)
          .setReconnectionDelay(500)
          .setTimeout(20000)
          .setAckTimeout(60000)
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build();

      socket = io.io(ApiConfig.apiBaseUrl, socketOptions);

      final completer = _StoryUploadCompleter();
      var emitSent = false;

      socket.onConnect((_) {
        debugPrint('story upload: socket connected');
        socket?.on('story:new', (payload) {
          debugPrint('story upload: story:new received');
          final storyMap = _readAckMap(payload);
          if (!emitSent || !_storyBelongsToUser(storyMap, widget.user)) {
            return;
          }
          debugPrint('story upload: completed by story:new');
          completer.complete(_StoryUploadResult(ok: true, story: _storyFromPayload(payload)));
        });
        emitSent = true;
        debugPrint('story upload: emit sent');
        socket?.emitWithAck(
          'story:create',
          {
            'videoDataUrl': videoDataUrl,
            if (text != null) 'text': text,
            'authToken': token,
            if (_selectedMusic != null) 'musicTitle': _selectedMusic!.title,
            if (_selectedMusic != null) 'musicArtist': _selectedMusic!.artist,
            if (_selectedMusic != null) 'musicArtworkUrl': _selectedMusic!.artworkUrl,
            if (_selectedMusic != null) 'musicPreviewUrl': _selectedMusic!.previewUrl,
            if (_selectedMusic != null) 'musicSource': _selectedMusic!.source,
          },
          ack: (response) {
            debugPrint('story upload: ack received');
            final ackMap = _readAckMap(response);
            if (ackMap?['ok'] == true) {
              debugPrint('story upload: completed by ack');
              completer.complete(
                _StoryUploadResult(
                  ok: true,
                  story: _storyFromPayload(ackMap?['story']) ?? _storyFromPayload(response),
                ),
              );
            } else {
              final error = ackMap?['error']?.toString() ?? 'Failed to create story';
              completer.complete(_StoryUploadResult(ok: false, error: error));
            }
          },
        );
      });

      socket.onConnectError((error) {
        completer.complete(_StoryUploadResult(ok: false, error: error.toString()));
      });

      socket.onError((error) {
        completer.complete(_StoryUploadResult(ok: false, error: error.toString()));
      });

      socket.connect();

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('story upload: completed by timeout');
          return const _StoryUploadResult(ok: false, error: 'Upload timeout');
        },
      );
    } catch (error) {
      return _StoryUploadResult(ok: false, error: error.toString());
    } finally {
      socket?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Edit story',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSharing ? null : _shareStory,
                        child: Text(
                          'Share',
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRect(
                        child: Stack(
                          key: _canvasKey,
                          fit: StackFit.expand,
                          children: [
                            if (_videoInitialized)
                              Center(
                                child: AspectRatio(
                                  aspectRatio: _videoController.value.aspectRatio,
                                  child: VideoPlayer(_videoController),
                                ),
                              )
                            else
                              Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                            ..._textOverlays.map((overlay) {
                              return Positioned(
                                left: overlay.position.dx,
                                top: overlay.position.dy,
                                child: Draggable(
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: _TextOverlayWidget(text: overlay.text),
                                  ),
                                  childWhenDragging: SizedBox.shrink(),
                                  onDragEnd: (details) {
                                    setState(() {
                                      final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                      if (renderBox != null) {
                                        final localPosition = renderBox.globalToLocal(details.offset);
                                        overlay.position = localPosition;
                                      }
                                    });
                                  },
                                  child: _TextOverlayWidget(text: overlay.text),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedMusic != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _StorySelectedMusicChip(
                            music: _selectedMusic!,
                            onRemove: _removeMusic,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _pickMusic,
                            icon: const Icon(Icons.queue_music_outlined, color: Colors.white, size: 30),
                          ),
                          SizedBox(width: 8.w),
                          IconButton(
                            onPressed: _addText,
                            icon: const Icon(Icons.text_fields, color: Colors.white, size: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSharing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.82),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF7A59),
                              strokeWidth: 4,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          _uploadStatus,
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            ),
                        ),
                        SizedBox(height: 16.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999.r),
                          child: SizedBox(
                            width: 240,
                            height: 8,
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF7A59)),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: TextStyle(fontFamily: 'SF Pro Rounded', 
                            color: Colors.white70,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            ),
                        ),
                      ],
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
