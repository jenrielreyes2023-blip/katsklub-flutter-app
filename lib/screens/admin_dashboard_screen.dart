import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import 'shop_screen.dart';
import '../services/promotions_service.dart';

class _AdminAchievementOption {
  const _AdminAchievementOption({required this.key, required this.label});

  final String key;
  final String label;
}

const List<_AdminAchievementOption> _achievementOptions = [
  _AdminAchievementOption(key: 'richie_rich', label: 'Richie Rich'),
  _AdminAchievementOption(key: 'stars_catcher', label: 'Stars catcher'),
  _AdminAchievementOption(key: 'soulmate', label: 'Soulmate'),
  _AdminAchievementOption(
      key: 'spring_herald_pink', label: 'Spring Herald Pink'),
  _AdminAchievementOption(
      key: 'spring_herald_purple', label: 'Spring Herald Purple'),
  _AdminAchievementOption(
      key: 'spring_herald_blue', label: 'Spring Herald Blue'),
  _AdminAchievementOption(key: 'supreme_warlord', label: 'Supreme Warlord'),
  _AdminAchievementOption(key: 'tech_support', label: 'Tech & Support'),
  _AdminAchievementOption(key: 'google_workspace', label: 'Google Workspace'),
  _AdminAchievementOption(key: 'pop_superstar', label: 'Pop Superstar'),
  _AdminAchievementOption(key: 'fresh_paw', label: 'Fresh Paw'),
  _AdminAchievementOption(key: 'rising_paw', label: 'Rising Paw'),
];

final Map<String, _AdminAchievementOption> _achievementOptionsByKey = {
  for (final option in _achievementOptions) option.key: option,
};

List<String> _readAchievementKeys(dynamic value) {
  if (value is! List) {
    return const [];
  }

  final seen = <String>{};
  final achievements = <String>[];
  for (final entry in value) {
    final key = entry.toString().trim().toLowerCase();
    if (key.isEmpty ||
        !_achievementOptionsByKey.containsKey(key) ||
        !seen.add(key)) {
      continue;
    }
    achievements.add(key);
  }
  return achievements;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.sessionCookie,
    required this.authToken,
  });

  final String? sessionCookie;
  final String? authToken;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  // State Lists
  List<dynamic> _users = [];
  List<dynamic> _posts = [];
  List<dynamic> _flaggedPosts = [];
  List<dynamic> _flaggedStories = [];

  // Service Config States
  Map<String, dynamic>? _rcloneStatus;
  Map<String, dynamic>? _r2Status;
  Map<String, dynamic>? _awsStatus;

  // Loading States
  bool _isLoadingUsers = false;
  bool _isLoadingPosts = false;
  bool _isLoadingFlaggedPosts = false;
  bool _isLoadingFlaggedStories = false;
  bool _isLoadingRclone = false;
  bool _isLoadingR2 = false;
  bool _isLoadingAWS = false;
  bool _isShopStateLoading = true;
  List<Promotion> _promotionsList = [];
  bool _isLoadingPromotions = false;

  // Action Pending flags
  bool _isTestingR2 = false;
  bool _isTestingAWS = false;
  bool _isRestartingRclone = false;
  bool _isResettingPostcards = false;

  // Search Queries
  String _userSearchQuery = '';
  String _postSearchQuery = '';

  // Controllers
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _postSearchController = TextEditingController();

  // Flag Tab Inner Segment
  int _flagSegmentIndex = 0; // 0 = Posts, 1 = Stories

  // Enabled themes config
  final Map<String, bool> _enabledThemes = {};

  @override
  void initState() {
    super.initState();
    // 7 Tabs: Stats, Users, Posts, Flags, Services, Shop, Ads & Promo
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Initial loads
    _fetchUsers();
    _fetchPosts();
    _fetchFlaggedPosts();
    _fetchFlaggedStories();
    _fetchRcloneStatus();
    _fetchR2Status();
    _fetchAWSStatus();
    _loadAdminShopSettings();
    _fetchPromotions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _postSearchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<String?> _getToken() async {
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      return widget.authToken;
    }
    return await _authService.getToken();
  }

  Map<String, String> _headers(String token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // API calls - Fetching
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/users?q=${Uri.encodeComponent(_userSearchQuery)}&limit=50');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['users'] != null) {
          setState(() {
            _users = data['users'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/posts?q=${Uri.encodeComponent(_postSearchQuery)}&limit=50');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['posts'] != null) {
          setState(() {
            _posts = data['posts'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _fetchFlaggedPosts() async {
    setState(() {
      _isLoadingFlaggedPosts = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/reports/posts');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['reports'] != null) {
          setState(() {
            _flaggedPosts = data['reports'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching flagged posts: $e');
    } finally {
      setState(() {
        _isLoadingFlaggedPosts = false;
      });
    }
  }

  Future<void> _fetchFlaggedStories() async {
    setState(() {
      _isLoadingFlaggedStories = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/reports/stories');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['reports'] != null) {
          setState(() {
            _flaggedStories = data['reports'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching flagged stories: $e');
    } finally {
      setState(() {
        _isLoadingFlaggedStories = false;
      });
    }
  }

  Future<void> _fetchRcloneStatus() async {
    setState(() {
      _isLoadingRclone = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/rclone/status');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true) {
          setState(() {
            _rcloneStatus = data['status'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching rclone status: $e');
    } finally {
      setState(() {
        _isLoadingRclone = false;
      });
    }
  }

  Future<void> _fetchR2Status() async {
    setState(() {
      _isLoadingR2 = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/storage/r2/status');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true) {
          setState(() {
            _r2Status = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching R2 status: $e');
    } finally {
      setState(() {
        _isLoadingR2 = false;
      });
    }
  }

  Future<void> _fetchAWSStatus() async {
    setState(() {
      _isLoadingAWS = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/storage/aws-video/status');
      final res = await http.get(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true) {
          setState(() {
            _awsStatus = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching AWS status: $e');
    } finally {
      setState(() {
        _isLoadingAWS = false;
      });
    }
  }

  // API Actions
  Future<void> _toggleUserVerification(String userId, bool isVerified) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/users/$userId/badge');
      final res = await http.patch(
        url,
        headers: _headers(token),
        body: jsonEncode({'isVerified': !isVerified}),
      );

      if (res.statusCode == 200) {
        _fetchUsers();
        _showSuccessSnackBar('User verification status updated.');
      } else {
        _showErrorSnackBar('Failed to update verification status.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _toggleUserAuthor(String userId, bool isAuthor) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/users/$userId/author');
      final res = await http.patch(
        url,
        headers: _headers(token),
        body: jsonEncode({'isAuthor': !isAuthor}),
      );

      if (res.statusCode == 200) {
        _fetchUsers();
        _showSuccessSnackBar('User author status updated.');
      } else {
        _showErrorSnackBar('Failed to update author status.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _updateUserProfileBorder(String userId, String border) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/users/$userId/border');
      final res = await http.patch(
        url,
        headers: _headers(token),
        body: jsonEncode({'profileBorder': border}),
      );

      if (res.statusCode == 200) {
        _fetchUsers();
        _showSuccessSnackBar('User profile border updated.');
      } else {
        _showErrorSnackBar('Failed to update profile border.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  void _showBorderSelectionDialog(String userId, String currentBorder) {
    final borders = [
      {'value': '', 'label': 'None'},
      {'value': 'heart', 'label': 'Heart'},
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Profile Border'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: borders.map((b) {
                final isSelected = b['value'] == currentBorder;
                return ListTile(
                  title: Text(b['label']!),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _updateUserProfileBorder(userId, b['value']!);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUserRoleTitle(
      String userId, String currentRoleTitle) async {
    final textController = TextEditingController(text: currentRoleTitle);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Role Title',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Role Title',
                hintText: 'e.g., Verified Creator, Admin',
                border: OutlineInputBorder(),
              ),
              maxLength: 40,
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Please enter a title'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);

                try {
                  final token = await _getToken();
                  if (token == null) return;

                  final url = Uri.parse(
                      '${ApiConfig.apiBaseUrl}/api/admin/users/$userId/role-title');
                  final res = await http.patch(
                    url,
                    headers: _headers(token),
                    body: jsonEncode({'roleTitle': textController.text.trim()}),
                  );

                  if (res.statusCode == 200) {
                    _fetchUsers();
                    _showSuccessSnackBar('Role title updated.');
                  } else {
                    _showErrorSnackBar('Failed to update role title.');
                  }
                } catch (e) {
                  _showErrorSnackBar('An error occurred.');
                }
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  Future<void> _updateUserAchievements(
    String userId,
    List<String> achievements,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/users/$userId/achievements');
      final res = await http.patch(
        url,
        headers: _headers(token),
        body: jsonEncode({'achievements': achievements}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final userJson = data['user'];
        if (userJson is Map<String, dynamic>) {
          final updatedUser = User.fromJson(userJson);
          final updatedUsername =
              updatedUser.username?.trim().toLowerCase() ?? '';
          if (updatedUsername.isNotEmpty) {
            final currentUser = await _authService.getSavedUser();
            final currentUsername =
                currentUser?.username?.trim().toLowerCase() ?? '';
            if (currentUsername.isNotEmpty &&
                currentUsername == updatedUsername) {
              await _authService.saveCurrentUser(updatedUser);
            }
            FeedService.notifyProfileStatsChanged(
              username: updatedUsername,
              user: updatedUser,
            );
          }
        }
        _fetchUsers();
        _showSuccessSnackBar('User achievements updated.');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to update achievements.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  void _showGrantAchievementDialog(
    String userId,
    List<String> currentAchievements,
  ) {
    final selected = currentAchievements.toSet();

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Grant Achievements',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _achievementOptions.map((option) {
                      return CheckboxListTile(
                        value: selected.contains(option.key),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(option.label),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setModalState(() {
                            if (value == true) {
                              selected.add(option.key);
                            } else {
                              selected.remove(option.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final achievements = _achievementOptions
                        .where((option) => selected.contains(option.key))
                        .map((option) => option.key)
                        .toList();
                    _updateUserAchievements(userId, achievements);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _revokeUserSessions(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/users/$userId/revoke-sessions');
      final res = await http.post(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _fetchUsers();
        _showSuccessSnackBar(
            'Sessions revoked. Count: ${data['revokedSessions'] ?? 0}');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to revoke sessions.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _deleteUserAccount(String userId) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Account',
      content:
          'Are you sure you want to permanently delete this user account? All posts, stories, and comments uploaded by this user will be removed. This action cannot be undone.',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/users/$userId');
      final res = await http.delete(url, headers: _headers(token));

      if (res.statusCode == 200) {
        _fetchUsers();
        _fetchPosts();
        _fetchFlaggedPosts();
        _fetchFlaggedStories();
        _showSuccessSnackBar('User account deleted successfully.');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to delete user.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _deletePost(dynamic postId) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Post',
      content:
          'Are you sure you want to delete this post? This action cannot be undone.',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/posts/$postId');
      final res = await http.delete(url, headers: _headers(token));

      if (res.statusCode == 200) {
        _fetchPosts();
        _fetchFlaggedPosts();
        _showSuccessSnackBar('Post deleted successfully.');
      } else {
        _showErrorSnackBar('Failed to delete post.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _deleteStory(dynamic storyId) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Story',
      content:
          'Are you sure you want to delete this story? This action cannot be undone.',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/stories/$storyId');
      final res = await http.delete(url, headers: _headers(token));

      if (res.statusCode == 200) {
        _fetchFlaggedStories();
        _showSuccessSnackBar('Story deleted successfully.');
      } else {
        _showErrorSnackBar('Failed to delete story.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _dismissPostReports(dynamic postId) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/reports/posts/$postId/dismiss');
      final res = await http.delete(url, headers: _headers(token));

      if (res.statusCode == 200) {
        _fetchFlaggedPosts();
        _showSuccessSnackBar('Reports dismissed for this post.');
      } else {
        _showErrorSnackBar('Failed to dismiss reports.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _togglePostSensitivity(dynamic postId, bool currentSensitive) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/posts/$postId/sensitive');
      final res = await http.patch(
        url,
        headers: _headers(token),
        body: jsonEncode({'isSensitive': !currentSensitive}),
      );

      if (res.statusCode == 200) {
        _fetchFlaggedPosts();
        _fetchPosts();
        _showSuccessSnackBar(
            !currentSensitive ? 'Post marked as sensitive.' : 'Post marked as safe.');
      } else {
        _showErrorSnackBar('Failed to update post sensitivity.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _dismissStoryReports(dynamic storyId) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/reports/stories/$storyId/dismiss');
      final res = await http.delete(url, headers: _headers(token));

      if (res.statusCode == 200) {
        _fetchFlaggedStories();
        _showSuccessSnackBar('Reports dismissed for this story.');
      } else {
        _showErrorSnackBar('Failed to dismiss reports.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  // Rclone Actions
  Future<void> _updateRcloneCredentials({
    required String remoteName,
    required String clientId,
    required String clientSecret,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/rclone/credentials');
      final res = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode({
          'remoteName': remoteName,
          'clientId': clientId,
          'clientSecret': clientSecret,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _fetchRcloneStatus();
        _showSuccessSnackBar(data['message'] ?? 'Rclone credentials updated.');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(
            data['error'] ?? 'Failed to update rclone credentials.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _restartRcloneAudioMount() async {
    setState(() {
      _isRestartingRclone = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/rclone/restart-audio');
      final res = await http.post(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSuccessSnackBar(data['message'] ?? 'Rclone service restarted.');
        _fetchRcloneStatus();
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to restart rclone mount.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    } finally {
      setState(() {
        _isRestartingRclone = false;
      });
    }
  }

  Future<void> _resetAllPostcardThemes() async {
    setState(() {
      _isResettingPostcards = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/reset-postcard-themes');
      final res = await http.post(url, headers: _headers(token));

      if (res.statusCode == 200) {
        await FeedService().clearAllCachedPostcardThemes();
        FeedService.notifyPostcardThemesReset();
        final data = jsonDecode(res.body);
        _showSuccessSnackBar(data['message'] ?? 'All postcard themes have been reset.');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to reset postcard themes.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    } finally {
      setState(() {
        _isResettingPostcards = false;
      });
    }
  }

  void _confirmResetPostcards() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Postcard Themes?'),
        content: const Text(
          'Are you sure you want to remove postcard themes from all users? '
          'This will return all posts to the default layout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetAllPostcardThemes();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  // R2 Actions
  Future<void> _updateR2Settings({
    required bool enabled,
    required String accountId,
    required String accessKeyId,
    required String secretAccessKey,
    required String bucket,
    required String publicBaseUrl,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/storage/r2/settings');
      final res = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode({
          'enabled': enabled,
          'accountId': accountId,
          'accessKeyId': accessKeyId,
          'secretAccessKey': secretAccessKey,
          'bucket': bucket,
          'publicBaseUrl': publicBaseUrl,
        }),
      );

      if (res.statusCode == 200) {
        _showSuccessSnackBar('R2 settings updated successfully.');
        _fetchR2Status();
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to update R2 settings.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _testR2Connection() async {
    setState(() {
      _isTestingR2 = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/storage/r2/test');
      final res = await http.post(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSuccessSnackBar(
            data['message'] ?? 'R2 connection test succeeded.');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'R2 connection test failed.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred during testing.');
    } finally {
      setState(() {
        _isTestingR2 = false;
      });
    }
  }

  // AWS Actions
  Future<void> _updateAWSSettings({
    required bool enabled,
    required String region,
    required String bucket,
    required String accessKeyId,
    required String secretAccessKey,
    required String publicBaseUrl,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse(
          '${ApiConfig.apiBaseUrl}/api/admin/storage/aws-video/settings');
      final res = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode({
          'enabled': enabled,
          'region': region,
          'bucket': bucket,
          'accessKeyId': accessKeyId,
          'secretAccessKey': secretAccessKey,
          'publicBaseUrl': publicBaseUrl,
        }),
      );

      if (res.statusCode == 200) {
        _showSuccessSnackBar('AWS video settings updated successfully.');
        _fetchAWSStatus();
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to update AWS settings.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    }
  }

  Future<void> _testAWSConnection() async {
    setState(() {
      _isTestingAWS = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final url =
          Uri.parse('${ApiConfig.apiBaseUrl}/api/admin/storage/aws-video/test');
      final res = await http.post(url, headers: _headers(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _showSuccessSnackBar(
            data['message'] ?? 'AWS connection test succeeded.');
      } else {
        final data = jsonDecode(res.body);
        _showErrorSnackBar(data['error'] ?? 'AWS connection test failed.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred.');
    } finally {
      setState(() {
        _isTestingAWS = false;
      });
    }
  }

  // Helpers
  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: isDestructive
                  ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              child: Text('Confirm',
                  style: TextStyle(color: isDestructive ? Colors.white : null)),
            )
          ],
        );
      },
    );
  }

  // Show bottom sheet to update Rclone Credentials
  void _showRcloneCredsDialog() {
    final remoteController = TextEditingController(text: 'gdrive');
    final clientIdController = TextEditingController();
    final secretController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rclone Credentials',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: remoteController,
                    decoration: const InputDecoration(
                        labelText: 'Remote Name', border: OutlineInputBorder()),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: clientIdController,
                    decoration: const InputDecoration(
                        labelText: 'Client ID', border: OutlineInputBorder()),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: secretController,
                    decoration: const InputDecoration(
                        labelText: 'Client Secret',
                        border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                _updateRcloneCredentials(
                  remoteName: remoteController.text.trim(),
                  clientId: clientIdController.text.trim(),
                  clientSecret: secretController.text.trim(),
                );
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

  // Show dialog to update R2 settings
  void _showR2ConfigDialog() {
    final bool enabledVal = _r2Status?['enabled'] == true;
    final accountController = TextEditingController();
    final keyController = TextEditingController();
    final secretController = TextEditingController();
    final bucketController =
        TextEditingController(text: _r2Status?['bucket'] ?? '');
    final urlController =
        TextEditingController(text: _r2Status?['publicBaseUrl'] ?? '');
    bool isEnabled = enabledVal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cloudflare R2 Storage',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('Enable Cloudflare R2'),
                      value: isEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          isEnabled = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accountController,
                      decoration: const InputDecoration(
                          labelText: 'Account ID',
                          border: OutlineInputBorder(),
                          hintText: 'Cloudflare Account ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyController,
                      decoration: const InputDecoration(
                          labelText: 'Access Key ID',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretController,
                      decoration: const InputDecoration(
                          labelText: 'Secret Access Key',
                          border: OutlineInputBorder(),
                          hintText: 'Leave empty to keep existing'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bucketController,
                      decoration: const InputDecoration(
                          labelText: 'R2 Bucket Name',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                          labelText:
                              'Public Base URL (must start with http/https)',
                          border: OutlineInputBorder(),
                          hintText: 'https://cdn.example.com'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateR2Settings(
                      enabled: isEnabled,
                      accountId: accountController.text.trim(),
                      accessKeyId: keyController.text.trim(),
                      secretAccessKey: secretController.text.trim(),
                      bucket: bucketController.text.trim(),
                      publicBaseUrl: urlController.text.trim(),
                    );
                  },
                  child: const Text('Save'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // Show dialog to update AWS settings
  void _showAWSConfigDialog() {
    final bool enabledVal = _awsStatus?['enabled'] == true;
    final regionController =
        TextEditingController(text: _awsStatus?['region'] ?? '');
    final bucketController =
        TextEditingController(text: _awsStatus?['bucket'] ?? '');
    final keyController = TextEditingController();
    final secretController = TextEditingController();
    final urlController =
        TextEditingController(text: _awsStatus?['publicBaseUrl'] ?? '');
    bool isEnabled = enabledVal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('AWS Video Storage (S3)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('Enable AWS Storage'),
                      value: isEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          isEnabled = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: regionController,
                      decoration: const InputDecoration(
                          labelText: 'AWS Region',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., ap-northeast-1'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bucketController,
                      decoration: const InputDecoration(
                          labelText: 'S3 Bucket Name',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyController,
                      decoration: const InputDecoration(
                          labelText: 'Access Key ID',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretController,
                      decoration: const InputDecoration(
                          labelText: 'Secret Access Key',
                          border: OutlineInputBorder(),
                          hintText: 'Leave empty to keep existing'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                          labelText: 'CloudFront / Public URL',
                          border: OutlineInputBorder(),
                          hintText: 'https://video.example.com'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateAWSSettings(
                      enabled: isEnabled,
                      region: regionController.text.trim(),
                      bucket: bucketController.text.trim(),
                      accessKeyId: keyController.text.trim(),
                      secretAccessKey: secretController.text.trim(),
                      publicBaseUrl: urlController.text.trim(),
                    );
                  },
                  child: const Text('Save'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // Bottom action sheet for user administration options
  void _showUserActionOptions(dynamic user) {
    final String userId = user['id'];
    final String fullName = user['fullName'] ?? '';
    final String username = user['username'] ?? '';
    final bool isVerified = user['isVerified'] == true;
    final bool isAuthor = user['isAuthor'] == true;
    final String roleTitle = user['roleTitle'] ?? '';
    final String currentBorder = user['profileBorder'] ?? '';
    final List<String> currentAchievements =
        _readAchievementKeys(user['achievements']);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      '@$username',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isVerified ? Icons.verified_user : Icons.verified,
                  color: isVerified ? Colors.grey : Colors.blue,
                ),
                title: Text(isVerified
                    ? 'Remove Verification Badge'
                    : 'Grant Verification Badge'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleUserVerification(userId, isVerified);
                },
              ),
              ListTile(
                leading: Icon(
                  isAuthor ? Icons.edit_off : Icons.create,
                  color: isAuthor ? Colors.grey : Colors.green,
                ),
                title: Text(isAuthor
                    ? 'Revoke Author Privileges'
                    : 'Grant Author Privileges'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleUserAuthor(userId, isAuthor);
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge, color: Colors.amber),
                title: const Text('Update Role Title'),
                onTap: () {
                  Navigator.pop(context);
                  _updateUserRoleTitle(userId, roleTitle);
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined,
                    color: Colors.blueAccent),
                title: const Text('Update Profile Border'),
                onTap: () {
                  Navigator.pop(context);
                  _showBorderSelectionDialog(userId, currentBorder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined,
                    color: Colors.deepPurple),
                title: const Text('Grant Achievements'),
                subtitle: currentAchievements.isEmpty
                    ? const Text('No achievements granted yet')
                    : Text('${currentAchievements.length} granted'),
                onTap: () {
                  Navigator.pop(context);
                  _showGrantAchievementDialog(userId, currentAchievements);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.orange),
                title: const Text('Force Revoke All Sessions'),
                onTap: () {
                  Navigator.pop(context);
                  _revokeUserSessions(userId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Account',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteUserAccount(userId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // BUILD UI tabs
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Admin Console',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF2563EB),
          indicatorSize: TabBarIndicatorSize.tab,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Stats'),
            Tab(icon: Icon(Icons.people_outline), text: 'Users'),
            Tab(icon: Icon(Icons.article_outlined), text: 'Posts'),
            Tab(icon: Icon(Icons.report_gmailerrorred_outlined), text: 'Flags'),
            Tab(icon: Icon(Icons.cloud_sync_outlined), text: 'Services'),
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Shop'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Ads & Promo'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111827)),
            onPressed: () {
              _fetchUsers();
              _fetchPosts();
              _fetchFlaggedPosts();
              _fetchFlaggedStories();
              _fetchRcloneStatus();
              _fetchR2Status();
              _fetchAWSStatus();
              _loadAdminShopSettings();
              _fetchPromotions();
              _showSuccessSnackBar('Data reloaded.');
            },
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildPostsTab(),
          _buildFlagsTab(),
          _buildServicesTab(),
          _buildShopTab(),
          _buildPromotionsTab(),
        ],
      ),
    );
  }

  // 1. Overview Tab
  Widget _buildOverviewTab() {
    final reportsCount = _flaggedPosts.length + _flaggedStories.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Activity',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Flagged Content',
                  value: '$reportsCount',
                  icon: Icons.report_problem,
                  color: Colors.red,
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Active Users',
                  value: '${_users.length}',
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Posts Managed',
                  value: '${_posts.length}',
                  icon: Icons.post_add,
                  color: Colors.green,
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Integration Status',
                  value: 'Cloud & Sync',
                  icon: Icons.cloud_done_outlined,
                  color: Colors.purple,
                  onTap: () => _tabController.animateTo(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Admin Guidelines',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _buildGuidelineRow(Icons.check_circle_outline,
                    'Verify original creators by toggling the badge in the Users tab.'),
                const SizedBox(height: 12),
                _buildGuidelineRow(Icons.security,
                    'Promptly review content flagged under the Flags tab. Dismiss reports if they comply with platform policies.'),
                const SizedBox(height: 12),
                _buildGuidelineRow(Icons.sync_alt,
                    'Manage AWS S3, Cloudflare R2, and Rclone mount configuration parameters in the Services tab.'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF4B5563), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
          ),
        ),
      ],
    );
  }

  // 2. Users Tab
  Widget _buildUsersTab() {
    return Column(
      children: [
        _buildSearchField(
          controller: _userSearchController,
          hint: 'Search users by name, username, email...',
          onChanged: (val) {
            setState(() {
              _userSearchQuery = val;
            });
            _fetchUsers();
          },
          onClear: () {
            setState(() {
              _userSearchQuery = '';
              _userSearchController.clear();
            });
            _fetchUsers();
          },
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : ListView.builder(
                      itemCount: _users.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final u = _users[index];
                        final avatarUrl = u['avatarUrl'] ?? '';
                        final fullName = u['fullName'] ?? '';
                        final username = u['username'] ?? '';
                        final isVerified = u['isVerified'] == true;
                        final isAuthor = u['isAuthor'] == true;
                        final roleTitle = u['roleTitle'] ?? '';
                        final postCount = u['postCount'] ?? 0;
                        final sessions = u['activeSessionCount'] ?? 0;
                        final profileBorder = u['profileBorder'] ?? '';
                        final achievements =
                            _readAchievementKeys(u['achievements']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundImage: avatarUrl.toString().isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      ApiConfig.assetUrl(avatarUrl))
                                  : null,
                              backgroundColor: Colors.blue.shade100,
                              child: avatarUrl.toString().isEmpty
                                  ? Text(fullName.isNotEmpty
                                      ? fullName[0].toUpperCase()
                                      : '?')
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified)
                                  const Icon(Icons.verified,
                                      color: Colors.blue, size: 16),
                                if (isAuthor) const SizedBox(width: 4),
                                if (isAuthor)
                                  const Icon(Icons.border_color_rounded,
                                      color: Colors.green, size: 16),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('@$username',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13)),
                                if (roleTitle.toString().isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(
                                        top: 4, bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      roleTitle,
                                      style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (profileBorder.toString().isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(
                                        top: 2, bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.amber.shade200),
                                    ),
                                    child: Text(
                                      'Border: ${profileBorder.toString().substring(0, 1).toUpperCase()}${profileBorder.toString().substring(1)}',
                                      style: TextStyle(
                                          color: Colors.amber.shade800,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (achievements.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(
                                        top: 2, bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.deepPurple.shade100),
                                    ),
                                    child: Text(
                                      '${achievements.length} achievement${achievements.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                          color: Colors.deepPurple.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  '$postCount posts • $sessions active sessions',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _showUserActionOptions(u),
                            ),
                          ),
                        );
                      },
                    ),
        )
      ],
    );
  }

  // 3. Posts Tab
  Widget _buildPostsTab() {
    return Column(
      children: [
        _buildSearchField(
          controller: _postSearchController,
          hint: 'Search posts by content or author...',
          onChanged: (val) {
            setState(() {
              _postSearchQuery = val;
            });
            _fetchPosts();
          },
          onClear: () {
            setState(() {
              _postSearchQuery = '';
              _postSearchController.clear();
            });
            _fetchPosts();
          },
        ),
        Expanded(
          child: _isLoadingPosts
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
                  ? const Center(child: Text('No posts found.'))
                  : ListView.builder(
                      itemCount: _posts.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final p = _posts[index];
                        final postId = p['id'];
                        final authorName =
                            p['author_full_name'] ?? p['author'] ?? '';
                        final postText = p['text'] ?? '';
                        final likes = p['like_count'] ?? 0;
                        final comments = p['comment_count'] ?? 0;
                        final reports = p['report_count'] ?? 0;
                        final authorAvatar = p['author_avatar_url'] ?? '';
                        final isSensitive = p['is_sensitive'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: authorAvatar
                                              .toString()
                                              .isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              ApiConfig.assetUrl(authorAvatar))
                                          : null,
                                      child: authorAvatar.toString().isEmpty
                                          ? const Icon(Icons.person, size: 18)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  authorName,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isSensitive)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 6),
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.amber.shade200),
                                                  ),
                                                  child: Text(
                                                    'SENSITIVE',
                                                    style: TextStyle(
                                                        color: Colors.amber.shade800,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 9),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            p['created_at'] != null
                                                ? p['created_at']
                                                    .toString()
                                                    .split('T')
                                                    .first
                                                : '',
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (reports > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '🚨 $reports',
                                          style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        isSensitive
                                            ? Icons.warning_amber_rounded
                                            : Icons.warning_amber_outlined,
                                        color: isSensitive
                                            ? Colors.amber.shade700
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: () =>
                                          _togglePostSensitivity(postId, isSensitive),
                                      tooltip: isSensitive
                                          ? 'Mark Safe'
                                          : 'Mark Sensitive',
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () => _deletePost(postId),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  postText.isNotEmpty
                                      ? postText
                                      : '(No text content)',
                                  style: TextStyle(
                                    color: postText.isNotEmpty
                                        ? const Color(0xFF1F2937)
                                        : Colors.grey,
                                    fontSize: 14,
                                    fontStyle: postText.isNotEmpty
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.favorite_border,
                                        size: 16, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text('$likes',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12)),
                                    const SizedBox(width: 16),
                                    Icon(Icons.chat_bubble_outline,
                                        size: 16, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text('$comments',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        )
      ],
    );
  }

  // 4. Flags/Reports Tab
  Widget _buildFlagsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSegmentButton(0, 'Post Flags (${_flaggedPosts.length})'),
              const SizedBox(width: 8),
              _buildSegmentButton(1, 'Story Flags (${_flaggedStories.length})'),
            ],
          ),
        ),
        Expanded(
          child: _flagSegmentIndex == 0
              ? _buildFlaggedPostsList()
              : _buildFlaggedStoriesList(),
        ),
      ],
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final isSelected = _flagSegmentIndex == index;
    return TextButton(
      onPressed: () {
        setState(() {
          _flagSegmentIndex = index;
        });
      },
      style: TextButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFE0E7FF) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF4B5563),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFlaggedPostsList() {
    if (_isLoadingFlaggedPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_flaggedPosts.isEmpty) {
      return const Center(child: Text('No flagged posts reported.'));
    }

    return ListView.builder(
      itemCount: _flaggedPosts.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final g = _flaggedPosts[index];
        final postId = g['post_id'];
        final count = g['report_count'] ?? 0;
        final author = g['post_author_full_name'] ?? g['post_author'] ?? '';
        final text = g['post_text'] ?? '';
        final reports = g['reports'] as List<dynamic>? ?? [];
        final isSensitive = g['post_is_sensitive'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          author,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSensitive)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            'SENSITIVE',
                            style: TextStyle(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 9),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🚨 $count',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                )
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                text.isNotEmpty ? text : '(No text content)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reports Reason List:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...reports.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${r['reporter_username'] ?? 'anonymous'}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Expanded(
                                child: Text(
                                  r['reason'] ?? '',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _togglePostSensitivity(postId, isSensitive),
                          icon: Icon(
                            isSensitive
                                ? Icons.warning_amber_rounded
                                : Icons.warning_amber_outlined,
                            size: 16,
                            color: Colors.amber.shade800,
                          ),
                          label: Text(
                            isSensitive ? 'Mark Safe' : 'Mark Sensitive',
                            style: TextStyle(color: Colors.amber.shade800),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.amber.shade300),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _dismissPostReports(postId),
                          child: const Text('Dismiss Flags',
                              style: TextStyle(color: Colors.blue)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _deletePost(postId),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Delete Post',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlaggedStoriesList() {
    if (_isLoadingFlaggedStories) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_flaggedStories.isEmpty) {
      return const Center(child: Text('No flagged stories reported.'));
    }

    return ListView.builder(
      itemCount: _flaggedStories.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final g = _flaggedStories[index];
        final storyId = g['story_id'];
        final count = g['report_count'] ?? 0;
        final author =
            g['story_author_full_name'] ?? g['story_author_username'] ?? '';
        final text = g['story_text'] ?? '';
        final imageUrl = g['story_image_url'] ?? '';
        final reports = g['reports'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    author,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🚨 $count',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                )
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  if (imageUrl.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      text.isNotEmpty ? text : '(Image Story)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reports Reason List:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...reports.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${r['reporter_username'] ?? 'anonymous'}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Expanded(
                                child: Text(
                                  r['reason'] ?? '',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _dismissStoryReports(storyId),
                          child: const Text('Dismiss Flags',
                              style: TextStyle(color: Colors.blue)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _deleteStory(storyId),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Delete Story',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // 5. Cloud & Services Tab (AWS, Cloudflare R2, Rclone)
  Widget _buildServicesTab() {
    if (_rcloneStatus == null && _r2Status == null && _awsStatus == null) {
      if (_isLoadingRclone || _isLoadingR2 || _isLoadingAWS) {
        return const Center(child: CircularProgressIndicator());
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section A: Rclone Config
          _buildServiceHeaderCard(
            title: 'Rclone (Google Drive mount)',
            subtitle: 'Syncing and serving audio library files',
            icon: Icons.sync,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _buildStatusRow(
                  label: 'Systemctl daemon status',
                  isActive: _rcloneStatus?['serviceActive'] == true,
                  activeText: 'Active & running',
                  inactiveText: 'Inactive / stopped',
                ),
                const Divider(height: 24),
                _buildStatusRow(
                  label: 'Rclone mount active',
                  isActive: _rcloneStatus?['isMountpoint'] == true,
                  activeText: 'Mounted successfully',
                  inactiveText: 'Unmounted',
                ),
                const Divider(height: 24),
                _buildStatusRow(
                  label: 'Google Drive response test',
                  isActive: _rcloneStatus?['rcloneConnected'] == true,
                  activeText: 'Connected & listing files',
                  inactiveText: 'Connection failed',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showRcloneCredsDialog,
                        icon: const Icon(Icons.vpn_key_outlined, size: 16),
                        label: const Text('Update Credentials'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRestartingRclone
                            ? null
                            : _restartRcloneAudioMount,
                        icon: _isRestartingRclone
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.restart_alt_rounded, size: 16),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B5563)),
                        label: const Text('Restart Mount',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section B: Cloudflare R2
          _buildServiceHeaderCard(
            title: 'Cloudflare R2 Storage',
            subtitle: 'Dynamic image uploads and avatar media hosting',
            icon: Icons.cloud_outlined,
            color: Colors.orange.shade700,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                  label: 'Cloudflare R2 Status',
                  isActive: _r2Status?['enabled'] == true,
                  activeText: 'R2 Storage Enabled',
                  inactiveText: 'Disabled (fallback to local)',
                ),
                const Divider(height: 24),
                Text(
                  'Configuration:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade800),
                ),
                const SizedBox(height: 6),
                _buildConfigTextRow(
                    'Bucket Name', _r2Status?['bucket'] ?? '(Not set)'),
                _buildConfigTextRow('Public Domain',
                    _r2Status?['publicBaseUrl'] ?? '(Not set)'),
                _buildConfigTextRow('Access Key Configured',
                    _r2Status?['accessKeyIdSet'] == true ? 'Yes' : 'No'),
                _buildConfigTextRow('Secret Key Configured',
                    _r2Status?['secretAccessKeySet'] == true ? 'Yes' : 'No'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showR2ConfigDialog,
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Update Settings'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTestingR2 ? null : _testR2Connection,
                        icon: _isTestingR2
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.flourescent_outlined, size: 16),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700),
                        label: const Text('Test Connection',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section C: AWS S3 Video Storage
          _buildServiceHeaderCard(
            title: 'AWS S3 Video Storage',
            subtitle: 'CDN optimized video streaming & uploads',
            icon: Icons.video_library_outlined,
            color: Colors.amber.shade800,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                  label: 'AWS Video Integration',
                  isActive: _awsStatus?['enabled'] == true,
                  activeText: 'AWS S3 Upload Enabled',
                  inactiveText: 'Disabled (fallback to local)',
                ),
                const Divider(height: 24),
                Text(
                  'Configuration:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade800),
                ),
                const SizedBox(height: 6),
                _buildConfigTextRow(
                    'S3 Bucket', _awsStatus?['bucket'] ?? '(Not set)'),
                _buildConfigTextRow(
                    'AWS Region', _awsStatus?['region'] ?? '(Not set)'),
                _buildConfigTextRow('CloudFront URL',
                    _awsStatus?['publicBaseUrl'] ?? '(Not set)'),
                _buildConfigTextRow('Access Key Configured',
                    _awsStatus?['accessKeyIdSet'] == true ? 'Yes' : 'No'),
                _buildConfigTextRow('Secret Key Configured',
                    _awsStatus?['secretAccessKeySet'] == true ? 'Yes' : 'No'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showAWSConfigDialog,
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Update Settings'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTestingAWS ? null : _testAWSConnection,
                        icon: _isTestingAWS
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.flourescent_outlined, size: 16),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800),
                        label: const Text('Test Connection',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section D: System Utilities / Database Tools
          _buildServiceHeaderCard(
            title: 'Database Utilities',
            subtitle: 'Global operations and resets',
            icon: Icons.storage_outlined,
            color: Colors.red.shade600,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Postcard UI Themes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will clear the postcard_theme setting for all users, resetting all posts back to the default UI layout.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResettingPostcards ? null : _confirmResetPostcards,
                    icon: _isResettingPostcards
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cleaning_services_outlined, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Reset All Postcard Themes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHeaderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF111827)),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String label,
    required bool isActive,
    required String activeText,
    required String inactiveText,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF374151)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 4,
                backgroundColor: isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? activeText : inactiveText,
                style: TextStyle(
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTextRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$key: ',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563))),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }

  // Common Search field
  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Shop Tab methods
  Future<void> _loadAdminShopSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final theme in themeProducts) {
        final themeKey = _themeKeyForPublic(theme.type);
        final key = 'katsklub_theme_public_$themeKey';
        _enabledThemes[themeKey] = prefs.getBool(key) ?? true;
      }
      _isShopStateLoading = false;
    });
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoadingPromotions = true);
    try {
      final list = await PromotionsService().getPromotions();
      setState(() {
        _promotionsList = list;
      });
    } catch (_) {}
    setState(() => _isLoadingPromotions = false);
  }

  String _themeKeyForPublic(ThemeProductType type) {
    switch (type) {
      case ThemeProductType.sunrise:
        return 'sunrise';
      case ThemeProductType.ocean:
        return 'ocean';
      case ThemeProductType.bees:
        return 'bee';
      case ThemeProductType.eagle:
        return 'eagle';
      case ThemeProductType.pinkswan:
        return 'pinkswan';
      case ThemeProductType.dandelion:
        return 'dandelion';
      case ThemeProductType.gtaPastel:
        return 'gta_pastel';
      case ThemeProductType.sharinganEyes:
        return 'sharingan_eyes';
      case ThemeProductType.pastel:
        return 'pastel';
      case ThemeProductType.lavender:
        return 'lavender';
      case ThemeProductType.phFlag:
        return 'ph_flag';
      case ThemeProductType.xmasCozy:
        return 'xmas_cozy';
      case ThemeProductType.xmasSnowy:
        return 'xmas_snowy';
      case ThemeProductType.geminiRogerHunter:
        return 'gemini_roger_hunter';
      case ThemeProductType.geminiRogerWolf:
        return 'gemini_roger_wolf';
      case ThemeProductType.bunny:
        return 'bunny';
      case ThemeProductType.ghost:
        return 'ghost';
      case ThemeProductType.prince:
        return 'prince';
      case ThemeProductType.cuteHeart:
        return 'cute_heart';
      case ThemeProductType.elsa:
        return 'elsa';
      case ThemeProductType.bubbleDream:
        return 'bubble_dream';
    }
  }

  Future<void> _toggleThemePublicStatus(String themeKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'katsklub_theme_public_$themeKey';
    await prefs.setBool(key, value);
    setState(() {
      _enabledThemes[themeKey] = value;
    });
  }

  Widget _buildShopTab() {
    return _isShopStateLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: themeProducts.length,
            itemBuilder: (context, index) {
              final theme = themeProducts[index];
              final themeKey = _themeKeyForPublic(theme.type);
              final isEnabled = _enabledThemes[themeKey] ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                elevation: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header preview gradient
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: theme.previewGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.previewAvatarColor,
                            child: Text(
                              theme.previewInitial,
                              style: TextStyle(
                                color: theme.previewInitialColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            theme.previewLabel,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  theme.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              Switch(
                                value: isEnabled,
                                activeThumbColor: const Color(0xFF2563EB),
                                onChanged: (value) async {
                                  await _toggleThemePublicStatus(themeKey, value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            theme.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isEnabled ? 'Visible in Shop' : 'Hidden from Shop',
                                  style: TextStyle(
                                    color: isEnabled ? const Color(0xFF16A34A) : const Color(0xFF4B5563),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (theme.badgeText.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    theme.badgeText,
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildPromotionsTab() {
    return _isLoadingPromotions
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            body: RefreshIndicator(
              onRefresh: _fetchPromotions,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Feed Promotions & Ads',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => _showAddEditPromotionDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Promotions are injected into the home feed list after every 15 posts. Toggle the switch to activate or deactivate them.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_promotionsList.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No promotions configured',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _promotionsList.length,
                      itemBuilder: (context, index) {
                        final promo = _promotionsList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        promo.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: promo.isEnabled,
                                      activeColor: const Color(0xFF2563EB),
                                      onChanged: (val) async {
                                        final list = List<Promotion>.from(_promotionsList);
                                        list[index] = Promotion(
                                          id: promo.id,
                                          title: promo.title,
                                          text: promo.text,
                                          imageUrl: promo.imageUrl,
                                          actionUrl: promo.actionUrl,
                                          buttonText: promo.buttonText,
                                          isEnabled: val,
                                        );
                                        await PromotionsService().savePromotions(list);
                                        _fetchPromotions();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  promo.text,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (promo.imageUrl != null && promo.imageUrl!.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      promo.imageUrl!,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  children: [
                                    if (promo.actionUrl != null && promo.actionUrl!.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Action: ${promo.actionUrl} (${promo.buttonText})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF4B5563)),
                                      onPressed: () => _showAddEditPromotionDialog(promotion: promo),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deletePromotion(promo),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
  }

  Future<void> _deletePromotion(Promotion promo) async {
    final list = _promotionsList.where((p) => p.id != promo.id).toList();
    await PromotionsService().savePromotions(list);
    _fetchPromotions();
  }

  void _showAddEditPromotionDialog({Promotion? promotion}) {
    final titleCtrl = TextEditingController(text: promotion?.title ?? '');
    final textCtrl = TextEditingController(text: promotion?.text ?? '');
    final imageCtrl = TextEditingController(text: promotion?.imageUrl ?? '');
    final actionCtrl = TextEditingController(text: promotion?.actionUrl ?? '');
    final buttonCtrl = TextEditingController(text: promotion?.buttonText ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(promotion == null ? 'Add Promotion' : 'Edit Promotion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title / Sponsor Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description / Message'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(labelText: 'Image URL (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: actionCtrl,
                  decoration: const InputDecoration(labelText: 'Action Link (e.g. katsklub://shop or https://...)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: buttonCtrl,
                  decoration: const InputDecoration(labelText: 'Button Label (e.g. Learn More)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final text = textCtrl.text.trim();
                if (title.isEmpty || text.isEmpty) return;

                final list = List<Promotion>.from(_promotionsList);
                if (promotion == null) {
                  final newPromo = Promotion(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    text: text,
                    imageUrl: imageCtrl.text.trim(),
                    actionUrl: actionCtrl.text.trim(),
                    buttonText: buttonCtrl.text.trim(),
                    isEnabled: true,
                  );
                  list.add(newPromo);
                } else {
                  final idx = list.indexWhere((p) => p.id == promotion.id);
                  if (idx >= 0) {
                    list[idx] = Promotion(
                      id: promotion.id,
                      title: title,
                      text: text,
                      imageUrl: imageCtrl.text.trim(),
                      actionUrl: actionCtrl.text.trim(),
                      buttonText: buttonCtrl.text.trim(),
                      isEnabled: promotion.isEnabled,
                    );
                  }
                }
                await PromotionsService().savePromotions(list);
                _fetchPromotions();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
