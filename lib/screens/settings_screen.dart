import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.user,
    required this.onLogout,
    super.key,
  });

  final User user;
  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final FeedService _feedService = FeedService();
  late User _currentUser;

  // Change Password state
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSavingPassword = false;
  String? _passwordError;
  String? _passwordSuccess;

  // Privacy Settings state
  late bool _showEmail;
  late bool _showPhone;
  late bool _showGender;
  late bool _showBirthday;
  late bool _showLocation;
  late bool _showFollowers;
  late bool _showFollowing;
  bool _isSavingPrivacy = false;
  String? _privacyError;
  String? _privacySuccess;

  // Private account state
  late bool _isPrivate;
  bool _isSavingPrivateAccount = false;

  // General loading states
  bool _isLoggingOutOther = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _showEmail = _currentUser.profileShowEmail;
    _showPhone = _currentUser.profileShowPhone;
    _showGender = _currentUser.profileShowGender;
    _showBirthday = _currentUser.profileShowBirthday;
    _showLocation = _currentUser.profileShowLocation;
    _showFollowers = _currentUser.profileShowFollowers;
    _showFollowing = _currentUser.profileShowFollowing;
    _isPrivate = _currentUser.isPrivate;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // API Call - Change Password
  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      setState(() => _passwordError = 'Current password is required.');
      return;
    }
    if (newPassword.isEmpty) {
      setState(() => _passwordError = 'New password is required.');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _passwordError = 'New password must be at least 8 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _passwordError = 'New passwords do not match.');
      return;
    }

    setState(() {
      _isSavingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    try {
      final headers = await _headers();
      final response = await http.patch(
        ApiConfig.uri('/api/me/password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _passwordSuccess = 'Password updated successfully.';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        setState(() {
          _passwordError = responseData['error'] ?? 'Failed to update password.';
        });
      }
    } catch (e) {
      setState(() {
        _passwordError = 'An error occurred. Please check your connection.';
      });
    } finally {
      setState(() {
        _isSavingPassword = false;
      });
    }
  }

  // API Call - Save Privacy Settings
  Future<void> _updatePrivacy() async {
    setState(() {
      _isSavingPrivacy = true;
      _privacyError = null;
      _privacySuccess = null;
    });

    try {
      final headers = await _headers();
      final response = await http.patch(
        ApiConfig.uri('/api/me/profile-privacy'),
        headers: headers,
        body: jsonEncode({
          'showEmail': _showEmail,
          'showPhone': _showPhone,
          'showGender': _showGender,
          'showBirthday': _showBirthday,
          'showLocation': _showLocation,
          'showFollowers': _showFollowers,
          'showFollowing': _showFollowing,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && responseData['user'] != null) {
        var updatedUser = User.fromJson(responseData['user']);
        if (responseData['user']['profileShowFollowers'] == null &&
            responseData['user']['profile_show_followers'] == null &&
            responseData['user']['showFollowers'] == null) {
          updatedUser = updatedUser.copyWith(
            profileShowFollowers: _showFollowers,
            profileShowFollowing: _showFollowing,
          );
        }
        await _authService.saveCurrentUser(updatedUser);
        setState(() {
          _currentUser = updatedUser;
          _privacySuccess = 'Privacy settings saved successfully.';
        });
      } else {
        setState(() {
          _privacyError = responseData['error'] ?? 'Failed to update privacy settings.';
        });
      }
    } catch (e) {
      setState(() {
        _privacyError = 'An error occurred. Please check your connection.';
      });
    } finally {
      setState(() {
        _isSavingPrivacy = false;
      });
    }
  }

  // API Call - Toggle Private Account
  Future<void> _updatePrivateAccount(bool nextValue) async {
    final previous = _isPrivate;
    setState(() {
      _isPrivate = nextValue;
      _isSavingPrivateAccount = true;
    });

    final updatedUser = await _feedService.setPrivateAccount(nextValue);

    if (!mounted) return;

    if (updatedUser != null) {
      await _authService.saveCurrentUser(updatedUser);
      setState(() {
        _currentUser = updatedUser;
        _isPrivate = updatedUser.isPrivate;
        _isSavingPrivateAccount = false;
      });
    } else {
      // Revert on failure.
      setState(() {
        _isPrivate = previous;
        _isSavingPrivateAccount = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update account privacy.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // API Call - Logout Other Sessions
  Future<void> _logoutOtherSessions() async {
    setState(() {
      _isLoggingOutOther = true;
    });

    try {
      final headers = await _headers();
      final response = await http.post(
        ApiConfig.uri('/api/me/logout-other-sessions'),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All other sessions logged out successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['error'] ?? 'Failed to logout other sessions.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to the server.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOutOther = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });
    await widget.onLogout();
    if (mounted) {
      setState(() {
        _isLoggingOut = false;
      });
    }
  }

  void _showLogoutOtherConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Other Sessions?'),
        content: const Text(
          'This will sign you out from all other devices and active web browsers. Your current device will remain logged in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logoutOtherSessions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout Others'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to log out of KatsKlub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2D2E30) : const Color(0x1F787878);
    final fill = isDark ? const Color(0xFF1C1E21) : const Color(0xFFF9FAFB);
    final focusColor = isDark ? const Color(0xFFFF7A45) : Colors.black;

    return InputDecoration(
      filled: true,
      fillColor: fill,
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF9CA3AF),
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: const Color(0xFF9CA3AF),
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _currentUser.avatarUrl ?? '';
    final joinedDate = _currentUser.createdAt != null
        ? DateTime.tryParse(_currentUser.createdAt!) != null
            ? '${_getMonthName(DateTime.parse(_currentUser.createdAt!).month)} ${DateTime.parse(_currentUser.createdAt!).day}, ${DateTime.parse(_currentUser.createdAt!).year}'
            : '-'
        : '-';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242526) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB);
    final scaffoldBg = isDark ? const Color(0xFF18191A) : const Color(0xFFF9FAFB);
    final textTitleColor = isDark ? Colors.white : const Color(0xFF111827);
    final textSubtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _currentUser);
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
          surfaceTintColor: isDark ? const Color(0xFF18191A) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFFFF7A45)),
            onPressed: () => Navigator.pop(context, _currentUser),
          ),
          title: Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: cardBorder),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile / Account Info Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isDark ? const Color(0xFF18191A) : Colors.blue.shade50,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(ApiConfig.assetUrl(avatarUrl))
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                _currentUser.initials,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFF7A45) : Colors.blue.shade700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textTitleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentUser.email ?? _currentUser.handle ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSubtitleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Joined $joinedDate',
                              style: TextStyle(
                                fontSize: 11,
                                color: textSubtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Account Privacy Card (private account)
                _buildSectionHeader(title: 'Account Privacy', icon: Icons.shield_outlined),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: _buildPrivacySwitch(
                    title: 'Private account',
                    subtitle:
                        'When your account is private, only people you approve can see your posts and follow you.',
                    value: _isPrivate,
                    onChanged: _isSavingPrivateAccount
                        ? (_) {}
                        : (val) => _updatePrivateAccount(val),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Privacy Settings Card
                _buildSectionHeader(title: 'Profile Privacy', icon: Icons.lock_outline_rounded),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      _buildPrivacySwitch(
                        title: 'Show email on profile',
                        subtitle: 'Allow other users to see your email address',
                        value: _showEmail,
                        onChanged: (val) => setState(() => _showEmail = val),
                      ),
                      Divider(
                        height: 24,
                        color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
                      ),
                      _buildPrivacySwitch(
                        title: 'Show phone on profile',
                        subtitle: 'Allow other users to see your phone number',
                        value: _showPhone,
                        onChanged: (val) => setState(() => _showPhone = val),
                      ),
                      Divider(
                        height: 24,
                        color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
                      ),
                      _buildPrivacySwitch(
                        title: 'Show gender on profile',
                        subtitle: 'Display your gender details on your profile page',
                        value: _showGender,
                        onChanged: (val) => setState(() => _showGender = val),
                      ),
                      Divider(
                        height: 24,
                        color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
                      ),
                      _buildPrivacySwitch(
                        title: 'Show birthday on profile',
                        subtitle: 'Allow your birth date to be displayed to others',
                        value: _showBirthday,
                        onChanged: (val) => setState(() => _showBirthday = val),
                      ),
                      Divider(
                        height: 24,
                        color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
                      ),
                      _buildPrivacySwitch(
                        title: 'Show location on profile',
                        subtitle: 'Share your city and country details publicly',
                        value: _showLocation,
                        onChanged: (val) => setState(() => _showLocation = val),
                      ),
                      Divider(
                        height: 24,
                        color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
                      ),
                      _buildPrivacySwitch(
                        title: 'Show followers list',
                        subtitle: 'Allow other users to view your followers list',
                        value: _showFollowers,
                        onChanged: (val) => setState(() => _showFollowers = val),
                      ),
                      Divider(
                        height: 24,
                        color: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
                      ),
                      _buildPrivacySwitch(
                        title: 'Show following list',
                        subtitle: 'Allow other users to view the list of people you follow',
                        value: _showFollowing,
                        onChanged: (val) => setState(() => _showFollowing = val),
                      ),
                      if (_privacyError != null) ...[
                        const SizedBox(height: 14),
                        _buildStatusBox(message: _privacyError!, isSuccess: false),
                      ],
                      if (_privacySuccess != null) ...[
                        const SizedBox(height: 14),
                        _buildStatusBox(message: _privacySuccess!, isSuccess: true),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingPrivacy ? null : _updatePrivacy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A45),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSavingPrivacy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save privacy settings', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Change Password Card
                _buildSectionHeader(title: 'Change Password', icon: Icons.vpn_key_outlined),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        style: TextStyle(color: textTitleColor),
                        decoration: _inputDecoration(
                          hintText: 'Enter current password',
                          icon: Icons.lock_open_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'New Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        style: TextStyle(color: textTitleColor),
                        decoration: _inputDecoration(
                          hintText: 'Minimum 8 characters',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Confirm New Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: textTitleColor),
                        decoration: _inputDecoration(
                          hintText: 'Repeat new password',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),
                      if (_passwordError != null) ...[
                        const SizedBox(height: 14),
                        _buildStatusBox(message: _passwordError!, isSuccess: false),
                      ],
                      if (_passwordSuccess != null) ...[
                        const SizedBox(height: 14),
                        _buildStatusBox(message: _passwordSuccess!, isSuccess: true),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingPassword ? null : _updatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A45),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSavingPassword
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save password', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Session Management Card
                _buildSectionHeader(title: 'Sessions', icon: Icons.devices_other_rounded),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep your current device active and sign out from everywhere else.',
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isLoggingOutOther ? null : _showLogoutOtherConfirm,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : const Color(0xFF374151),
                            side: BorderSide(color: isDark ? const Color(0xFF4E4F51) : const Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoggingOutOther
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.white : Colors.black54,
                                  ),
                                )
                              : const Text('Logout all other sessions', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Danger Zone / Account Deletion
                _buildSectionHeader(title: 'Danger Zone', icon: Icons.warning_amber_rounded, color: const Color(0xFFE53935)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x22EF4444) : Colors.red.shade50.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deleting your account is permanent and cannot be undone.',
                        style: TextStyle(fontSize: 13, color: Color(0xFFE53935)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: null, // Disabled / Coming soon
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            side: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Delete account (Coming Soon)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 6. Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoggingOut ? null : _showLogoutConfirm,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.logout_rounded, size: 20),
                    label: Text(_isLoggingOut ? 'Logging out...' : 'Sign Out', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon, Color? color}) {
    final effectiveColor = color ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF7A45) : Colors.black);
    return Row(
      children: [
        Icon(icon, size: 18, color: effectiveColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFFF7A45),
        ),
      ],
    );
  }

  Widget _buildStatusBox({required String message, required bool isSuccess}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    
    if (isSuccess) {
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      borderColor = const Color(0xFF10B981);
      textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);
    } else {
      bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFEF4444);
      textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
}
