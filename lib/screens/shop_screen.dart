import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/conversation_theme.dart';
import '../services/feed_service.dart';

enum ThemeProductType {
  sunrise,
  ocean,
  bees,
  eagle,
  pinkswan,
  dandelion,
  gtaPastel,
  sharinganEyes,
  pastel,
  lavender,
  phFlag,
  xmasCozy,
  xmasSnowy,
  geminiRogerHunter,
  geminiRogerWolf,
  bunny,
  ghost,
  prince,
  cuteHeart,
  elsa,
  bubbleDream,
}

const List<ThemeProductData> themeProducts = [
  ThemeProductData(
    type: ThemeProductType.sunrise,
    title: 'Postcard Premium - Sunrise Theme',
    description:
        'Personalize your feed posts with a gorgeous sunrise header backdrop. Features a central glowing sun, flying birds silhouettes, and soft pink clouds fading smoothly into your card layout.',
    successMessage:
        'The Sunrise Postcard Theme is now active on your account! Your posts will now feature the gorgeous sunrise header.',
    previewLabel: 'daisy',
    previewInitial: 'D',
    assetPath: 'assets/images/sunrise_sticker.png',
    previewGradient: [
      Color(0xFFB3E5FC),
      Color(0xFFFFE082),
      Color(0xFFFFF9C4),
      Colors.white,
    ],
    badgeText: 'BEST SELLER',
    badgeGradient: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    buttonGradient: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    previewAvatarColor: Color(0xFFFBCFE8),
    previewInitialColor: Color(0xFFDB2777),
  ),
  ThemeProductData(
    type: ThemeProductType.ocean,
    title: 'Postcard Premium - Ocean Theme',
    description:
        'Give your posts a calm ocean horizon with cool blue layers, soft seafoam highlights, and a clean banner fade that blends naturally into the card.',
    successMessage:
        'The Ocean Postcard Theme is now active on your account! Your posts will now feature the refreshing ocean header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/ocean_sticker_v3.png',
    previewGradient: [
      Color(0xFF0F3D6E),
      Color(0xFF1D6FA5),
      Color(0xFF86D6E7),
      Colors.white,
    ],
    badgeText: 'NEW',
    badgeGradient: [Color(0xFF0F766E), Color(0xFF06B6D4)],
    buttonGradient: [Color(0xFF0F766E), Color(0xFF0891B2)],
    previewAvatarColor: Color(0xFFBFDBFE),
    previewInitialColor: Color(0xFF1D4ED8),
  ),
  ThemeProductData(
    type: ThemeProductType.bees,
    title: 'Postcard Premium - Bee Garden Theme',
    description:
        'Add a warm honey-garden banner with a bright readable left side, graceful bee accents, and rich golden detail concentrated on the right.',
    successMessage:
        'The Bee Garden Postcard Theme is now active on your account! Your posts will now feature the warm bee-garden header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/bee_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFCF0),
      Color(0xFFFFF7D6),
      Color(0xFFFDE68A),
      Color(0xFFF59E0B),
    ],
    badgeText: 'FRESH DROP',
    badgeGradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
    buttonGradient: [Color(0xFFD97706), Color(0xFFFBBF24)],
    previewAvatarColor: Color(0xFFFEF3C7),
    previewInitialColor: Color(0xFFB45309),
  ),
  ThemeProductData(
    type: ThemeProductType.eagle,
    title: 'Postcard Premium - Eagle Horizon Theme',
    description:
        'Give your posts a refined eagle postcard banner with a bright readable left side, graceful feather motion, and rich golden-bronze detail focused on the right.',
    successMessage:
        'The Eagle Horizon Postcard Theme is now active on your account! Your posts will now feature the elegant eagle header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/eagle_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFCF6),
      Color(0xFFF6E9D1),
      Color(0xFFE8C089),
      Color(0xFFC08A42),
    ],
    badgeText: 'NEW DROP',
    badgeGradient: [Color(0xFF8C6239), Color(0xFFC08A42)],
    buttonGradient: [Color(0xFF9A6B3B), Color(0xFFD4A55A)],
    previewAvatarColor: Color(0xFFFAE9CC),
    previewInitialColor: Color(0xFF8A5A2B),
  ),
  ThemeProductData(
    type: ThemeProductType.pinkswan,
    title: 'Postcard Premium - Pink Swan Theme',
    description:
        'Give your posts a graceful swan postcard banner with a bright readable left side, soft feather flow, and elegant rosy detail focused on the right.',
    successMessage:
        'The Pink Swan Postcard Theme is now active on your account! Your posts will now feature the elegant swan header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/pinkswan_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFCFD),
      Color(0xFFFCE7F3),
      Color(0xFFF9A8D4),
      Color(0xFFF472B6),
    ],
    badgeText: 'PINK SWAN',
    badgeGradient: [Color(0xFFDB2777), Color(0xFFF472B6)],
    buttonGradient: [Color(0xFFEC4899), Color(0xFFF9A8D4)],
    previewAvatarColor: Color(0xFFFCE7F3),
    previewInitialColor: Color(0xFFBE185D),
  ),
  ThemeProductData(
    type: ThemeProductType.dandelion,
    title: 'Postcard Premium - Dandelion Theme',
    description:
        'Give your posts a dreamy dandelion postcard banner with a bright readable left side, gentle floating seeds, and fresh spring detail focused on the right.',
    successMessage:
        'The Dandelion Postcard Theme is now active on your account! Your posts will now feature the airy dandelion header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/dandelion_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFDF7),
      Color(0xFFFEF9C3),
      Color(0xFFD9F99D),
      Color(0xFFA3E635),
    ],
    badgeText: 'SPRING AIR',
    badgeGradient: [Color(0xFF65A30D), Color(0xFFFACC15)],
    buttonGradient: [Color(0xFF84CC16), Color(0xFFFDE047)],
    previewAvatarColor: Color(0xFFFEF9C3),
    previewInitialColor: Color(0xFF4D7C0F),
  ),
  ThemeProductData(
    type: ThemeProductType.gtaPastel,
    title: 'Postcard Premium - GTA Pastel Theme',
    description:
        'Give your posts a polished pastel neon skyline banner with a bright readable left side, soft sunset glow, and stylish retro city energy on the right.',
    successMessage:
        'The GTA Pastel Postcard Theme is now active on your account! Your posts will now feature the pastel neon city header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/gta_pastel_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFCF8),
      Color(0xFFFBCFE8),
      Color(0xFF99F6E4),
      Color(0xFFFB923C),
    ],
    badgeText: 'PASTEL CITY',
    badgeGradient: [Color(0xFFEC4899), Color(0xFF22D3EE)],
    buttonGradient: [Color(0xFFF97316), Color(0xFF67E8F9)],
    previewAvatarColor: Color(0xFFFCE7F3),
    previewInitialColor: Color(0xFFDB2777),
  ),
  ThemeProductData(
    type: ThemeProductType.sharinganEyes,
    title: 'Postcard Premium - Sharingan Eyes Theme',
    description:
        'Give your posts a dramatic mystical eye-energy banner with a bright readable left side, soft crimson glow, and premium anime-inspired detail on the right.',
    successMessage:
        'The Sharingan Eyes Postcard Theme is now active on your account! Your posts will now feature the crimson eye-energy header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/sharingan_eyes_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFCFD),
      Color(0xFFFDE2E8),
      Color(0xFFFCA5A5),
      Color(0xFFB91C1C),
    ],
    badgeText: 'CRIMSON EYES',
    badgeGradient: [Color(0xFF991B1B), Color(0xFFEF4444)],
    buttonGradient: [Color(0xFFDC2626), Color(0xFFFCA5A5)],
    previewAvatarColor: Color(0xFFFEE2E2),
    previewInitialColor: Color(0xFF991B1B),
  ),
  ThemeProductData(
    type: ThemeProductType.pastel,
    title: 'Postcard Premium - Pastel Bloom Theme',
    description:
        'Give your posts a dreamy pastel bloom banner with an airy readable left side and soft floral-cloud color concentrated on the right.',
    successMessage:
        'The Pastel Bloom Postcard Theme is now active on your account! Your posts will now feature the dreamy pastel header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/pastel_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFBF8),
      Color(0xFFF8E8F7),
      Color(0xFFE1F4EE),
      Color(0xFFC7D2FE),
    ],
    badgeText: 'SOFT DROP',
    badgeGradient: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    buttonGradient: [Color(0xFFF472B6), Color(0xFF818CF8)],
    previewAvatarColor: Color(0xFFFCE7F3),
    previewInitialColor: Color(0xFFBE185D),
  ),
  ThemeProductData(
    type: ThemeProductType.lavender,
    title: 'Postcard Premium - Lavender Theme',
    description:
        'Give your posts a soothing lavender pastel banner with an airy readable left side and beautiful purple watercolor flowers on the right.',
    successMessage:
        'The Lavender Postcard Theme is now active on your account! Your posts will now feature the beautiful lavender header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/lavender_sticker_v1.png',
    previewGradient: [
      Color(0xFFFAF8FF),
      Color(0xFFF1E9FF),
      Color(0xFFE3D3FF),
      Colors.white,
    ],
    badgeText: 'LAVENDER',
    badgeGradient: [Color(0xFF7C3AED), Color(0xFFC084FC)],
    buttonGradient: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
    previewAvatarColor: Color(0xFFEDE9FE),
    previewInitialColor: Color(0xFF6D28D9),
  ),
  ThemeProductData(
    type: ThemeProductType.phFlag,
    title: 'Postcard Premium - Pinoy Pride Theme',
    description:
        'Show your Pinoy Pride with a beautiful wavy Philippine flag banner on the right, golden stars, and a soft, readable blue-red-yellow mist on the left.',
    successMessage:
        'The Pinoy Pride Postcard Theme is now active on your account! Your posts will now feature the wavy flag header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/ph_flag_sticker_v1.png',
    previewGradient: [
      Color(0xFFF0F9FF),
      Color(0xFFFEF2F2),
      Color(0xFFFFFBEB),
      Colors.white,
    ],
    badgeText: 'PINOY PRIDE',
    badgeGradient: [Color(0xFF1E3A8A), Color(0xFFDC2626)],
    buttonGradient: [Color(0xFF2563EB), Color(0xFFEF4444)],
    previewAvatarColor: Color(0xFFDBEAFE),
    previewInitialColor: Color(0xFF1E40AF),
  ),
  ThemeProductData(
    type: ThemeProductType.xmasCozy,
    title: 'Postcard Premium - Cozy Christmas Theme',
    description:
        'Bring holiday warmth to your posts with pine branches, red berries, gold ornaments, and a cozy cream-to-red gradient backdrop.',
    successMessage:
        'The Cozy Christmas Postcard Theme is now active on your account! Your posts will now feature the cozy holiday header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/xmas_cozy_sticker.png',
    previewGradient: [
      Color(0xFFFFFDF9),
      Color(0xFFFEE2E2),
      Color(0xFFFEF08A),
      Colors.white,
    ],
    badgeText: 'COZY XMAS',
    badgeGradient: [Color(0xFFB91C1C), Color(0xFFD97706)],
    buttonGradient: [Color(0xFFDC2626), Color(0xFFF59E0B)],
    previewAvatarColor: Color(0xFFFEE2E2),
    previewInitialColor: Color(0xFF991B1B),
  ),
  ThemeProductData(
    type: ThemeProductType.xmasSnowy,
    title: 'Postcard Premium - Snowy Christmas Theme',
    description:
        'Turn your posts into a winter wonderland with frosted pine trees, delicate blue-silver snowflakes, and a cool frosty gradient backdrop.',
    successMessage:
        'The Snowy Christmas Postcard Theme is now active on your account! Your posts will now feature the frosty winter header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/xmas_snowy_sticker.png',
    previewGradient: [
      Color(0xFFF0F9FF),
      Color(0xFFE0F2FE),
      Color(0xFFBAE6FD),
      Colors.white,
    ],
    badgeText: 'SNOWY XMAS',
    badgeGradient: [Color(0xFF0369A1), Color(0xFF38BDF8)],
    buttonGradient: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
    previewAvatarColor: Color(0xFFE0F2FE),
    previewInitialColor: Color(0xFF0369A1),
  ),
  ThemeProductData(
    type: ThemeProductType.geminiRogerHunter,
    title: 'Gemini Exclusive - Roger Hunter',
    description:
        'A Gemini-only Roger inspired hunter postcard theme with a bright left reading zone and moonlit hunter detail concentrated on the right.',
    successMessage:
        'The Gemini-exclusive Roger Hunter theme is now active. Gemini posts will use the new hunter postcard header.',
    previewLabel: 'gemini',
    previewInitial: 'G',
    assetPath: 'assets/images/gemini_roger_hunter_v1.png',
    previewGradient: [
      Color(0xFFF8FAFC),
      Color(0xFFE2E8F0),
      Color(0xFF94A3B8),
      Color(0xFF334155),
    ],
    badgeText: 'GEMINI ONLY',
    badgeGradient: [Color(0xFF475569), Color(0xFF1E293B)],
    buttonGradient: [Color(0xFF64748B), Color(0xFF1E293B)],
    previewAvatarColor: Color(0xFFE2E8F0),
    previewInitialColor: Color(0xFF334155),
  ),
  ThemeProductData(
    type: ThemeProductType.geminiRogerWolf,
    title: 'Gemini Exclusive - Roger Wolf',
    description:
        'A Gemini-only Roger inspired wolf postcard theme with a bright left reading zone and powerful moonlit wolf energy on the right.',
    successMessage:
        'The Gemini-exclusive Roger Wolf theme is now active. Gemini posts will use the new wolf postcard header.',
    previewLabel: 'gemini',
    previewInitial: 'G',
    assetPath: 'assets/images/gemini_roger_wolf_v1.png',
    previewGradient: [
      Color(0xFFF8FAFC),
      Color(0xFFDBEAFE),
      Color(0xFF60A5FA),
      Color(0xFF1D4ED8),
    ],
    badgeText: 'GEMINI ONLY',
    badgeGradient: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
    buttonGradient: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
    previewAvatarColor: Color(0xFFDBEAFE),
    previewInitialColor: Color(0xFF1D4ED8),
  ),
  ThemeProductData(
    type: ThemeProductType.bunny,
    title: 'Postcard Premium - Bunny Meadow Theme',
    description:
        'Add a whimsical watercolor bunny meadow banner to your posts, featuring soft pastel flowers, green clover, and a cute watercolor bunny on the right.',
    successMessage:
        'The Bunny Meadow Postcard Theme is now active on your account! Your posts will now feature the cute bunny meadow header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/bunny_sticker_v1.png',
    previewGradient: [
      Color(0xFFFFFDFB),
      Color(0xFFFFF5F7),
      Color(0xFFFCE7F3),
      Color(0xFFFBCFE8),
    ],
    badgeText: 'BUNNY',
    badgeGradient: [Color(0xFFEC4899), Color(0xFFF472B6)],
    buttonGradient: [Color(0xFFEC4899), Color(0xFFF472B6)],
    previewAvatarColor: Color(0xFFFCE7F3),
    previewInitialColor: Color(0xFFDB2777),
  ),
  ThemeProductData(
    type: ThemeProductType.ghost,
    title: 'Postcard Premium - Spooky Ghost Theme',
    description:
        'Give your posts a cozy spooky aesthetic with a watercolor ghost banner, featuring soft purple mist, cute little friendly ghosts, and warm candlelit glows on the right.',
    successMessage:
        'The Spooky Ghost Postcard Theme is now active on your account! Your posts will now feature the cozy ghost header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/ghost_sticker_v1.png',
    previewGradient: [
      Color(0xFFFAF9FD),
      Color(0xFFF3F0FA),
      Color(0xFFE9E3F8),
      Color(0xFFDCD3F5),
    ],
    badgeText: 'SPOOKY CUTE',
    badgeGradient: [Color(0xFF6B21A8), Color(0xFF8B5CF6)],
    buttonGradient: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    previewAvatarColor: Color(0xFFF3E8FF),
    previewInitialColor: Color(0xFF7E22CE),
  ),
  ThemeProductData(
    type: ThemeProductType.prince,
    title: 'Postcard Premium - Little Prince Theme',
    description:
        'Add a majestic celestial theme to your posts inspired by the Little Prince, featuring starry night gradients, soft clouds, and a golden prince silhouette on the right.',
    successMessage:
        'The Little Prince Postcard Theme is now active on your account! Your posts will now feature the celestial prince header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/prince_sticker_v1.png',
    previewGradient: [
      Color(0xFFF0F7FF),
      Color(0xFFE0EFFF),
      Color(0xFFBAE0FF),
      Color(0xFF7DD3FC),
    ],
    badgeText: 'ROYAL STAR',
    badgeGradient: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    buttonGradient: [Color(0xFF2563EB), Color(0xFF60A5FA)],
    previewAvatarColor: Color(0xFFDBEAFE),
    previewInitialColor: Color(0xFF1E3A8A),
  ),
  ThemeProductData(
    type: ThemeProductType.cuteHeart,
    title: 'Postcard Premium - Cute Heart Theme',
    description:
        'Give your posts a super clean postcard header with a flat soft background and one cute pink heart on the right for a light, smooth look.',
    successMessage:
        'The Cute Heart Postcard Theme is now active on your account! Your posts will now feature the lightweight heart header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: '',
    previewGradient: [
      Color(0xFFFFFCFE),
      Color(0xFFFFFCFE),
      Color(0xFFFFFCFE),
      Color(0xFFFFFCFE),
    ],
    badgeText: 'SMOOTH',
    badgeGradient: [Color(0xFFF472B6), Color(0xFFF9A8D4)],
    buttonGradient: [Color(0xFFF472B6), Color(0xFFF472B6)],
    previewAvatarColor: Color(0xFFFCE7F3),
    previewInitialColor: Color(0xFFBE185D),
  ),
  ThemeProductData(
    type: ThemeProductType.elsa,
    title: 'Postcard Premium - Cozy Cat Theme',
    description:
        'Add a cozy, peaceful pastel winter theme to your posts featuring soft ice-blue and lavender gradients, and a cute watercolor sleeping cat on the right.',
    successMessage:
        'The Cozy Cat Postcard Theme is now active on your account! Your posts will now feature the cute sleeping cat header.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/images/elsa_sticker.png',
    previewGradient: [
      Color(0xFFE0F2FE),
      Color(0xFFBAE6FD),
      Color(0xFFF3E8FF),
      Color(0xFFE9D5FF),
    ],
    badgeText: 'CAT',
    badgeGradient: [Color(0xFF0EA5E9), Color(0xFFA855F7)],
    buttonGradient: [Color(0xFF0EA5E9), Color(0xFFA855F7)],
    previewAvatarColor: Color(0xFFE0F2FE),
    previewInitialColor: Color(0xFF0369A1),
  ),
  ThemeProductData(
    type: ThemeProductType.bubbleDream,
    title: 'Chat Premium - Bubble Dream Theme',
    description:
        'Stylize your direct messages with a soft lavender background and beautiful pink-to-violet gradient bubble chat messages.',
    successMessage:
        'The Bubble Dream Chat Theme is now active on your account! Your direct messages will feature the premium gradient chat bubbles.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: '',
    previewGradient: [
      Color(0xFFF5F3FF),
      Color(0xFFE9D5FF),
      Color(0xFFF3E8FF),
      Colors.white,
    ],
    badgeText: 'NEW CHAT THEME',
    badgeGradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    buttonGradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    previewAvatarColor: Color(0xFFF5F3FF),
    previewInitialColor: Color(0xFF8B5CF6),
  ),
];

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final AuthService _authService = AuthService();
  final FeedService _feedService = FeedService();

  String _appliedPostcardTheme = '';
  String _appliedBubbleTheme = '';
  String _currentUsername = '';
  bool _isThemeStateLoading = true;
  List<ThemeProductData> _visibleProducts = [];
  ThemeProductData? _selectedTheme;

  @override
  void initState() {
    super.initState();
    _loadThemeState();
  }

  bool _isGeminiOnly(ThemeProductType type) {
    return type == ThemeProductType.geminiRogerHunter ||
        type == ThemeProductType.geminiRogerWolf;
  }

  bool _canApplyTheme(ThemeProductType type) {
    return !_isGeminiOnly(type) || _currentUsername == 'gemini';
  }

  String _themeKeyFor(ThemeProductType type) {
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

  bool _isApplied(ThemeProductType type) {
    if (type == ThemeProductType.bubbleDream) {
      return _appliedBubbleTheme == _themeKeyFor(type);
    }
    return _appliedPostcardTheme == _themeKeyFor(type);
  }

  Future<void> _loadThemeState() async {
    final user = await _authService.getSavedUser();
    final prefs = await SharedPreferences.getInstance();

    final visible = <ThemeProductData>[];
    for (final product in themeProducts) {
      final key = 'katsklub_theme_public_${_themeKeyFor(product.type)}';
      final isPublic = prefs.getBool(key) ?? true;
      if (isPublic) {
        visible.add(product);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _appliedPostcardTheme = (user?.postcardTheme ?? '').trim().toLowerCase();
      _appliedBubbleTheme = (user?.bubbleTheme ?? '').trim().toLowerCase();
      _currentUsername = (user?.username ?? '').trim().toLowerCase();
      _visibleProducts = visible;

      // Initialize selected theme for live preview
      ThemeProductData? selected;
      if (_appliedPostcardTheme.isNotEmpty) {
        for (final p in visible) {
          if (p.type != ThemeProductType.bubbleDream && _themeKeyFor(p.type) == _appliedPostcardTheme) {
            selected = p;
            break;
          }
        }
      }
      if (selected == null && _appliedBubbleTheme.isNotEmpty) {
        for (final p in visible) {
          if (p.type == ThemeProductType.bubbleDream && _themeKeyFor(p.type) == _appliedBubbleTheme) {
            selected = p;
            break;
          }
        }
      }
      _selectedTheme = selected ??
          (visible.isNotEmpty
              ? visible.firstWhere(
                  (p) => p.type == ThemeProductType.bunny,
                  orElse: () => visible.first,
                )
              : null);

      _isThemeStateLoading = false;
    });
  }

  Future<void> _setApplied(ThemeProductType type, bool applied) async {
    if (type == ThemeProductType.bubbleDream) {
      final themeVal = applied ? _themeKeyFor(type) : '';
      final updatedUser = await _feedService.updateCurrentUserBubbleTheme(themeVal);
      await ConversationThemeStore.setGlobalBubbleTheme(themeVal);
      if (!mounted) return;
      setState(() {
        _appliedBubbleTheme = (updatedUser.bubbleTheme ?? '').trim().toLowerCase();
        _isThemeStateLoading = false;
      });
    } else {
      final themeVal = applied ? _themeKeyFor(type) : '';
      final updatedUser = await _feedService.updateCurrentUserPostcardTheme(themeVal);
      if (!mounted) return;
      setState(() {
        _appliedPostcardTheme = (updatedUser.postcardTheme ?? '').trim().toLowerCase();
        _isThemeStateLoading = false;
      });
    }
  }

  void _handleApplyTheme(
    BuildContext context,
    ThemeProductData theme,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PurchaseProcessDialog(
          accentColor: theme.buttonGradient.last,
          onComplete: () async {
            try {
              await _setApplied(theme.type, true);
              if (!context.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              _showSuccessSheet(context, theme);
            } catch (error) {
              if (!context.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(error.toString().replaceFirst('Bad state: ', ''))),
              );
            }
          },
        );
      },
    );
  }

  void _showSuccessSheet(BuildContext context, ThemeProductData theme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF86EFAC),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                     Icons.check_rounded,
                    color: Color(0xFF15803D),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Theme Applied Successfully!',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                theme.successMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Awesome',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleTheme(
    BuildContext context,
    ThemeProductData theme,
  ) async {
    if (_isThemeStateLoading) {
      return;
    }

    if (!_canApplyTheme(theme.type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This postcard theme is Gemini-only.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final isApplied = _isApplied(theme.type);
    if (isApplied) {
      try {
        await _setApplied(theme.type, false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Theme deactivated.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString().replaceFirst('Bad state: ', ''),
              ),
            ),
          );
        }
      }
      return;
    }

    _handleApplyTheme(context, theme);
  }

  void _onSelectTheme(ThemeProductData theme) {
    setState(() {
      _selectedTheme = theme;
    });
  }

  Widget _buildLivePreviewCard(ThemeProductData? selected) {
    if (selected == null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text(
            'Select a theme to preview',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (selected.type == ThemeProductType.bubbleDream) {
      return _buildChatPreviewCard(selected);
    }

    final firstColor = selected.previewGradient.first;
    final isDark = firstColor.computeLuminance() < 0.55;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF6B7280);
    final verifiedColor =
        isDark ? const Color(0xFFE0F2FE) : const Color(0xFF2563EB);

    final showCuteHeart = selected.type == ThemeProductType.cuteHeart;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme postcard header
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  // Gradient Background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: selected.previewGradient,
                        ),
                      ),
                    ),
                  ),

                  // Sticker Art
                  if (showCuteHeart)
                    const Positioned.fill(
                      child: _CuteHeartPreviewArt(),
                    )
                  else
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.7, 1.0],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          selected.assetPath,
                          fit: BoxFit.cover,
                           alignment: selected.type == ThemeProductType.xmasSnowy ||
                                  selected.type == ThemeProductType.bees ||
                                  selected.type == ThemeProductType.bunny ||
                                  selected.type == ThemeProductType.ghost ||
                                  selected.type == ThemeProductType.prince ||
                                  selected.type == ThemeProductType.elsa
                              ? Alignment.centerRight
                              : Alignment.center,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),

                  // Metadata Header Overlay
                  Positioned(
                    left: 16,
                    top: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // User Avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: selected.previewAvatarColor,
                          child: Center(
                            child: Text(
                              _currentUsername.isNotEmpty
                                  ? _currentUsername[0].toUpperCase()
                                  : 'Y',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: selected.previewInitialColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Metadata text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _currentUsername.isNotEmpty
                                          ? _currentUsername
                                          : 'You',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    color: verifiedColor,
                                    size: 15,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'Just now',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.public,
                                    color: secondaryTextColor,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Small "Preview" Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PREVIEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Mock Post Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Just updated my postcard theme! What do you think of this premium look? ✨ #vibes #katsklub',
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mock Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMockActionButton(
                          Icons.favorite_border_rounded, '24'),
                      _buildMockActionButton(
                          Icons.chat_bubble_outline_rounded, '8'),
                      _buildMockActionButton(Icons.repeat_rounded, '3'),
                      _buildMockActionButton(Icons.share_outlined, ''),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockActionButton(IconData icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChatPreviewCard(ThemeProductData selected) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.purple.shade100,
                  child: const Text('G', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Gemini',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, size: 18, color: Colors.grey),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.purple.shade50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Hi! How is the new chat bubble theme? 💬',
                        style: TextStyle(
                          color: Color(0xFF4C1D95),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Looks super premium and aesthetic! 😍',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Type a message...',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.send, color: Color(0xFF8B5CF6), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, ThemeProductData selected) {
    final isApplied = _isApplied(selected.type);
    final isLocked = !_canApplyTheme(selected.type);
    final isLoading = _isThemeStateLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected.title.replaceFirst('Postcard Premium - ', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isApplied
                      ? 'Currently active on your posts'
                      : isLocked
                          ? 'Exclusive to Gemini account'
                          : 'Ready to apply',
                  style: TextStyle(
                    color: isApplied
                        ? const Color(0xFF15803D)
                        : isLocked
                            ? const Color(0xFFEF4444)
                            : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action Button
          InkWell(
            onTap: (isLoading || isLocked) && !isApplied
                ? null
                : () => _toggleTheme(context, selected),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: isApplied || isLocked || isLoading
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFF0EA5E9), // Elsa Ice Blue
                          Color(0xFFA855F7), // Magic Lavender
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isApplied
                    ? const Color(0xFFFEE2E2) // soft red for deactivation
                    : isLocked || isLoading
                        ? const Color(0xFFE5E7EB)
                        : null,
                borderRadius: BorderRadius.circular(14),
                border: isApplied
                    ? Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1,
                      )
                    : isLocked || isLoading
                        ? Border.all(
                            color: const Color(0xFFD1D5DB),
                            width: 1,
                          )
                        : null,
                boxShadow: isApplied || isLocked || isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFA855F7).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Text(
                isApplied
                    ? 'Deactivate'
                    : isLocked
                        ? 'Locked'
                        : isLoading
                            ? 'Loading...'
                            : 'Apply Theme',
                style: TextStyle(
                  color: isApplied
                      ? const Color(0xFF991B1B)
                      : isLocked || isLoading
                          ? const Color(0xFF9CA3AF)
                          : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pop(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: SvgPicture.string(
                '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M15 19.9201L8.47997 13.4001C7.70997 12.6301 7.70997 11.3701 8.47997 10.6001L15 4.08008" stroke="#292D32" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
                width: 24,
                height: 24,
              ),
            ),
          ),
        ),
        title: const Text(
          'KatsShop',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F2FE), // Elsa Ice Blue
              Color(0xFFF3E8FF), // Magic Lavender
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Live Preview Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Interactive Preview',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLivePreviewCard(_selectedTheme),
                  ],
                ),
              ),

              // Themes List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Available Themes',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_visibleProducts.length} themes',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Themes List
              Expanded(
                child: _isThemeStateLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFA855F7),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _visibleProducts.length,
                        itemBuilder: (context, index) {
                          final theme = _visibleProducts[index];
                          final isSelected =
                              _selectedTheme?.type == theme.type;
                          return _ThemeListItem(
                            theme: theme,
                            isSelected: isSelected,
                            isApplied: _isApplied(theme.type),
                            isLocked: !_canApplyTheme(theme.type),
                            onTap: () => _onSelectTheme(theme),
                          );
                        },
                      ),
              ),

              // Bottom Action Bar
              if (_selectedTheme != null)
                _buildBottomActionBar(context, _selectedTheme!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeListItem extends StatelessWidget {
  const _ThemeListItem({
    required this.theme,
    required this.isSelected,
    required this.isApplied,
    required this.isLocked,
    required this.onTap,
  });

  final ThemeProductData theme;
  final bool isSelected;
  final bool isApplied;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCuteHeart = theme.type == ThemeProductType.cuteHeart;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.9)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFA855F7).withOpacity(0.6) // lavender border
                : Colors.white.withOpacity(0.4),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFA855F7).withOpacity(0.12)
                  : Colors.black.withOpacity(0.02),
              blurRadius: isSelected ? 12 : 6,
              offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Mini theme preview block
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    children: [
                      // Gradient
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: theme.previewGradient,
                            ),
                          ),
                        ),
                      ),
                      // Sticker
                      if (showCuteHeart)
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: const Color(0xFFF472B6).withOpacity(0.8),
                              size: 24,
                            ),
                          ),
                        )
                      else if (theme.assetPath.isNotEmpty)
                        Positioned.fill(
                          child: Image.asset(
                            theme.assetPath,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            theme.title.replaceFirst('Postcard Premium - ', ''),
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isApplied) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF86EFAC),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (isLocked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Locked',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      theme.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuteHeartPreviewArt extends StatelessWidget {
  const _CuteHeartPreviewArt();

  @override
  Widget build(BuildContext context) {
    Widget wing({required bool left}) {
      const feathers = [0.0, 6.0, 12.0];
      return SizedBox(
        width: 26,
        height: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final offset in feathers)
              Positioned(
                left: left ? null : offset,
                right: left ? offset : null,
                top: offset * 0.3,
                child: Transform.rotate(
                  angle: left ? -0.55 : 0.55,
                  child: Container(
                    width: 13,
                    height: 16 - (offset * 0.2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFF0C8DA),
                        width: 0.9,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        const Positioned(
          left: 12,
          top: 14,
          child: SizedBox(
            width: 86,
            child: Text(
              'soft winged heart',
              style: TextStyle(
                color: Color(0xFF9F6B84),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 18,
          child: SizedBox(
            width: 76,
            height: 52,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: 0, top: 13, child: wing(left: true)),
                Positioned(right: 18, top: 13, child: wing(left: false)),
                Positioned(
                  right: 0,
                  top: 11,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF0C5D7),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFF472B6),
                      size: 28,
                    ),
                  ),
                ),
                const Positioned(
                  right: 31,
                  top: 0,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFF9A8D4),
                    size: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ThemeProductData {
  const ThemeProductData({
    required this.type,
    required this.title,
    required this.description,
    required this.successMessage,
    required this.previewLabel,
    required this.previewInitial,
    required this.assetPath,
    required this.previewGradient,
    required this.badgeText,
    required this.badgeGradient,
    required this.buttonGradient,
    required this.previewAvatarColor,
    required this.previewInitialColor,
  });

  final ThemeProductType type;
  final String title;
  final String description;
  final String successMessage;
  final String previewLabel;
  final String previewInitial;
  final String assetPath;
  final List<Color> previewGradient;
  final String badgeText;
  final List<Color> badgeGradient;
  final List<Color> buttonGradient;
  final Color previewAvatarColor;
  final Color previewInitialColor;
}

class _PurchaseProcessDialog extends StatefulWidget {
  const _PurchaseProcessDialog({
    required this.onComplete,
    required this.accentColor,
  });

  final VoidCallback onComplete;
  final Color accentColor;

  @override
  State<_PurchaseProcessDialog> createState() => _PurchaseProcessDialogState();
}

class _PurchaseProcessDialogState extends State<_PurchaseProcessDialog> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Applying Theme...',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please hold on while we configure the theme for your posts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
