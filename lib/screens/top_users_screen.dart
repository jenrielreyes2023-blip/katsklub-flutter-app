import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/gold_shimmer_text.dart';
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

class _TopUsersScreenState extends State<TopUsersScreen> {
  final FeedService _feedService = FeedService();
  late List<TopUser> _topUsers;
  final Set<String> _followingInFlight = <String>{};
  final Set<String> _followedUsernames = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeTopUsers();
  }

  void _initializeTopUsers() {
    // Construct mock top users
    _topUsers = [
      TopUser(
        user: User.fromJson(const {
          'id': 'u-gemini',
          'username': 'gemini',
          'fullName': 'Gemini AI',
          'avatarUrl': '',
          'isVerified': true,
          'isAdmin': true,
          'isFollowing': false,
          'charmPoints': 12500,
        }),
        rank: 1,
        score: 12500,
        status: 'Outstanding Admin',
      ),
      TopUser(
        user: User.fromJson(const {
          'id': 'u-kat_boss',
          'username': 'kat_boss',
          'fullName': 'Kat Boss',
          'avatarUrl': '',
          'isVerified': true,
          'isFollowing': false,
          'charmPoints': 9800,
        }),
        rank: 2,
        score: 9800,
        status: 'Top Contributor',
      ),
      TopUser(
        user: User.fromJson(const {
          'id': 'u-music_fanatic',
          'username': 'music_fanatic',
          'fullName': 'Music Fanatic',
          'avatarUrl': '',
          'isFollowing': false,
          'charmPoints': 7400,
        }),
        rank: 3,
        score: 7400,
        status: 'Daily Star',
      ),
      TopUser(
        user: User.fromJson(const {
          'id': 'u-katsklub_dev',
          'username': 'katsklub_dev',
          'fullName': 'KatsKlub Developer',
          'avatarUrl': '',
          'isVerified': true,
          'isFollowing': false,
          'charmPoints': 5200,
        }),
        rank: 4,
        score: 5200,
        status: 'Rising Star',
      ),
      TopUser(
        user: User.fromJson(const {
          'id': 'u-traveler_01',
          'username': 'traveler_01',
          'fullName': 'Traveler One',
          'avatarUrl': '',
          'isFollowing': false,
          'charmPoints': 3900,
        }),
        rank: 5,
        score: 3900,
        status: 'Popular Explorer',
      ),
    ];

    // Set initial follow states
    for (final tu in _topUsers) {
      if (tu.user.isFollowing) {
        _followedUsernames.add(tu.user.username!.toLowerCase());
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

  @override
  Widget build(BuildContext context) {
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
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _topUsers.length,
          itemBuilder: (context, index) {
            final tu = _topUsers[index];
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
                          child: Center(
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
                      child: isGemini
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
          },
        ),
      ),
    );
  }
}
