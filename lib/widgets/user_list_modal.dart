import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user.dart';
import '../services/feed_service.dart';
import 'avatar_with_border.dart';


class UserListModal extends StatefulWidget {
  const UserListModal({
    required this.username,
    required this.isFollowersList,
    required this.isOwnProfile,
    required this.showList,
    required this.currentUser,
    required this.onOpenUserProfile,
    super.key,
  });

  final String username;
  final bool isFollowersList;
  final bool isOwnProfile;
  final bool showList;
  final User currentUser;
  final ValueChanged<String> onOpenUserProfile;

  @override
  State<UserListModal> createState() => _UserListModalState();
}

class _UserListModalState extends State<UserListModal> {
  final FeedService _feedService = FeedService();
  final TextEditingController _searchController = TextEditingController();
  
  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _loadingUsernames = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    if (widget.showList || widget.isOwnProfile) {
      _loadUsers();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fetched = widget.isFollowersList
          ? await _feedService.getUserFollowers(widget.username)
          : await _feedService.getUserFollowing(widget.username);

      if (mounted) {
        setState(() {
          _users = fetched;
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

  Future<void> _toggleFollow(User targetUser) async {
    final targetUsername = targetUser.username ?? '';
    if (targetUsername.isEmpty || _loadingUsernames.contains(targetUsername)) {
      return;
    }

    setState(() {
      _loadingUsernames.add(targetUsername);
    });

    try {
      final User? updated;
      if (targetUser.isFollowing) {
        updated = await _feedService.unfollowUser(targetUsername);
      } else {
        updated = await _feedService.followUser(targetUsername);
      }

      if (mounted && updated != null) {
        setState(() {
          final index = _users.indexWhere((u) => u.username == targetUsername);
          if (index >= 0) {
            _users[index] = _users[index].copyWith(
              isFollowing: updated!.isFollowing,
              isRequested: updated.isRequested,
            );
          }
        });
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsernames.remove(targetUsername);
        });
      }
    }
  }

  List<User> _filteredUsers() {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    return _users.where((user) {
      final name = (user.fullName ?? '').toLowerCase();
      final username = (user.username ?? '').toLowerCase();
      return name.contains(_searchQuery) || username.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFollowersList ? 'Followers' : 'Following';
    final hasAccess = widget.showList || widget.isOwnProfile;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),

          // Header Title
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF1F2937),
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          if (!hasAccess)
            Expanded(
              child: _buildPrivatePlaceholder(),
            )
          else ...[
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 15.sp, color: const Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: const Color(0xFF9CA3AF), fontSize: 15.sp),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : _buildUserList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivatePlaceholder() {
    final listName = widget.isFollowersList ? 'followers list' : 'following list';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF9CA3AF),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'This ${widget.isFollowersList ? "followers" : "following"} list is private',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This user has chosen to hide their $listName. Only they can view it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: 14.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final filtered = _filteredUsers();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _searchQuery.isNotEmpty ? 'No matches found' : 'No users found',
                style: TextStyle(
                  color: const Color(0xFF4B5563),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try searching with a different name or username.'
                    : 'This list is empty.',
                style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        final isSelf = user.id == widget.currentUser.id;
        final borderType = AvatarBorderType.parse(user.profileBorder);

        return InkWell(
          onTap: () {
            Navigator.pop(context);
            if (user.username != null) {
              widget.onOpenUserProfile(user.username!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Avatar with Border
                AvatarWithBorder(
                  avatarUrl: user.avatarUrl ?? '',
                  initials: user.initials,
                  borderType: borderType,
                  size: 44,
                ),
                const SizedBox(width: 12),

                // Name and Username
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1F2937),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.handle ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),

                // Follow Button
                if (!isSelf) ...[
                  const SizedBox(width: 8),
                  _buildFollowButton(user),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowButton(User user) {
    final username = user.username ?? '';
    final isPending = _loadingUsernames.contains(username);
    
    if (isPending) {
      return const SizedBox(
        width: 80,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    if (user.isFollowing) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: () => _toggleFollow(user),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF374151),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(80, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Following',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    if (user.isRequested) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: () => _toggleFollow(user),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(80, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Requested',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () => _toggleFollow(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(80, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Follow',
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
