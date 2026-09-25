import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/api_config.dart';

class CoverPhotoCropResult {
  const CoverPhotoCropResult({
    required this.previewBytes,
    required this.dataUrl,
  });

  final Uint8List previewBytes;
  final String dataUrl;
}

class CoverPhotoEditorScreen extends StatefulWidget {
  const CoverPhotoEditorScreen({
    required this.imageBytes,
    this.userAvatarUrl,
    this.userInitials = '',
    super.key,
  });

  final Uint8List imageBytes;
  final String? userAvatarUrl;
  final String userInitials;

  @override
  State<CoverPhotoEditorScreen> createState() => _CoverPhotoEditorScreenState();
}

class _CoverPhotoEditorScreenState extends State<CoverPhotoEditorScreen> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  ui.Image? _decodedImage;
  bool _isLoadingImage = true;
  bool _isSaving = false;
  bool _showGuidelines = true;
  bool _hasInitializedTransform = false;

  double _canvasWidth = 0.0;
  double _canvasHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _decodedImage = frame.image;
        _isLoadingImage = false;
        if (!_hasInitializedTransform &&
            _canvasWidth > 0 &&
            _canvasHeight > 0) {
          _hasInitializedTransform = true;
          _centerTransform(_canvasWidth, _canvasHeight);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingImage = false;
      });
    }
  }

  void _centerTransform(double canvasWidth, double canvasHeight) {
    if (_decodedImage == null) return;
    final imgWidth = _decodedImage!.width.toDouble();
    final imgHeight = _decodedImage!.height.toDouble();
    final scale = math.max(canvasWidth / imgWidth, canvasHeight / imgHeight);
    final scaledWidth = imgWidth * scale;
    final scaledHeight = imgHeight * scale;

    final dx = -(scaledWidth - canvasWidth) / 2.0;
    final dy = -(scaledHeight - canvasHeight) / 2.0;
    _transformController.value = Matrix4.translationValues(dx, dy, 0.0);
  }

  void _resetTransform() {
    if (_canvasWidth > 0 && _canvasHeight > 0) {
      setState(() {
        _centerTransform(_canvasWidth, _canvasHeight);
      });
    }
  }

  Future<void> _saveCover() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _showGuidelines = false; // Hide guidelines for clean capture
    });

    // Wait 1 frame so guidelines disappear from paint tree
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas boundary not ready.');
      }

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to prepare cover photo.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        format: CompressFormat.jpeg,
        quality: 88,
        minWidth: 1200,
        minHeight: 520,
      );

      final outputBytes = compressedBytes.isEmpty
          ? pngBytes
          : Uint8List.fromList(compressedBytes);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(outputBytes)}';

      if (!mounted) return;

      Navigator.of(context).pop(
        CoverPhotoCropResult(previewBytes: outputBytes, dataUrl: dataUrl),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _showGuidelines = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save cover photo: $error')),
        );
      }
    }
  }

  Widget _buildAvatarFallback() {
    if (widget.userInitials.isNotEmpty) {
      return Center(
        child: Text(
          widget.userInitials.toUpperCase(),
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFF7A45),
          ),
        ),
      );
    }
    return Icon(
      Icons.person_rounded,
      size: 30.r,
      color: Colors.white70,
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Cover canvas aspect ratio matches KatsKlub profile header (approx 2.34:1)
    final canvasWidth = screenWidth - 32.w;
    final canvasHeight = canvasWidth * (160.0 / 375.0);

    _canvasWidth = canvasWidth;
    _canvasHeight = canvasHeight;

    if (!_hasInitializedTransform && _decodedImage != null) {
      _hasInitializedTransform = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _centerTransform(canvasWidth, canvasHeight);
        }
      });
    }

    final double imgWidth = _decodedImage?.width.toDouble() ?? 1200.0;
    final double imgHeight = _decodedImage?.height.toDouble() ?? 600.0;

    // Calculate scale to guarantee coverage of the viewport
    final scale = math.max(
      canvasWidth / imgWidth,
      canvasHeight / imgHeight,
    );
    final scaledWidth = imgWidth * scale;
    final scaledHeight = imgHeight * scale;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        title: Text(
          'Reposition Cover Photo',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontFamily: 'SF Pro Rounded',
            fontSize: 16.5.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _resetTransform,
            child: Text(
              'Reset',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: TextButton(
              onPressed: (_isSaving || _isLoadingImage) ? null : _saveCover,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12.h),

            // Instructional tip
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E5EA),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32.r,
                    height: 32.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.open_with_rounded,
                        size: 16.r,
                        color: const Color(0xFFFF7A45),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drag image to reposition',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Pinch to zoom in or out to fit the frame.',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Interactive Editor Box
            Center(
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Canvas boundary captured upon Save
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14.r),
                      child: RepaintBoundary(
                        key: _canvasKey,
                        child: Container(
                          width: canvasWidth,
                          height: canvasHeight,
                          color: isDark
                              ? const Color(0xFF1E1E20)
                              : const Color(0xFFE5E7EB),
                          child: _isLoadingImage
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF7A45),
                                    ),
                                  ),
                                )
                              : InteractiveViewer(
                                  transformationController:
                                      _transformController,
                                  minScale: 1.0,
                                  maxScale: 4.0,
                                  panAxis: PanAxis.free,
                                  boundaryMargin: EdgeInsets.zero,
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.memory(
                                    widget.imageBytes,
                                    width: scaledWidth,
                                    height: scaledHeight,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Guidelines overlay: Avatar watermark position & bottom fade guide
                    if (_showGuidelines && !_isLoadingImage)
                      IgnorePointer(
                        child: Container(
                          width: canvasWidth,
                          height: canvasHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: const Color(0xFFFF7A45)
                                  .withValues(alpha: 0.65),
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Subtle bottom gradient guide showing the fade zone
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: canvasHeight * 0.45,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(13.r),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.0, 0.4, 0.75, 1.0],
                                      colors: [
                                        Colors.transparent,
                                        (isDark
                                                ? const Color(0xFF101012)
                                                : const Color(0xFFF2F2F7))
                                            .withValues(alpha: 0.25),
                                        (isDark
                                                ? const Color(0xFF101012)
                                                : const Color(0xFFF2F2F7))
                                            .withValues(alpha: 0.60),
                                        (isDark
                                                ? const Color(0xFF101012)
                                                : const Color(0xFFF2F2F7))
                                            .withValues(alpha: 0.90),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Avatar silhouette position guide (bottom-left)
                              Positioned(
                                left: 14.w,
                                bottom: -20.h,
                                child: Container(
                                  width: 64.r,
                                  height: 64.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF101012)
                                          : const Color(0xFFF2F2F7),
                                      width: 3.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    color: isDark
                                        ? const Color(0xFF242526)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                  child: ClipOval(
                                    child: (widget.userAvatarUrl != null &&
                                            widget.userAvatarUrl!
                                                .trim()
                                                .isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: ApiConfig.assetUrl(
                                                widget.userAvatarUrl!),
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                _buildAvatarFallback(),
                                            errorWidget: (_, __, ___) =>
                                                _buildAvatarFallback(),
                                          )
                                        : _buildAvatarFallback(),
                                  ),
                                ),
                              ),

                              // Guideline badge (top-right)
                              Positioned(
                                right: 10.w,
                                top: 10.h,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.crop_free_rounded,
                                        size: 12.r,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Preview frame',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Rounded',
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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
                  ],
                ),
              ),
            ),

            SizedBox(height: 28.h),

            // Helper actions
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showGuidelines = !_showGuidelines;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFFE4E6EB)
                          : const Color(0xFF111827),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF38383A)
                            : const Color(0xFFD1D1D6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 9.h,
                      ),
                    ),
                    icon: Icon(
                      _showGuidelines
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16.r,
                    ),
                    label: Text(
                      _showGuidelines ? 'Hide guides' : 'Show guides',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
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
}
