import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/top_users_screen.dart';
import '../screens/user_profile_screen.dart';
import 'gold_shimmer_text.dart';

class TopUsersHomeCard extends StatelessWidget {
  const TopUsersHomeCard({super.key});

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

  Widget _buildPodiumUser(BuildContext context, {
    required String username,
    required String fullName,
    required int rank,
    required double avatarSize,
    required double yOffset,
    required bool isDark,
  }) {
    final rankColor = _getRankColor(rank);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final isGemini = username.toLowerCase() == 'gemini';

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
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTileUser(BuildContext context, {
    required String username,
    required String fullName,
    required int rank,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final tempUser = User.fromJson({
      'username': username,
      'fullName': fullName,
    });

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
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1F20) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

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
                    username: 'kat_boss',
                    fullName: 'Kat Boss',
                    rank: 2,
                    avatarSize: 52,
                    yOffset: 8,
                    isDark: isDark,
                  ),
                ),
                // 1st Place (Center - Larger)
                Expanded(
                  child: _buildPodiumUser(
                    context,
                    username: 'gemini',
                    fullName: 'Gemini AI',
                    rank: 1,
                    avatarSize: 66,
                    yOffset: -10,
                    isDark: isDark,
                  ),
                ),
                // 3rd Place (Right)
                Expanded(
                  child: _buildPodiumUser(
                    context,
                    username: 'music_fanatic',
                    fullName: 'Music Fanatic',
                    rank: 3,
                    avatarSize: 50,
                    yOffset: 12,
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
                  username: 'katsklub_dev',
                  fullName: 'KatsKlub Dev',
                  rank: 4,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildSmallTileUser(
                  context,
                  username: 'traveler_01',
                  fullName: 'Traveler One',
                  rank: 5,
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
