import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../services/auth_service.dart';
import '../widgets/gold_shimmer_text.dart';
import '../widgets/loading_skeletons.dart';
import 'user_profile_screen.dart';

class TopUser {
  final User user;
  final int rank;
  final int score;
  final String status;

  TopUser({
    required this.user,
    required this.rank,
    required this.score,
    required this.status,
  });
}

class TopUsersScreen extends StatefulWidget {
  const TopUsersScreen({super.key});

  @override
  State<TopUsersScreen> createState() => _TopUsersScreenState();
}

class _TopUsersScreenState extends State<TopUsersScreen>
    with AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  List<TopUser> _topUsers = [];
  final Set<String> _followingInFlight = <String>{};
  final Set<String> _followedUsernames = <String>{};
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRealLeaderboard();
  }

  Future<void> _loadRealLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<User> leaderboardUsers = await _feedService.loadLeaderboard();
      List<User> suggestionUsers = [];
      try {
        suggestionUsers = await _feedService.loadFollowSuggestions();
      } catch (_) {}

      final Map<String, User> uniqueUsers = {};
      for (final u in leaderboardUsers) {
        if (u.username != null && u.username!.isNotEmpty) {
          uniqueUsers[u.username!.toLowerCase()] = u;
        }
      }
      for (final u in suggestionUsers) {
        if (u.username != null && u.username!.isNotEmpty) {
          final key = u.username!.toLowerCase();
          if (!uniqueUsers.containsKey(key)) {
            uniqueUsers[key] = u;
          }
        }
      }

      // Fetch recent feed posts to find other active posting users (like 'jade')
      try {
        final feedResult = await _feedService.loadFeed(offset: 0, limit: 100);
        final Set<String> missingUsernames = {};
        for (final post in feedResult.posts) {
          final username = post.authorUsername;
          if (username.isNotEmpty) {
            final key = username.toLowerCase();
            if (!uniqueUsers.containsKey(key)) {
              missingUsernames.add(username);
            }
          }
        }

        if (missingUsernames.isNotEmpty) {
          final List<User?> profiles = await Future.wait(
            missingUsernames.map((username) => _feedService.loadUserProfile(username)),
          );
          for (final profile in profiles) {
            if (profile != null && profile.username != null && profile.username!.isNotEmpty) {
              uniqueUsers[profile.username!.toLowerCase()] = profile;
            }
          }
        }
      } catch (_) {}

      // Fetch current user's followers/following to find users like 'vanessa'
      try {
        final authUser = await AuthService().getSavedUser();
        if (authUser != null && authUser.username != null && authUser.username!.isNotEmpty) {
          final currentUsername = authUser.username!;
          final List<User> followers = await _feedService.getUserFollowers(currentUsername);
          final List<User> following = await _feedService.getUserFollowing(currentUsername);

          for (final u in followers) {
            if (u.username != null && u.username!.isNotEmpty) {
              final key = u.username!.toLowerCase();
              if (!uniqueUsers.containsKey(key)) {
                uniqueUsers[key] = u;
              }
            }
          }
          for (final u in following) {
            if (u.username != null && u.username!.isNotEmpty) {
              final key = u.username!.toLowerCase();
              if (!uniqueUsers.containsKey(key)) {
                uniqueUsers[key] = u;
              }
            }
          }
        }
      } catch (_) {}

      // Filter out users who have 0 or negative charm points
      final List<User> combinedList = uniqueUsers.values
          .where((user) => user.charmPoints > 0)
          .toList();

      // Sort by charmPoints descending
      combinedList.sort((a, b) => b.charmPoints.compareTo(a.charmPoints));

      int rank = 1;
      final List<TopUser> fetchedList = combinedList.map((user) {
        String status = 'Kat Member';
        if (rank == 1) {
          status = 'Outstanding Member';
        } else if (rank == 2) {
          status = 'Top Contributor';
        } else if (rank == 3) {
          status = 'Daily Star';
        } else if (rank <= 5) {
          status = 'Rising Star';
        } else {
          status = 'Popular Member';
        }

        final tu = TopUser(
          user: user,
          rank: rank,
          score: user.charmPoints,
          status: status,
        );
        rank++;
        return tu;
      }).toList();

      if (mounted) {
        setState(() {
          _topUsers = fetchedList.take(50).toList();
          _followedUsernames.clear();
          for (final tu in _topUsers) {
            if (tu.user.isFollowing) {
              _followedUsernames.add(tu.user.username!.toLowerCase());
            }
          }
          _isLoading = false;
        });
      }
      return;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _topUsers = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || _followingInFlight.contains(cleanUsername)) {
      return;
    }

    final wasFollowing = _followedUsernames.contains(cleanUsername);
    setState(() {
      _followingInFlight.add(cleanUsername);
      if (wasFollowing) {
        _followedUsernames.remove(cleanUsername);
      } else {
        _followedUsernames.add(cleanUsername);
      }
    });

    try {
      if (wasFollowing) {
        await _feedService.unfollowUser(cleanUsername);
      } else {
        await _feedService.followUser(cleanUsername);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFollowing) {
          _followedUsernames.add(cleanUsername);
        } else {
          _followedUsernames.remove(cleanUsername);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update follow status.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _followingInFlight.remove(cleanUsername);
        });
      }
    }
  }

  void _openProfile(String username) {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: cleanUsername),
      ),
    );
  }

  Widget _buildCharmLevelBadge(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A45), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 9,
          ),
          const SizedBox(width: 2),
          Text(
            'Lv.$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
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

  Widget _buildLeaderboardSkeleton(BuildContext context, Color cardColor, bool isDark) {
    return SkeletonPulse(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          LayoutBuilder(
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
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SkeletonBox(width: 180, height: 16, radius: 8),
              ],
            ),
          ),
          ...List.generate(5, (index) {
            return Card(
              color: cardColor,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SkeletonBox(width: 46, height: 46, radius: 23),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SkeletonBox(width: 110, height: 14, radius: 7),
                              SizedBox(width: 6),
                              SkeletonBox(width: 32, height: 14, radius: 7),
                            ],
                          ),
                          SizedBox(height: 8),
                          SkeletonBox(width: 70, height: 11, radius: 6),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 68, height: 26, radius: 13),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWePlayCard(
    BuildContext context, {
    required TopUser topUser,
    required double height,
    required bool isDark,
    required bool showCrown,
  }) {
    final user = topUser.user;
    final rank = topUser.rank;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final bannerBg = isDark ? const Color(0xFF242526).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85);
    final charmColor = isDark ? const Color(0xFFFF9F7C) : const Color(0xFFFF5E3A);
    final rankColor = _getRankColor(rank);

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
      onTap: () => _openProfile(user.username ?? ''),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.hardEdge,
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
                                child: (user.isAdmin || user.username?.toLowerCase() == 'gemini')
                                    ? GoldShimmerText(
                                        text: '$rank.${user.displayName}',
                                        style: TextStyle(
                                          fontSize: height > 120 ? 12 : 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : Text(
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

  Widget _buildWePlayCollage(BuildContext context, List<TopUser> activeUsers, bool isDark) {
    return LayoutBuilder(
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
                    topUser: activeUsers[0],
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
                          topUser: activeUsers[1],
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
                          topUser: activeUsers[2],
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
                    topUser: activeUsers[3],
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
                    topUser: activeUsers[4],
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
                    topUser: activeUsers[5],
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
                    topUser: activeUsers[6],
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
                    topUser: activeUsers[7],
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
                    topUser: activeUsers[8],
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
    );
  }

  Widget _buildUserRow(
    BuildContext context,
    TopUser tu,
    Color cardColor,
    bool isDark,
    Color titleColor,
    Color subtitleColor,
  ) {
    final isGemini = tu.user.username?.toLowerCase() == 'gemini';
    final isFollowing = _followedUsernames.contains(tu.user.username!.toLowerCase());
    final isFlight = _followingInFlight.contains(tu.user.username!.toLowerCase());

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () => _openProfile(tu.user.username!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getRankColor(tu.rank),
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: Container(
                  color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
                  child: (tu.user.avatarUrl != null && tu.user.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: ApiConfig.assetUrl(tu.user.avatarUrl!),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              tu.user.initials,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            tu.user.initials,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
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
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _getRankColor(tu.rank),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${tu.rank}',
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
        title: Row(
          children: [
            Flexible(
              child: (tu.user.isAdmin || isGemini)
                  ? GoldShimmerText(
                      text: tu.user.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Text(
                      tu.user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            if (tu.user.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.verified,
                color: Color(0xFFFF7A45),
                size: 15,
              ),
            ],
            const SizedBox(width: 6),
            _buildCharmLevelBadge(tu.user.charmLevel),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              tu.status,
              style: const TextStyle(
                color: Color(0xFFFF7A45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${tu.score.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} pts',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 82,
          height: 32,
          child: OutlinedButton(
            onPressed: isFlight ? null : () => _toggleFollow(tu.user.username!),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isFollowing
                    ? (isDark ? Colors.white30 : Colors.black26)
                    : const Color(0xFFFF7A45),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: EdgeInsets.zero,
            ),
            child: isFlight
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFFF7A45),
                    ),
                  )
                : Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFollowing
                          ? titleColor
                          : const Color(0xFFFF7A45),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Top Users Leaderboard',
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLeaderboardSkeleton(context, cardColor, isDark)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _topUsers.length < 9 
                    ? _topUsers.length 
                    : _topUsers.length - 7,
                itemBuilder: (context, index) {
                  if (_topUsers.length < 9) {
                    final tu = _topUsers[index];
                    return _buildUserRow(context, tu, cardColor, isDark, titleColor, subtitleColor);
                  }

                  if (index == 0) {
                    return _buildWePlayCollage(context, _topUsers.sublist(0, 9), isDark);
                  }

                  if (index == 1) {
                    final maxRank = _topUsers.length;
                    final titleText = maxRank > 10 
                        ? 'Leaderboard Rankings (10-$maxRank)' 
                        : 'Leaderboard Rankings (10)';
                    return Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 12),
                      child: Text(
                        titleText,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    );
                  }

                  final tu = _topUsers[index + 7];
                  return _buildUserRow(context, tu, cardColor, isDark, titleColor, subtitleColor);
                },
              ),
      ),
    );
  }
}
