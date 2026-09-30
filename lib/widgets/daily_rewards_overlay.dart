import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/daily_reward_item.dart';
import '../services/daily_rewards_service.dart';
import '../services/game_sound_service.dart';
import '../widgets/user_avatar_with_frame.dart';

class DailyRewardsOverlay extends StatefulWidget {
  const DailyRewardsOverlay({
    super.key,
    this.initialStatus,
  });

  final DailyRewardsStatus? initialStatus;

  static Future<void> show(
    BuildContext context, {
    DailyRewardsStatus? initialStatus,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DailyRewardsOverlay',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => DailyRewardsOverlay(
        initialStatus: initialStatus,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<DailyRewardsOverlay> createState() => _DailyRewardsOverlayState();
}

class _DailyRewardsOverlayState extends State<DailyRewardsOverlay>
    with SingleTickerProviderStateMixin {
  final DailyRewardsService _rewardsService = DailyRewardsService();
  DailyRewardsStatus? _status;
  bool _isLoading = true;
  bool _isClaiming = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (_status == null) {
      setState(() => _isLoading = true);
    }
    final fetched = await _rewardsService.getDailyRewardsStatus();
    if (mounted) {
      setState(() {
        if (fetched != null) _status = fetched;
        _isLoading = false;
      });
    }
  }

  Future<void> _claimToday() async {
    if (_isClaiming || _status == null || !_status!.canClaimToday) return;

    setState(() => _isClaiming = true);
    try {
      final res = await _rewardsService.claimDailyReward();
      if (!mounted) return;

      if (res != null && res.ok && res.reward != null) {
        GameSoundService.playCorrect();
        // Update equipped avatar frame globally if frame was granted
        if (res.reward!.type == 'avatar_frame' && res.reward!.path != null) {
          equippedAdminFrameNotifier.value = res.reward!.path!;
        }

        // Show celebration reveal
        await _showClaimCelebration(res.reward!, res.coinsBalance);

        // Refresh status
        _loadStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?.error ?? res?.message ?? 'Failed to claim reward'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  Future<void> _showClaimCelebration(ClaimedReward reward, double balance) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ClaimCelebrationDialog(
        reward: reward,
        newBalance: balance,
        isAdmin: _status?.isAdmin ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 335.w,
          constraints: BoxConstraints(maxHeight: 620.h),
          decoration: BoxDecoration(
            color: const Color(0xFF14161A),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A45).withValues(alpha: 0.18),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: Stack(
              children: [
                // Background subtle ambient glows
                Positioned(
                  top: -40.h,
                  right: -40.w,
                  child: Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30.h,
                  left: -30.w,
                  child: Container(
                    width: 120.w,
                    height: 120.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEC4899).withValues(alpha: 0.10),
                    ),
                  ),
                ),

                // Main Content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    Flexible(
                      child: _isLoading && _status == null
                          ? SizedBox(
                              height: 300.h,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF7A45),
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : _buildDaysGrid(),
                    ),
                    _buildFooter(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final streak = _status?.streakCount ?? 0;
    final cycle = _status?.currentCycle ?? 1;
    final isAdmin = _status?.isAdmin ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Sparkle / Trophy Icon
          Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A45), Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 20.r,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '7-Day Achievements',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '👑 ADMIN',
                          style: TextStyle(
                            color: const Color(0xFFFBBF24),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      '🔥 $streak Day Streak',
                      style: TextStyle(
                        color: const Color(0xFFFF7A45),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 3.r,
                      height: 3.r,
                      decoration: const BoxDecoration(
                        color: Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Cycle $cycle',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20.r),
            splashRadius: 18.r,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysGrid() {
    final rewards = _status?.rewards ?? [];
    if (rewards.isEmpty) {
      return SizedBox(
        height: 280.h,
        child: const Center(
          child: Text(
            'Daily rewards loading...',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Days 1 to 6 in top 3x2 grid, Day 7 as full-width grand card
    final days1to6 = rewards.take(6).toList();
    final day7 = rewards.length >= 7 ? rewards[6] : null;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Column(
        children: [
          // 3x2 Grid for Days 1-6
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days1to6.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: 0.84,
            ),
            itemBuilder: (context, index) {
              final reward = days1to6[index];
              return _buildDayCard(reward);
            },
          ),
          if (day7 != null) ...[
            SizedBox(height: 8.h),
            _buildDay7GrandCard(day7),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(DailyRewardDay item) {
    final isClaimed = item.isClaimed;
    final isToday = item.isToday && (_status?.canClaimToday ?? false);
    final isAdmin = _status?.isAdmin ?? false;

    Color borderColor = Colors.white.withValues(alpha: 0.08);
    Color bgColor = const Color(0xFF1B1E23);

    if (isClaimed) {
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.35);
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.08);
    } else if (isToday) {
      borderColor = const Color(0xFFFF7A45);
      bgColor = const Color(0xFFFF7A45).withValues(alpha: 0.12);
    }

    Widget card = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: borderColor,
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(7.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Day Pill
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFFF7A45)
                        : (isClaimed
                            ? const Color(0xFF10B981)
                            : Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'DAY ${item.day}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // Icon / Graphic
                _buildRewardGraphic(item, size: 36.r),

                // Bottom Title / Duration
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _shortTitle(item),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      isAdmin && item.durationDays != null
                          ? '👑 Permanent'
                          : item.badge,
                      style: TextStyle(
                        color: isToday
                            ? const Color(0xFFFF9466)
                            : (isClaimed
                                ? const Color(0xFF34D399)
                                : Colors.white54),
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Claimed Checkmark Overlay
          if (isClaimed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18.r,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isToday) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildDay7GrandCard(DailyRewardDay item) {
    final isClaimed = item.isClaimed;
    final isToday = item.isToday && (_status?.canClaimToday ?? false);
    final isAdmin = _status?.isAdmin ?? false;

    Color borderColor = const Color(0xFF8B5CF6).withValues(alpha: 0.4);
    Color bgColor = const Color(0xFF1E1B2E);

    if (isClaimed) {
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.08);
    } else if (isToday) {
      borderColor = const Color(0xFFEC4899);
      bgColor = const Color(0xFFEC4899).withValues(alpha: 0.15);
    }

    Widget grandCard = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A1B3D),
            const Color(0xFF191624),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Grand Icon
          Container(
            width: 52.r,
            height: 52.r,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 28.r,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'DAY 7 • GRAND PRIZE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isAdmin
                      ? '👑 Permanent Profile Effect + 7-Day Streak Badge'
                      : '7-Day Profile Effect Unlock + Streak Badge',
                  style: TextStyle(
                    color: const Color(0xFFD8B4FE),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isClaimed)
            Container(
              padding: EdgeInsets.all(5.r),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20.r,
              ),
            ),
        ],
      ),
    );

    if (isToday) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: grandCard,
      );
    }

    return grandCard;
  }

  Widget _buildRewardGraphic(DailyRewardDay item, {required double size}) {
    switch (item.type) {
      case 'avatar_frame':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEC4899).withValues(alpha: 0.15),
            border: Border.all(
              color: const Color(0xFFEC4899).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.portrait_rounded,
            color: const Color(0xFFF472B6),
            size: size * 0.62,
          ),
        );
      case 'coins':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '🪙',
              style: TextStyle(fontSize: (size * 0.52).sp),
            ),
          ),
        );
      case 'mystery_theme_frame':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
        );
      case 'profile_effect':
      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: size * 0.58,
            ),
          ),
        );
    }
  }

  String _shortTitle(DailyRewardDay item) {
    if (item.type == 'coins') {
      if (item.coinsRange != null && item.coinsRange!.length == 2) {
        return '${item.coinsRange![0]}-${item.coinsRange![1]} KC';
      }
      return 'KatsCoins';
    }
    if (item.type == 'avatar_frame') return 'Avatar Frame';
    if (item.type == 'mystery_theme_frame') return 'Theme / Frame';
    if (item.type == 'profile_effect') return 'Profile Effect';
    return item.title;
  }

  Widget _buildFooter() {
    final canClaim = _status?.canClaimToday ?? false;
    final currentDay = _status?.currentDay ?? 1;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF111317),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canClaim) ...[
            GestureDetector(
              onTap: _isClaiming ? null : _claimToday,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.5.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A45), Color(0xFFFF5252)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isClaiming
                      ? SizedBox(
                          height: 20.r,
                          width: 20.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white,
                              size: 19.r,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'CLAIM DAY $currentDay REWARD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 11.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: const Color(0xFF10B981),
                    size: 18.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Come back tomorrow for Day $currentDay!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimCelebrationDialog extends StatelessWidget {
  const _ClaimCelebrationDialog({
    required this.reward,
    required this.newBalance,
    required this.isAdmin,
  });

  final ClaimedReward reward;
  final double newBalance;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300.w,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D24),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: const Color(0xFFFF7A45).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A45).withValues(alpha: 0.28),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A45), Color(0xFFF97316)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    reward.type == 'coins' ? '🪙' : (reward.type == 'profile_effect' ? '✨' : '🎁'),
                    style: TextStyle(fontSize: 32.sp),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                '🎉 CONGRATULATIONS!',
                style: TextStyle(
                  color: const Color(0xFFFF7A45),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                reward.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  reward.description,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (reward.type == 'coins') ...[
                SizedBox(height: 8.h),
                Text(
                  'New Balance: ${newBalance.toStringAsFixed(0)} KC',
                  style: TextStyle(
                    color: const Color(0xFFFBBF24),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, color: const Color(0xFFD8B4FE), size: 13.r),
                      SizedBox(width: 5.w),
                      Text(
                        'Stored in KatShop > Owned tab',
                        style: TextStyle(
                          color: const Color(0xFFE9D5FF),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 18.h),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 11.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A45), Color(0xFFFF5252)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'AWESOME!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
