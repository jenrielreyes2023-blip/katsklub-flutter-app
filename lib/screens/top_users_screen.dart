import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/special_name_text.dart';
import '../widgets/loading_skeletons.dart';
import 'user_profile_screen.dart';

class TopUser {
  final User user;
  final int rank;
  final int score;
  final String status;
  final int rankTrend;

  TopUser({
    required this.user,
    required this.rank,
    required this.score,
    required this.status,
    required this.rankTrend,
  });
}

class TopUsersScreen extends StatefulWidget {
  final List<User>? initialUsers;
  const TopUsersScreen({super.key, this.initialUsers});

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
  String _activePeriod = 'weekly';
  static final Map<String, List<TopUser>> _cachedLeaderboards = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsers != null && widget.initialUsers!.isNotEmpty) {
      int rank = 1;
      _topUsers = widget.initialUsers!.map((user) {
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
        final int hash = user.username?.hashCode ?? 0;
        int trend = 0;
        if (hash % 7 == 0) {
          trend = (hash % 3) + 1;
        } else if (hash % 5 == 0) {
          trend = -((hash % 2) + 1);
        }

        final tu = TopUser(
          user: user,
          rank: rank,
          score: user.charmPoints,
          status: status,
          rankTrend: trend,
        );
        rank++;
        return tu;
      }).toList();
      _isLoading = false;
    }
    _loadRealLeaderboard();
  }

  Future<void> _loadRealLeaderboard() async {
    final loadingPeriod = _activePeriod;

    if (_cachedLeaderboards.containsKey(loadingPeriod)) {
      setState(() {
        _topUsers = _cachedLeaderboards[loadingPeriod]!;
        _isLoading = false;
      });
    } else if (_topUsers.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final realUsers = await _feedService.loadLeaderboard(period: loadingPeriod);
      int rank = 1;
      final List<TopUser> fetchedList = realUsers.map((user) {
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

        final int hash = user.username?.hashCode ?? 0;
        int trend = 0;
        if (hash % 7 == 0) {
          trend = (hash % 3) + 1;
        } else if (hash % 5 == 0) {
          trend = -((hash % 2) + 1);
        }

        final tu = TopUser(
          user: user,
          rank: rank,
          score: user.charmPoints,
          status: status,
          rankTrend: trend,
        );
        rank++;
        return tu;
      }).toList();

      // Always cache the retrieved results for the loaded period
      _cachedLeaderboards[loadingPeriod] = fetchedList.take(50).toList();

      if (!mounted) return;

      // Only update the active UI if the user is still viewing this period
      if (_activePeriod == loadingPeriod) {
        setState(() {
          _topUsers = _cachedLeaderboards[loadingPeriod]!;
          _followedUsernames.clear();
          for (final tu in _topUsers) {
            if (tu.user.isFollowing) {
              _followedUsernames.add(tu.user.username!.toLowerCase());
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _activePeriod == loadingPeriod) {
        setState(() {
          _isLoading = false;
        });
      }
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.string(
          '''<svg width="800" height="800" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" role="img" class="iconify iconify--noto"><path d="M68.05 7.23l13.46 30.7a7.047 7.047.0 005.82 4.19l32.79 2.94c3.71.54 5.19 5.09 2.5 7.71l-24.7 20.75c-2 1.68-2.91 4.32-2.36 6.87l7.18 33.61c.63 3.69-3.24 6.51-6.56 4.76L67.56 102a7.033 7.033.0 00-7.12.0l-28.62 16.75c-3.31 1.74-7.19-1.07-6.56-4.76l7.18-33.61c.54-2.55-.36-5.19-2.36-6.87L5.37 52.78c-2.68-2.61-1.2-7.17 2.5-7.71l32.79-2.94a7.047 7.047.0 005.82-4.19l13.46-30.7c1.67-3.36 6.45-3.36 8.11-.01z" fill="#fdd835"/><path d="M67.07 39.77l-2.28-22.62c-.09-1.26-.35-3.42 1.67-3.42 1.6.0 2.47 3.33 2.47 3.33l6.84 18.16c2.58 6.91 1.52 9.28-.97 10.68-2.86 1.6-7.08.35-7.73-6.13z" fill="#ffff8d"/><path d="M95.28 71.51 114.9 56.2c.97-.81 2.72-2.1 1.32-3.57-1.11-1.16-4.11.51-4.11.51l-17.17 6.71c-5.12 1.77-8.52 4.39-8.82 7.69-.39 4.4 3.56 7.79 9.16 3.97z" fill="#f4b400"/></svg>''',
          width: 15,
          height: 15,
        ),
        const SizedBox(width: 2),
        Text(
          '$level',
          style: const TextStyle(
            color: Color(0xFFFF7A45),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
    if (showCrown && rank <= 3) {
      crownWidget = Positioned(
        top: -10,
        left: -10,
        child: AnimatedRankBadge(rank: rank, size: 36),
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
                                child: SpecialNameText(
                                  username: user.username ?? '',
                                  displayName: '$rank.${user.displayName}',
                                  isAdmin: user.isAdmin,
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
              child: SpecialNameText(
                username: tu.user.username ?? '',
                displayName: tu.user.displayName,
                isAdmin: tu.user.isAdmin,
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tu.rankTrend > 0) ...[
                  const Icon(
                    Icons.arrow_upward,
                    color: Color(0xFF22C55E), // Green
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '+${tu.rankTrend}',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else if (tu.rankTrend < 0) ...[
                  const Icon(
                    Icons.arrow_downward,
                    color: Color(0xFFEF4444), // Red
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${tu.rankTrend}',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.remove,
                    color: Colors.grey,
                    size: 14,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _activePeriod == 'daily'
                  ? 'today'
                  : (_activePeriod == 'weekly' ? 'this week' : 'this month'),
              style: TextStyle(
                color: subtitleColor.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, bool isDark) {
    final periods = [
      {'key': 'daily', 'label': 'Daily'},
      {'key': 'weekly', 'label': 'Weekly'},
      {'key': 'monthly', 'label': 'Monthly'},
      {'key': 'all-time', 'label': 'All-Time'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = _activePeriod == p['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_activePeriod != p['key']) {
                  final target = p['key']!;
                  final isCached = _cachedLeaderboards.containsKey(target);
                  setState(() {
                    _activePeriod = target;
                    if (isCached) {
                      _topUsers = _cachedLeaderboards[target]!;
                      _isLoading = false;
                    } else {
                      _topUsers.clear();
                      _isLoading = true;
                    }
                  });
                  _loadRealLeaderboard();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFF8C00),
                            Color(0xFFFF5E3A),
                          ],
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF5E3A).withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p['label']!,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFFE4E6EB) : const Color(0xFF4B5563)),
                      fontSize: 12.0,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
        child: Column(
          children: [
            _buildPeriodSelector(context, isDark),
            _LeaderboardCountdownBanner(isDark: isDark),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}

class AnimatedRankBadge extends StatefulWidget {
  final int rank;
  final double size;

  const AnimatedRankBadge({
    super.key,
    required this.rank,
    this.size = 36.0,
  });

  @override
  State<AnimatedRankBadge> createState() => _AnimatedRankBadgeState();
}

class _AnimatedRankBadgeState extends State<AnimatedRankBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> metallicGradient;
    final Color jewelColor;
    final IconData iconData;
    
    if (widget.rank == 1) {
      metallicGradient = [
        const Color(0xFFFFD700),
        const Color(0xFFFFA500),
        const Color(0xFFFFE066),
        const Color(0xFFFFD700),
      ];
      jewelColor = const Color(0xFFD4AF37);
      iconData = Icons.workspace_premium_rounded;
    } else if (widget.rank == 2) {
      metallicGradient = [
        const Color(0xFFE0E0E0),
        const Color(0xFFB0B0B0),
        const Color(0xFFF5F5F5),
        const Color(0xFFB0B0B0),
      ];
      jewelColor = const Color(0xFF9E9E9E);
      iconData = Icons.workspace_premium_rounded;
    } else {
      metallicGradient = [
        const Color(0xFFCD7F32),
        const Color(0xFF8B5A2B),
        const Color(0xFFFFB07C),
        const Color(0xFFCD7F32),
      ];
      jewelColor = const Color(0xFF8B5A2B);
      iconData = Icons.workspace_premium_rounded;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double value = _controller.value;
        final double pulse = 1.0 + (0.04 * (value < 0.5 ? value * 2 : (1.0 - value) * 2));
        
        return Transform.scale(
          scale: pulse,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.size + 4,
                height: widget.size + 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: metallicGradient,
                    transform: GradientRotation(value * 2 * 3.14159),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: jewelColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E1F22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: metallicGradient,
                        stops: const [0.0, 0.3, 0.7, 1.0],
                        transform: GradientRotation(value * 2 * 3.14159),
                      ).createShader(bounds);
                    },
                    child: Icon(
                      iconData,
                      size: widget.size * 0.55,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -4,
                child: Transform.scale(
                  scale: 0.85,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: metallicGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      'TOP ${widget.rank}',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardCountdownBanner extends StatefulWidget {
  const _LeaderboardCountdownBanner({required this.isDark});
  final bool isDark;

  @override
  State<_LeaderboardCountdownBanner> createState() => _LeaderboardCountdownBannerState();
}

class _LeaderboardCountdownBannerState extends State<_LeaderboardCountdownBanner> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isInitialStart = true;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final target = _getTargetTime();
    final nowUtc = DateTime.now().toUtc();
    final diff = target.difference(nowUtc);
    
    final initialStart = DateTime.utc(2026, 7, 18, 16, 0, 0);
    
    if (mounted) {
      setState(() {
        _timeLeft = diff.isNegative ? Duration.zero : diff;
        _isInitialStart = nowUtc.isBefore(initialStart);
      });
    }
  }

  DateTime _getTargetTime() {
    final targetStart = DateTime.utc(2026, 7, 18, 16, 0, 0);
    final nowUtc = DateTime.now().toUtc();
    if (nowUtc.isBefore(targetStart)) {
      return targetStart;
    }
    
    final nowManila = DateTime.now().toUtc().add(const Duration(hours: 8));
    int daysUntilSunday = 7 - nowManila.weekday;
    if (daysUntilSunday == 0) {
      daysUntilSunday = 7;
    }
    
    final nextSundayManila = DateTime(
      nowManila.year,
      nowManila.month,
      nowManila.day,
      0, 0, 0
    ).add(Duration(days: daysUntilSunday));
    
    return nextSundayManila.subtract(const Duration(hours: 8));
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.isNegative || _timeLeft == Duration.zero) {
      return const SizedBox.shrink();
    }

    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours % 24;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    final timeStr = '${days}d ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    
    final titleText = _isInitialStart 
        ? '🏆 Trackings Start In:'
        : '⏳ Next Weekly Reset In:';

    final infoText = _isInitialStart
        ? 'Daily, Weekly, & Monthly rankings will activate on July 19 (12:00 AM PHT). Current All-Time scores remain fully active.'
        : 'Leaderboard points will reset. Top 50 earners this week will receive the custom profile achievement badge.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0x1AFF8C00) : const Color(0x0DFF5E3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5E3A).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                titleText,
                style: const TextStyle(
                  color: Color(0xFFFF5E3A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            infoText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4B5563),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

