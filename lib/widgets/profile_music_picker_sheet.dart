import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/feed_service.dart';

class ProfileMusicPickerSheet extends StatefulWidget {
  const ProfileMusicPickerSheet({
    this.currentTitle,
    this.currentArtist,
    this.currentArtwork,
    this.currentMusicUrl,
    required this.onSelected,
    this.onRemove,
    super.key,
  });

  final String? currentTitle;
  final String? currentArtist;
  final String? currentArtwork;
  final String? currentMusicUrl;
  final ValueChanged<MusicSearchResult> onSelected;
  final VoidCallback? onRemove;

  static Future<void> show({
    required BuildContext context,
    String? currentTitle,
    String? currentArtist,
    String? currentArtwork,
    String? currentMusicUrl,
    required ValueChanged<MusicSearchResult> onSelected,
    VoidCallback? onRemove,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileMusicPickerSheet(
        currentTitle: currentTitle,
        currentArtist: currentArtist,
        currentArtwork: currentArtwork,
        currentMusicUrl: currentMusicUrl,
        onSelected: (song) {
          Navigator.of(ctx).pop();
          onSelected(song);
        },
        onRemove: onRemove != null
            ? () {
                Navigator.of(ctx).pop();
                onRemove();
              }
            : null,
      ),
    );
  }

  @override
  State<ProfileMusicPickerSheet> createState() => _ProfileMusicPickerSheetState();
}

class _ProfileMusicPickerSheetState extends State<ProfileMusicPickerSheet> {
  final FeedService _feedService = FeedService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MusicSearchResult> _results = const <MusicSearchResult>[];
  bool _isLoading = false;
  String? _error;

  AudioPlayer? _previewPlayer;
  String? _previewingUrl;
  bool _isPreviewPlaying = false;

  @override
  void initState() {
    super.initState();
    _previewPlayer = AudioPlayer();
    _previewPlayer?.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = (state == PlayerState.playing);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _previewPlayer?.stop();
    _previewPlayer?.dispose();
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

  Future<void> _togglePreview(String previewUrl) async {
    final player = _previewPlayer;
    if (player == null) return;

    if (_previewingUrl == previewUrl && _isPreviewPlaying) {
      await player.pause();
      return;
    }

    try {
      _previewingUrl = previewUrl;
      await player.stop();
      await player.setSourceUrl(previewUrl);
      await player.resume();
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF141416) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);
    final inputFillColor = isDark ? const Color(0xFF202024) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFE5E7EB);

    final hasCurrent = widget.currentTitle != null && widget.currentTitle!.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF38383A) : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
          SizedBox(height: 14.h),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: Row(
              children: [
                Icon(
                  Icons.music_note_rounded,
                  color: const Color(0xFFFF7A45),
                  size: 24.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Profile Song',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22.r, color: subtitleColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Current Song Banner (if exists)
          if (hasCurrent) ...[
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F24) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: widget.currentArtwork != null && widget.currentArtwork!.trim().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.currentArtwork!,
                            width: 38.r,
                            height: 38.r,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: inputFillColor),
                            errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                          )
                        : Container(
                            width: 38.r,
                            height: 38.r,
                            color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                            child: const Icon(Icons.music_note_rounded, color: Color(0xFFFF7A45)),
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: ${widget.currentTitle!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        if (widget.currentArtist != null && widget.currentArtist!.trim().isNotEmpty)
                          Text(
                            widget.currentArtist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 11.5.sp,
                              color: subtitleColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.onRemove != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: widget.onRemove,
                      icon: Icon(Icons.delete_outline_rounded, size: 16.r),
                      label: Text(
                        'Remove',
                        style: TextStyle(fontFamily: 'SF Pro Rounded', fontSize: 12.sp),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Search Field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: TextField(
              controller: _searchController,
              onChanged: _onChanged,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 14.sp,
                color: titleColor,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputFillColor,
                hintText: 'Search song or artist...',
                hintStyle: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 13.5.sp,
                  color: subtitleColor,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20.r,
                  color: subtitleColor,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18.r, color: subtitleColor),
                        onPressed: () {
                          _searchController.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: borderColor, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: borderColor, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFFF7A45), width: 1.2),
                ),
              ),
            ),
          ),

          // Results List
          Expanded(
            child: _buildResults(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFFF7A45),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Searching tracks...',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.sp,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            fontSize: 13.sp,
            color: subtitleColor,
          ),
        ),
      );
    }

    if (_searchController.text.trim().length >= 2 && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded, size: 40.r, color: subtitleColor.withValues(alpha: 0.6)),
            SizedBox(height: 8.h),
            Text(
              'No songs found. Try another title or artist.',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.sp,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 48.r,
              color: subtitleColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 10.h),
            Text(
              'Search for any song to play on your profile',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF222328) : const Color(0xFFF3F4F6),
      ),
      itemBuilder: (context, index) {
        final song = _results[index];
        final isThisPreviewPlaying = _previewingUrl == song.previewUrl && _isPreviewPlaying;

        return ListTile(
          contentPadding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: CachedNetworkImage(
                  imageUrl: song.artworkUrl,
                  width: 48.r,
                  height: 48.r,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 48.r,
                    height: 48.r,
                    color: isDark ? const Color(0xFF222328) : const Color(0xFFE5E7EB),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 48.r,
                    height: 48.r,
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.15),
                    child: const Icon(Icons.music_note, color: Color(0xFFFF7A45)),
                  ),
                ),
              ),
              // Mini preview play/pause overlay
              Material(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: () => _togglePreview(song.previewUrl),
                  child: SizedBox(
                    width: 48.r,
                    height: 48.r,
                    child: Icon(
                      isThisPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26.r,
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isThisPreviewPlaying ? const Color(0xFFFF7A45) : titleColor,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              fontSize: 12.sp,
              color: subtitleColor,
            ),
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A45),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: () {
              _previewPlayer?.stop();
              widget.onSelected(song);
            },
            child: Text(
              'Set',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
