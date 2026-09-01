import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authService,
    required this.onLoginSuccess,
    super.key,
  });

  final AuthService authService;
  final ValueChanged<User> onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    serverClientId: AuthService.googleWebClientId,
  );

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showPasswordStep = false;
  bool _rememberMe = true;
  String? _errorMessage;
  String? _checkedIdentifier;
  bool _isPhoneLogin = false;
  bool _phoneOtpSent = false;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_handleIdentifierChanged);
  }

  void _handleIdentifierChanged() {
    final normalizedIdentifier = _normalizeIdentifier(_identifierController.text);
    if (_showPasswordStep && normalizedIdentifier != (_checkedIdentifier ?? '')) {
      setState(() {
        _showPasswordStep = false;
        _checkedIdentifier = null;
        _passwordController.clear();
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _identifierController.removeListener(_handleIdentifierChanged);
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _normalizeIdentifier(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _handleContinue() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_isPhoneLogin) {
      if (_phoneOtpSent) {
        await _submitPhoneLogin();
      } else {
        await _sendLoginOtp();
      }
      return;
    }

    if (_showPasswordStep) {
      await _submitLogin();
      return;
    }

    await _checkIdentifier();
  }

  Future<void> _checkIdentifier() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.authService.checkIdentifier(_identifierController.text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.statusCode == 429) {
        _errorMessage = 'Too many login attempts. Try again in 15 minutes.';
        _showPasswordStep = false;
        _checkedIdentifier = null;
        _passwordController.clear();
      } else if (result.ok && result.exists) {
        _showPasswordStep = true;
        _checkedIdentifier = _normalizeIdentifier(_identifierController.text);
        _errorMessage = null;
      } else if (result.ok && !result.exists) {
        _errorMessage = 'These credentials do not match our records.';
        _showPasswordStep = false;
        _checkedIdentifier = null;
        _passwordController.clear();
      } else {
        _errorMessage = result.error ?? 'Unable to continue. Please try again.';
        _showPasswordStep = false;
        _checkedIdentifier = null;
        _passwordController.clear();
      }
    });
  }

  Future<void> _handleContinueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    GoogleSignInAccount? account;
    try {
      // Force a fresh picker each time so the user can switch accounts.
      await _googleSignIn.signOut();
      account = await _googleSignIn.signIn();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-in failed. Please try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    if (account == null) {
      // User cancelled the picker.
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (!mounted) return;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Google did not return an ID token. Please try again.';
      });
      return;
    }

    final result =
        await widget.authService.exchangeGoogleIdToken(idToken: idToken);
    if (!mounted) return;

    if (result.ok && result.user != null) {
      setState(() {
        _isLoading = false;
      });
      widget.onLoginSuccess(result.user!);
      return;
    }

    if (result.ok &&
        result.needsSignup &&
        result.draftId != null &&
        result.draftId!.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SignupScreen(
            authService: widget.authService,
            onSignupSuccess: widget.onLoginSuccess,
            googleContext: GoogleSignupContext(
              draftId: result.draftId!,
              email: result.googleEmail ?? '',
              fullName: result.googleFullName ?? '',
              googleAvatarUrl: result.googleAvatarUrl,
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage =
          result.error ?? 'Google sign-in failed. Please try again.';
    });
  }

  Future<void> _submitLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.authService.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
      persistSession: _rememberMe,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.statusCode == 429) {
        _errorMessage = 'Too many login attempts. Try again in 15 minutes.';
      } else if (result.statusCode == 401) {
        _errorMessage = 'These credentials do not match our records.';
        _passwordController.clear();
      } else {
        _errorMessage = result.error;
      }
    });

    if (result.ok && result.user != null) {
      widget.onLoginSuccess(result.user!);
    }
  }

  Future<void> _sendLoginOtp() async {
    final phone = _identifierController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number.';
      });
      return;
    }
    if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone)) {
      setState(() {
        _errorMessage = 'Gumamit ng E.164 format (e.g. +639187843417).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.sendLoginOtp(phone: phone);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result.ok) {
          _phoneOtpSent = true;
          _errorMessage = null;
        } else {
          _errorMessage = result.error ?? 'Failed to send OTP code.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to connect to KatsKlub. Check your connection.';
        });
      }
    }
  }

  Future<void> _submitPhoneLogin() async {
    final phone = _identifierController.text.trim();
    final otpCode = _otpController.text.trim();

    if (otpCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.verifyLoginOtp(
        phone: phone,
        otpCode: otpCode,
        persistSession: _rememberMe,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result.ok && result.user != null) {
          widget.onLoginSuccess(result.user!);
        } else {
          _errorMessage = result.error ?? 'Invalid verification code.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection error. Please try again.';
        });
      }
    }
  }

  Widget _userSvgIcon(Color color, {double size = 18}) {
    final hex = '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    return SvgPicture.string(
      '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 12c2.7614.0 5-2.23858 5-5 0-2.76142-2.2386-5-5-5C9.23858 2 7 4.23858 7 7c0 2.76142 2.23858 5 5 5z" stroke="$hex" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M20.5901 22c0-3.87-3.8499-7-8.5899-7-4.74005.0-8.59004 3.13-8.59004 7" stroke="$hex" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>''',
      width: size,
      height: size,
    );
  }

  Widget _passwordSvgIcon(Color color, {double size = 18}) {
    final hex = '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    return SvgPicture.string(
      '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M18.25 7c0 .69036-.5596 1.25-1.25 1.25S15.75 7.69036 15.75 7 16.3096 5.75 17 5.75s1.25.55964 1.25 1.25z" fill="$hex"/><path d="M15.5 2.04999c-3.6143.0-6.55005 2.93578-6.55005 6.55C8.94995 8.9872 9.00013 9.36035 9.06042 9.704 9.07822 9.80547 9.04566 9.89362 8.99119 9.94809L2.75541 16.1839C2.23968 16.6996 1.94995 17.3991 1.94995 18.1284V20.3c0 .9665.7835 1.75 1.75 1.75h2.5c.9665.0 1.75-.7835 1.75-1.75V19.05h1.75C10.3903 19.05 10.95 18.4903 10.95 17.8V16.05H12.7C13.3748 16.05 13.9248 15.5151 13.9491 14.8462 14.4458 14.974 14.9696 15.05 15.5 15.05c3.6142.0 6.5499-2.9358 6.5499-6.55001.0-3.63115-2.9529-6.45-6.5499-6.45zm-5.05 6.55c0-2.78579 2.2642-5.05 5.05-5.05 2.8029.0 5.0499 2.18115 5.0499 4.95.0 2.78581-2.2642 5.05001-5.0499 5.05001C14.8206 13.55 14.1213 13.3789 13.4954 13.1106 13.2637 13.0113 12.9976 13.0351 12.7871 13.1739 12.5766 13.3126 12.45 13.5479 12.45 13.8v.75H10.7C10.0096 14.55 9.44995 15.1096 9.44995 15.8v1.75h-1.75c-.69036.0-1.25.5596-1.25 1.25v1.5c0 .138099999999998-.11193.25-.25.25h-2.5c-.13807.0-.25-.111900000000002-.25-.25V18.1284C3.44995 17.7969 3.58165 17.479 3.81607 17.2445l6.23573-6.2358C10.4702 10.5904 10.6356 10.002 10.5379 9.44479 10.4842 9.13883 10.45 8.86239 10.45 8.59999z" fill="$hex"/></svg>''',
      width: size,
      height: size,
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? icon,
    Widget? prefixWidget,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0x1F787878);
    final iconColor = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);
    final prefix = prefixWidget ??
        (icon != null
            ? Icon(
                icon,
                size: 17.sp,
                color: iconColor,
              )
            : null);
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF3F4F7),
      isDense: true,
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 12.sp,
        color: iconColor,
      ),
      prefixIcon: prefix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: prefix,
            ),
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFF7A59), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sfTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'SF Pro Rounded'),
    );
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);
    final outlineColor = isDark ? const Color(0x2DFFFFFF) : const Color(0x1F787878);
    const brandOrange = Color(0xFFFF7A59);
    final scaffoldBg = isDark ? const Color(0xFF18191A) : Colors.white;

    return Theme(
      data: sfTheme,
      child: Scaffold(
        backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            Center(
                              child: SvgPicture.asset(
                                isDark ? 'assets/images/kb.svg' : 'assets/images/kb_light.svg',
                                height: 84,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to continue to your klub.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                color: secondaryText,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (_isPhoneLogin) ...[
                              TextFormField(
                                controller: _identifierController,
                                enabled: !_isLoading && !_phoneOtpSent,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) {
                                    _handleContinue();
                                  }
                                },
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: primaryText,
                                ),
                                decoration: _inputDecoration(
                                  hintText: 'Phone number (e.g. +639187843417)',
                                  icon: Icons.phone_android_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your phone number.';
                                  }
                                  return null;
                                },
                              ),
                              if (_phoneOtpSent) ...[
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _otpController,
                                  enabled: !_isLoading,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  style: TextStyle(
                                    fontSize: 13.5.sp,
                                    color: primaryText,
                                  ),
                                  decoration: _inputDecoration(
                                    hintText: 'Enter 6-digit OTP code',
                                    prefixWidget: _passwordSvgIcon(secondaryText),
                                  ).copyWith(counterText: ''),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter the OTP code.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: _isLoading ? null : _sendLoginOtp,
                                      style: TextButton.styleFrom(
                                        foregroundColor: brandOrange,
                                      ),
                                      child: Text(
                                        'Resend Code',
                                        style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _phoneOtpSent = false;
                                          _otpController.clear();
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: secondaryText,
                                      ),
                                      child: Text(
                                        'Change Number',
                                        style: TextStyle(fontSize: 12.5.sp),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ] else ...[
                              TextFormField(
                                controller: _identifierController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                textInputAction:
                                    _showPasswordStep ? TextInputAction.next : TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) {
                                    _handleContinue();
                                  }
                                },
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: primaryText,
                                ),
                                decoration: _inputDecoration(
                                  hintText: 'Username, Email, or Phone number',
                                  prefixWidget: _userSvgIcon(secondaryText),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your username, email, or phone number.';
                                  }
                                  return null;
                                },
                              ),
                              if (_showPasswordStep) ...[
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !_isLoading,
                                  obscureText: _obscurePassword,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) {
                                      _handleContinue();
                                    }
                                  },
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    color: primaryText,
                                  ),
                                  decoration: _inputDecoration(
                                    hintText: 'Password',
                                    prefixWidget: _passwordSvgIcon(secondaryText),
                                    suffixIcon: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: secondaryText,
                                        size: 18.sp,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_showPasswordStep && (value == null || value.isEmpty)) {
                                      return 'Enter your password.';
                                    }
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: Theme.of(context)
                                                  .scaffoldBackgroundColor,
                                              shape: const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                        top: Radius.circular(
                                                            16)),
                                              ),
                                              builder: (_) =>
                                                  _ForgotPasswordBottomSheet(
                                                authService: widget.authService,
                                                initialIdentifier:
                                                    _identifierController.text
                                                        .trim(),
                                              ),
                                            );
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: brandOrange,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      'Forgot password?',
                                      style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            if (!_isPhoneLogin || _phoneOtpSent) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Switch.adaptive(
                                    value: _rememberMe,
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _rememberMe = value;
                                            });
                                          },
                                    activeThumbColor: brandOrange,
                                    activeTrackColor: const Color(0x33FF7A59),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Remember me',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 12.5.sp,
                                      color: primaryText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                             SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleContinue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: brandOrange,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  disabledBackgroundColor: brandOrange.withValues(alpha: 0.5),
                                  disabledForegroundColor: isDark ? Colors.black54 : Colors.white60,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  elevation: 0,
                                  textStyle: TextStyle(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_isPhoneLogin
                                        ? (_phoneOtpSent ? 'Verify & Sign in' : 'Send OTP')
                                        : (_showPasswordStep ? 'Sign in' : 'Continue')),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!_isPhoneLogin && !_showPasswordStep) ...[
                              TextButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    builder: (_) => _ForgotPasswordBottomSheet(
                                      authService: widget.authService,
                                      initialIdentifier: _identifierController.text.trim(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: secondaryText,
                                  textStyle: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isPhoneLogin = !_isPhoneLogin;
                                        _phoneOtpSent = false;
                                        _errorMessage = null;
                                        _identifierController.clear();
                                        _passwordController.clear();
                                        _otpController.clear();
                                      });
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: brandOrange,
                                textStyle: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text(_isPhoneLogin
                                  ? 'Log in with Email/Username'
                                  : 'Log in with Phone Number'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleContinueWithGoogle,
                                icon: SvgPicture.string(
                                   '''<svg width="800" height="800" viewBox="-3 0 262 262" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid"><g><path d="M255.878 133.451C255.878 122.717 255.007 114.884 253.122 106.761H130.55v48.448h71.947C201.047 167.249 193.214 185.381 175.807 197.565L175.563 199.187l38.755 30.023L217.003 229.478c24.659-22.774 38.875-56.282 38.875-96.027" fill="#4285F4"/><path d="M130.55 261.1c35.248.0 64.839-11.605 86.453-31.622l-41.196-31.913C164.783 205.253 149.987 210.62 130.55 210.62c-34.523.0-63.824-22.773-74.269-54.25L54.75 156.5 14.452 187.687 13.925 189.152C35.393 231.798 79.49 261.1 130.55 261.1" fill="#34A853"/><path d="M56.281 156.37C53.525 148.247 51.93 139.543 51.93 130.55 51.93 121.556 53.525 112.853 56.136 104.73L56.063 103 15.26 71.312 13.925 71.947C5.077 89.644.0 109.517.0 130.55c0 21.033 5.077 40.905 13.925 58.602L56.281 156.37" fill="#FBBC05"/><path d="M130.55 50.479c24.514.0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798.0 130.55.0 79.49.0 35.393 29.301 13.925 71.947L56.136 104.73c10.59-31.477 39.891-54.251 74.414-54.251" fill="#EB4335"/></g></svg>''',
                                   width: 20,
                                   height: 20,
                                 ),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  foregroundColor: primaryText,
                                  side: BorderSide(color: outlineColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  textStyle: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'New to KatsKlub?',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => SignupScreen(
                                              authService: widget.authService,
                                              onSignupSuccess: widget.onLoginSuccess,
                                            ),
                                          ),
                                        );
                                      },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  foregroundColor: primaryText,
                                  side: BorderSide(color: outlineColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  textStyle: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: const Text('Create an account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _ForgotPasswordBottomSheet extends StatefulWidget {
  const _ForgotPasswordBottomSheet({
    required this.authService,
    required this.initialIdentifier,
  });

  final AuthService authService;
  final String initialIdentifier;

  @override
  State<_ForgotPasswordBottomSheet> createState() =>
      _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<_ForgotPasswordBottomSheet> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _error;
  String? _target;
  String? _method;
  bool _hasAlternative = false;
  String? _alternativeMethod;
  String? _alternativeTarget;

  @override
  void initState() {
    super.initState();
    _identifierController.text = widget.initialIdentifier;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool useAlternative = false}) async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() {
        _error = 'Please enter your email or phone number.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.authService.sendForgotPasswordOtp(
        identifier: identifier,
        useAlternative: useAlternative,
      );

      if (!mounted) return;

      if (result.ok) {
        setState(() {
          _otpSent = true;
          _method = result.method;
          _target = result.target;
          _hasAlternative = result.hasAlternative;
          _alternativeMethod = result.alternativeMethod;
          _alternativeTarget = result.alternativeTarget;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.method == 'phone'
                ? 'Verification code sent to your phone!'
                : 'Verification code sent to your email!'),
          ),
        );
      } else {
        setState(() {
          _error = result.error ?? 'Failed to send verification code.';
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Connection error. Please check your internet connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final identifier = _identifierController.text.trim();
    final code = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();

    if (code.isEmpty || newPassword.isEmpty) {
      setState(() {
        _error = 'Please fill in all fields.';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.authService.resetPassword(
        identifier: identifier,
        otpCode: code,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password updated successfully! You can now log in.')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = result.error ?? 'Failed to reset password.';
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sfTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'SF Pro Rounded'),
    );
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText =
        isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);

    return Theme(
      data: sfTheme,
      child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Password Recovery',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: primaryText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
              ),
              const SizedBox(height: 12),
            ],
            if (!_otpSent) ...[
              Text(
                'Enter the email address or phone number linked to your account to receive a verification code.',
                style: TextStyle(fontSize: 12.5.sp, color: secondaryText, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _identifierController,
                enabled: !_isLoading,
                style: TextStyle(fontSize: 12.5.sp, color: primaryText),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  labelText: 'Email or Phone Number',
                  labelStyle: TextStyle(fontSize: 12.sp, color: secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: secondaryText.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFF7A59)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A59),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Send Verification Code', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              Text(
                'A 6-digit verification code has been sent to your ${_method == 'phone' ? 'phone' : 'email'} at $_target.',
                style: TextStyle(fontSize: 12.5.sp, color: secondaryText, height: 1.4),
              ),
              if (_hasAlternative) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => _sendOtp(useAlternative: true),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF7A59),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Send to ${_alternativeMethod == 'phone' ? 'phone' : 'email'} instead ($_alternativeTarget)',
                      style: TextStyle(
                          fontSize: 12.5.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _otpController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(fontSize: 13.5.sp, color: primaryText),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  labelText: 'Verification Code',
                  labelStyle: TextStyle(fontSize: 12.sp, color: secondaryText),
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: secondaryText.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFF7A59)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                style: TextStyle(fontSize: 12.5.sp, color: primaryText),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  labelText: 'New Password',
                  labelStyle: TextStyle(fontSize: 12.sp, color: secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: secondaryText.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFFF7A59)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A59),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Reset Password', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }
}
