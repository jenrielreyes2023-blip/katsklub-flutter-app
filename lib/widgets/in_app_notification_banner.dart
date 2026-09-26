import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InAppNotificationOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show({
    required BuildContext context,
    required Map<String, dynamic> notification,
    required VoidCallback onTap,
  }) {
    dismiss();

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      return;
    }

    HapticFeedback.lightImpact();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayCtx) {
        return _InAppNotificationBannerHost(
          notification: notification,
          onTap: () {
            dismiss();
            onTap();
          },
          onDismiss: () {
            if (_currentEntry == entry) {
              dismiss();
            }
          },
        );
      },
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    final entry = _currentEntry;
    _currentEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }
}

class _InAppNotificationBannerHost extends StatefulWidget {
  const _InAppNotificationBannerHost({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_InAppNotificationBannerHost> createState() =>
      _InAppNotificationBannerHostState();
}

class _InAppNotificationBannerHostState
    extends State<_InAppNotificationBannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final n = widget.notification;
    final title = n['title']?.toString() ?? 'Notification';
    final body = n['body']?.toString() ?? '';
    final type = n['type']?.toString().toLowerCase() ?? 'general';

    // Sender details
    final actor = n['actor'] is Map ? n['actor'] as Map : null;
    final sender = n['sender'] is Map ? n['sender'] as Map : null;
    final senderName = actor?['displayName']?.toString() ??
        sender?['fullName']?.toString() ??
        n['actorUsername']?.toString() ??
        n['username']?.toString() ??
        title;
    final avatarUrl = actor?['avatarUrl']?.toString() ??
        actor?['avatar_url']?.toString() ??
        sender?['avatarUrl']?.toString() ??
        n['avatarUrl']?.toString() ??
        n['avatar_url']?.toString() ??
        '';

    // Thumbnail preview (for post/photo likes or comments)
    final thumbnailUrl = n['thumbnailUrl']?.toString() ??
        n['postThumbnailUrl']?.toString() ??
        n['imageUrl']?.toString() ??
        n['postImageUrl']?.toString() ??
        '';

    return Positioned(
      top: statusBarHeight + 8.h,
      left: 14.w,
      right: 14.w,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => _handleDismiss(),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E22).withValues(alpha: 0.94)
                            : Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x33FFFFFF)
                              : const Color(0x18000000),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.12,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar with mini action badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 42.w,
                                height: 42.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            color: const Color(0xFF2B2B30),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white54,
                                              size: 20,
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            color: const Color(0xFF2B2B30),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white54,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFF2B2B30),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white54,
                                            size: 20,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: _buildTypeBadge(type),
                              ),
                            ],
                          ),
                          SizedBox(width: 10.w),

                          // Text details
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        senderName,
                                        style: TextStyle(
                                          inherit: false,
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      '• now',
                                      style: TextStyle(
                                        inherit: false,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.45)
                                            : Colors.black.withValues(alpha: 0.45),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  body.isNotEmpty ? body : title,
                                  style: TextStyle(
                                    inherit: false,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : Colors.black87.withValues(alpha: 0.85),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Optional thumbnail preview on right
                          if (thumbnailUrl.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Container(
                                width: 38.w,
                                height: 38.w,
                                color: const Color(0xFF2B2B30),
                                child: CachedNetworkImage(
                                  imageUrl: thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const SizedBox(),
                                  errorWidget: (_, __, ___) => const SizedBox(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    IconData icon;
    List<Color> gradient;

    if (type.contains('like')) {
      icon = Icons.favorite;
      gradient = const [Color(0xFFFF2D55), Color(0xFFE11D48)];
    } else if (type.contains('comment') || type.contains('reply')) {
      icon = Icons.chat_bubble_rounded;
      gradient = const [Color(0xFF3B82F6), Color(0xFF2563EB)];
    } else if (type.contains('follow')) {
      icon = Icons.person_add_rounded;
      gradient = const [Color(0xFFFF7A45), Color(0xFFEA580C)];
    } else if (type.contains('tag') || type.contains('mention')) {
      icon = Icons.local_offer_rounded;
      gradient = const [Color(0xFFF59E0B), Color(0xFFD97706)];
    } else {
      icon = Icons.notifications_rounded;
      gradient = const [Color(0xFFFF7A45), Color(0xFFEC4899)];
    }

    return Container(
      width: 18.w,
      height: 18.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: gradient),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 9.5,
        ),
      ),
    );
  }
}
