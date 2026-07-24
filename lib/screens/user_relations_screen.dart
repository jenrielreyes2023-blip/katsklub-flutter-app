import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/feed_service.dart';
import '../widgets/avatar_with_border.dart';
import 'user_profile_screen.dart';

class UserRelationsScreen extends StatelessWidget {
  const UserRelationsScreen({
    required this.username,
    required this.isOwnProfile,
    required this.showListFollowers,
    required this.showListFollowing,
    required this.currentUser,
    required this.initialTabIndex,
    this.onOpenUserProfile,
    super.key,
  });

  final String username;
  final bool isOwnProfile;
  final bool showListFollowers;
  final bool showListFollowing;
  final User currentUser;
  final int initialTabIndex; // 0 for Followers, 1 for Following, 2 for Suggestions
  final ValueChanged<String>? onOpenUserProfile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFF3F4F6);
    final tabIndicatorColor = isDark ? const Color(0xFFFF7A45) : Colors.black;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: bgColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: bgColor,
                elevation: 0,
                pinned: true,
                floating: true,
                titleSpacing: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: titleColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Connections',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
                    ),
                    child: TabBar(
                      indicatorColor: tabIndicatorColor,
                      labelColor: titleColor,
                      unselectedLabelColor: subtitleColor,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Followers'),
                        Tab(text: 'Following'),
                        Tab(text: 'Suggestions'),
                      ],
                    ),
                  ),
                ),
              )
            ];
          },
          body: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _RelationsTab(
                username: username,
                isFollowersList: true,
                isOwnProfile: isOwnProfile,
                showList: showListFollowers,
                currentUser: currentUser,
                onOpenUserProfile: onOpenUserProfile,
              ),
              _RelationsTab(
                username: username,
                isFollowersList: false,
                isOwnProfile: isOwnProfile,
                showList: showListFollowing,
                currentUser: currentUser,
                onOpenUserProfile: onOpenUserProfile,
              ),
              _SuggestionsTab(
                currentUser: currentUser,
                onOpenUserProfile: onOpenUserProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationsTab extends StatefulWidget {
  const _RelationsTab({
    required this.username,
    required this.isFollowersList,
    required this.isOwnProfile,
    required this.showList,
    required this.currentUser,
    this.onOpenUserProfile,
  });

  final String username;
  final bool isFollowersList;
  final bool isOwnProfile;
  final bool showList;
  final User currentUser;
  final ValueChanged<String>? onOpenUserProfile;

  @override
  State<_RelationsTab> createState() => _RelationsTabState();
}

class _RelationsTabState extends State<_RelationsTab> with AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  final TextEditingController _searchController = TextEditingController();

  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _loadingUsernames = {};

  @override
  bool get wantKeepAlive => true;

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
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
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
    super.build(context);
    final hasAccess = widget.showList || widget.isOwnProfile;

    if (!hasAccess) {
      return _buildPrivatePlaceholder();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final searchHintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF);
    final searchFillColor = isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F6);
    final loaderColor = isDark ? const Color(0xFFFF7A45) : Colors.black;

    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 15, color: searchTextColor),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: searchHintColor, fontSize: 15),
              prefixIcon: Icon(Icons.search, color: searchHintColor, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: searchHintColor, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: searchFillColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: loaderColor,
                  ),
                )
              : _buildUserList(),
        ),
      ],
    );
  }

  Widget _buildPrivatePlaceholder() {
    final listName = widget.isFollowersList ? 'followers list' : 'following list';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final descColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final iconBgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconBgColor,
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
              color: titleColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This user has chosen to hide their $listName. Only they can view it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: descColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final filtered = _filteredUsers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final descColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

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
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try searching with a different name or username.'
                    : 'This list is empty.',
                style: TextStyle(
                  color: descColor,
                  fontSize: 13,
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
            if (user.username != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(username: user.username!),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AvatarWithBorder(
                  avatarUrl: user.avatarUrl ?? '',
                  initials: user.initials,
                  borderType: borderType,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.handle ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: descColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isPending) {
      return SizedBox(
        width: 80,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? const Color(0xFFFF7A45) : Colors.black,
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
            foregroundColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
            side: BorderSide(color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFD1D5DB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(80, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Following',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
            foregroundColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
            side: BorderSide(color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(80, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Requested',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () => _toggleFollow(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A45),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(80, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Follow',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SuggestionsTab extends StatefulWidget {
  const _SuggestionsTab({
    required this.currentUser,
    this.onOpenUserProfile,
  });

  final User currentUser;
  final ValueChanged<String>? onOpenUserProfile;

  @override
  State<_SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends State<_SuggestionsTab> with AutomaticKeepAliveClientMixin {
  final FeedService _feedService = FeedService();
  List<User> _suggestions = [];
  bool _isLoading = true;
  final Set<String> _loadingUsernames = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final fetched = await _feedService.loadFollowSuggestions();
      if (mounted) {
        setState(() {
          _suggestions = fetched;
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
          final index = _suggestions.indexWhere((u) => u.username == targetUsername);
          if (index >= 0) {
            _suggestions[index] = _suggestions[index].copyWith(
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final descColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final loaderColor = isDark ? const Color(0xFFFF7A45) : Colors.black;
    final iconBgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: loaderColor,
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No suggestions',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You\'ve followed everyone we can recommend right now!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: descColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final user = _suggestions[index];
        final isSelf = user.id == widget.currentUser.id;
        final borderType = AvatarBorderType.parse(user.profileBorder);

        return InkWell(
          onTap: () {
            if (user.username != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(username: user.username!),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                AvatarWithBorder(
                  avatarUrl: user.avatarUrl ?? '',
                  initials: user.initials,
                  borderType: borderType,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.handle ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: descColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isPending) {
      return SizedBox(
        width: 80,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? const Color(0xFFFF7A45) : Colors.black,
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
            foregroundColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
            side: BorderSide(color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFD1D5DB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(80, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Following',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
            foregroundColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
            side: BorderSide(color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(80, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Requested',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () => _toggleFollow(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A45),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(80, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Follow',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
