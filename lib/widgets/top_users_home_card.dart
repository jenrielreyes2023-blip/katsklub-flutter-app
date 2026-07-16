import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/top_users_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/feed_service.dart';
import 'gold_shimmer_text.dart';
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

  int _calculateLevel(int points) {
    if (points < 100) return 1;
    if (points < 300) return 2;
    if (points < 600) return 3;
    if (points < 1000) return 4;
    if (points < 2000) return 5;
    if (points < 3500) return 6;
    if (points < 5500) return 7;
    if (points < 8000) return 8;
    if (points < 11000) return 9;
    return 10;
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

  Widget _buildPodiumUser(BuildContext context, {
    required String username,
    required String fullName,
    required int rank,
    required double avatarSize,
    required double yOffset,
    required int charmPoints,
    required bool isDark,
  }) {
    final rankColor = _getRankColor(rank);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final isGemini = username.toLowerCase() == 'gemini';
    final level = _calculateLevel(charmPoints);

    // Mock user for initials
    final tempUser = User.fromJson({
      'username': username,
      'fullName': fullName,
    });

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: GestureDetector(
        onTap: () => _navigateToProfile(context, username),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Glowing background ring for 1st rank
                if (rank == 1)
                  Container(
                    width: avatarSize + 8,
                    height: avatarSize + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: rankColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                // Avatar container with rank border
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rankColor,
                      width: rank == 1 ? 3.0 : 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
                      child: Center(
                        child: Text(
                          tempUser.initials,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: avatarSize * 0.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Crown Badge / Rank Badge
                Positioned(
                  top: -6,
                  child: rank == 1
                      ? const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFFFD700),
                          size: 20,
                        )
                      : Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: rankColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                ),
                // Rank number at the bottom right
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E1F20) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            isGemini
                ? GoldShimmerText(
                    text: fullName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Text(
                    fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            _buildCharmLevelBadge(level),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTileUser(BuildContext context, {
    required String username,
    required String fullName,
    required int rank,
    required int charmPoints,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final tempUser = User.fromJson({
      'username': username,
      'fullName': fullName,
    });
    final level = _calculateLevel(charmPoints);

    return Expanded(
      child: GestureDetector(
        onTap: () => _navigateToProfile(context, username),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Container(
                        color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
                        child: Center(
                          child: Text(
                            tempUser.initials,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF9CA3AF),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildCharmLevelBadge(level),
                      ],
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const SkeletonBox(width: 52, height: 52, radius: 26),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 60, height: 10, radius: 5),
                        const SizedBox(height: 4),
                        const SkeletonBox(width: 40, height: 8, radius: 4),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SkeletonBox(width: 66, height: 66, radius: 33),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 70, height: 12, radius: 6),
                        const SizedBox(height: 4),
                        const SkeletonBox(width: 50, height: 8, radius: 4),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SkeletonBox(width: 50, height: 50, radius: 25),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 60, height: 10, radius: 5),
                        const SizedBox(height: 4),
                        const SkeletonBox(width: 40, height: 8, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2E30).withValues(alpha: 0.3) : const Color(0xFFE6EBF2).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const Row(
                        children: [
                          SkeletonBox(width: 24, height: 24, radius: 12),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(width: 50, height: 8, radius: 4),
                                SizedBox(height: 4),
                                SkeletonBox(width: 30, height: 6, radius: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2E30).withValues(alpha: 0.3) : const Color(0xFFE6EBF2).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const Row(
                        children: [
                          SkeletonBox(width: 24, height: 24, radius: 12),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonBox(width: 50, height: 8, radius: 4),
                                SizedBox(height: 4),
                                SkeletonBox(width: 30, height: 6, radius: 3),
                              ],
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1F20) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    if (_isLoading) {
      return _buildHomeCardSkeleton(context, cardColor, isDark);
    }

    // Determine active top users list
    final List<User> activeUsers = [];
    if (_users.length >= 3) {
      activeUsers.addAll(_users);
    }

    // Fill remaining ranks with mock data if necessary
    final mockUserList = [
      User.fromJson(const {
        'username': 'gemini',
        'fullName': 'Gemini AI',
        'charmPoints': 12500,
        'isVerified': true,
      }),
      User.fromJson(const {
        'username': 'kat_boss',
        'fullName': 'Kat Boss',
        'charmPoints': 9800,
        'isVerified': true,
      }),
      User.fromJson(const {
        'username': 'music_fanatic',
        'fullName': 'Music Fanatic',
        'charmPoints': 7400,
      }),
      User.fromJson(const {
        'username': 'katsklub_dev',
        'fullName': 'KatsKlub Dev',
        'charmPoints': 5200,
        'isVerified': true,
      }),
      User.fromJson(const {
        'username': 'traveler_01',
        'fullName': 'Traveler One',
        'charmPoints': 3900,
      }),
    ];

    while (activeUsers.length < 5) {
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
          // Header Row
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

          // Podium Section (Ranks 1, 2, 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd Place (Left)
                Expanded(
                  child: _buildPodiumUser(
                    context,
                    username: activeUsers[1].username ?? '',
                    fullName: activeUsers[1].displayName,
                    rank: 2,
                    avatarSize: 52,
                    yOffset: 8,
                    charmPoints: activeUsers[1].charmPoints,
                    isDark: isDark,
                  ),
                ),
                // 1st Place (Center - Larger)
                Expanded(
                  child: _buildPodiumUser(
                    context,
                    username: activeUsers[0].username ?? '',
                    fullName: activeUsers[0].displayName,
                    rank: 1,
                    avatarSize: 66,
                    yOffset: -10,
                    charmPoints: activeUsers[0].charmPoints,
                    isDark: isDark,
                  ),
                ),
                // 3rd Place (Right)
                Expanded(
                  child: _buildPodiumUser(
                    context,
                    username: activeUsers[2].username ?? '',
                    fullName: activeUsers[2].displayName,
                    rank: 3,
                    avatarSize: 50,
                    yOffset: 12,
                    charmPoints: activeUsers[2].charmPoints,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4th and 5th Place Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _buildSmallTileUser(
                  context,
                  username: activeUsers[3].username ?? '',
                  fullName: activeUsers[3].displayName,
                  rank: 4,
                  charmPoints: activeUsers[3].charmPoints,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildSmallTileUser(
                  context,
                  username: activeUsers[4].username ?? '',
                  fullName: activeUsers[4].displayName,
                  rank: 5,
                  charmPoints: activeUsers[4].charmPoints,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
