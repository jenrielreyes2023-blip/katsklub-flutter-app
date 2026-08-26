import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'terms_of_use_screen.dart';
import 'privacy_policy_screen.dart';

class GoogleSignupContext {
  const GoogleSignupContext({
    required this.draftId,
    required this.email,
    required this.fullName,
    this.googleAvatarUrl,
  });

  final String draftId;
  final String email;
  final String fullName;
  final String? googleAvatarUrl;
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    required this.authService,
    required this.onSignupSuccess,
    this.googleContext,
    super.key,
  });

  final AuthService authService;
  final ValueChanged<User> onSignupSuccess;
  final GoogleSignupContext? googleContext;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{3,24}$');

  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _countryFocusNode = FocusNode();
  final _cityFocusNode = FocusNode();

  Uint8List? _avatarPreviewBytes;
  String? _avatarDataUrl;
  String? _selectedDefaultAvatarPath;
  final List<String> _defaultAvatars = const [
    'assets/images/default_avatar_cat.jpg',
    'assets/images/default_avatar_dog.jpg',
    'assets/images/default_avatar_panda.jpg',
    'assets/images/default_avatar_bunny.jpg',
  ];

  final Map<String, UsernameAvailabilityResult> _usernameCheckCache =
      <String, UsernameAvailabilityResult>{};

  Timer? _usernameDebounce;
  List<CountryOption> _countries = const <CountryOption>[];
  List<String> _cities = const <String>[];
  UsernameAvailabilityResult? _usernameAvailability;
  String? _checkedUsername;
  String? _selectedCountry;
  String? _selectedCity;
  String? _countryLoadError;
  String? _cityLoadError;
  bool _isLoading = false;
  bool _isPickingAvatar = false;
  bool _isCheckingUsername = false;
  bool _isLoadingCountries = false;
  bool _isLoadingCities = false;
  bool _didAttemptEmailContinue = false;
  bool _didAttemptFirstNameContinue = false;
  bool _didAttemptBasicInfoContinue = false;
  bool _didAttemptProfileContinue = false;
  bool _didAttemptSecurityContinue = false;
  bool _didCompleteSignup = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _inlineError;
  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedYear;
  String? _selectedGender;
  _SignupStage _stage = _SignupStage.email;
  bool _googleAvatarRemoved = false;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  String? _activeDraftId;

  bool get _isGoogleMode => widget.googleContext != null;
  bool get _isPhoneSignup {
    final val = _emailController.text.trim();
    if (val.isEmpty) return false;
    return !val.contains('@');
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value);
  }

  @override
  void initState() {
    super.initState();
    _loadCountries();

    final googleContext = widget.googleContext;
    if (googleContext != null) {
      _emailController.text = googleContext.email;
      final trimmedName = googleContext.fullName.trim();
      if (trimmedName.isNotEmpty) {
        final spaceIndex = trimmedName.indexOf(' ');
        if (spaceIndex < 0) {
          _firstNameController.text = trimmedName;
        } else {
          _firstNameController.text = trimmedName.substring(0, spaceIndex);
          _lastNameController.text =
              trimmedName.substring(spaceIndex + 1).trim();
        }
      }
      _stage = _SignupStage.name;
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _countryFocusNode.dispose();
    _cityFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_isLoading || _didCompleteSignup) {
      return;
    }

    switch (_stage) {
      case _SignupStage.email:
        await _handleEmailContinue();
        return;
      case _SignupStage.name:
        _handleNameContinue();
        return;
      case _SignupStage.basicInfo:
        _handleBasicInfoContinue();
        return;
      case _SignupStage.profile:
        await _handleProfileContinue();
        return;
      case _SignupStage.security:
        await _handleSecurityContinue();
        return;
      case _SignupStage.phone:
        await _handlePhoneContinue();
        return;
    }
  }

  Future<void> _handleEmailContinue() async {
    final email = _normalizedEmail;
    setState(() {
      _didAttemptEmailContinue = true;
      _inlineError = null;
    });

    if (_emailErrorText != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.authService.checkIdentifier(email);
      if (!mounted) {
        return;
      }

      setState(() {
        if (!result.ok) {
          _inlineError =
              result.error ?? 'Unable to continue. Please try again.';
          return;
        }

        if (result.exists) {
          _inlineError = 'This email already has an account. Please log in.';
          return;
        }

        _didAttemptFirstNameContinue = false;
        _inlineError = null;
        _stage = _SignupStage.name;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleNameContinue() {
    setState(() {
      _didAttemptFirstNameContinue = true;
      _inlineError = null;
    });

    if (_firstNameErrorText != null) {
      return;
    }

    setState(() {
      _didAttemptBasicInfoContinue = false;
      _stage = _SignupStage.basicInfo;
    });
  }

  void _handleBasicInfoContinue() {
    setState(() {
      _didAttemptBasicInfoContinue = true;
      _inlineError = null;
    });

    if (_birthdayErrorText != null || _genderErrorText != null) {
      return;
    }

    setState(() {
      _didAttemptProfileContinue = false;
      _stage = _SignupStage.profile;
    });

    if (_normalizedUsername.isEmpty) {
      unawaited(_prefillBestSuggestedUsername());
    } else {
      _scheduleUsernameCheck(immediate: true);
    }
  }

  Future<void> _handleProfileContinue() async {
    setState(() {
      _didAttemptProfileContinue = true;
      _inlineError = null;
    });

    await _syncLocationSelectionFromText();
    final usernameReady = await _ensureUsernameIsAvailable();
    if (!mounted) {
      return;
    }

    if (!usernameReady ||
        _usernameErrorText != null ||
        _countryErrorText != null ||
        _cityErrorText != null) {
      return;
    }

    setState(() {
      _didAttemptSecurityContinue = false;
      _stage = _SignupStage.security;
    });
  }

  Future<void> _handleSecurityContinue() async {
    setState(() {
      _didAttemptSecurityContinue = true;
      _inlineError = null;
    });

    if (_bioErrorText != null) {
      return;
    }
    if (!_isGoogleMode &&
        (_passwordErrorText != null || _confirmPasswordErrorText != null)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isGoogleMode) {
        final draftId = widget.googleContext!.draftId;
        String? googleAvatarUrl;
        if (!_googleAvatarRemoved && _avatarDataUrl == null) {
          googleAvatarUrl = widget.googleContext!.googleAvatarUrl;
        }

        final signupCompleteResult = await widget.authService.signupComplete(
          draftId: draftId,
          username: _normalizedUsername,
          gender: _selectedGender ?? '',
          birthday: _birthdayValue ?? '',
          location: _selectedLocation,
          fullName: _fullName,
          bio: _bioController.text.trim(),
          avatarDataUrl: _avatarDataUrl,
          googleAvatarUrl: googleAvatarUrl,
        );

        if (!mounted) return;

        if (!signupCompleteResult.ok || signupCompleteResult.user == null) {
          setState(() {
            _inlineError = signupCompleteResult.error ??
                'Unable to complete signup. Please try again.';
          });
          return;
        }

        setState(() {
          _didCompleteSignup = true;
        });

        try {
          widget.onSignupSuccess(signupCompleteResult.user!);
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _inlineError = 'Your account was created, but we could not finish signing you in.';
          });
          return;
        }
      } else {
        final signupStartResult = await widget.authService.signupStart(
          fullName: _fullName,
          email: _emailController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        );

        if (!mounted) return;

        if (!signupStartResult.ok || signupStartResult.draftId == null) {
          setState(() {
            _inlineError = signupStartResult.error ??
                'Unable to start signup. Please try again.';
          });
          return;
        }

        setState(() {
          _activeDraftId = signupStartResult.draftId;
          _stage = _SignupStage.phone;
          if (_isPhoneSignup) {
            _phoneController.text = _emailController.text.trim();
          }
        });

        // Auto-send verification code (SMS or Email)
        _sendOtp();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendOtp() async {
    final String phone;
    if (_isPhoneSignup) {
      phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        setState(() {
          _inlineError = 'Please enter your phone number.';
        });
        return;
      }
      if (!_isValidPhone(phone)) {
        setState(() {
          _inlineError = 'Gumamit ng tamang format (e.g. +639187843417).';
        });
        return;
      }
    } else {
      phone = '';
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });

    try {
      final result = await widget.authService.sendOtp(
        draftId: _activeDraftId!,
        phone: phone,
      );

      if (!mounted) return;

      if (result.ok) {
        setState(() {
          _otpSent = true;
          _inlineError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPhoneSignup
                ? 'OTP sent successfully to your phone!'
                : 'Verification code sent to your email address!'),
          ),
        );
      } else {
        setState(() {
          _inlineError = result.error ?? 'Failed to send OTP code.';
        });
      }
    } catch (e) {
      setState(() {
        _inlineError = 'Error connection. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePhoneContinue() async {
    if (_isPhoneSignup && _phoneController.text.trim().isEmpty) {
      setState(() {
        _inlineError = 'Please enter your phone number.';
      });
      return;
    }
    if (!_otpSent) {
      setState(() {
        _inlineError = 'Please wait for the code to be sent.';
      });
      return;
    }
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _inlineError = 'Please enter the verification code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });

    try {
      final signupCompleteResult = await widget.authService.signupComplete(
        draftId: _activeDraftId!,
        username: _normalizedUsername,
        gender: _selectedGender ?? '',
        birthday: _birthdayValue ?? '',
        location: _selectedLocation,
        fullName: _fullName,
        bio: _bioController.text.trim(),
        avatarDataUrl: _avatarDataUrl,
        otpCode: _otpController.text.trim(),
      );

      if (!mounted) return;

      if (!signupCompleteResult.ok || signupCompleteResult.user == null) {
        setState(() {
          _inlineError = signupCompleteResult.error ?? 'Invalid verification code or registration failed.';
        });
        return;
      }

      setState(() {
        _didCompleteSignup = true;
      });

      try {
        widget.onSignupSuccess(signupCompleteResult.user!);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _inlineError = 'Your account was created, but we could not sign you in automatically.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countryLoadError = null;
    });

    final countries = await widget.authService.loadCountries();
    if (!mounted) {
      return;
    }

    setState(() {
      _countries = countries;
      _isLoadingCountries = false;
      if (countries.isEmpty) {
        _countryLoadError = 'Unable to load countries right now.';
      }
    });
  }

  Future<void> _loadCitiesForCountry(String country) async {
    setState(() {
      _isLoadingCities = true;
      _cityLoadError = null;
      _cities = const <String>[];
      _selectedCity = null;
      _cityController.clear();
    });

    final matchedCountry = _countries.where(
      (option) => option.name.toLowerCase() == country.trim().toLowerCase(),
    );

    if (matchedCountry.isNotEmpty) {
      final localCities = matchedCountry.first.cities;
      if (mounted) {
        setState(() {
          _isLoadingCities = false;
          _cities = localCities;
          _cityLoadError = localCities.isEmpty
              ? 'No cities were available for this country yet.'
              : null;
        });
      }
      return;
    }

    final result = await widget.authService.loadCitiesForCountry(country);
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingCities = false;
      _cities = result.cities;
      _cityLoadError = result.ok ? (result.cities.isEmpty ? 'No cities were available for this country yet.' : null) : result.error;
    });
  }

  void _onUsernameChanged(String value) {
    if (_didAttemptProfileContinue || _inlineError != null) {
      setState(() {
        _inlineError = null;
      });
    }
    _scheduleUsernameCheck();
  }

  void _scheduleUsernameCheck({bool immediate = false}) {
    _usernameDebounce?.cancel();
    final username = _normalizedUsername;

    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _usernameAvailability = null;
        _checkedUsername = null;
      });
      return;
    }

    if (!_usernamePattern.hasMatch(username)) {
      setState(() {
        _isCheckingUsername = false;
        _usernameAvailability = null;
        _checkedUsername = null;
      });
      return;
    }

    final cached = _usernameCheckCache[username];
    if (cached != null) {
      setState(() {
        _isCheckingUsername = false;
        _usernameAvailability = cached;
        _checkedUsername = username;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _checkedUsername = null;
    });

    if (immediate) {
      unawaited(_checkUsernameAvailability(username));
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_checkUsernameAvailability(username));
    });
  }

  Future<bool> _ensureUsernameIsAvailable() async {
    final username = _normalizedUsername;
    if (username.isEmpty || !_usernamePattern.hasMatch(username)) {
      return false;
    }

    if (_isCheckingUsername) {
      _usernameDebounce?.cancel();
      await _checkUsernameAvailability(username);
      return _isUsernameCurrentlyAvailable;
    }

    if (_checkedUsername == username) {
      return _isUsernameCurrentlyAvailable;
    }

    await _checkUsernameAvailability(username);
    return _isUsernameCurrentlyAvailable;
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final result = await widget.authService.checkUsernameAvailability(username);
    if (!mounted || _normalizedUsername != username) {
      return;
    }

    setState(() {
      _isCheckingUsername = false;
      _checkedUsername = username;
      _usernameAvailability = result;
      _usernameCheckCache[username] = result;
    });
  }


  Future<void> _prefillBestSuggestedUsername() async {
    if (_normalizedUsername.isNotEmpty) {
      _scheduleUsernameCheck(immediate: true);
      return;
    }

    final suggestions = _usernameSuggestions;
    if (suggestions.isEmpty) {
      return;
    }

    for (final suggestion in suggestions) {
      final cached = _usernameCheckCache[suggestion];
      if (cached != null) {
        if (cached.ok && cached.available) {
          if (!mounted || _normalizedUsername.isNotEmpty) {
            return;
          }
          _applySuggestedUsername(suggestion, cachedResult: cached);
          return;
        }
        continue;
      }

      final result =
          await widget.authService.checkUsernameAvailability(suggestion);
      _usernameCheckCache[suggestion] = result;
      if (!mounted || _normalizedUsername.isNotEmpty) {
        return;
      }
      if (result.ok && result.available) {
        _applySuggestedUsername(suggestion, cachedResult: result);
        return;
      }
    }

    if (_normalizedUsername.isEmpty) {
      _selectSuggestedUsername(suggestions.first);
    }
  }

  void _applySuggestedUsername(
    String suggestion, {
    UsernameAvailabilityResult? cachedResult,
  }) {
    final result = cachedResult ?? _usernameCheckCache[suggestion];
    _usernameController
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length);
    setState(() {
      _isCheckingUsername = false;
      _checkedUsername = suggestion;
      _usernameAvailability = result;
    });
  }

  Future<void> _syncLocationSelectionFromText() async {
    final typedCountry = _countryController.text.trim();
    final countryMatch = _findCaseInsensitiveMatch(
      typedCountry,
      _countries.map((country) => country.name),
    );

    if (countryMatch != null && countryMatch != _selectedCountry) {
      _selectedCountry = countryMatch;
      _countryController.text = countryMatch;
      await _loadCitiesForCountry(countryMatch);
    }

    if (_selectedCountry == null || _cities.isEmpty) {
      return;
    }

    final typedCity = _cityController.text.trim();
    final cityMatch = _findCaseInsensitiveMatch(typedCity, _cities);
    if (cityMatch != null) {
      _selectedCity = cityMatch;
      _cityController.text = cityMatch;
    }
  }

  String? _findCaseInsensitiveMatch(String value, Iterable<String> options) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final option in options) {
      if (option.toLowerCase() == normalized) {
        return option;
      }
    }
    return null;
  }

  void _selectSuggestedUsername(String suggestion) {
    _usernameController
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length);
    final cached = _usernameCheckCache[suggestion];
    if (cached != null) {
      setState(() {
        _isCheckingUsername = false;
        _checkedUsername = suggestion;
        _usernameAvailability = cached;
      });
      return;
    }
    _scheduleUsernameCheck(immediate: true);
  }

  void _handleCountryChanged(String value) {
    final matchesSelected = _selectedCountry != null &&
        _selectedCountry!.toLowerCase() == value.trim().toLowerCase();
    if (matchesSelected) {
      return;
    }

    setState(() {
      _inlineError = null;
      _selectedCountry = null;
      _selectedCity = null;
      _cities = const <String>[];
      _cityController.clear();
      _cityLoadError = null;
    });
  }

  void _handleCountrySelected(String country) {
    setState(() {
      _inlineError = null;
      _selectedCountry = country;
      _countryController.text = country;
    });
    unawaited(_loadCitiesForCountry(country));
  }

  void _handleCityChanged(String value) {
    final matchesSelected = _selectedCity != null &&
        _selectedCity!.toLowerCase() == value.trim().toLowerCase();
    if (matchesSelected) {
      return;
    }

    setState(() {
      _inlineError = null;
      _selectedCity = null;
    });
  }

  void _handleCitySelected(String city) {
    setState(() {
      _inlineError = null;
      _selectedCity = city;
      _cityController.text = city;
    });
  }

  Future<void> _pickAvatar() async {
    if (_isLoading || _didCompleteSignup || _isPickingAvatar) {
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF4E4F50) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: <Widget>[
                      _AvatarSourceRow(
                        icon: Icons.photo_camera_outlined,
                        label: 'Take photo',
                        onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF3E4042) : const Color(0xFFE5E7EB),
                      ),
                      _AvatarSourceRow(
                        icon: Icons.photo_library_outlined,
                        label: 'Choose from gallery',
                        onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    setState(() {
      _isPickingAvatar = true;
      _inlineError = null;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2200,
        maxHeight: 2200,
      );

      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }

      final result = await Navigator.of(context).push<_SignupAvatarResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _SignupAvatarEditorScreen(imageBytes: bytes),
        ),
      );

      if (!mounted || result == null) {
        return;
      }

      setState(() {
        _avatarPreviewBytes = result.previewBytes;
        _avatarDataUrl = result.dataUrl;
        _selectedDefaultAvatarPath = null;
        _googleAvatarRemoved = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _inlineError =
            'Unable to load that photo right now. Please try another image.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAvatar = false;
        });
      }
    }
  }

  Future<void> _selectDefaultAvatar(String assetPath) async {
    if (_isLoading || _didCompleteSignup) return;
    setState(() {
      _isPickingAvatar = true;
      _inlineError = null;
    });
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _avatarPreviewBytes = bytes;
        _avatarDataUrl = dataUrl;
        _selectedDefaultAvatarPath = assetPath;
        _googleAvatarRemoved = false;
      });
    } catch (e) {
      setState(() {
        _inlineError = 'Failed to load default avatar.';
      });
    } finally {
      setState(() {
        _isPickingAvatar = false;
      });
    }
  }

  void _removeAvatar() {
    setState(() {
      _avatarPreviewBytes = null;
      _avatarDataUrl = null;
      _selectedDefaultAvatarPath = null;
      if (_isGoogleMode) {
        _googleAvatarRemoved = true;
      }
    });
  }

  void _suggestStrongPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final random = math.Random.secure();
    final password = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = password;
      _confirmPasswordController.text = password;
      _obscurePassword = false;
      _obscureConfirmPassword = false;
      _inlineError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Suggested password: $password'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: password));
          },
        ),
      ),
    );
  }

  String _normalizeSuggestionBase(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  List<String> get _usernameSuggestions {
    final first = _normalizeSuggestionBase(_firstNameController.text);
    final last = _normalizeSuggestionBase(_lastNameController.text);
    final emailBase = _normalizeSuggestionBase(
      _normalizedEmail.split('@').isNotEmpty ? _normalizedEmail.split('@').first : '',
    );
    final year = DateTime.now().year;
    final candidates = <String>[
      if (first.isNotEmpty) first,
      if (first.isNotEmpty && last.isNotEmpty) '${first}_$last',
      if (first.isNotEmpty && last.isNotEmpty) '$first$last',
      if (first.isNotEmpty && last.isNotEmpty) '${first}_${last[0]}',
      if (first.isNotEmpty) '${first}_$year',
      if (emailBase.isNotEmpty) emailBase,
      if (emailBase.isNotEmpty) '${emailBase}_$year',
      if (first.isNotEmpty && last.isNotEmpty) '$first${year.toString().substring(2)}',
    ];

    final results = <String>[];
    for (final candidate in candidates) {
      if (_usernamePattern.hasMatch(candidate) && !results.contains(candidate)) {
        results.add(candidate);
      }
      if (results.length == 5) {
        break;
      }
    }
    return results;
  }

  String get _normalizedEmail => _emailController.text.trim().toLowerCase();

  String get _normalizedUsername =>
      _usernameController.text.trim().toLowerCase();

  String get _fullName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    return last.isEmpty ? first : '$first $last';
  }

  String get _selectedLocation {
    if (_selectedCountry == null || _selectedCity == null) {
      return '';
    }
    return '$_selectedCity, $_selectedCountry';
  }

  bool get _isUsernameCurrentlyAvailable {
    final username = _normalizedUsername;
    return _checkedUsername == username &&
        _usernameAvailability != null &&
        _usernameAvailability!.ok &&
        _usernameAvailability!.available;
  }

  int get _currentProgressStep {
    switch (_stage) {
      case _SignupStage.email:
        return 0;
      case _SignupStage.name:
        return 1;
      case _SignupStage.basicInfo:
        return 2;
      case _SignupStage.profile:
        return 3;
      case _SignupStage.security:
        return 4;
      case _SignupStage.phone:
        return 5;
    }
  }

  double get _progressValue => _currentProgressStep / 5;

  bool get _showOnboarding => _stage != _SignupStage.email;

  String get _buttonText {
    if (_stage == _SignupStage.email) {
      return 'Continue';
    }
    if (_stage == _SignupStage.security) {
      return _isGoogleMode ? 'Complete signup' : 'Continue to Verification';
    }
    if (_stage == _SignupStage.phone) {
      return 'Verify & Complete';
    }
    return 'Continue';
  }

  List<String> get _months => const <String>[
        'Month',
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
        'December',
      ];

  List<String> get _days =>
      List<String>.generate(32, (index) => index == 0 ? 'Day' : '$index');

  List<String> get _years {
    final currentYear = DateTime.now().year;
    return List<String>.generate(
      121,
      (index) => index == 0 ? 'Year' : '${currentYear - index + 1}',
    );
  }

  bool _isValidEmail(String value) {
    return _emailPattern.hasMatch(value);
  }

  String? get _emailErrorText {
    final value = _emailController.text.trim();
    if (value.isEmpty) {
      return 'Enter your email or phone number.';
    }
    if (_isPhoneSignup) {
      if (!_isValidPhone(value)) {
        return 'Enter a valid phone number (e.g. +639187843417).';
      }
    } else {
      if (!_isValidEmail(value)) {
        return 'Enter a valid email address.';
      }
    }
    return null;
  }

  String? get _firstNameErrorText {
    if (_firstNameController.text.trim().isEmpty) {
      return 'Enter your first name.';
    }
    return null;
  }

  String? get _birthdayErrorText {
    if (_birthdayValue == null) {
      return 'Enter your date of birth.';
    }
    return null;
  }

  String? get _genderErrorText {
    if ((_selectedGender ?? '').isEmpty) {
      return 'Select your gender.';
    }
    return null;
  }

  String? get _usernameErrorText {
    final username = _normalizedUsername;
    if (username.isEmpty) {
      return 'Enter a username.';
    }
    if (!_usernamePattern.hasMatch(username)) {
      return 'Use 3-24 lowercase letters, numbers, or underscores.';
    }
    if (_isCheckingUsername) {
      return 'Checking username availability.';
    }
    if (_checkedUsername != username) {
      return 'Choose an available username.';
    }
    if (_usernameAvailability == null) {
      return 'Choose an available username.';
    }
    if (!_usernameAvailability!.ok) {
      return _usernameAvailability!.error ?? 'Unable to verify username right now.';
    }
    if (!_usernameAvailability!.available) {
      return _usernameAvailability!.reason ?? 'This username is not available.';
    }
    return null;
  }

  String? get _countryErrorText {
    if (_selectedCountry != null) {
      return null;
    }
    if (_countryLoadError != null && _countries.isEmpty) {
      return _countryLoadError;
    }
    return 'Select your country.';
  }

  String? get _cityErrorText {
    if (_selectedCountry == null) {
      return 'Select your country first.';
    }
    if (_isLoadingCities) {
      return 'Loading cities.';
    }
    if (_selectedCity != null) {
      return null;
    }
    if (_cityLoadError != null && _cities.isEmpty) {
      return _cityLoadError;
    }
    return 'Select your city.';
  }

  String? get _bioErrorText {
    if (_bioController.text.length > 280) {
      return 'Bio must be 280 characters or less.';
    }
    return null;
  }

  String? get _passwordErrorText {
    if (_passwordController.text.isEmpty) {
      return 'Enter a password.';
    }
    return null;
  }

  String? get _confirmPasswordErrorText {
    if (_confirmPasswordController.text.isEmpty) {
      return 'Confirm your password.';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  String? get _birthdayValue {
    final yearLabel = _selectedYear;
    final monthLabel = _selectedMonth;
    final dayLabel = _selectedDay;
    if (yearLabel == null || monthLabel == null || dayLabel == null) {
      return null;
    }

    final year = int.tryParse(yearLabel);
    final month = _monthNumber(monthLabel);
    final day = int.tryParse(dayLabel);
    if (year == null || month == null || day == null) {
      return null;
    }

    final parsed = DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }

    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  int? _monthNumber(String value) {
    final index = _months.indexOf(value);
    if (index <= 0) {
      return null;
    }
    return index;
  }

  _FieldStatus? get _usernameStatus {
    final username = _normalizedUsername;
    if (username.isEmpty) {
      return null;
    }
    if (!_usernamePattern.hasMatch(username)) {
      return const _FieldStatus(
        message: 'Use 3-24 lowercase letters, numbers, or underscores.',
        color: Color(0xFFDC2626),
      );
    }
    if (_isCheckingUsername) {
      return const _FieldStatus(
        message: 'Checking availability...',
        color: Color(0xFF6C7174),
      );
    }
    if (_checkedUsername != username || _usernameAvailability == null) {
      return null;
    }
    if (!_usernameAvailability!.ok) {
      return _FieldStatus(
        message: _usernameAvailability!.error ?? 'Unable to verify username right now.',
        color: const Color(0xFFD97706),
      );
    }
    if (_usernameAvailability!.available) {
      return const _FieldStatus(
        message: 'Username available',
        color: Color(0xFF16A34A),
      );
    }
    return _FieldStatus(
      message: _usernameAvailability!.reason ?? 'This username is not available.',
      color: const Color(0xFFDC2626),
    );
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
      prefixStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: iconColor,
      ),
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

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);

    return Column(
      children: <Widget>[
        SvgPicture.asset(
          isDark ? 'assets/images/kb.svg' : 'assets/images/kb_light.svg',
          height: 56,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 22),
        Text(
          _showOnboarding ? "You're almost there!" : "Create an account",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _showOnboarding
              ? "Your account is almost ready, all that's left is to tell us a little about yourself"
              : "Join us, it's easy and fast.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5.sp,
            color: secondaryText,
          ),
        ),
        if (_showOnboarding) ...<Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Signing up $_currentProgressStep/4',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 4,
              color: const Color(0xFFE5E7EB),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _progressValue,
                  child: Container(color: const Color(0xFFFF7A59)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 18),
        TextFormField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_isLoading) {
              _handleContinue();
            }
          },
          onChanged: (_) {
            setState(() {
              if (_didAttemptEmailContinue || _inlineError != null) {
                _inlineError = null;
              }
            });
          },
          style: TextStyle(
            fontSize: 12.5.sp,
            color: primaryText,
          ),
          decoration: _inputDecoration(
            hintText: 'Email address or Phone number (e.g. +63...)',
            prefixWidget: _isPhoneSignup ? null : _userSvgIcon(secondaryText),
            icon: _isPhoneSignup ? Icons.phone_android_outlined : null,
          ).copyWith(
            errorText: _didAttemptEmailContinue ? _emailErrorText : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameSuggestions() {
    final suggestions = _usernameSuggestions
        .where((suggestion) => suggestion != _normalizedUsername)
        .toList();
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Text(
              'Suggestions',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1419),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tap one to use it',
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF6C7174),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((suggestion) {
            final cached = _usernameCheckCache[suggestion];
            final isAvailable = cached?.ok == true && cached?.available == true;
            final isUnavailable = cached?.ok == true && cached?.available == false;
            return InkWell(
              onTap: _isLoading ? null : () => _selectSuggestedUsername(suggestion),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFFF0FDF4)
                      : isUnavailable
                          ? const Color(0xFFFAFAFA)
                          : const Color(0xFFF3F4F7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isAvailable
                        ? const Color(0xFFBBF7D0)
                        : isUnavailable
                            ? const Color(0xFFE5E7EB)
                            : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '@$suggestion',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isUnavailable
                            ? const Color(0xFF6C7174)
                            : const Color(0xFF0F1419),
                      ),
                    ),
                    if (isAvailable) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUsernameStatus() {
    final status = _usernameStatus;
    if (status == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Icon(
            status.color == const Color(0xFF16A34A)
                ? Icons.check_circle_outline
                : status.color == const Color(0xFFDC2626)
                    ? Icons.error_outline
                    : Icons.info_outline,
            size: 16,
            color: status.color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status.message,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: status.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMeta({required String message, required bool isError}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12.sp,
          color: isError ? const Color(0xFFDC2626) : const Color(0xFF6C7174),
        ),
      ),
    );
  }

  Widget _buildOnboardingFields() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);
    const brandOrange = Color(0xFFFF7A59);

    final Widget currentStepFields;
    switch (_stage) {
      case _SignupStage.email:
        currentStepFields = const SizedBox.shrink();
        break;
      case _SignupStage.name:
        currentStepFields = Column(
          key: const ValueKey(_SignupStage.name),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _firstNameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _handleContinue();
                }
              },
              onChanged: (_) {
                if (_didAttemptFirstNameContinue || _inlineError != null) {
                  setState(() {
                    _inlineError = null;
                  });
                }
              },
              style: TextStyle(
                fontSize: 12.5.sp,
                color: primaryText,
              ),
              decoration: _inputDecoration(
                hintText: 'What is your name?',
              ).copyWith(
                errorText:
                    _didAttemptFirstNameContinue ? _firstNameErrorText : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _handleContinue();
                }
              },
              onChanged: (_) {
                if (_inlineError != null) {
                  setState(() {
                    _inlineError = null;
                  });
                }
              },
              style: TextStyle(
                fontSize: 12.5.sp,
                color: primaryText,
              ),
              decoration: _inputDecoration(
                hintText: 'Last name (Optional)',
              ),
            ),
          ],
        );
        break;
      case _SignupStage.basicInfo:
        currentStepFields = Column(
          key: const ValueKey(_SignupStage.basicInfo),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Date of birth',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DropdownField(
                    value: _selectedMonth,
                    items: _months,
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value;
                        _inlineError = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DropdownField(
                    value: _selectedDay,
                    items: _days,
                    onChanged: (value) {
                      setState(() {
                        _selectedDay = value;
                        _inlineError = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DropdownField(
                    value: _selectedYear,
                    items: _years,
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value;
                        _inlineError = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_didAttemptBasicInfoContinue && _birthdayErrorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _birthdayErrorText!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Enter your date of birth, even if creating an account for an organization or pet.',
              style: TextStyle(
                fontSize: 12.sp,
                color: secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gender',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'male', label: Text('Male')),
                ButtonSegment<String>(value: 'female', label: Text('Female')),
              ],
              selected: _selectedGender == null
                  ? const <String>{}
                  : <String>{_selectedGender!},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedGender = selection.isEmpty ? null : selection.first;
                  _inlineError = null;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0x1F767680);
                  }
                  return isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F7);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFFF7A59);
                  }
                  return isDark ? Colors.white : const Color(0xFF0F1419);
                }),
                textStyle: WidgetStateProperty.all(
                  TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
                ),
                side: WidgetStateProperty.all(BorderSide.none),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_didAttemptBasicInfoContinue && _genderErrorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _genderErrorText!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'This information will not be made publicly available.',
              style: TextStyle(
                fontSize: 12.sp,
                color: secondaryText,
                height: 1.45,
              ),
            ),
          ],
        );
        break;
      case _SignupStage.profile:
        currentStepFields = Column(
          key: const ValueKey(_SignupStage.profile),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _usernameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _countryFocusNode.requestFocus();
                }
              },
              onChanged: _onUsernameChanged,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: primaryText,
              ),
              decoration: _inputDecoration(
                hintText: 'Choose a username',
                prefixWidget: _userSvgIcon(secondaryText),
              ).copyWith(
                prefixText: '@ ',
                prefixStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                suffixIcon: _isCheckingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                errorText: _didAttemptProfileContinue ? _usernameErrorText : null,
              ),
            ),
            _buildUsernameStatus(),
            _buildUsernameSuggestions(),
            const SizedBox(height: 12),
            _SearchSelectField(
              controller: _countryController,
              focusNode: _countryFocusNode,
              enabled: !_isLoading && !_isLoadingCountries && _countries.isNotEmpty,
              options: _countries.map((country) => country.name).toList(),
              hintText: _isLoadingCountries
                  ? 'Loading countries...'
                  : 'Choose your country',
              errorText: _didAttemptProfileContinue ? _countryErrorText : null,
              onChanged: _handleCountryChanged,
              onSelected: _handleCountrySelected,
              decoration: _inputDecoration(
                hintText: _isLoadingCountries
                    ? 'Loading countries...'
                    : 'Choose your country',
              ).copyWith(
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              ),
              trailing: _isLoadingCountries
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6C7174),
                      size: 20,
                    ),
            ),
            if (_countryLoadError != null && _countries.isEmpty)
              _buildLocationMeta(message: _countryLoadError!, isError: true),
            if (_selectedCountry != null) ...<Widget>[
              const SizedBox(height: 10),
              _SearchSelectField(
                controller: _cityController,
                focusNode: _cityFocusNode,
                enabled: !_isLoading && !_isLoadingCities && _cities.isNotEmpty,
                options: _cities,
                hintText: _isLoadingCities ? 'Loading cities...' : 'Choose your city',
                errorText: _didAttemptProfileContinue ? _cityErrorText : null,
                onChanged: _handleCityChanged,
                onSelected: _handleCitySelected,
                decoration: _inputDecoration(
                  hintText: _isLoadingCities ? 'Loading cities...' : 'Choose your city',
                ).copyWith(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                ),
                trailing: _isLoadingCities
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6C7174),
                        size: 20,
                      ),
              ),
              if (_cityLoadError != null && _cities.isEmpty)
                _buildLocationMeta(message: _cityLoadError!, isError: true),
            ],
          ],
        );
        break;
      case _SignupStage.security:
        currentStepFields = Column(
          key: const ValueKey(_SignupStage.security),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Profile photo',
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Optional. Upload one now and adjust it so your profile is ready after signup.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: secondaryText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE5E7EB),
                        ),
                        child: ClipOval(
                          child: _avatarPreviewBytes != null
                              ? Image.memory(
                                  _avatarPreviewBytes!,
                                  fit: BoxFit.cover,
                                )
                              : (_isGoogleMode &&
                                      !_googleAvatarRemoved &&
                                      (widget.googleContext!.googleAvatarUrl
                                              ?.isNotEmpty ??
                                          false))
                                  ? Image.network(
                                      widget.googleContext!.googleAvatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person_outline_rounded,
                                        size: 30,
                                        color: Color(0xFF6C7174),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline_rounded,
                                      size: 30,
                                      color: Color(0xFF6C7174),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: (_isLoading || _didCompleteSignup || _isPickingAvatar)
                                    ? null
                                    : _pickAvatar,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F1419),
                                  side: BorderSide(color: isDark ? const Color(0xFF444444) : const Color(0xFFD1D5DB)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: _isPickingAvatar
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(_avatarPreviewBytes == null ? 'Upload avatar' : 'Adjust photo'),
                              ),
                            ),
                            if (_avatarPreviewBytes != null ||
                                (_isGoogleMode &&
                                    !_googleAvatarRemoved &&
                                    (widget.googleContext!.googleAvatarUrl
                                            ?.isNotEmpty ??
                                        false))) ...<Widget>[
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: (_isLoading || _didCompleteSignup || _isPickingAvatar)
                                    ? null
                                    : _removeAvatar,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: const Color(0xFF6C7174),
                                ),
                                child: Text('Remove photo', style: TextStyle(fontSize: 12.sp)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Or choose a default avatar:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _defaultAvatars.length,
                      itemBuilder: (context, index) {
                        final path = _defaultAvatars[index];
                        final isSelected = _selectedDefaultAvatarPath == path;
                        return GestureDetector(
                          onTap: () => _selectDefaultAvatar(path),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? brandOrange : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: ClipOval(
                                child: Image.asset(
                                  path,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    enabled: !_isLoading && !_didCompleteSignup,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 280,
                    onChanged: (_) {
                      setState(() {
                        _inlineError = null;
                      });
                    },
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: primaryText,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'Tell people a little about yourself',
                    ).copyWith(
                      counterText: '${_bioController.text.length}/280',
                      counterStyle: TextStyle(fontSize: 11.5.sp),
                      errorText: _didAttemptSecurityContinue ? _bioErrorText : null,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isGoogleMode) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading && !_didCompleteSignup,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_didAttemptSecurityContinue || _inlineError != null) {
                  setState(() {
                    _inlineError = null;
                  });
                }
              },
              style: TextStyle(
                fontSize: 12.5.sp,
                color: primaryText,
              ),
              decoration: _inputDecoration(
                hintText: 'Create a password',
                prefixWidget: _passwordSvgIcon(secondaryText),
                suffixIcon: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _isLoading || _didCompleteSignup
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
              ).copyWith(
                errorText: _didAttemptSecurityContinue ? _passwordErrorText : null,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmPasswordController,
              enabled: !_isLoading && !_didCompleteSignup,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_isLoading && !_didCompleteSignup) {
                  _handleContinue();
                }
              },
              onChanged: (_) {
                if (_didAttemptSecurityContinue || _inlineError != null) {
                  setState(() {
                    _inlineError = null;
                  });
                }
              },
              style: TextStyle(
                fontSize: 12.5.sp,
                color: primaryText,
              ),
              decoration: _inputDecoration(
                hintText: 'Confirm your password',
                prefixWidget: _passwordSvgIcon(secondaryText),
                suffixIcon: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _isLoading || _didCompleteSignup
                      ? null
                      : () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: secondaryText,
                    size: 18.sp,
                  ),
                ),
              ).copyWith(
                errorText: _didAttemptSecurityContinue
                    ? _confirmPasswordErrorText
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isLoading || _didCompleteSignup
                    ? null
                    : _suggestStrongPassword,
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text('Suggest strong password', style: TextStyle(fontSize: 12.5.sp)),
                style: TextButton.styleFrom(
                  foregroundColor: brandOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            ],
          ],
        );
        break;
      case _SignupStage.phone:
        currentStepFields = Column(
          key: const ValueKey(_SignupStage.phone),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isPhoneSignup ? 'Verify your phone number' : 'Verify your email address',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isPhoneSignup
                  ? 'We will send an SMS OTP verification code to secure your account.'
                  : 'We have sent a verification code to ${_emailController.text.trim()} to secure your account.',
              style: TextStyle(
                fontSize: 12.sp,
                color: secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            if (_isPhoneSignup) ...[
              TextFormField(
                controller: _phoneController,
                enabled: !_isLoading && !_didCompleteSignup && !_otpSent,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 12.5.sp, color: primaryText),
                decoration: _inputDecoration(
                  hintText: 'Enter phone number (e.g. +639187843417)',
                  icon: Icons.phone_android_rounded,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!_otpSent) ...[
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _sendOtp,
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
                      : Text(_isPhoneSignup ? 'Send Verification Code' : 'Send Code to Email'),
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _otpController,
                enabled: !_isLoading && !_didCompleteSignup,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(fontSize: 13.5.sp, color: primaryText),
                decoration: _inputDecoration(
                  hintText: 'Enter 6-digit verification code',
                  prefixWidget: _passwordSvgIcon(secondaryText),
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: TextButton.styleFrom(
                      foregroundColor: brandOrange,
                    ),
                    child: Text('Resend Code', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600)),
                  ),
                  if (_isPhoneSignup)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _otpSent = false;
                          _otpController.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryText,
                      ),
                      child: Text('Change Number', style: TextStyle(fontSize: 12.5.sp)),
                    ),
                ],
              ),
            ],
          ],
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: currentStepFields,
        ),
      ],
    );
  }

  Widget _buildInlineError() {
    final message = _inlineError?.trim();
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5.sp,
          color: const Color(0xFFDC2626),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTerms(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 12.sp,
              color: secondaryText,
              height: 1.45,
            ),
            children: <InlineSpan>[
              const TextSpan(
                text: 'By continuing, you agree to the terms of the main documents ',
              ),
              TextSpan(
                text: 'KatsKlub Terms of Service',
                style: TextStyle(
                  color: primaryText,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsOfUseScreen(),
                      ),
                    );
                  },
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: primaryText,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          ApiConfig.apiBaseUrl,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11.5.sp,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sfTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'SF Pro Rounded'),
    );
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);
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
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: 12),
                          _buildHeader(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _showOnboarding
                                ? _buildOnboardingFields()
                                : _buildEmailStep(),
                          ),
                          _buildInlineError(),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: (_isLoading || _didCompleteSignup)
                                  ? null
                                  : _handleContinue,
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
                                  : Text(_buttonText),
                            ),
                          ),
                          if (!_showOnboarding) ...<Widget>[
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: brandOrange,
                                textStyle: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Already have an account?'),
                            ),
                          ],
                          _buildTerms(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        'About project',
                        style: TextStyle(fontSize: 12.sp, color: secondaryText),
                      ),
                      Text('|', style: TextStyle(fontSize: 12.sp, color: secondaryText)),
                      Text(
                        'Help Center',
                        style: TextStyle(fontSize: 12.sp, color: secondaryText),
                      ),
                      Text('|', style: TextStyle(fontSize: 12.sp, color: secondaryText)),
                      Text(
                        'Terms of Use',
                        style: TextStyle(fontSize: 12.sp, color: secondaryText),
                      ),
                      Text('|', style: TextStyle(fontSize: 12.sp, color: secondaryText)),
                      Text(
                        'Privacy Policy',
                        style: TextStyle(fontSize: 12.sp, color: secondaryText),
                      ),
                    ],
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

enum _SignupStage {
  email,
  name,
  basicInfo,
  profile,
  security,
  phone,
}

class _FieldStatus {
  const _FieldStatus({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF3F4F7),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF7A59), width: 1.2),
          ),
        ),
        hint: Text(
          items.first,
          style: TextStyle(
            fontSize: 12.5.sp,
            color: isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174),
          ),
        ),
        items: items
            .skip(1)
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: isDark ? Colors.white : const Color(0xFF0F1419),
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SearchSelectField extends StatelessWidget {
  const _SearchSelectField({
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.hintText,
    required this.onSelected,
    required this.onChanged,
    required this.decoration,
    this.enabled = true,
    this.errorText,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final String hintText;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final bool enabled;
  final String? errorText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          displayStringForOption: (option) => option,
          optionsBuilder: (textEditingValue) {
            if (!enabled || options.isEmpty) {
              return const Iterable<String>.empty();
            }

            final query = textEditingValue.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? options
                : options
                    .where((option) => option.toLowerCase().contains(query))
                    .toList();
            return filtered.take(30);
          },
          onSelected: onSelected,
          fieldViewBuilder: (
            context,
            textEditingController,
            textFocusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: textFocusNode,
              enabled: enabled,
              textInputAction: TextInputAction.done,
              onChanged: onChanged,
              style: TextStyle(fontSize: 12.5.sp),
              decoration: decoration.copyWith(
                hintText: hintText,
                errorText: errorText,
                suffixIcon: trailing == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: trailing,
                      ),
              ),
            );
          },
          optionsViewBuilder: (context, onOptionSelected, filteredOptions) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final optionsList = filteredOptions.toList(growable: false);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    maxHeight: 200,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: optionsList.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final option = optionsList[index];
                      return InkWell(
                        onTap: () {
                          onOptionSelected(option);
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: isDark ? Colors.white : const Color(0xFF0F1419),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}



class _AvatarSourceRow extends StatelessWidget {
  const _AvatarSourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F1419);
    final chevronColor = isDark ? const Color(0xFF8E9598) : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18.sp, color: primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: chevronColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupAvatarResult {
  const _SignupAvatarResult({
    required this.previewBytes,
    required this.dataUrl,
  });

  final Uint8List previewBytes;
  final String dataUrl;
}

class _SignupAvatarEditorScreen extends StatefulWidget {
  const _SignupAvatarEditorScreen({
    required this.imageBytes,
  });

  final Uint8List imageBytes;

  @override
  State<_SignupAvatarEditorScreen> createState() =>
      _SignupAvatarEditorScreenState();
}

class _SignupAvatarEditorScreenState extends State<_SignupAvatarEditorScreen> {
  static const double _avatarSize = 280;

  final GlobalKey _canvasKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  bool _isSaving = false;

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
    setState(() {});
  }

  Future<void> _saveAvatar() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final boundary =
          _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Avatar canvas not ready.');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to prepare avatar.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        format: CompressFormat.jpeg,
        quality: 88,
        minWidth: 600,
        minHeight: 600,
      );
      final outputBytes =
          compressedBytes.isEmpty ? pngBytes : Uint8List.fromList(compressedBytes);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(outputBytes)}';

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        _SignupAvatarResult(previewBytes: outputBytes, dataUrl: dataUrl),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save avatar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF18191A) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F1419);
    final secondaryText = isDark ? const Color(0xFF8E9598) : const Color(0xFF6C7174);
    final outlineColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFD1D5DB);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, color: primaryText),
        ),
        title: Text(
          'Adjust avatar',
          style: TextStyle(
            color: primaryText,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : _resetTransform,
            child: Text(
              'Reset',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveAvatar,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Use',
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: <Widget>[
              Text(
                'Pinch to zoom and drag to position your profile photo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The photo inside the circle is what will be saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: secondaryText.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: _avatarSize,
                    height: _avatarSize,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        RepaintBoundary(
                          key: _canvasKey,
                          child: SizedBox(
                            width: _avatarSize,
                            height: _avatarSize,
                            child: ClipRect(
                              clipBehavior: Clip.hardEdge,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  ColoredBox(
                                    color: isDark ? const Color(0xFF242526) : const Color(0xFFF3F4F7),
                                  ),
                                  InteractiveViewer(
                                    transformationController:
                                        _transformController,
                                    minScale: 1.0,
                                    maxScale: 4.5,
                                    boundaryMargin: const EdgeInsets.all(140),
                                    clipBehavior: Clip.none,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.cover,
                                      width: _avatarSize,
                                      height: _avatarSize,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            size: const Size(_avatarSize, _avatarSize),
                            painter: const _CircleMaskPainter(
                              circleRadius: _avatarSize / 2,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Container(
                            width: _avatarSize,
                            height: _avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _resetTransform,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryText,
                        side: BorderSide(color: outlineColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size.fromHeight(48),
                        textStyle: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveAvatar,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A59),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save avatar'),
                      ),
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
}

class _CircleMaskPainter extends CustomPainter {
  const _CircleMaskPainter({required this.circleRadius});
  final double circleRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addOval(Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: circleRadius,
    ));
    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) {
    return oldDelegate.circleRadius != circleRadius;
  }
}
