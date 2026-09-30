import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

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

class CreateStoryScreen extends StatelessWidget {
  const CreateStoryScreen({
    required this.user,
    this.initialImageBytes,
    super.key,
  });

  final User user;
  final Uint8List? initialImageBytes;

  @override
  Widget build(BuildContext context) {
    return ImageStoryEditorScreen(
      user: user,
      imageBytes: initialImageBytes,
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

class StoryEditorScreen extends StatelessWidget {
  const StoryEditorScreen({
    required this.user,
    super.key,
  });

  final User user;

  @override
  Widget build(BuildContext context) {
    return ImageStoryEditorScreen(
      user: user,
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

enum StoryTextStyle {
  classic,
  modern,
  neon,
  typewriter,
  strong,
  script,
}

enum TextBgMode {
  none,
  solid,
  translucent,
}

enum BrushType {
  pen,
  neon,
  marker,
}

enum StickerType {
  emoji,
  time,
  day,
  date,
  location,
  badge,
}

const List<Color> _storyPalette = [
  Colors.white,
  Colors.black,
  Color(0xFFFF7A45), // KatsKlub Coral
  Color(0xFFFF2D55), // Hot Pink
  Color(0xFFAF52DE), // Electric Purple
  Color(0xFF007AFF), // Azure Blue
  Color(0xFF5AC8FA), // Sky Cyan
  Color(0xFF34C759), // Mint Green
  Color(0xFFFFCC00), // Sunflower Yellow
  Color(0xFFFF9500), // Tangerine Orange
  Color(0xFFD70015), // Crimson Red
  Color(0xFF00C7BE), // Turquoise
  Color(0xFFD0A9F5), // Pastel Lavender
  Color(0xFF8C6239), // Warm Latte
  Color(0xFF00FF66), // Cyber Neon
  Color(0xFF00FFFF), // Electric Cyan
];

TextStyle _resolveStoryTextStyle(StoryTextStyle style, Color color, {double fontSize = 24}) {
  switch (style) {
    case StoryTextStyle.modern:
      return GoogleFonts.montserrat(
        color: color,
        fontSize: fontSize.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      );
    case StoryTextStyle.neon:
      return GoogleFonts.caveat(
        color: Colors.white,
        fontSize: (fontSize + 6).sp,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.95), blurRadius: 16),
          Shadow(color: color.withValues(alpha: 0.8), blurRadius: 28),
        ],
      );
    case StoryTextStyle.typewriter:
      return GoogleFonts.spaceMono(
        color: color,
        fontSize: (fontSize - 3).sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );
    case StoryTextStyle.strong:
      return GoogleFonts.anton(
        color: color,
        fontSize: (fontSize + 4).sp,
        letterSpacing: 1.2,
      );
    case StoryTextStyle.script:
      return GoogleFonts.dancingScript(
        color: color,
        fontSize: (fontSize + 6).sp,
        fontWeight: FontWeight.w700,
      );
    case StoryTextStyle.classic:
      return TextStyle(
        fontFamily: 'SF Pro Rounded',
        color: color,
        fontSize: fontSize.sp,
        fontWeight: FontWeight.w800,
      );
  }
}

String _formatCurrentTime() {
  final now = DateTime.now();
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  final period = now.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatCurrentDay() {
  const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  final now = DateTime.now();
  return days[now.weekday - 1];
}

String _formatCurrentDate() {
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  final now = DateTime.now();
  return '${months[now.month - 1]} ${now.day}';
}

class _DoodleStroke {
  _DoodleStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.brushType,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final BrushType brushType;
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({
    required this.strokes,
    this.activeStroke,
  });

  final List<_DoodleStroke> strokes;
  final _DoodleStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final allStrokes = [...strokes, if (activeStroke != null) activeStroke!];
    for (final stroke in allStrokes) {
      if (stroke.points.isEmpty) continue;
      if (stroke.points.length == 1) {
        final dotPaint = Paint()
          ..color = stroke.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stroke.points.first, stroke.width / 2, dotPaint);
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        final p0 = stroke.points[i - 1];
        final p1 = stroke.points[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);

      if (stroke.brushType == BrushType.neon) {
        final glowPaint = Paint()
          ..color = stroke.color.withValues(alpha: 0.65)
          ..strokeWidth = stroke.width * 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawPath(path, glowPaint);

        final corePaint = Paint()
          ..color = Colors.white
          ..strokeWidth = stroke.width * 0.75
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, corePaint);
      } else if (stroke.brushType == BrushType.marker) {
        final markerPaint = Paint()
          ..color = stroke.color.withValues(alpha: 0.52)
          ..strokeWidth = stroke.width * 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter;
        canvas.drawPath(path, markerPaint);
      } else {
        final penPaint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, penPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}

class _EqualizerWave extends StatefulWidget {
  const _EqualizerWave({this.color = const Color(0xFFFF7A45)});
  final Color color;

  @override
  State<_EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<_EqualizerWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(10 + 8 * ((val * 1.3) % 1.0)),
            SizedBox(width: 2.w),
            _bar(6 + 14 * ((val * 1.7 + 0.3) % 1.0)),
            SizedBox(width: 2.w),
            _bar(12 + 10 * ((val * 0.9 + 0.6) % 1.0)),
            SizedBox(width: 2.w),
            _bar(5 + 11 * ((val * 1.5 + 0.2) % 1.0)),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3.w,
      height: height.clamp(4.0, 22.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }
}

class _VinylDisc extends StatelessWidget {
  const _VinylDisc({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF141414),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(2, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10, width: 1),
          ),
          child: Center(
            child: Container(
              width: size * 0.44,
              height: size * 0.44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF2D55),
              ),
              child: Center(
                child: Container(
                  width: size * 0.14,
                  height: size * 0.14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF141414),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextOverlay {
  _TextOverlay({
    required this.text,
    Offset? position,
    this.color = Colors.white,
    this.style = StoryTextStyle.classic,
    this.bgMode = TextBgMode.none,
    this.textAlign = TextAlign.center,
  })  : position = position ?? const Offset(50, 100),
        scale = 1.0,
        rotation = 0.0;

  String text;
  Offset position;
  Color color;
  StoryTextStyle style;
  TextBgMode bgMode;
  TextAlign textAlign;
  double scale;
  double rotation;
}

class _TextOverlayWidget extends StatelessWidget {
  const _TextOverlayWidget({
    this.overlay,
    this.text,
  }) : assert(overlay != null || text != null);

  final _TextOverlay? overlay;
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (overlay != null) {
      Color textColor = overlay!.color;
      Color? bgColor;
      Color? borderColor;

      if (overlay!.bgMode == TextBgMode.solid) {
        if (overlay!.color == Colors.white) {
          bgColor = Colors.white;
          textColor = Colors.black;
        } else if (overlay!.color == Colors.black) {
          bgColor = Colors.black;
          textColor = Colors.white;
        } else {
          bgColor = overlay!.color;
          textColor = ThemeData.estimateBrightnessForColor(overlay!.color) == Brightness.dark
              ? Colors.white
              : Colors.black;
        }
      } else if (overlay!.bgMode == TextBgMode.translucent) {
        bgColor = Colors.black.withValues(alpha: 0.65);
        borderColor = Colors.white24;
        textColor = overlay!.color;
      }

      final textStyle = _resolveStoryTextStyle(overlay!.style, textColor);

      return Container(
        constraints: BoxConstraints(maxWidth: 280.w),
        padding: overlay!.bgMode == TextBgMode.none
            ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h)
            : EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14.r),
          border: borderColor != null ? Border.all(color: borderColor, width: 1.2) : null,
          boxShadow: overlay!.bgMode != TextBgMode.none
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          overlay!.text,
          textAlign: overlay!.textAlign,
          style: textStyle,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text ?? '',
        style: TextStyle(
          fontFamily: 'SF Pro Rounded',
          color: Colors.white,
          fontSize: 24.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StoryStickerOverlay {
  _StoryStickerOverlay({
    required this.id,
    required this.type,
    required this.content,
    Offset? position,
  })  : position = position ?? const Offset(120, 220),
        scale = 1.0,
        rotation = 0.0;

  final String id;
  final StickerType type;
  final String content;
  Offset position;
  double scale;
  double rotation;
}

class _StickerOverlayWidget extends StatelessWidget {
  const _StickerOverlayWidget({required this.overlay});

  final _StoryStickerOverlay overlay;

  @override
  Widget build(BuildContext context) {
    switch (overlay.type) {
      case StickerType.emoji:
        return Text(
          overlay.content,
          style: TextStyle(fontSize: 48.sp),
        );

      case StickerType.time:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white24, width: 1.2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, color: const Color(0xFFFF7A45), size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                overlay.content,
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );

      case StickerType.day:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A45), Color(0xFFFF2D55)],
            ),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Text(
            overlay.content,
            style: GoogleFonts.anton(
              color: Colors.white,
              fontSize: 18.sp,
              letterSpacing: 2.0,
            ),
          ),
        );

      case StickerType.date:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Text(
            overlay.content,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: const Color(0xFF111827),
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        );

      case StickerType.location:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFFFF7A45).withValues(alpha: 0.8), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFFF7A45), size: 16),
              SizedBox(width: 6.w),
              Text(
                overlay.content,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case StickerType.badge:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Text(
            overlay.content,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        );
    }
  }
}

class _StoryMusicOverlay {
  _StoryMusicOverlay({
    required this.music,
    Offset? position,
  })  : position = position ?? const Offset(40, 360),
        scale = 1.0,
        rotation = 0.0,
        styleIndex = 0;

  _SelectedStoryMusic music;
  Offset position;
  double scale;
  double rotation;
  int styleIndex; // 0: Glass Card, 1: Minimalist Capsule, 2: Vinyl Showcase
}

class _MusicOverlayWidget extends StatelessWidget {
  const _MusicOverlayWidget({
    required this.overlay,
    required this.onTap,
  });

  final _StoryMusicOverlay overlay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final music = overlay.music;

    if (overlay.styleIndex == 1) {
      // Style 1: Minimalist Capsule Pill
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: Colors.white30, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded, color: Color(0xFFFF7A45), size: 18),
              SizedBox(width: 8.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 180.w),
                child: Text(
                  '${music.title} • ${music.artist}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const _EqualizerWave(color: Colors.white),
            ],
          ),
        ),
      );
    }

    if (overlay.styleIndex == 2) {
      // Style 2: Retro Vinyl Showcase
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.82),
                Colors.black.withValues(alpha: 0.68),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 110.r,
                height: 74.r,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _VinylDisc(size: 70.r),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: CachedNetworkImage(
                          imageUrl: music.artworkUrl,
                          width: 70.r,
                          height: 70.r,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 70.r,
                            height: 70.r,
                            color: Colors.white12,
                            child: const Icon(Icons.music_note, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 140.w),
                child: Column(
                  children: [
                    Text(
                      music.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      music.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        color: Colors.white70,
                        fontSize: 10.sp,
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

    // Style 0: Glassmorphism Album Card (Default)
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: CachedNetworkImage(
                imageUrl: music.artworkUrl,
                width: 44.r,
                height: 44.r,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 44.r,
                  height: 44.r,
                  color: Colors.white12,
                  child: const Icon(Icons.music_note, color: Colors.white70),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 150.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    music.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    music.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            const _EqualizerWave(color: Color(0xFFFF7A45)),
          ],
        ),
      ),
    );
  }
}

class ImageStoryEditorScreen extends StatefulWidget {
  const ImageStoryEditorScreen({
    required this.user,
    this.imageBytes,
    super.key,
  });

  final User user;
  final Uint8List? imageBytes;

  @override
  State<ImageStoryEditorScreen> createState() => _ImageStoryEditorScreenState();
}

class _ImageStoryEditorScreenState extends State<ImageStoryEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _trashKey = GlobalKey();
  final TransformationController _transformController = TransformationController();

  Uint8List? _imageBytes;
  int _gradientIndex = 0;

  static const List<Gradient> _bgGradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2E0854), Color(0xFF180B26), Color(0xFF0D021A)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF0844), Color(0xFFFFB199)],
    ),
    LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFF6A00), Color(0xFFEE0979)],
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
    ),
  ];

  // Mode: Normal vs Drawing vs TextEditing
  bool _isDrawingMode = false;
  bool _isEditingText = false;
  _TextOverlay? _editingTextOverlay;

  // Freehand Doodle State
  final List<_DoodleStroke> _strokes = [];
  _DoodleStroke? _activeStroke;
  Color _brushColor = Colors.white;
  double _brushWidth = 7.0;
  BrushType _brushType = BrushType.pen;

  // Overlays
  final List<_TextOverlay> _textOverlays = [];
  final List<_StoryStickerOverlay> _stickerOverlays = [];
  _StoryMusicOverlay? _musicOverlay;

  // Dragging & Trash Target
  bool _isDraggingOverlay = false;
  bool _isOverTrash = false;

  // Music State (Apple Music)
  _SelectedStoryMusic? _selectedMusic;

  // Text Composer Active State
  final TextEditingController _textEditingController = TextEditingController();
  StoryTextStyle _currentStyle = StoryTextStyle.classic;
  Color _currentColor = Colors.white;
  TextBgMode _currentBgMode = TextBgMode.none;
  TextAlign _currentAlign = TextAlign.center;

  // Sharing & Upload State
  bool _isSharing = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.imageBytes;
  }

  @override
  void dispose() {
    _transformController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _transformController.value = Matrix4.identity();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  Future<void> _capturePhotoFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _transformController.value = Matrix4.identity();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }

  void _cycleGradient() {
    setState(() {
      if (_imageBytes != null) {
        _imageBytes = null;
      } else {
        _gradientIndex = (_gradientIndex + 1) % _bgGradients.length;
      }
    });
  }

  void _openTextEditor({_TextOverlay? existing}) {
    setState(() {
      _editingTextOverlay = existing;
      if (existing != null) {
        _textEditingController.text = existing.text;
        _currentStyle = existing.style;
        _currentColor = existing.color;
        _currentBgMode = existing.bgMode;
        _currentAlign = existing.textAlign;
      } else {
        _textEditingController.clear();
        _currentStyle = StoryTextStyle.classic;
        _currentColor = Colors.white;
        _currentBgMode = TextBgMode.none;
        _currentAlign = TextAlign.center;
      }
      _isEditingText = true;
    });
  }

  void _closeTextEditor() {
    final text = _textEditingController.text.trim();
    setState(() {
      if (_editingTextOverlay != null) {
        if (text.isEmpty) {
          _textOverlays.remove(_editingTextOverlay);
        } else {
          _editingTextOverlay!.text = text;
          _editingTextOverlay!.style = _currentStyle;
          _editingTextOverlay!.color = _currentColor;
          _editingTextOverlay!.bgMode = _currentBgMode;
          _editingTextOverlay!.textAlign = _currentAlign;
        }
      } else if (text.isNotEmpty) {
        _textOverlays.add(
          _TextOverlay(
            text: text,
            position: Offset(50.w, 240.h),
            style: _currentStyle,
            color: _currentColor,
            bgMode: _currentBgMode,
            textAlign: _currentAlign,
          ),
        );
      }
      _isEditingText = false;
      _editingTextOverlay = null;
    });
  }

  void _cycleAlignment() {
    setState(() {
      if (_currentAlign == TextAlign.center) {
        _currentAlign = TextAlign.left;
      } else if (_currentAlign == TextAlign.left) {
        _currentAlign = TextAlign.right;
      } else {
        _currentAlign = TextAlign.center;
      }
    });
  }

  void _cycleBgMode() {
    setState(() {
      if (_currentBgMode == TextBgMode.none) {
        _currentBgMode = TextBgMode.solid;
      } else if (_currentBgMode == TextBgMode.solid) {
        _currentBgMode = TextBgMode.translucent;
      } else {
        _currentBgMode = TextBgMode.none;
      }
    });
  }

  Future<void> _openStickerTray() async {
    final selected = await showModalBottomSheet<_StoryStickerOverlay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return _StoryStickerTraySheet(userLocation: widget.user.location);
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _stickerOverlays.add(selected);
      });
    }
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
      _musicOverlay = _StoryMusicOverlay(
        music: selected,
        position: Offset(40.w, 360.h),
      );
    });
  }

  void _removeMusic() {
    setState(() {
      _selectedMusic = null;
      _musicOverlay = null;
    });
  }

  void _checkTrashHover(Offset globalPoint) {
    final trashBox = _trashKey.currentContext?.findRenderObject() as RenderBox?;
    if (trashBox != null && trashBox.hasSize) {
      final trashOrigin = trashBox.localToGlobal(Offset.zero);
      final trashRect = Rect.fromLTWH(
        trashOrigin.dx - 25,
        trashOrigin.dy - 25,
        trashBox.size.width + 50,
        trashBox.size.height + 50,
      );
      final isOver = trashRect.contains(globalPoint);
      if (isOver != _isOverTrash) {
        if (isOver) {
          HapticFeedback.mediumImpact();
        }
        setState(() {
          _isOverTrash = isOver;
        });
      }
    }
  }

  void _onDragEnd(dynamic overlay) {
    if (_isOverTrash) {
      HapticFeedback.heavyImpact();
      setState(() {
        if (overlay is _TextOverlay) {
          _textOverlays.remove(overlay);
        } else if (overlay is _StoryStickerOverlay) {
          _stickerOverlays.remove(overlay);
        } else if (overlay is _StoryMusicOverlay) {
          _removeMusic();
        }
        _isOverTrash = false;
        _isDraggingOverlay = false;
      });
    } else {
      setState(() {
        _isDraggingOverlay = false;
        _isOverTrash = false;
      });
    }
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

      progressTimer.cancel();
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
      if (progressTimer != null) {
        progressTimer.cancel();
      }
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

  Widget _buildBrushWidthDot(double width) {
    final isSelected = _brushWidth == width;
    return GestureDetector(
      onTap: () => setState(() => _brushWidth = width),
      child: Container(
        width: 34.r,
        height: 34.r,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: (width + 4).clamp(6.0, 24.0),
            height: (width + 4).clamp(6.0, 24.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white60,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Main Canvas Area
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background & Image Area
                          if (_imageBytes != null) ...[
                            // Blurred Background
                            ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.18),
                            ),
                            // Main Image
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
                                          _imageBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ] else ...[
                            // Gradient Background
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: _bgGradients[_gradientIndex],
                              ),
                            ),
                            if (_textOverlays.isEmpty && _stickerOverlays.isEmpty && _strokes.isEmpty && !_isDrawingMode && !_isEditingText)
                              Center(
                                child: GestureDetector(
                                  onTap: () => _openTextEditor(),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(24.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_outlined, color: Colors.white70, size: 18.sp),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Tap to add text',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          // Freehand Doodle Layer
                          CustomPaint(
                            painter: _DoodlePainter(
                              strokes: _strokes,
                              activeStroke: _activeStroke,
                            ),
                            size: Size.infinite,
                          ),
                          // Doodle Touch Area (in drawing mode)
                          if (_isDrawingMode)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) {
                                  final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                  if (renderBox != null) {
                                    final localPos = renderBox.globalToLocal(details.globalPosition);
                                    setState(() {
                                      _activeStroke = _DoodleStroke(
                                        points: [localPos],
                                        color: _brushColor,
                                        width: _brushWidth,
                                        brushType: _brushType,
                                      );
                                    });
                                  }
                                },
                                onPanUpdate: (details) {
                                  final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                                  if (renderBox != null && _activeStroke != null) {
                                    final localPos = renderBox.globalToLocal(details.globalPosition);
                                    setState(() {
                                      _activeStroke!.points.add(localPos);
                                    });
                                  }
                                },
                                onPanEnd: (_) {
                                  if (_activeStroke != null) {
                                    setState(() {
                                      _strokes.add(_activeStroke!);
                                      _activeStroke = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          // Overlays: Music Sticker
                          if (_musicOverlay != null && !_isDrawingMode)
                            Positioned(
                              left: _musicOverlay!.position.dx,
                              top: _musicOverlay!.position.dy,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onScaleStart: (_) {
                                  setState(() => _isDraggingOverlay = true);
                                },
                                onScaleUpdate: (details) {
                                  setState(() {
                                    _musicOverlay!.position += details.focalPointDelta;
                                    if (details.scale != 1.0) {
                                      _musicOverlay!.scale = (_musicOverlay!.scale * details.scale).clamp(0.5, 4.0);
                                    }
                                    if (details.rotation != 0.0) {
                                      _musicOverlay!.rotation += details.rotation;
                                    }
                                  });
                                  _checkTrashHover(details.focalPoint);
                                },
                                onScaleEnd: (_) => _onDragEnd(_musicOverlay),
                                child: Transform.rotate(
                                  angle: _musicOverlay!.rotation,
                                  child: Transform.scale(
                                    scale: _musicOverlay!.scale,
                                    child: _MusicOverlayWidget(
                                      overlay: _musicOverlay!,
                                      onTap: () {
                                        setState(() {
                                          _musicOverlay!.styleIndex = (_musicOverlay!.styleIndex + 1) % 3;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Overlays: Stickers
                          if (!_isDrawingMode)
                            ..._stickerOverlays.map((sticker) {
                              return Positioned(
                                left: sticker.position.dx,
                                top: sticker.position.dy,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (_) {
                                    setState(() {
                                      _isDraggingOverlay = true;
                                      _stickerOverlays.remove(sticker);
                                      _stickerOverlays.add(sticker);
                                    });
                                  },
                                  onScaleUpdate: (details) {
                                    setState(() {
                                      sticker.position += details.focalPointDelta;
                                      if (details.scale != 1.0) {
                                        sticker.scale = (sticker.scale * details.scale).clamp(0.5, 4.0);
                                      }
                                      if (details.rotation != 0.0) {
                                        sticker.rotation += details.rotation;
                                      }
                                    });
                                    _checkTrashHover(details.focalPoint);
                                  },
                                  onScaleEnd: (_) => _onDragEnd(sticker),
                                  child: Transform.rotate(
                                    angle: sticker.rotation,
                                    child: Transform.scale(
                                      scale: sticker.scale,
                                      child: _StickerOverlayWidget(overlay: sticker),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          // Overlays: Text
                          if (!_isDrawingMode)
                            ..._textOverlays.map((overlay) {
                              return Positioned(
                                left: overlay.position.dx,
                                top: overlay.position.dy,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _openTextEditor(existing: overlay),
                                  onScaleStart: (_) {
                                    setState(() {
                                      _isDraggingOverlay = true;
                                      _textOverlays.remove(overlay);
                                      _textOverlays.add(overlay);
                                    });
                                  },
                                  onScaleUpdate: (details) {
                                    setState(() {
                                      overlay.position += details.focalPointDelta;
                                      if (details.scale != 1.0) {
                                        overlay.scale = (overlay.scale * details.scale).clamp(0.5, 4.0);
                                      }
                                      if (details.rotation != 0.0) {
                                        overlay.rotation += details.rotation;
                                      }
                                    });
                                    _checkTrashHover(details.focalPoint);
                                  },
                                  onScaleEnd: (_) => _onDragEnd(overlay),
                                  child: Transform.rotate(
                                    angle: overlay.rotation,
                                    child: Transform.scale(
                                      scale: overlay.scale,
                                      child: _TextOverlayWidget(overlay: overlay),
                                    ),
                                  ),
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
          ),

          // 2. Normal Mode Top Bar
          if (!_isDrawingMode && !_isEditingText)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Gallery Picker Button
                              GestureDetector(
                                onTap: _pickImageFromGallery,
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.0),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Camera Capture Button
                              GestureDetector(
                                onTap: _capturePhotoFromCamera,
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.0),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Palette / Background Gradient Button
                              GestureDetector(
                                onTap: _cycleGradient,
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _imageBytes == null ? const Color(0xFFFF7A45) : Colors.white24,
                                      width: _imageBytes == null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.palette_outlined,
                                    color: _imageBytes == null ? const Color(0xFFFF7A45) : Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Apple Music Button
                              GestureDetector(
                                onTap: _pickMusic,
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedMusic != null ? const Color(0xFFFF7A45) : Colors.white24,
                                      width: _selectedMusic != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: _selectedMusic != null ? const Color(0xFFFF7A45) : Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Stickers & Emojis Button
                              GestureDetector(
                                onTap: _openStickerTray,
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.0),
                                  ),
                                  child: const Icon(
                                    Icons.sentiment_satisfied_alt_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Doodle Drawing Button
                              GestureDetector(
                                onTap: () => setState(() => _isDrawingMode = true),
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.0),
                                  ),
                                  child: const Icon(
                                    Icons.gesture_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Text Tool Button (Aa)
                              GestureDetector(
                                onTap: () => _openTextEditor(),
                                child: Container(
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.0),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Aa',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
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

          // 3. Drawing Mode Top Bar
          if (_isDrawingMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  child: Row(
                    children: [
                      // Pen
                      GestureDetector(
                        onTap: () => setState(() => _brushType = BrushType.pen),
                        child: Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: _brushType == BrushType.pen ? Colors.white : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: _brushType == BrushType.pen ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Neon Glow
                      GestureDetector(
                        onTap: () => setState(() => _brushType = BrushType.neon),
                        child: Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: _brushType == BrushType.neon ? Colors.white : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: _brushType == BrushType.neon ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Marker
                      GestureDetector(
                        onTap: () => setState(() => _brushType = BrushType.marker),
                        child: Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: _brushType == BrushType.marker ? Colors.white : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.brush_rounded,
                            color: _brushType == BrushType.marker ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Undo
                      IconButton(
                        icon: Icon(
                          Icons.undo_rounded,
                          color: _strokes.isNotEmpty ? Colors.white : Colors.white38,
                          size: 24,
                        ),
                        onPressed: _strokes.isNotEmpty
                            ? () => setState(() => _strokes.removeLast())
                            : null,
                      ),
                      // Clear
                      IconButton(
                        icon: Icon(
                          Icons.delete_sweep_rounded,
                          color: _strokes.isNotEmpty ? Colors.white : Colors.white38,
                          size: 24,
                        ),
                        onPressed: _strokes.isNotEmpty
                            ? () => setState(() => _strokes.clear())
                            : null,
                      ),
                      // Done
                      TextButton(
                        onPressed: () => setState(() => _isDrawingMode = false),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Drawing Mode Bottom Bar
          if (_isDrawingMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildBrushWidthDot(3.0),
                          SizedBox(width: 16.w),
                          _buildBrushWidthDot(7.0),
                          SizedBox(width: 16.w),
                          _buildBrushWidthDot(14.0),
                          SizedBox(width: 16.w),
                          _buildBrushWidthDot(24.0),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      SizedBox(
                        height: 38.r,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          itemCount: _storyPalette.length,
                          separatorBuilder: (_, __) => SizedBox(width: 8.w),
                          itemBuilder: (context, index) {
                            final color = _storyPalette[index];
                            final isSelected = _brushColor == color;
                            return GestureDetector(
                              onTap: () => setState(() => _brushColor = color),
                              child: Container(
                                width: 32.r,
                                height: 32.r,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white24,
                                    width: isSelected ? 3.0 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Drag-to-Delete Trash Can
          if (_isDraggingOverlay)
            Positioned(
              bottom: 74.h,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  key: _trashKey,
                  duration: const Duration(milliseconds: 180),
                  width: _isOverTrash ? 62.r : 50.r,
                  height: _isOverTrash ? 62.r : 50.r,
                  decoration: BoxDecoration(
                    color: _isOverTrash
                        ? const Color(0xFFFF2D55)
                        : Colors.black.withValues(alpha: 0.68),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isOverTrash ? Colors.white : Colors.white38,
                      width: _isOverTrash ? 2.5 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isOverTrash
                            ? const Color(0xFFFF2D55).withValues(alpha: 0.6)
                            : Colors.black45,
                        blurRadius: _isOverTrash ? 18 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isOverTrash
                          ? Icons.delete_forever_rounded
                          : Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: _isOverTrash ? 28.sp : 22.sp,
                    ),
                  ),
                ),
              ),
            ),

          // 6. Normal Mode Bottom Bar
          if (!_isDrawingMode && !_isEditingText)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.5.r),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF7A45), Color(0xFFFF2D55), Color(0xFFAF52DE)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 17.r,
                          backgroundImage: widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(widget.user.avatarUrl!)
                              : null,
                          child: widget.user.avatarUrl == null || widget.user.avatarUrl!.isEmpty
                              ? const Icon(Icons.person, color: Colors.white, size: 20)
                              : null,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSharing ? null : _shareStory,
                          child: Container(
                            height: 44.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24.r),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Your story',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Rounded',
                                    color: const Color(0xFF111827),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: const Color(0xFF111827),
                                  size: 13.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. Fullscreen Rich Text Editor Overlay
          if (_isEditingText)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Top Bar: Alignment, Background Mode, Done
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _currentAlign == TextAlign.left
                                      ? Icons.format_align_left_rounded
                                      : _currentAlign == TextAlign.center
                                          ? Icons.format_align_center_rounded
                                          : Icons.format_align_right_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: _cycleAlignment,
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: _cycleBgMode,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: _currentBgMode == TextBgMode.none
                                        ? Colors.white24
                                        : _currentBgMode == TextBgMode.solid
                                            ? Colors.white
                                            : Colors.white38,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: _currentBgMode == TextBgMode.solid ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _closeTextEditor,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    'Done',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Center TextField with Live Preview
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: TextField(
                                controller: _textEditingController,
                                autofocus: true,
                                maxLines: null,
                                textAlign: _currentAlign,
                                cursorColor: const Color(0xFFFF7A45),
                                inputFormatters: [EmojiPresentationFormatter()],
                                style: _resolveStoryTextStyle(
                                  _currentStyle,
                                  _currentBgMode == TextBgMode.solid && _currentColor == Colors.white
                                      ? Colors.black
                                      : _currentColor,
                                  fontSize: 28,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Type something...',
                                  hintStyle: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 24.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom Controls: Font Styles & Color Palette
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Font Styles Row
                            SizedBox(
                              height: 38.h,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                children: [
                                  _buildFontStyleChip('Classic', StoryTextStyle.classic),
                                  _buildFontStyleChip('Modern', StoryTextStyle.modern),
                                  _buildFontStyleChip('Neon', StoryTextStyle.neon),
                                  _buildFontStyleChip('Typewriter', StoryTextStyle.typewriter),
                                  _buildFontStyleChip('Strong', StoryTextStyle.strong),
                                  _buildFontStyleChip('Script', StoryTextStyle.script),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),
                            // Color Palette Row
                            SizedBox(
                              height: 38.r,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                itemCount: _storyPalette.length,
                                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                                itemBuilder: (context, index) {
                                  final color = _storyPalette[index];
                                  final isSelected = _currentColor == color;
                                  return GestureDetector(
                                    onTap: () => setState(() => _currentColor = color),
                                    child: Container(
                                      width: 32.r,
                                      height: 32.r,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white24,
                                          width: isSelected ? 3.0 : 1.0,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.6),
                                                  blurRadius: 8,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 16.h),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 8. Sharing Progress Dialog
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
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF7A59),
                              strokeWidth: 4,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          _uploadStatus,
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
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
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
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

  Widget _buildFontStyleChip(String label, StoryTextStyle style) {
    final isSelected = _currentStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _currentStyle = style),
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }
}

class _StoryStickerTraySheet extends StatelessWidget {
  const _StoryStickerTraySheet({this.userLocation});

  final String? userLocation;

  static const List<String> _popularEmojis = [
    '❤️', '🔥', '😂', '✨', '🥺', '🌸',
    '🐱', '🎧', '🌧️', '☕', '🦋', '🍓',
    '🧸', '🌙', '🥂', '📸', '💖', '🍰',
    '🤍', '💫', '🎶', '🍿', '⚡', '🐾',
    '🎀', '🎉', '🤤', '💐', '🫠', '🥰',
    '🥳', '👀', '💅', '☀️', '🌊', '🧁',
  ];

  @override
  Widget build(BuildContext context) {
    final locationText = (userLocation != null && userLocation!.trim().isNotEmpty)
        ? userLocation!.trim()
        : 'Manila, PH 📍';

    return Container(
      height: 520.h,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Stickers & Emojis',
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                Text(
                  'Smart Badges',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white70,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildBadgeChip(
                      context,
                      label: _formatCurrentTime(),
                      type: StickerType.time,
                    ),
                    _buildBadgeChip(
                      context,
                      label: _formatCurrentDay(),
                      type: StickerType.day,
                    ),
                    _buildBadgeChip(
                      context,
                      label: _formatCurrentDate(),
                      type: StickerType.date,
                    ),
                    _buildBadgeChip(
                      context,
                      label: locationText,
                      type: StickerType.location,
                    ),
                    _buildBadgeChip(
                      context,
                      label: '✦ NEW POST ✦',
                      type: StickerType.badge,
                    ),
                    _buildBadgeChip(
                      context,
                      label: 'VIBES ONLY 🎧',
                      type: StickerType.badge,
                    ),
                    _buildBadgeChip(
                      context,
                      label: 'MOOD ☕',
                      type: StickerType.badge,
                    ),
                    _buildBadgeChip(
                      context,
                      label: 'KatsKlub 🐾',
                      type: StickerType.badge,
                    ),
                    _buildBadgeChip(
                      context,
                      label: 'FOR YOU 💫',
                      type: StickerType.badge,
                    ),
                    _buildBadgeChip(
                      context,
                      label: 'COZY 🌧️',
                      type: StickerType.badge,
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Text(
                  'Popular Emojis',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    color: Colors.white70,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _popularEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _popularEmojis[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(
                          _StoryStickerOverlay(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            type: StickerType.emoji,
                            content: emoji,
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: 28.sp),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(
    BuildContext context, {
    required String label,
    required StickerType type,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(
          _StoryStickerOverlay(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            content: label,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
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

      progressTimer.cancel();
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
