import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    const borderColor = Color(0x1F787878);
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF3F4F7),
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF6C7174),
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: const Color(0xFF6C7174),
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A5CF9), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryText = Color(0xFF0F1419);
    const secondaryText = Color(0xFF6C7174);
    const outlineColor = Color(0x1F787878);
    const brandBlue = Color(0xFF4A5CF9);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 24),
                            Center(
                              child: Image.asset(
                                'assets/images/kats-logo-final.png',
                                height: 64,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Sign in to continue to your klub.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: secondaryText,
                              ),
                            ),
                            const SizedBox(height: 28),
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
                              style: const TextStyle(
                                fontSize: 14,
                                color: primaryText,
                              ),
                              decoration: _inputDecoration(
                                hintText: 'Login or Email',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your login or email.';
                                }
                                return null;
                              },
                            ),
                            if (_showPasswordStep) ...[
                              const SizedBox(height: 12),
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: primaryText,
                                ),
                                decoration: _inputDecoration(
                                  hintText: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
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
                              const SizedBox(height: 12),
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
                                    activeThumbColor: brandBlue,
                                    activeTrackColor: const Color(0x334A5CF9),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Remember me',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 14,
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleContinue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: brandBlue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: brandBlue.withValues(alpha: 0.5),
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  elevation: 0,
                                  textStyle: const TextStyle(
                                    fontSize: 15,
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
                                    : Text(_showPasswordStep ? 'Sign in' : 'Continue'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password recovery is not available in this Flutter build yet.'),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: secondaryText,
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Forgot password?'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleContinueWithGoogle,
                                icon: Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: outlineColor),
                                  ),
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4),
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryText,
                                  side: const BorderSide(color: outlineColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'New to KatsKlub?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: outlineColor, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
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
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryText,
                                  side: const BorderSide(color: outlineColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
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
                  const Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
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
    );
  }
}
