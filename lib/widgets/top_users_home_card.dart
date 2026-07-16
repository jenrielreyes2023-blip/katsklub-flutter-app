import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../screens/top_users_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/feed_service.dart';
import 'loading_skeletons.dart';

class TopUsersHomeCard extends StatefulWidget {
  const TopUsersHomeCard({super.key});

  @override
  State<TopUsersHomeCard> createState() => _TopUsersHomeCardState();
}

class _TopUsersHomeCardState extends State<TopUsersHomeCard>
    with AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  List<User> _users = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTopUsers();
  }

  Future<void> _loadTopUsers() async {
    try {
      final list = await _feedService.loadLeaderboard();
      if (list.length >= 3 && mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToLeaderboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TopUsersScreen(),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String username) {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: cleanUsername),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF9CA3AF); // Gray
    }
  }



  Widget _buildCharmLevelBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A45), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 8,
          ),
          const SizedBox(width: 2),
          Text(
            'Lv.$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeCardSkeleton(BuildContext context, Color cardColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SkeletonBox(width: 24, height: 24, radius: 6),
                      const SizedBox(width: 8),
                      const SkeletonBox(width: 140, height: 14, radius: 7),
                    ],
                  ),
                  const SkeletonBox(width: 50, height: 14, radius: 7),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double gap = 10.0;
                  final double s = (constraints.maxWidth - (2 * gap)) / 3;
                  final double bigSize = 2 * s + gap;

                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: bigSize, height: bigSize, radius: 12),
                          SizedBox(width: gap),
                          SizedBox(
                            width: s,
                            height: bigSize,
                            child: Column(
                              children: [
                                SkeletonBox(width: s, height: s, radius: 12),
                                SizedBox(height: gap),
                                SkeletonBox(width: s, height: s, radius: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: gap),
                      Row(
                        children: [
                          SkeletonBox(width: s, height: s, radius: 12),
                          SizedBox(width: gap),
                          SkeletonBox(width: s, height: s, radius: 12),
                          SizedBox(width: gap),
                          SkeletonBox(width: s, height: s, radius: 12),
                        ],
                      ),
                      SizedBox(height: gap),
                      Row(
                        children: [
                          SkeletonBox(width: s, height: s, radius: 12),
                          SizedBox(width: gap),
                          SkeletonBox(width: s, height: s, radius: 12),
                          SizedBox(width: gap),
                          SkeletonBox(width: s, height: s, radius: 12),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWePlayCard(
    BuildContext context, {
    required User user,
    required int rank,
    required double height,
    required bool isDark,
    required bool showCrown,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final bannerBg = isDark ? const Color(0xFF242526).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85);
    final charmColor = isDark ? const Color(0xFFFF9F7C) : const Color(0xFFFF5E3A);
    final rankColor = _getRankColor(rank);

    // Optimize image cache decoding size (prevents jank on rendering large assets)
    final int cacheSize = (height * MediaQuery.of(context).devicePixelRatio).round().clamp(120, 360);

    Widget imageWidget;
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: ApiConfig.assetUrl(user.avatarUrl!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
      );
    } else {
      imageWidget = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF3E4042), const Color(0xFF2D2E30)]
                : [const Color(0xFFE5E7EB), const Color(0xFFD1D5DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            user.initials,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w900,
              fontSize: height > 120 ? 32 : 20,
            ),
          ),
        ),
      );
    }

    Widget? crownWidget;
    if (showCrown) {
      IconData crownIcon = Icons.workspace_premium_rounded;
      Color crownColor = const Color(0xFFFFD700); // Gold
      if (rank == 2) {
        crownColor = const Color(0xFFC0C0C0); // Silver
      } else if (rank == 3) {
        crownColor = const Color(0xFFCD7F32); // Bronze
      }

      crownWidget = Positioned(
        top: -4,
        left: -4,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Icon(
            crownIcon,
            color: crownColor,
            size: 16,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _navigateToProfile(context, user.username ?? ''),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rank <= 3 ? rankColor : (isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB)),
                width: rank <= 3 ? 2.0 : 1.0,
              ),
            ),
            // Replaced Clip.antiAlias on the Container decoration with a fast ClipRRect sub-hierarchy
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.hardEdge, // Blazing fast clipping on GPUs
              child: Stack(
                children: [
                  Positioned.fill(child: imageWidget),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: bannerBg,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$rank.${user.displayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                    fontSize: height > 120 ? 12 : 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildCharmLevelBadge(user.charmLevel),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Charm ${user.charmPoints}',
                            style: TextStyle(
                              color: charmColor,
                              fontSize: height > 120 ? 9.5 : 8.5,
                              fontWeight: FontWeight.w700,
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
          if (crownWidget != null) crownWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1F20) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    if (_isLoading) {
      return _buildHomeCardSkeleton(context, cardColor, isDark);
    }

    final List<User> activeUsers = [];
    if (_users.length >= 9) {
      activeUsers.addAll(_users);
    }

    final mockUserList = [
      User.fromJson(const {
        'username': 'gemini',
        'fullName': 'Gemini AI',
        'charmPoints': 319283,
        'isVerified': true,
      }),
      User.fromJson(const {
        'username': 'kat_boss',
        'fullName': 'Kat Boss',
        'charmPoints': 222695,
        'isVerified': true,
      }),
      User.fromJson(const {
        'username': 'music_fanatic',
        'fullName': 'Music Fanatic',
        'charmPoints': 207150,
      }),
      User.fromJson(const {
        'username': 'katsklub_dev',
        'fullName': 'KatsKlub Dev',
        'charmPoints': 196963,
        'isVerified': true,
      }),
      User.fromJson(const {
        'username': 'traveler_01',
        'fullName': 'Traveler One',
        'charmPoints': 133679,
      }),
      User.fromJson(const {
        'username': 'designer_cat',
        'fullName': 'Designer Cat',
        'charmPoints': 129929,
      }),
      User.fromJson(const {
        'username': 'sythe_user',
        'fullName': 'SYTHE',
        'charmPoints': 122294,
      }),
      User.fromJson(const {
        'username': 'haize_2.0',
        'fullName': 'haize 2.0',
        'charmPoints': 117635,
      }),
      User.fromJson(const {
        'username': 'cent_aams',
        'fullName': 'CENT aams',
        'charmPoints': 90226,
      }),
    ];

    while (activeUsers.length < 9) {
      activeUsers.add(mockUserList[activeUsers.length]);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A45).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFF7A45),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Top Outstanding Users',
                      style: TextStyle(
                        color: titleColor,
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _navigateToLeaderboard(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          color: Color(0xFFFF7A45),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFFF7A45),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double gap = 10.0;
                final double s = (constraints.maxWidth - (2 * gap)) / 3;
                final double bigSize = 2 * s + gap;

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: bigSize,
                          height: bigSize,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[0],
                            rank: 1,
                            height: bigSize,
                            isDark: isDark,
                            showCrown: true,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: s,
                          height: bigSize,
                          child: Column(
                            children: [
                              SizedBox(
                                width: s,
                                height: s,
                                child: _buildWePlayCard(
                                  context,
                                  user: activeUsers[1],
                                  rank: 2,
                                  height: s,
                                  isDark: isDark,
                                  showCrown: true,
                                ),
                              ),
                              SizedBox(height: gap),
                              SizedBox(
                                width: s,
                                height: s,
                                child: _buildWePlayCard(
                                  context,
                                  user: activeUsers[2],
                                  rank: 3,
                                  height: s,
                                  isDark: isDark,
                                  showCrown: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),
                    Row(
                      children: [
                        SizedBox(
                          width: s,
                          height: s,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[3],
                            rank: 4,
                            height: s,
                            isDark: isDark,
                            showCrown: false,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: s,
                          height: s,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[4],
                            rank: 5,
                            height: s,
                            isDark: isDark,
                            showCrown: false,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: s,
                          height: s,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[5],
                            rank: 6,
                            height: s,
                            isDark: isDark,
                            showCrown: false,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),
                    Row(
                      children: [
                        SizedBox(
                          width: s,
                          height: s,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[6],
                            rank: 7,
                            height: s,
                            isDark: isDark,
                            showCrown: false,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: s,
                          height: s,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[7],
                            rank: 8,
                            height: s,
                            isDark: isDark,
                            showCrown: false,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: s,
                          height: s,
                          child: _buildWePlayCard(
                            context,
                            user: activeUsers[8],
                            rank: 9,
                            height: s,
                            isDark: isDark,
                            showCrown: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
