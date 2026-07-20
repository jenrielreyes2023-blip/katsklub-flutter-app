import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/avatar_with_border.dart';
import 'user_profile_screen.dart';

class VisitorsScreen extends StatefulWidget {
  final User currentUser;
  const VisitorsScreen({required this.currentUser, super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  final FeedService _feedService = FeedService();
  List<User> _visitors = [];
  bool _isLoading = true;
  final Set<String> _followingInFlight = <String>{};
  final Set<String> _followedUsernames = <String>{};

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final visitors = await _feedService.loadProfileVisitors();
      if (mounted) {
        setState(() {
          _visitors = visitors;
          _followedUsernames.clear();
          for (final u in _visitors) {
            if (u.isFollowing) {
              _followedUsernames.add(u.username!.toLowerCase());
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
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
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _followedUsernames.add(cleanUsername);
          } else {
            _followedUsernames.remove(cleanUsername);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _followingInFlight.remove(cleanUsername);
        });
      }
    }
  }

  String _formatVisitedTime(String? visitedAtStr) {
    if (visitedAtStr == null) return '';
    try {
      final visitedAt = DateTime.parse(visitedAtStr).toLocal();
      final diff = DateTime.now().difference(visitedAt);
      
      if (diff.isNegative || diff.inSeconds < 60) {
        return 'Just now';
      }
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      }
      if (diff.inDays < 30) {
        return '${(diff.inDays / 7).floor()}w ago';
      }
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile Visitors',
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5E3A)),
              ),
            )
          : _visitors.isEmpty
              ? _buildEmptyState(isDark, subtitleColor)
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _visitors.length,
                  separatorBuilder: (context, index) => Divider(color: dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final visitor = _visitors[index];
                    final visitorUsername = visitor.username ?? '';
                    final cleanUsername = visitorUsername.trim().toLowerCase();
                    final isFollowing = _followedUsernames.contains(cleanUsername);
                    final isSelf = cleanUsername == widget.currentUser.username?.toLowerCase();
                    final isFlight = _followingInFlight.contains(cleanUsername);
                    
                    // Retrieve parsed visitedAt string from visitor.raw
                    final visitedAtStr = visitor.raw['visitedAt']?.toString();

                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(username: visitorUsername),
                          ),
                        );
                      },
                      leading: AvatarWithBorder(
                        avatarUrl: visitor.avatarUrl ?? '',
                        initials: visitor.initials,
                        size: 40,
                        borderType: AvatarBorderType.parse(visitor.profileBorder),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              visitor.displayName,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                fontFamily: 'Inter',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (visitor.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFFFF5E3A),
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$visitorUsername',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                          if (visitedAtStr != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Visited ${_formatVisitedTime(visitedAtStr)}',
                              style: const TextStyle(
                                color: Color(0xFFFF5E3A),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isSelf
                          ? const SizedBox.shrink()
                          : SizedBox(
                              height: 32,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: isFollowing
                                      ? (isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6))
                                      : const Color(0xFFFF5E3A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isFollowing
                                          ? (isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB))
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: isFlight ? null : () => _toggleFollow(visitorUsername),
                                child: isFlight
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        isFollowing ? 'Following' : 'Follow Back',
                                        style: TextStyle(
                                          color: isFollowing
                                              ? (isDark ? Colors.white : const Color(0xFF111827))
                                              : Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                              ),
                            ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color subtitleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 64,
              color: isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 16),
            Text(
              'No visitors yet',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your profile with friends to get more visits and views!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
