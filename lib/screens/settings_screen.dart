import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import 'about_screen.dart';
import 'help_center_screen.dart';
import 'terms_of_use_screen.dart';
import 'privacy_policy_screen.dart';
import 'gift_tester_screen.dart';

// Threads Inset Grouped standard tokens.
const _kSettingsBg = Color(0xFF101012);
const _kCardBg = Color(0xFF1E1E20);
const _kDivider = Color(0xFF2C2C2E);
const _kDestructive = Color(0xFFED4956);
const _kTitle = Color(0xFFFFFFFF);
const _kBody = Color(0xFFE4E6EB);
const _kSubtitle = Color(0xFF9CA3AF);
const _kAccent = Color(0xFFFF7A45);
const _kFont = 'SF Pro Rounded';

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
          backgroundColor: _kDestructive,
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
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      } else {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['error'] ?? 'Failed to logout other sessions.'),
              backgroundColor: _kDestructive,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to the server.'),
            backgroundColor: _kDestructive,
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
    _showThreadsConfirm(
      title: 'Log out other sessions?',
      message:
          'This will sign you out from all other devices and active web browsers. Your current device will stay logged in.',
      confirmLabel: 'Log Out Others',
      onConfirm: _logoutOtherSessions,
    );
  }

  void _showLogoutConfirm() {
    _showThreadsConfirm(
      title: 'Sign out?',
      message: 'Are you sure you want to sign out of KatsKlub?',
      confirmLabel: 'Sign Out',
      onConfirm: _logout,
    );
  }

  void _showThreadsConfirm({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: const Color(0x8A000000),
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? _kCardBg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? _kTitle : const Color(0xFF111827),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: isDark ? _kSubtitle : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _DialogButton(
                      label: confirmLabel,
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(dialogContext);
                        onConfirm();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? _kDivider : const Color(0xFFE5E5EA);
    final fill = isDark ? _kSettingsBg : const Color(0xFFF9FAFB);

    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: fill,
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: _kFont,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w400,
        color: isDark ? _kSubtitle : const Color(0xFF9CA3AF),
      ),
      prefixIconConstraints: BoxConstraints(minWidth: 34.w, minHeight: 32.h),
      prefixIcon: Padding(
        padding: EdgeInsets.only(left: 10.w, right: 6.w),
        child: Icon(
          icon,
          size: 15.r,
          color: isDark ? _kSubtitle : const Color(0xFF9CA3AF),
        ),
      ),
      suffixIconConstraints: BoxConstraints(minWidth: 34.w, minHeight: 32.h),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: borderColor, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: borderColor, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: const BorderSide(color: _kAccent, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _currentUser.avatarUrl ?? '';
    final parsedDate = _currentUser.createdAt != null
        ? DateTime.tryParse(_currentUser.createdAt!)
        : null;
    final joinedDate = parsedDate != null
        ? '${_getMonthName(parsedDate.month)} ${parsedDate.day}, ${parsedDate.year}'
        : '-';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? _kSettingsBg : const Color(0xFFF2F2F7);
    final dividerColor = isDark ? _kDivider : const Color(0xFFE5E5EA);
    final titleColor = isDark ? _kTitle : const Color(0xFF111827);
    final bodyColor = isDark ? _kBody : const Color(0xFF374151);
    final subtitleColor = isDark ? _kSubtitle : const Color(0xFF6B7280);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _currentUser);
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: scaffoldBg,
          surfaceTintColor: scaffoldBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18.r, color: titleColor),
            onPressed: () => Navigator.pop(context, _currentUser),
          ),
          title: Text(
            'Account settings',
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 16.5.sp,
              fontWeight: FontWeight.w600,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(0.5.h),
            child: Container(height: 0.5.h, color: dividerColor),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile info island.
                _IslandCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26.r,
                          backgroundColor: isDark
                              ? const Color(0xFF141416)
                              : const Color(0xFFE5E5EA),
                          backgroundImage: avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  ApiConfig.assetUrl(avatarUrl))
                              : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  _currentUser.initials,
                                  style: TextStyle(
                                    fontFamily: _kFont,
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _kAccent,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser.displayName,
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: titleColor,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                _currentUser.email ?? _currentUser.handle ?? '',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w400,
                                  color: subtitleColor,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Joined $joinedDate',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w400,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18.h),

                // 2. Account privacy island.
                const _SectionLabel('Account privacy'),
                SizedBox(height: 8.h),
                _IslandCard(
                  child: _PrivacySwitch(
                    title: 'Private account',
                    subtitle:
                        'Only people you approve can see your posts and follow you.',
                    value: _isPrivate,
                    onChanged: _isSavingPrivateAccount
                        ? (_) {}
                        : (val) => _updatePrivateAccount(val),
                  ),
                ),
                SizedBox(height: 18.h),

                // 3. Profile privacy island.
                const _SectionLabel('Profile privacy'),
                SizedBox(height: 8.h),
                _IslandCard(
                  child: Column(
                    children: [
                      _PrivacySwitch(
                        title: 'Show email on profile',
                        subtitle: 'Let others see your email address',
                        value: _showEmail,
                        onChanged: (val) => setState(() => _showEmail = val),
                      ),
                      const _Hairline(),
                      _PrivacySwitch(
                        title: 'Show phone on profile',
                        subtitle: 'Let others see your phone number',
                        value: _showPhone,
                        onChanged: (val) => setState(() => _showPhone = val),
                      ),
                      const _Hairline(),
                      _PrivacySwitch(
                        title: 'Show gender on profile',
                        subtitle: 'Display your gender on your profile',
                        value: _showGender,
                        onChanged: (val) => setState(() => _showGender = val),
                      ),
                      const _Hairline(),
                      _PrivacySwitch(
                        title: 'Show birthday on profile',
                        subtitle: 'Display your birth date to others',
                        value: _showBirthday,
                        onChanged: (val) => setState(() => _showBirthday = val),
                      ),
                      const _Hairline(),
                      _PrivacySwitch(
                        title: 'Show location on profile',
                        subtitle: 'Share your city and country publicly',
                        value: _showLocation,
                        onChanged: (val) => setState(() => _showLocation = val),
                      ),
                      const _Hairline(),
                      _PrivacySwitch(
                        title: 'Show followers list',
                        subtitle: 'Let others view your followers list',
                        value: _showFollowers,
                        onChanged: (val) => setState(() => _showFollowers = val),
                      ),
                      const _Hairline(),
                      _PrivacySwitch(
                        title: 'Show following list',
                        subtitle: 'Let others view who you follow',
                        value: _showFollowing,
                        onChanged: (val) => setState(() => _showFollowing = val),
                      ),
                      if (_privacyError != null) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              14.w, 10.h, 14.w, 0),
                          child: _StatusBox(
                              message: _privacyError!, isSuccess: false),
                        ),
                      ],
                      if (_privacySuccess != null) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              14.w, 10.h, 14.w, 0),
                          child: _StatusBox(
                              message: _privacySuccess!, isSuccess: true),
                        ),
                      ],
                      Padding(
                        padding: EdgeInsets.all(14.w),
                        child: _PrimaryButton(
                          label: 'Save privacy settings',
                          isLoading: _isSavingPrivacy,
                          onPressed:
                              _isSavingPrivacy ? null : _updatePrivacy,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // 4. Change password island.
                const _SectionLabel('Change password'),
                SizedBox(height: 8.h),
                _IslandCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                        child: Text(
                          'Current password',
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: bodyColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: TextField(
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrent,
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                          ),
                          decoration: _inputDecoration(
                            hintText: 'Enter current password',
                            icon: Icons.lock_open_rounded,
                            suffixIcon: IconButton(
                              padding: EdgeInsets.only(right: 8.w),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _kSubtitle,
                                size: 16.r,
                              ),
                              onPressed: () => setState(
                                  () => _obscureCurrent = !_obscureCurrent),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Text(
                          'New password',
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: bodyColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: TextField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                          ),
                          decoration: _inputDecoration(
                            hintText: 'Minimum 8 characters',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              padding: EdgeInsets.only(right: 8.w),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _kSubtitle,
                                size: 16.r,
                              ),
                              onPressed: () => setState(
                                  () => _obscureNew = !_obscureNew),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Text(
                          'Confirm new password',
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: bodyColor,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                          ),
                          decoration: _inputDecoration(
                            hintText: 'Repeat new password',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              padding: EdgeInsets.only(right: 8.w),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _kSubtitle,
                                size: 16.r,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                      ),
                      if (_passwordError != null) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
                          child: _StatusBox(
                              message: _passwordError!, isSuccess: false),
                        ),
                      ],
                      if (_passwordSuccess != null) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
                          child: _StatusBox(
                              message: _passwordSuccess!, isSuccess: true),
                        ),
                      ],
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
                        child: _PrimaryButton(
                          label: 'Save password',
                          isLoading: _isSavingPassword,
                          onPressed:
                              _isSavingPassword ? null : _updatePassword,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // 5. Sessions island.
                const _SectionLabel('Sessions'),
                SizedBox(height: 8.h),
                _IslandCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                        child: Text(
                          'Keep this device active and sign out everywhere else.',
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w400,
                            color: subtitleColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(14.w),
                        child: SizedBox(
                          width: double.infinity,
                          height: 36.h,
                          child: OutlinedButton(
                            onPressed: _isLoggingOutOther
                                ? null
                                : _showLogoutOtherConfirm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: titleColor,
                              side: BorderSide(color: dividerColor, width: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: _isLoggingOutOther
                                ? SizedBox(
                                    width: 16.r,
                                    height: 16.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: titleColor,
                                    ),
                                  )
                                : Text(
                                    'Log out all other sessions',
                                    style: TextStyle(
                                      fontFamily: _kFont,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // 6. Support & Legal island.
                const _SectionLabel('Support & legal'),
                SizedBox(height: 8.h),
                _IslandCard(
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.card_giftcard_outlined,
                        title: 'Gift animation tester',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GiftTesterScreen(),
                            ),
                          );
                        },
                      ),
                      const _Hairline(),
                      _NavRow(
                        icon: Icons.info_outline_rounded,
                        title: 'About KatsKlub',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                      const _Hairline(),
                      _NavRow(
                        icon: Icons.help_outline_rounded,
                        title: 'Help center',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const HelpCenterScreen(),
                            ),
                          );
                        },
                      ),
                      const _Hairline(),
                      _NavRow(
                        icon: Icons.gavel_outlined,
                        title: 'Terms of use',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TermsOfUseScreen(),
                            ),
                          );
                        },
                      ),
                      const _Hairline(),
                      _NavRow(
                        icon: Icons.shield_outlined,
                        title: 'Privacy policy',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // 7. Danger zone island.
                const _SectionLabel('Danger zone', isDestructive: true),
                SizedBox(height: 8.h),
                _IslandCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                        child: Text(
                          'Deleting your account is permanent and cannot be undone.',
                          style: TextStyle(
                            fontFamily: _kFont,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w400,
                            color: _kDestructive,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(14.w),
                        child: SizedBox(
                          width: double.infinity,
                          height: 36.h,
                          child: OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  _kDestructive.withValues(alpha: 0.5),
                              side: BorderSide(
                                  color: _kDestructive.withValues(
                                      alpha: 0.4),
                                  width: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: Text(
                              'Delete account (coming soon)',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),

                // 8. Sign out island.
                _IslandCard(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14.r),
                      onTap: _isLoggingOut ? null : _showLogoutConfirm,
                      splashColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE5E5EA),
                      highlightColor: isDark
                          ? const Color(0xFF252528)
                          : const Color(0xFFF2F2F7),
                      child: Container(
                        constraints: BoxConstraints(minHeight: 40.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 8.h),
                        alignment: Alignment.center,
                        child: _isLoggingOut
                            ? SizedBox(
                                width: 16.r,
                                height: 16.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kDestructive,
                                ),
                              )
                            : Text(
                                'Sign out',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: _kDestructive,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
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

/// Threads Inset Grouped island card: #1E1E20 at 14.r with subtle 0.5px border.
class _IslandCard extends StatelessWidget {
  const _IslandCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _kCardBg : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? _kDivider : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: child,
      ),
    );
  }
}

/// Small inset section label above each island.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.isDestructive = false});

  final String text;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: _kFont,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: isDestructive
              ? _kDestructive
              : (isDark ? _kSubtitle : const Color(0xFF6C6C70)),
        ),
      ),
    );
  }
}

/// 0.5 hairline divider with 14.w left inset.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 14.w),
      child: Container(
        height: 0.5.h,
        color: isDark ? _kDivider : const Color(0xFFE5E5EA),
      ),
    );
  }
}

/// Compact 44px nav row: label left (w500), chevron right.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        highlightColor: isDark ? const Color(0xFF252528) : const Color(0xFFF2F2F7),
        child: Container(
          constraints: BoxConstraints(minHeight: 44.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(
            children: [
              Icon(icon, size: 19.r, color: _kAccent),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? _kTitle : const Color(0xFF111827),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20.r, color: isDark ? _kSubtitle : const Color(0xFF8E8E93)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact 44px privacy toggle row.
class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(minHeight: 44.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? _kTitle : const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: isDark ? _kSubtitle : const Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: _kAccent,
              activeThumbColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary action button inside an island.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kAccent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 16.r,
                height: 16.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isSuccess
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF3A1418) : const Color(0xFFFEF2F2));
    final borderColor = isSuccess ? const Color(0xFF10B981) : _kDestructive;
    final textColor = isSuccess
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: _kFont,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// Dialog action button: neutral fill or destructive tint.
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutralBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final neutralFg = isDark ? Colors.white : const Color(0xFF111827);

    return SizedBox(
      height: 42.h,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor:
              isDestructive ? _kDestructive : neutralBg,
          foregroundColor: isDestructive ? Colors.white : neutralFg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _kFont,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
