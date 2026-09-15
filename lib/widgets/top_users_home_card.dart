import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../screens/top_users_screen.dart';
import '../screens/user_profile_screen.dart';
import '../services/feed_service.dart';
import 'loading_skeletons.dart';
import 'special_name_text.dart';

class TopUsersHomeCard extends StatefulWidget {
  const TopUsersHomeCard({super.key});

  @override
  State<TopUsersHomeCard> createState() => _TopUsersHomeCardState();
}

class _TopUsersHomeCardState extends State<TopUsersHomeCard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  static List<User> _cachedUsers = [];

  List<User> _users = _cachedUsers;
  bool _isLoading = _cachedUsers.isEmpty;
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  DateTime? _lastFetchTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _expandController.value = 1.0;
    }
    _loadTopUsers();
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _loadTopUsers({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastFetchTime != null && now.difference(_lastFetchTime!) < const Duration(minutes: 5)) {
      return;
    }
    _lastFetchTime = now;

    try {
      final list = await _feedService.loadLeaderboard(forceRefresh: force);
      if (list.length >= 3 && mounted) {
        _cachedUsers = list;
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
        builder: (_) => TopUsersScreen(initialUsers: _users),
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
    return Image.asset(
      User.getCharmBadgeAsset(level),
      height: 14,
      fit: BoxFit.contain,
    );
  }

  Widget _buildSkeletonContent(BuildContext context, bool isDark) {
    return SkeletonPulse(
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
    final bannerBg = isDark
        ? const Color(0xFF242526).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);
    final charmColor = isDark ? const Color(0xFFFF9F7C) : const Color(0xFFFF5E3A);
    final rankColor = _getRankColor(rank);

    final int cacheSize = 200;

    Widget imageWidget;
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: ApiConfig.assetUrl(user.avatarUrl!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (context, url) => ColoredBox(
          color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
        ),
        errorWidget: (context, url, error) => ColoredBox(
          color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB),
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
        ),
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
        child: RankBadge(rank: rank, size: 36),
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
                color: rank <= 3
                    ? rankColor
                    : (isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB)),
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

  Widget _buildGridContent(BuildContext context, List<User> activeUsers, bool isDark) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1F20) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

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

    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF2F3031) : const Color(0xFFD1D5DB),
              width: 2.5,
            ),
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
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                        if (_isExpanded) {
                          _expandController.forward();
                          _loadTopUsers();
                        } else {
                          _expandController.reverse();
                        }
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFFFF7A45),
                          size: 20,
                        ),
                      ],
                    ),
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
            SizeTransition(
              sizeFactor: _expandAnimation,
              axis: Axis.vertical,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (_isLoading)
                      _buildSkeletonContent(context, isDark)
                    else
                      _buildGridContent(context, activeUsers, isDark),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RankBadge extends StatelessWidget {
  final int rank;
  final double size;

  const RankBadge({
    super.key,
    required this.rank,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> metallicGradient;
    final Color jewelColor;
    final IconData iconData;

    if (rank == 1) {
      metallicGradient = const [
        Color(0xFFFFD700),
        Color(0xFFFFA500),
        Color(0xFFFFE066),
        Color(0xFFFFD700),
      ];
      jewelColor = const Color(0xFFD4AF37);
      iconData = Icons.workspace_premium_rounded;
    } else if (rank == 2) {
      metallicGradient = const [
        Color(0xFFE0E0E0),
        Color(0xFFB0B0B0),
        Color(0xFFF5F5F5),
        Color(0xFFB0B0B0),
      ];
      jewelColor = const Color(0xFF9E9E9E);
      iconData = Icons.workspace_premium_rounded;
    } else {
      metallicGradient = const [
        Color(0xFFCD7F32),
        Color(0xFF8B5A2B),
        Color(0xFFFFB07C),
        Color(0xFFCD7F32),
      ];
      jewelColor = const Color(0xFF8B5A2B);
      iconData = Icons.workspace_premium_rounded;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size + 4,
          height: size + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: metallicGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: jewelColor.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1F22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
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
                ).createShader(bounds);
              },
              child: Icon(
                iconData,
                size: size * 0.55,
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
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'TOP $rank',
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
    );
  }
}
