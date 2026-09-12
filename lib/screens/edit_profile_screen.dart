import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.user,
    super.key,
  });

  final User user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();

  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  
  final _countryFocusNode = FocusNode();
  final _cityFocusNode = FocusNode();

  List<CountryOption> _countries = const <CountryOption>[];
  List<String> _cities = const <String>[];
  String? _selectedCountry;
  String? _selectedCity;
  bool _isLoadingCountries = false;
  bool _isLoadingCities = false;
  String? _countryLoadError;
  String? _cityLoadError;

  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedYear;
  String? _selectedGender;

  Uint8List? _avatarPreviewBytes;
  String? _avatarDataUrl;
  String? _avatarUrl;
  String? _selectedDefaultAvatarPath;
  final List<String> _defaultAvatars = const [
    'assets/images/default_avatar_cat.jpg',
    'assets/images/default_avatar_dog.jpg',
    'assets/images/default_avatar_panda.jpg',
    'assets/images/default_avatar_bunny.jpg',
  ];

  final List<_EditableProfileLink> _profileLinks = [];

  bool _isSaving = false;
  String? _errorMessage;

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

  List<String> get _genders => const <String>[
        'Gender',
        'Male',
        'Female',
        'Non-binary',
        'Prefer not to say',
      ];

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.user.fullName ?? '';
    _bioController.text = widget.user.bio ?? '';
    _avatarUrl = widget.user.avatarUrl;

    // Parse location
    final loc = widget.user.location ?? '';
    final locParts = loc.split(',');
    if (locParts.length >= 2) {
      _selectedCity = locParts[0].trim();
      _selectedCountry = locParts.sublist(1).join(',').trim();
      _countryController.text = _selectedCountry!;
      _cityController.text = _selectedCity!;
    } else if (locParts.length == 1 && locParts[0].trim().isNotEmpty) {
      _selectedCountry = locParts[0].trim();
      _countryController.text = _selectedCountry!;
    }

    // Parse birthday into Month, Day, Year
    if (widget.user.birthday != null && widget.user.birthday!.isNotEmpty) {
      final parsed = DateTime.tryParse(widget.user.birthday!);
      if (parsed != null) {
        _selectedYear = parsed.year.toString();
        _selectedMonth = _months[parsed.month];
        _selectedDay = parsed.day.toString();
      }
    }

    // Parse gender dropdown selection
    final userGender = widget.user.gender ?? '';
    if (userGender.isNotEmpty) {
      final normalized = userGender.trim().toLowerCase();
      if (normalized == 'male') {
        _selectedGender = 'Male';
      } else if (normalized == 'female') {
        _selectedGender = 'Female';
      } else if (normalized == 'non-binary') {
        _selectedGender = 'Non-binary';
      } else if (normalized == 'prefer not to say' || normalized == 'other') {
        _selectedGender = 'Prefer not to say';
      } else {
        _selectedGender = 'Gender'; // fallback
      }
    }

    for (final link in widget.user.profileLinks) {
      _profileLinks.add(
        _EditableProfileLink(
          url: link.url,
          title: link.title,
          faviconUrl: link.faviconUrl,
        ),
      );
    }

    _loadCountries();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _countryFocusNode.dispose();
    _cityFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _countryLoadError = null;
    });

    final countries = await _authService.loadCountries();
    if (!mounted) return;

    setState(() {
      _countries = countries;
      _isLoadingCountries = false;
      if (countries.isEmpty) {
        _countryLoadError = 'Unable to load countries right now.';
      }
    });

    if (_selectedCountry != null) {
      _loadCitiesForCountry(_selectedCountry!);
    }
  }

  Future<void> _loadCitiesForCountry(String country) async {
    setState(() {
      _isLoadingCities = true;
      _cityLoadError = null;
      _cities = const <String>[];
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

    final result = await _authService.loadCitiesForCountry(country);
    if (!mounted) return;

    setState(() {
      _isLoadingCities = false;
      _cities = result.cities;
      _cityLoadError = result.ok ? (result.cities.isEmpty ? 'No cities were available for this country yet.' : null) : result.error;
    });
  }

  void _handleCountryChanged(String value) {
    if (_selectedCountry != null && _selectedCountry!.toLowerCase() != value.trim().toLowerCase()) {
      setState(() {
        _selectedCountry = null;
        _selectedCity = null;
        _cityController.clear();
        _cities = const <String>[];
      });
    }
  }

  void _handleCountrySelected(String country) {
    setState(() {
      _selectedCountry = country;
      _countryController.text = country;
    });
    _loadCitiesForCountry(country);
  }

  void _handleCityChanged(String value) {
    if (_selectedCity != null && _selectedCity!.toLowerCase() != value.trim().toLowerCase()) {
      setState(() {
        _selectedCity = null;
      });
    }
  }

  void _handleCitySelected(String city) {
    setState(() {
      _selectedCity = city;
      _cityController.text = city;
    });
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF141416) : const Color(0xFFF9FAFB),
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: 'SF Pro Rounded',
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
      ),
      prefixIcon: Icon(
        icon,
        size: 16.r,
        color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
      ),
      prefixIconConstraints: BoxConstraints(
        minWidth: 34.w,
        minHeight: 32.h,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: BoxConstraints(
        minWidth: 32.w,
        minHeight: 32.h,
      ),
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
        borderSide: const BorderSide(color: Color(0xFFFF7A45), width: 1.2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.5.h),
    );
  }


  Future<void> _pickAvatar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36.w,
                height: 3.5.h,
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: ColoredBox(
                  color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                  child: Column(
                    children: <Widget>[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
                          splashColor: isDark ? const Color(0xFF28282B) : const Color(0xFFE5E7EB),
                          child: Container(
                            constraints: BoxConstraints(minHeight: 42.h),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.5.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Take photo',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.photo_camera_outlined,
                                  size: 18.5.r,
                                  color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 14.w,
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
                          splashColor: isDark ? const Color(0xFF28282B) : const Color(0xFFE5E7EB),
                          child: Container(
                            constraints: BoxConstraints(minHeight: 42.h),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.5.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Choose from gallery',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 18.5.r,
                                  color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final isGif = bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
      if (isGif) {
        final isAdmin = widget.user.isAdmin == true || widget.user.username?.toLowerCase() == 'gemini';
        if (!isAdmin) {
          setState(() {
            _errorMessage = 'Only admin users are allowed to upload animated GIF avatars.';
          });
        } else {
          setState(() {
            _avatarPreviewBytes = bytes;
            _avatarDataUrl = 'data:image/gif;base64,${base64Encode(bytes)}';
            _selectedDefaultAvatarPath = null;
          });
        }
        return;
      }

      final result = await Navigator.of(context).push<_AvatarCropResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _AvatarEditorScreen(imageBytes: bytes),
        ),
      );

      if (result == null || !mounted) return;

      setState(() {
        _avatarPreviewBytes = result.previewBytes;
        _avatarDataUrl = result.dataUrl;
        _selectedDefaultAvatarPath = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to select avatar. Please try again.';
        });
      }
    }
  }

  Future<void> _selectDefaultAvatar(String assetPath) async {
    if (_isSaving) return;
    setState(() {
      _errorMessage = null;
    });
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _avatarPreviewBytes = bytes;
        _avatarDataUrl = dataUrl;
        _selectedDefaultAvatarPath = assetPath;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load default avatar.';
      });
    }
  }

  Future<void> _fetchLinkMetadata(_EditableProfileLink link) async {
    if (link.url.trim().isEmpty) return;
    setState(() {
      link.isFetching = true;
      _errorMessage = null;
    });

    try {
      var urlStr = link.url.trim();
      if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
        urlStr = 'https://$urlStr';
      }

      final metadata = await _authService.fetchLinkMetadata(urlStr);
      if (metadata != null && mounted) {
        setState(() {
          link.url = metadata['url']?.toString() ?? urlStr;
          link.title = metadata['title']?.toString() ?? link.title;
          link.faviconUrl = metadata['faviconUrl']?.toString() ?? link.faviconUrl;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to fetch link metadata.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          link.isFetching = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final bio = _bioController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Full name is required.');
      return;
    }

    if (fullName.length > 80) {
      setState(() => _errorMessage = 'Full name must be 80 characters or less.');
      return;
    }

    if (bio.length > 280) {
      setState(() => _errorMessage = 'Bio must be 280 characters or less.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // Links parsing
    final List<Map<String, dynamic>> finalLinks = [];
    for (var i = 0; i < _profileLinks.length; i++) {
      final link = _profileLinks[i];
      var urlStr = link.url.trim();
      if (urlStr.isEmpty) continue;

      if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
        urlStr = 'https://$urlStr';
      }

      finalLinks.add({
        'url': urlStr,
        'title': link.title.trim(),
        'faviconUrl': link.faviconUrl.trim(),
        'position': i,
      });
    }

    // Birthday formatting
    String birthdayStr = '';
    if (_selectedYear != null && _selectedMonth != null && _selectedDay != null) {
      final yearNum = int.tryParse(_selectedYear!);
      final monthNum = _months.indexOf(_selectedMonth!);
      final dayNum = int.tryParse(_selectedDay!);
      if (yearNum != null && monthNum > 0 && dayNum != null) {
        birthdayStr = '${yearNum.toString().padLeft(4, '0')}-${monthNum.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
      }
    }

    // Location construction
    String finalLocation = '';
    if (_selectedCountry != null && _selectedCity != null) {
      finalLocation = '$_selectedCity, $_selectedCountry';
    } else if (_selectedCountry != null) {
      finalLocation = _selectedCountry!;
    } else {
      finalLocation = _countryController.text.trim();
    }

    final genderStr = (_selectedGender != null && _selectedGender != 'Gender') ? _selectedGender! : '';

    final result = await _authService.updateProfile(
      fullName: fullName,
      bio: bio,
      gender: genderStr,
      birthday: birthdayStr,
      location: finalLocation,
      avatarImageDataUrl: _avatarDataUrl,
      profileLinks: finalLinks,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result.ok && result.user != null) {
      Navigator.of(context).pop(result.user);
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Failed to save changes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty) || _avatarPreviewBytes != null;
    final initials = widget.user.initials;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFFE4E6EB) : const Color(0xFF374151);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF101012) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18.r,
            color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
          ),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit profile',
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            fontSize: 16.5.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827),
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Center(
                child: SizedBox(
                  width: 20.r,
                  height: 20.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF7A45),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF7A45),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Avatar section
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _isSaving ? null : _pickAvatar,
                      child: CircleAvatar(
                        radius: 46.r,
                        backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.blue.shade50,
                        backgroundImage: _avatarPreviewBytes != null
                            ? MemoryImage(_avatarPreviewBytes!)
                            : (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty
                                ? CachedNetworkImageProvider(ApiConfig.assetUrl(_avatarUrl!)) as ImageProvider
                                : null),
                        child: !hasAvatar
                            ? Text(
                                initials,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFFF7A45) : Colors.blue.shade700,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isSaving ? null : _pickAvatar,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF7A45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 16.r,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Center(
                child: Text(
                  'Or pick a default avatar:',
                  style: TextStyle(
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: SizedBox(
                  height: 52.r,
                  width: 260.w,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _defaultAvatars.length,
                    itemBuilder: (context, index) {
                      final path = _defaultAvatars[index];
                      final isSelected = _selectedDefaultAvatarPath == path;
                      return GestureDetector(
                        onTap: () => _selectDefaultAvatar(path),
                        child: Container(
                          margin: EdgeInsets.only(right: 12.w),
                          width: 52.r,
                          height: 52.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF7A45) : Colors.transparent,
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
              ),
              SizedBox(height: 20.h),

              // Inputs Card (Threads Inset Grouped Island)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    Text(
                      'Full name',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    TextField(
                      controller: _fullNameController,
                      maxLength: 80,
                      enabled: !_isSaving,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                      ),
                      decoration: _inputDecoration(
                        hintText: 'Enter your full name',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Bio
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bio',
                          style: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w500,
                            color: labelColor,
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _bioController,
                          builder: (context, value, _) {
                            return Text(
                              '${value.text.length}/280',
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    TextField(
                      controller: _bioController,
                      maxLength: 280,
                      maxLines: null,
                      enabled: !_isSaving,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                      ),
                      decoration: _inputDecoration(
                        hintText: 'Tell us about yourself...',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Gender
                    Text(
                      'Gender',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    _DropdownField(
                      value: _selectedGender,
                      items: _genders,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                    SizedBox(height: 10.h),

                    // Date of birth
                    Text(
                      'Date of birth',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _DropdownField(
                            value: _selectedMonth,
                            items: _months,
                            onChanged: (value) {
                              setState(() {
                                _selectedMonth = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _DropdownField(
                            value: _selectedDay,
                            items: _days,
                            onChanged: (value) {
                              setState(() {
                                _selectedDay = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _DropdownField(
                            value: _selectedYear,
                            items: _years,
                            onChanged: (value) {
                              setState(() {
                                _selectedYear = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // Location - Country
                    Text(
                      'Country',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    _SearchSelectField(
                      controller: _countryController,
                      focusNode: _countryFocusNode,
                      enabled: !_isSaving && !_isLoadingCountries && _countries.isNotEmpty,
                      options: _countries.map((country) => country.name).toList(),
                      hintText: _isLoadingCountries ? 'Loading countries...' : 'Choose your country',
                      onChanged: _handleCountryChanged,
                      onSelected: _handleCountrySelected,
                      decoration: _inputDecoration(
                        hintText: _isLoadingCountries ? 'Loading countries...' : 'Choose your country',
                        icon: Icons.public_rounded,
                        suffixIcon: _isLoadingCountries
                            ? SizedBox(
                                width: 14.r,
                                height: 14.r,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18.r,
                                color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
                              ),
                      ),
                    ),
                    if (_countryLoadError != null && _countries.isEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        _countryLoadError!,
                        style: TextStyle(fontSize: 12.sp, color: Colors.red),
                      ),
                    ],

                    // Location - City
                    if (_selectedCountry != null) ...[
                      SizedBox(height: 10.h),
                      Text(
                        'City',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      _SearchSelectField(
                        controller: _cityController,
                        focusNode: _cityFocusNode,
                        enabled: !_isSaving && !_isLoadingCities && _cities.isNotEmpty,
                        options: _cities,
                        hintText: _isLoadingCities ? 'Loading cities...' : 'Choose your city',
                        onChanged: _handleCityChanged,
                        onSelected: _handleCitySelected,
                        decoration: _inputDecoration(
                          hintText: _isLoadingCities ? 'Loading cities...' : 'Choose your city',
                          icon: Icons.location_city_rounded,
                          suffixIcon: _isLoadingCities
                              ? SizedBox(
                                  width: 14.r,
                                  height: 14.r,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18.r,
                                  color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
                                ),
                        ),
                      ),
                      if (_cityLoadError != null && _cities.isEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          _cityLoadError!,
                          style: TextStyle(fontSize: 12.sp, color: Colors.red),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Websites Section Header
              Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16.r,
                    color: const Color(0xFFFF7A45),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Websites',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              // Websites List (Fully dynamic dark mode support with snug padding)
              ..._profileLinks.asMap().entries.map((entry) {
                final idx = entry.key;
                final link = entry.value;

                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22.r,
                            height: 22.r,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF28282B) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            alignment: Alignment.center,
                            child: link.faviconUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: link.faviconUrl,
                                    width: 13.r,
                                    height: 13.r,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.open_in_new_rounded,
                                      size: 11.r,
                                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    ),
                                  )
                                : Icon(
                                    Icons.open_in_new_rounded,
                                    size: 11.r,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextFormField(
                              initialValue: link.url,
                              enabled: !_isSaving && !link.isFetching,
                              style: TextStyle(
                                fontFamily: 'SF Pro Rounded',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                              ),
                              decoration: InputDecoration(
                                hintText: 'https://example.com',
                                hintStyle: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontSize: 13.sp,
                                  color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
                                ),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 2.h),
                              ),
                              onChanged: (val) => setState(() => link.url = val),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        height: 6.h,
                        thickness: 0.5,
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                      ),
                      TextFormField(
                        initialValue: link.title,
                        enabled: !_isSaving && !link.isFetching,
                        maxLength: 100,
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Website title',
                          hintStyle: TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 13.sp,
                            color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
                          ),
                          counterText: '',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 2.h),
                        ),
                        onChanged: (val) => setState(() => link.title = val),
                      ),
                      Divider(
                        height: 6.h,
                        thickness: 0.5,
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: (_isSaving || link.isFetching || link.url.trim().isEmpty)
                                ? null
                                : () => _fetchLinkMetadata(link),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: link.isFetching
                                ? SizedBox(
                                    width: 12.r,
                                    height: 12.r,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF7A45),
                                    ),
                                  )
                                : Text(
                                    'Fetch title & icon',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Rounded',
                                      fontSize: 11.5.sp,
                                      color: const Color(0xFFFF7A45),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: const Color(0xFFED4956),
                              size: 16.r,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _isSaving ? null : () => setState(() => _profileLinks.removeAt(idx)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              if (_profileLinks.length < 5) ...[
                Material(
                  color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  child: InkWell(
                    onTap: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _profileLinks.add(_EditableProfileLink());
                            });
                          },
                    borderRadius: BorderRadius.circular(8.r),
                    splashColor: isDark ? const Color(0xFF28282B) : const Color(0xFFE5E7EB),
                    child: Container(
                      height: 36.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16.r,
                            color: const Color(0xFFFF7A45),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Add website',
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFFF7A45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableProfileLink {
  _EditableProfileLink({
    this.url = '',
    this.title = '',
    this.faviconUrl = '',
  });

  String url;
  String title;
  String faviconUrl;
  bool isFetching = false;
}

class _AvatarCropResult {
  _AvatarCropResult({
    required this.previewBytes,
    required this.dataUrl,
  });

  final Uint8List previewBytes;
  final String dataUrl;
}

class _AvatarEditorScreen extends StatefulWidget {
  const _AvatarEditorScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<_AvatarEditorScreen> {
  final _transformController = TransformationController();
  final _canvasKey = GlobalKey();
  bool _isSaving = false;
  final double _avatarSize = 250.0;

  void _resetTransform() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _saveAvatar() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas boundary not ready.');
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
      final outputBytes = compressedBytes.isEmpty ? pngBytes : Uint8List.fromList(compressedBytes);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(outputBytes)}';

      if (!mounted) return;

      Navigator.of(context).pop(
        _AvatarCropResult(previewBytes: outputBytes, dataUrl: dataUrl),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save avatar: $error')),
        );
      }
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101012) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF101012) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
        ),
        title: Text(
          'Adjust avatar',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontFamily: 'SF Pro Rounded',
            fontSize: 16.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : _resetTransform,
            child: Text(
              'Reset',
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveAvatar,
            child: _isSaving
                ? SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A45)),
                  )
                : Text(
                    'Use',
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF7A45),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          child: Column(
            children: <Widget>[
              Text(
                'Pinch to zoom and drag to position your profile photo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 13.sp,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6C7174),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'The photo inside the circle is what will be saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Rounded',
                  fontSize: 12.sp,
                  color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
                ),
              ),
              SizedBox(height: 20.h),
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
                                    color: isDark ? const Color(0xFF1E1E20) : const Color(0xFFF3F4F7),
                                  ),
                                  InteractiveViewer(
                                    transformationController: _transformController,
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
                            size: Size(_avatarSize, _avatarSize),
                            painter: _CircleMaskPainter(
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
                              border: Border.all(color: Colors.white, width: 2.5),
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
              SizedBox(height: 20.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _resetTransform,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF0F1419),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF38383A) : const Color(0xFFD1D5DB),
                        ),
                        shape: const StadiumBorder(),
                        minimumSize: Size.fromHeight(46.h),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Reset',
                        style: TextStyle(
                          fontFamily: 'SF Pro Rounded',
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46.h,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveAvatar,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A45),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 18.r,
                                height: 18.r,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Save avatar',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Rounded',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
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
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    return SizedBox(
      height: 36.h,
      child: DropdownButtonFormField<String>(
        initialValue: (value != null && items.contains(value)) ? value : null,
        isExpanded: true,
        isDense: true,
        iconSize: 18.r,
        dropdownColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: isDark ? const Color(0xFF141416) : const Color(0xFFF9FAFB),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
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
            borderSide: const BorderSide(color: Color(0xFFFF7A45), width: 1.2),
          ),
        ),
        hint: Text(
          items.first,
          style: TextStyle(
            fontFamily: 'SF Pro Rounded',
            fontSize: 13.sp,
            color: isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF),
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
                    fontFamily: 'SF Pro Rounded',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final String hintText;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827),
              ),
              decoration: decoration.copyWith(
                hintText: hintText,
              ),
            );
          },
          optionsViewBuilder: (context, onOptionSelected, filteredOptions) {
            final optionsList = filteredOptions.toList(growable: false);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      width: 0.5,
                    ),
                  ),
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    maxHeight: 200.h,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    shrinkWrap: true,
                    itemCount: optionsList.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final option = optionsList[index];
                      return InkWell(
                        onTap: () {
                          onOptionSelected(option);
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontFamily: 'SF Pro Rounded',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
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
