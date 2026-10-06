import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room.dart';
import 'custom_icons.dart';

/// Single room card for the Party Rooms lobby grid.
///
/// Scroll-jank notes: the card deliberately avoids [ClipRRect] — the cover
/// image and the scrim carry their own [BorderRadius] so the raster thread
/// never pays a full-card saveLayer. Cover/avatar images are downscaled on
/// decode, the image placeholder is static (no spinner repainting while
/// scrolling), and each card is wrapped in a [RepaintBoundary] so it
/// rasterizes once and is reused from the raster cache.
class VoiceRoomCard extends StatelessWidget {
  static const double _radius = 16;

  /// Max decoded cover size. Cards are ~160dp wide, so ~512px covers 3x screens.
  static const int _coverCacheWidth = 512;
  static const int _coverCacheHeight = 560;

  /// Host avatar is ~18dp, so 72px covers 3x screens.
  static const int _avatarCacheSize = 72;

  const VoiceRoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  final VoiceRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Card Face Image: Room Cover / Icon (own radius, no clip).
              _buildCover(),
              // 2. Gradient Scrim Overlay for Readability (own radius, no clip).
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.65, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.65),
                      const Color(0xFF0F1015).withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
              // 3. Foreground Content.
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Category tag + Rule Badge + LIVE pill + Lock
                    Row(
                      children: [
                        // Category Chip
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomIcons.roomCategory(room.category, color: const Color(0xFFFF7A45), size: 10),
                              SizedBox(width: 3.w),
                              Text(
                                room.category,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 4.w),

                        // Rule Badge (Permanent crown / 24h Temp)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.5.h),
                          decoration: BoxDecoration(
                            color: room.isPermanent
                                ? const Color(0xFFFFB800).withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: room.isPermanent
                                  ? const Color(0xFFFFB800).withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (room.isPermanent)
                                CustomIcons.crown(color: const Color(0xFFFFB800), size: 8)
                              else
                                const Icon(Icons.access_time_rounded, color: Colors.white70, size: 8.5),
                              SizedBox(width: 2.5.w),
                              Text(
                                room.durationBadgeText,
                                style: TextStyle(
                                  color: room.isPermanent ? const Color(0xFFFFB800) : Colors.white70,
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // LIVE Pill
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: const Color(0xFF10B981),
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (room.isLocked) ...[
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 9),
                          ),
                        ],
                      ],
                    ),

                    const Spacer(),

                    // Host Info Row (Host Avatar + Host Name + Mics)
                    Row(
                      children: [
                        Container(
                          width: 18.r,
                          height: 18.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 1),
                          ),
                          child: ClipOval(
                            child: room.host.avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: room.host.avatarUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: _avatarCacheSize,
                                    memCacheHeight: _avatarCacheSize,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, __) => Container(color: const Color(0xFF1E2028)),
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFF141519),
                                      child: const Icon(Icons.person, color: Colors.white, size: 12),
                                    ),
                                  )
                                : const Icon(Icons.person, color: Colors.white, size: 12),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: Text(
                            room.host.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        // Active Mics Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_rounded, size: 9.5.r, color: Colors.white70),
                              SizedBox(width: 2.w),
                              Text(
                                '${room.occupiedSeatsCount}/8',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4.h),

                    // Room Title
                    Text(
                      room.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                        ],
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

  Widget _buildCover() {
    if (room.coverUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22242C), Color(0xFF121317)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.08),
            size: 48.r,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: room.coverUrl,
      fit: BoxFit.cover,
      memCacheWidth: _coverCacheWidth,
      memCacheHeight: _coverCacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      placeholder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2028),
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141519),
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: const Icon(Icons.graphic_eq_rounded, color: Colors.white24, size: 36),
      ),
    );
  }
}
