import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/conversation_theme.dart';
import '../services/feed_service.dart';
import '../models/user.dart';
import '../widgets/user_avatar_with_frame.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../widgets/profile_effect_widget.dart';
import 'wallet_screen.dart';

export '../models/theme_product.dart';
import '../models/theme_product.dart';
import '../config/postcard_nameplates_data.dart';

const List<ThemeProductData> themeProducts = [
  ThemeProductData(
    type: ThemeProductType.starlightWhales,
    title: 'Starlight Whales',
    description:
        'Majestic cosmic whales gliding gracefully across starry celestial skies inline with your postcard header.',
    successMessage:
        'The Starlight Whales postcard theme is now active on your account! Your posts now feature the animated starlight whales.',
    previewLabel: 'you',
    previewInitial: '🐋',
    assetPath: 'https://media.katsklub.top/postcard/starlight-whales.webp',
    previewGradient: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
      Color(0xFF334155),
      Colors.white,
    ],
    badgeText: 'ANIMATED',
    badgeGradient: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    buttonGradient: [Color(0xFF06B6D4), Color(0xFF2563EB)],
    previewAvatarColor: Color(0xFFE0F2FE),
    previewInitialColor: Color(0xFF0284C7),
    price: 399.0,
    isAnimatedPostcard: true,
  ),
  ...discordNameplateThemes,
  ThemeProductData(
    type: ThemeProductType.bubbleDream,
    title: 'Chat Bubble - Bubble Dream Skin',
    description:
        'Stylize your direct messages with beautiful pink-to-violet gradient bubble chat messages.',
    successMessage:
        'The Bubble Dream Chat Bubble Skin is now active on your account! Your direct messages will feature the premium gradient chat bubbles.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: '',
    previewGradient: [
      Color(0xFFF5F3FF),
      Color(0xFFE9D5FF),
      Color(0xFFF3E8FF),
      Colors.white,
    ],
    badgeText: 'NEW BUBBLE SKIN',
    badgeGradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    buttonGradient: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    previewAvatarColor: Color(0xFFF5F3FF),
    previewInitialColor: Color(0xFF8B5CF6),
  ),
  ThemeProductData(
    type: ThemeProductType.sagittariusBubble,
    title: 'Chat Bubble - Sagittarius Celestial Skin',
    description:
        'Transform your direct messages with glowing golden Sagittarius celestial bubbles, animated wing-and-bow ornaments, and radiant crystal details.',
    successMessage:
        'The Sagittarius Celestial Chat Bubble Skin is now active on your account! Your direct messages will feature the animated celestial chat bubbles.',
    previewLabel: 'you',
    previewInitial: 'Y',
    assetPath: 'assets/chatbubble/sagittarius_bubble.png',
    previewGradient: [
      Color(0xFF161128),
      Color(0xFF261D3D),
      Color(0xFF381F66),
      Colors.white,
    ],
    badgeText: 'VIP ANIMATED',
    badgeGradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    buttonGradient: [Color(0xFFF59E0B), Color(0xFFB45309)],
    previewAvatarColor: Color(0xFFFEF3C7),
    previewInitialColor: Color(0xFFB45309),
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

  User? _currentUser;
  int _activeTabIndex = 0; // 0 = Themes, 1 = Owned Items
  String _appliedPostcardTheme = '';
  String _appliedBubbleTheme = '';
  String _currentUsername = '';
  bool _isThemeStateLoading = true;
  List<ThemeProductData> _visibleProducts = [];
  ThemeProductData? _selectedTheme;
  String _equippedAdminFrame = 'none';

  List<Map<String, dynamic>> _dynamicFrames = [];
  List<String> _dynamicCategories = ['All'];
  String _selectedFrameCategory = 'All';
  bool _isLoadingFrames = false;

  // Profile Effects & KatsCoins State
  double _coinsBalance = 0.0;
  List<Map<String, dynamic>> _profileEffects = [];
  Set<String> _ownedEffectKeys = {};
  String _equippedProfileEffect = 'none';
  Map<String, dynamic>? _selectedEffect;
  bool _isLoadingEffects = false;
  bool _isPurchasingEffect = false;
  int _previewIntroSeed = 0;

  Future<void> _fetchDynamicFrames() async {
    setState(() => _isLoadingFrames = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.framesPath}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && mounted) {
          setState(() {
            _dynamicFrames = List<Map<String, dynamic>>.from(data['frames'] ?? []);
            _dynamicCategories = List<String>.from(data['categories'] ?? ['All']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching dynamic frames: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFrames = false);
    }
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return;
      final res = await http.get(
        ApiConfig.uri('/api/wallet'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _coinsBalance = (data['coins_balance'] as num?)?.toDouble() ??
                ((data['balanceCents'] as num?)?.toDouble() ?? 0.0) / 100.0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching wallet balance: $e');
    }
  }

  Future<void> _fetchProfileEffects() async {
    setState(() => _isLoadingEffects = true);
    try {
      final token = await _authService.getToken();
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http.get(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.effectsPath}'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && mounted) {
          final List<Map<String, dynamic>> effectsList =
              List<Map<String, dynamic>>.from(data['effects'] ?? []);
          final List<String> owned =
              List<String>.from(data['ownedKeys'] ?? []);
          final String equipped = data['equippedKey']?.toString() ?? 'none';

          unawaited(ProfileEffectConfig.saveToLocalCache(effectsList));
          for (final e in effectsList) {
            ProfileEffectConfig.registerFromMap(e);
          }

          setState(() {
            _profileEffects = effectsList;
            _ownedEffectKeys = owned.toSet();
            if (equipped != 'none' && equipped.isNotEmpty) {
              _equippedProfileEffect = equipped;
            }

            if (_selectedEffect == null && effectsList.isNotEmpty) {
              _selectedEffect = effectsList.firstWhere(
                (e) => e['key'] == _equippedProfileEffect,
                orElse: () => effectsList.first,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile effects: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEffects = false);
    }
  }

  Future<void> _buyProfileEffect(Map<String, dynamic> effect) async {
    final effectKey = effect['key']?.toString() ?? '';
    final price = (effect['price'] as num?)?.toDouble() ?? 0.0;

    if (_coinsBalance < price) {
      _showInsufficientCoinsDialog(price, _coinsBalance);
      return;
    }

    final confirmed = await _showBuyConfirmationDialog(effect);
    if (confirmed != true || !mounted) return;

    setState(() => _isPurchasingEffect = true);
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in to make a purchase.');
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.effectsPath}/buy'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'effectKey': effectKey}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        final newBal = (data['newBalance'] as num?)?.toDouble() ??
            (_coinsBalance - price);

        setState(() {
          _coinsBalance = newBal;
          _ownedEffectKeys.add(effectKey);
          _equippedProfileEffect = effectKey;
          if (data['user'] is Map<String, dynamic>) {
            _currentUser = User.fromJson(data['user']);
          }
        });

        if (_currentUser != null) {
          await _authService.saveCurrentUser(_currentUser!);
          final username = _currentUser!.username?.trim().toLowerCase() ?? '';
          if (username.isNotEmpty) {
            FeedService.notifyProfileStatsChanged(username: username, user: _currentUser);
          }
        }

        if (mounted) {
          _showEffectPurchaseSuccessDialog(effect);
        }
      } else {
        final err = data['error'] ?? 'Purchase failed. Please try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error purchasing effect: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasingEffect = false);
    }
  }

  Future<void> _toggleEquipEffect(String effectKey, String effectName) async {
    final isAlreadyEquipped = _equippedProfileEffect == effectKey;
    final targetKey = isAlreadyEquipped ? 'none' : effectKey;

    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return;

      final res = await http.post(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.effectsPath}/equip'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'effectKey': targetKey}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        setState(() {
          _equippedProfileEffect = targetKey;
          if (data['user'] is Map<String, dynamic>) {
            _currentUser = User.fromJson(data['user']);
          }
        });

        if (_currentUser != null) {
          await _authService.saveCurrentUser(_currentUser!);
          final username = _currentUser!.username?.trim().toLowerCase() ?? '';
          if (username.isNotEmpty) {
            FeedService.notifyProfileStatsChanged(username: username, user: _currentUser);
          }
        }

        final msg = isAlreadyEquipped
            ? 'Profile effect unequipped.'
            : '$effectName equipped to your profile!';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: isAlreadyEquipped
                  ? const Color(0xFF4B5563)
                  : const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final err = data['error'] ?? 'Failed to update profile effect.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString()),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling profile effect: $e');
    }
  }

  void _showInsufficientCoinsDialog(double required, double current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Text('🪙', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Not Enough Coins',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This effect costs ${required.toStringAsFixed(0)} KC, but your current balance is ${current.toStringAsFixed(0)} KC.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You need ${(required - current).toStringAsFixed(0)} more KatsCoins to unlock this effect.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final user = _currentUser ?? User(id: '0', username: _currentUsername, raw: const {});
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WalletScreen(user: user)),
              ).then((_) => _fetchWalletBalance());
            },
            child: const Text('Top Up Coins', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showBuyConfirmationDialog(Map<String, dynamic> effect) {
    final name = effect['name']?.toString() ?? 'Profile Effect';
    final price = (effect['price'] as num?)?.toDouble() ?? 0.0;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.shopping_bag_rounded, color: Color(0xFF22C55E)),
            SizedBox(width: 8),
            Text(
              'Unlock Effect',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to unlock "$name" for ${price.toStringAsFixed(0)} KatsCoins?',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Once unlocked, it will be added to your account permanently and equipped to your profile.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unlock (${price.toStringAsFixed(0)} KC)', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEffectPurchaseSuccessDialog(Map<String, dynamic> effect) {
    final name = effect['name']?.toString() ?? 'Profile Effect';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$name Unlocked!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Awesome! This profile effect is now active on your profile and stored in your inventory.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _equipAdminFrame(String framePath, String frameName) async {
    final prefs = await SharedPreferences.getInstance();
    if (framePath != 'none') {
      await prefs.setString('admin_equipped_frame', framePath);
    } else {
      await prefs.remove('admin_equipped_frame');
    }

    // Instantly notify ProfileScreen and all avatar frame listeners in real time!
    equippedAdminFrameNotifier.value = framePath;

    if (!mounted) return;

    setState(() {
      _equippedAdminFrame = framePath;
    });

    final isRemoved = framePath == 'none';
    final msg = isRemoved
        ? 'Avatar frame removed from your profile!'
        : '$frameName equipped successfully!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isRemoved ? const Color(0xFF4B5563) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Sync with backend PostgreSQL database so all users see the equipped frame!
    try {
      final updatedUser = await _feedService.updateCurrentUserAvatarFrame(framePath);
      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
        });
      }
    } catch (e) {
      debugPrint('Error syncing avatar frame with server: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadThemeState();
    _fetchDynamicFrames();
    _fetchWalletBalance();
    _fetchProfileEffects();
  }

  void _switchTab(int index) {
    if (_activeTabIndex == index) return;
    setState(() {
      _activeTabIndex = index;
      if (index == 0) {
        ThemeProductData? selected;
        final postcards = _visibleProducts.where((p) => !_isBubbleProduct(p)).toList();
        for (final p in postcards) {
          if (_themeKeyFor(p) == _appliedPostcardTheme) {
            selected = p;
            break;
          }
        }
        _selectedTheme = selected ?? (postcards.isNotEmpty ? postcards.first : null);
      } else if (index == 1) {
        if (_profileEffects.isNotEmpty && _selectedEffect == null) {
          _selectedEffect = _profileEffects.firstWhere(
            (e) => e['key'] == _equippedProfileEffect,
            orElse: () => _profileEffects.first,
          );
        }
      } else if (index == 2) {
        ThemeProductData? selected;
        for (final p in _visibleProducts) {
          if (_isBubbleProduct(p) && _themeKeyFor(p) == _appliedBubbleTheme) {
            selected = p;
            break;
          }
        }
        _selectedTheme = selected ??
            _visibleProducts.firstWhere(
              (p) => _isBubbleProduct(p),
              orElse: () => _visibleProducts.first,
            );
      }
    });
  }

  bool _isGeminiOnly(ThemeProductType type) {
    return type == ThemeProductType.geminiRogerHunter ||
        type == ThemeProductType.geminiRogerWolf;
  }

  bool _canApplyTheme(dynamic item) {
    final type = item is ThemeProductData ? item.type : item as ThemeProductType;
    final isJayrielOrAdmin = _currentUsername == 'jayriel' ||
        _currentUser?.id == '2' ||
        (_currentUser?.isAdmin ?? false);
    if (isJayrielOrAdmin) {
      return true;
    }
    if (_isGeminiOnly(type)) {
      return _currentUsername == 'gemini';
    }
    if (_isBubbleProduct(type)) {
      return false; // Locked for regular users in shop
    }
    return true;
  }

  String _themeKeyFor(dynamic item) {
    if (item is ThemeProductData) return item.key;
    if (item is ThemeProductType) return ThemeProductData.defaultKeyForType(item);
    return item.toString();
  }

  bool _isBubbleProduct(dynamic item) {
    final type = item is ThemeProductData ? item.type : item as ThemeProductType;
    return type == ThemeProductType.bubbleDream ||
        type == ThemeProductType.sagittariusBubble;
  }

  bool _isApplied(dynamic item) {
    final key = item is ThemeProductData ? item.key : _themeKeyFor(item);
    final isBubble = item is ThemeProductData
        ? _isBubbleProduct(item.type)
        : (item is ThemeProductType ? _isBubbleProduct(item) : false);
    if (isBubble) {
      return _appliedBubbleTheme == key;
    }
    return _appliedPostcardTheme == key;
  }

  Future<void> _loadThemeState() async {
    final user = await _authService.getSavedUser();

    final disabledSet = <String>{};
    try {
      final url = Uri.parse('${ApiConfig.apiBaseUrl}/api/shop/themes');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> disabled = data['disabledThemes'] ?? [];
        for (final item in disabled) {
          disabledSet.add(item.toString().trim().toLowerCase());
        }
      }
    } catch (_) {}

    final visible = <ThemeProductData>[];
    for (final product in themeProducts) {
      final themeKey = _themeKeyFor(product).trim().toLowerCase();
      final isPublic = !disabledSet.contains(themeKey);
      if (isPublic) {
        visible.add(product);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = user;
      _appliedPostcardTheme = (user?.postcardTheme ?? '').trim().toLowerCase();
      _appliedBubbleTheme = (user?.bubbleTheme ?? '').trim().toLowerCase();
      _currentUsername = (user?.username ?? '').trim().toLowerCase();
      _visibleProducts = visible;

      final serverFrame = user?.avatarFrame?.trim();
      if (serverFrame != null && serverFrame.isNotEmpty && serverFrame != 'none') {
        _equippedAdminFrame = serverFrame;
        equippedAdminFrameNotifier.value = serverFrame;
      } else {
        _equippedAdminFrame = 'none';
        equippedAdminFrameNotifier.value = 'none';
      }

      final currentEffect = user?.profileEffect?.trim();
      if (currentEffect != null && currentEffect.isNotEmpty && currentEffect != 'none') {
        _equippedProfileEffect = currentEffect;
      }

      // Initialize selected theme for live preview
      ThemeProductData? selected;
      if (_appliedPostcardTheme.isNotEmpty) {
        for (final p in visible) {
          if (!_isBubbleProduct(p) && _themeKeyFor(p) == _appliedPostcardTheme) {
            selected = p;
            break;
          }
        }
      }
      if (selected == null && _appliedBubbleTheme.isNotEmpty) {
        for (final p in visible) {
          if (_isBubbleProduct(p) && _themeKeyFor(p) == _appliedBubbleTheme) {
            selected = p;
            break;
          }
        }
      }
      _selectedTheme = selected ?? (visible.isNotEmpty ? visible.first : null);

      _isThemeStateLoading = false;
    });
  }

  Future<void> _setApplied(dynamic target, bool applied) async {
    final key = target is ThemeProductData ? target.key : _themeKeyFor(target);
    final isBubble = target is ThemeProductData
        ? _isBubbleProduct(target.type)
        : (target is ThemeProductType ? _isBubbleProduct(target) : false);
    if (isBubble) {
      final themeVal = applied ? key : '';
      final updatedUser = await _feedService.updateCurrentUserBubbleTheme(themeVal);
      await ConversationThemeStore.setGlobalBubbleTheme(themeVal);
      if (!mounted) return;
      setState(() {
        _appliedBubbleTheme = (updatedUser.bubbleTheme ?? '').trim().toLowerCase();
        _isThemeStateLoading = false;
      });
    } else {
      final themeVal = applied ? key : '';
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
              await _setApplied(theme, true);
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

    if (!_canApplyTheme(theme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This postcard theme is Gemini-only.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final isApplied = _isApplied(theme);
    if (isApplied) {
      try {
        await _setApplied(theme, false);
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

    if (theme.price > 0 && _coinsBalance < theme.price) {
      _showInsufficientCoinsDialog(theme.price, _coinsBalance);
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

    if (_isBubbleProduct(selected.type)) {
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
                  else if (selected.type == ThemeProductType.starlightWhales || selected.isAnimatedPostcard)
                    Positioned(
                      right: 0,
                      top: 14,
                      height: 28,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CachedNetworkImage(
                            imageUrl: selected.assetPath,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (_, __) => const SizedBox(),
                            errorWidget: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ),
                    )
                  else if (selected.assetPath.isNotEmpty)
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
                        child: CachedNetworkImage(
                          imageUrl: '${ApiConfig.postcardUrl(selected.assetPath)}',
                          placeholder: (context, url) => const SizedBox(),
                          errorWidget: (context, url, error) => Image.asset(selected.assetPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
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
    final isSagittarius = selected.type == ThemeProductType.sagittariusBubble;

    final bgColor = isSagittarius ? const Color(0xFF161128) : const Color(0xFFF5F3FF);
    final headerBg = isSagittarius ? const Color(0xFF211938) : Colors.white.withOpacity(0.95);
    final headerTextColor = isSagittarius ? Colors.white : const Color(0xFF111827);
    final headerBorderColor = isSagittarius ? const Color(0xFF322554) : Colors.grey.shade100;
    final accentColor = isSagittarius ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: bgColor,
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
              color: headerBg,
              border: Border(bottom: BorderSide(color: headerBorderColor)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isSagittarius ? const Color(0xFFFEF3C7) : Colors.purple.shade100,
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSagittarius ? const Color(0xFFB45309) : Colors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini',
                  style: TextStyle(
                    color: headerTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: isSagittarius ? Colors.white54 : Colors.grey,
                ),
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
                        color: isSagittarius ? const Color(0xFF261D3D) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSagittarius
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                              : Colors.purple.shade50,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isSagittarius
                            ? 'Sagittarius Celestial Theme equipped! 🏹✨'
                            : 'Hi! How is the new chat bubble theme? 💬',
                        style: TextStyle(
                          color: isSagittarius ? const Color(0xFFFDE68A) : const Color(0xFF4C1D95),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: isSagittarius
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/chatbubble/sagittarius_bubble.png'),
                                    centerSlice: Rect.fromLTRB(35, 25, 225, 55),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                child: const Text(
                                  'Super glowing and celestial! 🪐✨',
                                  style: TextStyle(
                                    color: Color(0xFF381E00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -14,
                                right: -12,
                                child: IgnorePointer(
                                  child: Image.asset(
                                    'assets/chatbubble/sagittarius_top_right.webp',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -10,
                                left: -10,
                                child: IgnorePointer(
                                  child: Image.asset(
                                    'assets/chatbubble/sagittarius_bottom_left.webp',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
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
            color: isSagittarius ? const Color(0xFF211938) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSagittarius ? const Color(0xFF161128) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Type a message...',
                      style: TextStyle(
                        color: isSagittarius ? Colors.white38 : Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.send, color: accentColor, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, ThemeProductData selected) {
    final isApplied = _isApplied(selected);
    final isLocked = !_canApplyTheme(selected);
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
                            : (selected.price > 0
                                ? 'Unlock (${selected.price.toStringAsFixed(0)} KC)'
                                : 'Apply Theme'),
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

  Widget _buildAdminFrameCard({
    required String avatarUrl,
    required String initials,
    required String title,
    required String description,
    required String? framePath,
    required String badgeText,
    required List<Color> badgeGradient,
    required bool isEquipped,
    required VoidCallback onEquip,
    required VoidCallback onUnequip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEquipped ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
          width: isEquipped ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isEquipped
                ? const Color(0xFFF59E0B).withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: isEquipped ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatarWithFrame(
            avatarUrl: avatarUrl,
            initials: initials,
            radius: 32.0,
            framePath: framePath,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: badgeGradient),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isEquipped) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'EQUIPPED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onUnequip,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Text(
                            'Unequip',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: onEquip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA855F7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Equip Frame',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEffectCard({
    required String title,
    required String description,
    required String effectKey,
    required String previewUrl,
    required String badgeText,
    required List<Color> badgeGradient,
    required bool isEquipped,
    required VoidCallback onEquip,
    required VoidCallback onUnequip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEquipped ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
          width: isEquipped ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isEquipped
                ? const Color(0xFF22C55E).withOpacity(0.18)
                : Colors.black.withOpacity(0.04),
            blurRadius: isEquipped ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: Colors.white24,
                ),
                Image.network(
                  previewUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF22C55E),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: badgeGradient),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (isEquipped) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Equipped',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onUnequip,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Unequip',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: onEquip,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Equip Effect',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedItemsTab() {
    final isAdmin = _currentUser?.isAdmin ?? false;
    final avatarUrl = _currentUser?.avatarUrl ?? '';
    final initials = _currentUser?.initials ?? 'U';

    final filteredDynamicFrames = _selectedFrameCategory == 'All'
        ? _dynamicFrames
        : _dynamicFrames.where((f) => f['category'] == _selectedFrameCategory).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Avatar Frames & Accessories',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            if (_dynamicFrames.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${filteredDynamicFrames.length} items',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Chips
        if (_dynamicCategories.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _dynamicCategories.map((cat) {
                final isSelected = cat == _selectedFrameCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF8B5CF6).withOpacity(0.18),
                    backgroundColor: const Color(0xFFF3F4F6),
                    checkmarkColor: const Color(0xFF8B5CF6),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF4B5563),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() => _selectedFrameCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Loading indicator
        if (_isLoadingFrames && _dynamicFrames.isEmpty) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            ),
          ),
        ],

        // Dynamic Frames from Cloudflare R2 / API
        for (final frame in filteredDynamicFrames) ...[
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: frame['name'] ?? 'Frame',
            description: frame['description'] ?? 'Animated avatar decoration frame.',
            framePath: frame['frameUrl'],
            badgeText: (frame['category'] ?? 'FRAME').toString().toUpperCase(),
            badgeGradient: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            isEquipped: _equippedAdminFrame == frame['frameUrl'] ||
                _equippedAdminFrame == frame['key'] ||
                _currentUser?.avatarFrame == frame['frameUrl'],
            onEquip: () => _equipAdminFrame(frame['frameUrl'], frame['name'] ?? 'Frame'),
            onUnequip: () => _equipAdminFrame('none', frame['name'] ?? 'Frame'),
          ),
          const SizedBox(height: 12),
        ],

        if (isAdmin) ...[
          // Option: Cyber Neon Pulse Frame (neon.json)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Cyber Neon Pulse Frame',
            description: 'Futuristic rotating purple accent & electric cyan glowing neon Lottie frame.',
            framePath: 'assets/frames/neon.json',
            badgeText: 'CYBER LOTTIE',
            badgeGradient: const [Color(0xFF00F0FF), Color(0xFFD946EF)],
            isEquipped: _equippedAdminFrame == 'assets/frames/neon.json',
            onEquip: () => _equipAdminFrame('assets/frames/neon.json', 'Cyber Neon Pulse Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Cyber Neon Pulse Frame'),
          ),
          const SizedBox(height: 12),

          // Option: Floating Hearts Animated Frame (heart_512.webp)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Floating Hearts Animated Frame',
            description: 'Adorable animated floating pink hearts with center pop animation streamed from Cloudflare R2.',
            framePath: 'https://media.katsklub.top/frames/heart_512.webp',
            badgeText: 'SWEET HEARTS',
            badgeGradient: const [Color(0xFFFF2D55), Color(0xFFFF69B4)],
            isEquipped: _equippedAdminFrame == 'https://media.katsklub.top/frames/heart_512.webp' ||
                _equippedAdminFrame == 'https://media.katsklub.top/frames/heart%20512%20optimized.webp',
            onEquip: () => _equipAdminFrame('https://media.katsklub.top/frames/heart_512.webp', 'Floating Hearts Animated Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Floating Hearts Animated Frame'),
          ),
          const SizedBox(height: 12),

          // Option: Magical Potion Animated Frame (magical_potion.webp)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Magical Potion Animated Frame',
            description: 'Translucent crystal flask with bubbling purple potion, popping cork & magical aura clouds.',
            framePath: 'https://media.katsklub.top/frames/magical_potion.webp',
            badgeText: 'MAGICAL POTION',
            badgeGradient: const [Color(0xFF9333EA), Color(0xFFC084FC)],
            isEquipped: _equippedAdminFrame == 'https://media.katsklub.top/frames/magical_potion.webp' ||
                _equippedAdminFrame == 'magical_potion.webp',
            onEquip: () => _equipAdminFrame('https://media.katsklub.top/frames/magical_potion.webp', 'Magical Potion Animated Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Magical Potion Animated Frame'),
          ),
          const SizedBox(height: 12),

          // Option: Purple Kawaii Animated Frame (purpleav.webp)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Purple Kawaii Animated Frame',
            description: 'Exclusive animated purple ribbon frame with sparkling accents & peeking eyes.',
            framePath: 'assets/frames/purpleav.webp',
            badgeText: 'NEW KAWAII',
            badgeGradient: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
            isEquipped: _equippedAdminFrame == 'assets/frames/purpleav.webp',
            onEquip: () => _equipAdminFrame('assets/frames/purpleav.webp', 'Purple Kawaii Animated Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Purple Kawaii Animated Frame'),
          ),
          const SizedBox(height: 12),

          // Option 0: Spring Master Blossom Frame (spring_blossom_frame.webp)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Spring Master Blossom Frame',
            description: 'Exclusive 60FPS animated floral & golden antlers frame.',
            framePath: 'assets/frames/spring_blossom_frame.webp',
            badgeText: 'SPRING SPECIAL',
            badgeGradient: const [Color(0xFF10B981), Color(0xFFF59E0B)],
            isEquipped: _equippedAdminFrame == 'assets/frames/spring_blossom_frame.webp',
            onEquip: () => _equipAdminFrame('assets/frames/spring_blossom_frame.webp', 'Spring Master Blossom Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Spring Master Blossom Frame'),
          ),
          const SizedBox(height: 12),

          // Option 0.5: Tropical Beach SVGA Frame (beach-frame.svga)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Tropical Beach SVGA Frame',
            description: 'Exclusive 30FPS animated summer beach & ocean SVGA frame.',
            framePath: 'assets/frames/beach-frame.svga',
            badgeText: 'SVGA BEACH',
            badgeGradient: const [Color(0xFF06B6D4), Color(0xFFF59E0B)],
            isEquipped: _equippedAdminFrame == 'assets/frames/beach-frame.svga',
            onEquip: () => _equipAdminFrame('assets/frames/beach-frame.svga', 'Tropical Beach SVGA Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Tropical Beach SVGA Frame'),
          ),
          const SizedBox(height: 12),

          // Option 0.6: Kawaii Cat Blossom SVGA Frame (kawaii2.svga)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Kawaii Cat Blossom SVGA Frame',
            description: 'Exclusive 60FPS animated cute kitty & falling sakura petals SVGA frame.',
            framePath: 'assets/frames/kawaii2.svga',
            badgeText: 'SVGA KAWAII',
            badgeGradient: const [Color(0xFFEC4899), Color(0xFFF43F5E)],
            isEquipped: _equippedAdminFrame == 'assets/frames/kawaii2.svga' ||
                _equippedAdminFrame == 'https://media.katsklub.top/frames/kawaii2.svga',
            onEquip: () => _equipAdminFrame('assets/frames/kawaii2.svga', 'Kawaii Cat Blossom SVGA Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Kawaii Cat Blossom SVGA Frame'),
          ),
          const SizedBox(height: 12),

          // Option 0.7: Golden Angel Ornament SVGA Frame (orna.svga)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Golden Angel Ornament SVGA Frame',
            description: 'Exclusive 30FPS animated golden crescent with fairy angel & stars.',
            framePath: 'assets/frames/orna.svga',
            badgeText: 'SVGA ORNAMENT',
            badgeGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            isEquipped: _equippedAdminFrame == 'assets/frames/orna.svga' ||
                _equippedAdminFrame == 'https://media.katsklub.top/frames/orna.svga',
            onEquip: () => _equipAdminFrame('assets/frames/orna.svga', 'Golden Angel Ornament SVGA Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Golden Angel Ornament SVGA Frame'),
          ),
          const SizedBox(height: 12),

          // Option 1: Golden Admin Frame (bframe.png)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Golden Admin Frame',
            description: 'Exclusive VIP animated frame (bframe.png).',
            framePath: 'assets/frames/bframe.png',
            badgeText: 'GOLDEN VIP',
            badgeGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            isEquipped: _equippedAdminFrame == 'assets/frames/bframe.png',
            onEquip: () => _equipAdminFrame('assets/frames/bframe.png', 'Golden Admin Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Golden Admin Frame'),
          ),
          const SizedBox(height: 12),

          // Option 2: Angel Wings Lottie Frame (wing_frame.json)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Angel Wings Lottie Frame',
            description: 'Exclusive Lottie animated wing frame (wing_frame.json).',
            framePath: 'assets/frames/wing_frame.json',
            badgeText: 'LOTTIE WINGS',
            badgeGradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            isEquipped: _equippedAdminFrame == 'assets/frames/wing_frame.json',
            onEquip: () => _equipAdminFrame('assets/frames/wing_frame.json', 'Angel Wings Lottie Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Angel Wings Lottie Frame'),
          ),
          const SizedBox(height: 12),

          // Option 3: Neon Sparkle Lottie Frame (test_frame.json)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Neon Sparkle Lottie Frame',
            description: 'Exclusive Lottie animated sparkle frame (test_frame.json).',
            framePath: 'assets/frames/test_frame.json',
            badgeText: 'NEON LOTTIE',
            badgeGradient: const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
            isEquipped: _equippedAdminFrame == 'assets/frames/test_frame.json',
            onEquip: () => _equipAdminFrame('assets/frames/test_frame.json', 'Neon Sparkle Lottie Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Neon Sparkle Lottie Frame'),
          ),
          const SizedBox(height: 12),

          // Option 3: Classic Frame (aframe.png)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Classic Frame',
            description: 'Classic animated frame overlay (aframe.png).',
            framePath: 'assets/frames/aframe.png',
            badgeText: 'CLASSIC',
            badgeGradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            isEquipped: _equippedAdminFrame == 'assets/frames/aframe.png',
            onEquip: () => _equipAdminFrame('assets/frames/aframe.png', 'Classic Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Classic Frame'),
          ),
          const SizedBox(height: 12),

          // Option 4: Cyber Crystal Frame (cframe.png)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'Cyber Crystal Frame',
            description: 'Exclusive Cyber Crystal VIP frame overlay (cframe.png).',
            framePath: 'assets/frames/cframe.png',
            badgeText: 'CYBER VIP',
            badgeGradient: const [Color(0xFF06B6D4), Color(0xFF0284C7)],
            isEquipped: _equippedAdminFrame == 'assets/frames/cframe.png',
            onEquip: () => _equipAdminFrame('assets/frames/cframe.png', 'Cyber Crystal Frame'),
            onUnequip: () => _equipAdminFrame('none', 'Cyber Crystal Frame'),
          ),
          const SizedBox(height: 12),

          // Option 5: Remove Avatar Frame (none)
          _buildAdminFrameCard(
            avatarUrl: avatarUrl,
            initials: initials,
            title: 'No Avatar Frame',
            description: 'Display profile photo without any frame overlay.',
            framePath: null,
            badgeText: 'NORMAL',
            badgeGradient: const [Color(0xFF6B7280), Color(0xFF4B5563)],
            isEquipped: _equippedAdminFrame == 'none',
            onEquip: () => _equipAdminFrame('none', 'No Frame'),
            onUnequip: () => _equipAdminFrame('assets/frames/bframe.png', 'Golden Admin Frame'),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.8)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.interests_outlined,
                    size: 32,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No owned avatar frames yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your inventory currently has 0 avatar frames. Check out KatShop for exclusive upcoming drops!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Profile Effects',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW FEATURE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Profile Effects in Inventory
        if (_profileEffects.isNotEmpty) ...[
          for (final effect in _profileEffects)
            if (_ownedEffectKeys.contains(effect['key']) ||
                _currentUser?.username == 'jayriel' ||
                _currentUser?.id == '2' ||
                (_currentUser?.isAdmin ?? false) ||
                effect['key'] == 'zombie_slime')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildProfileEffectCard(
                  title: effect['name']?.toString() ?? 'Profile Effect',
                  description: effect['description']?.toString() ?? '',
                  effectKey: effect['key']?.toString() ?? '',
                  previewUrl: effect['loopUrl']?.toString() ?? '',
                  badgeText: effect['name']?.toString().toUpperCase() ?? 'EFFECT',
                  badgeGradient: _getEffectBadgeGradient(effect['key']?.toString() ?? ''),
                  isEquipped: _equippedProfileEffect == effect['key'] ||
                      _currentUser?.profileEffect == effect['key'],
                  onEquip: () => _toggleEquipEffect(effect['key']?.toString() ?? '', effect['name']?.toString() ?? 'Profile Effect'),
                  onUnequip: () => _toggleEquipEffect('none', effect['name']?.toString() ?? 'Profile Effect'),
                ),
              ),
        ] else ...[
          _buildProfileEffectCard(
            title: 'Zombie Slime',
            description: 'Animated glowing toxic slime dripping over profile with bubbling green toxic particles.',
            effectKey: 'zombie_slime',
            previewUrl: 'https://media.katsklub.top/effects/zombie-slime/loop_v2.webp',
            badgeText: 'ZOMBIE SLIME',
            badgeGradient: const [Color(0xFF22C55E), Color(0xFF10B981)],
            isEquipped: _equippedProfileEffect == 'zombie_slime' ||
                _currentUser?.profileEffect == 'zombie_slime' ||
                _currentUser?.profileEffect == 'zombie-slime',
            onEquip: () => _toggleEquipEffect('zombie_slime', 'Zombie Slime'),
            onUnequip: () => _toggleEquipEffect('none', 'Zombie Slime'),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEffectsTab() {
    return Column(
      children: [
        // Live Effect Preview Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Live Profile Preview',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (_selectedEffect != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getEffectBadgeGradient(_selectedEffect!['key']?.toString() ?? ''),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedEffect!['isVip'] == true ? 'VIP EFFECT' : 'ANIMATED',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildLiveEffectPreviewCard(_selectedEffect),
            ],
          ),
        ),

        // Available Effects List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Available Effects',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                '${_profileEffects.length} effects',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Effects List
        Expanded(
          child: _isLoadingEffects
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF22C55E),
                  ),
                )
              : _profileEffects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No profile effects available yet.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _profileEffects.length,
                      itemBuilder: (context, index) {
                        final effect = _profileEffects[index];
                        final effectKey = effect['key']?.toString() ?? '';
                        final isSelected = _selectedEffect?['key'] == effectKey;
                        final isEquipped = _equippedProfileEffect == effectKey;
                        final isOwned = _ownedEffectKeys.contains(effectKey);

                        return _EffectListItem(
                          effect: effect,
                          isSelected: isSelected,
                          isEquipped: isEquipped,
                          isOwned: isOwned,
                          onTap: () {
                            setState(() {
                              _selectedEffect = effect;
                              _previewIntroSeed = DateTime.now().millisecondsSinceEpoch;
                            });
                          },
                        );
                      },
                    ),
        ),

        // Bottom Action Bar
        if (_selectedEffect != null)
          _buildEffectBottomActionBar(context, _selectedEffect!),
      ],
    );
  }

  List<Color> _getEffectBackdropColors(String effectKey) {
    final k = effectKey.toLowerCase().replaceAll('-', '_');
    switch (k) {
      case 'cloud_nine':
        return const [Color(0xFF1E1B4B), Color(0xFF311042), Color(0xFF4C0519)];
      case 'falling_stars':
        return const [Color(0xFF0B0F19), Color(0xFF0C1938), Color(0xFF1E1B4B)];
      case 'la_llorona':
        return const [Color(0xFF0F0F1A), Color(0xFF1C1335), Color(0xFF2E1065)];
      case 'boost_relic':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF451A03)];
      case 'cyberspace':
        return const [Color(0xFF030712), Color(0xFF042F2E), Color(0xFF083344)];
      case 'hydro_blast':
        return const [Color(0xFF082F49), Color(0xFF0C4A6E), Color(0xFF0369A1)];
      case 'shatter':
        return const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF2E1065)];
      case 'magic_hearts':
        return const [Color(0xFF1E1B4B), Color(0xFF4C0519), Color(0xFF701A75)];
      case 'sakura_dreams':
        return const [Color(0xFF1F1D2B), Color(0xFF3B1E32), Color(0xFF501934)];
      case 'power_surge':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF422006)];
      case 'shuriken_strike':
        return const [Color(0xFF0A0A0A), Color(0xFF1C1917), Color(0xFF450A0A)];
      case 'mystic_vines':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF065F46)];
      case 'pixie_dust':
        return const [Color(0xFF1C1917), Color(0xFF451A03), Color(0xFF78350F)];
      case 'discord_os':
        return const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)];
      case 'breakfast_plate':
        return const [Color(0xFF1C1917), Color(0xFF431407), Color(0xFF7C2D12)];
      case 'ghoulish_graffiti':
        return const [Color(0xFF09090B), Color(0xFF18181B), Color(0xFF3B0764)];
      case 'dark_omens':
        return const [Color(0xFF09090B), Color(0xFF1C1917), Color(0xFF450A0A)];
      case 'fall_foliage':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF451A03)];
case 'all_nighter':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF451A03)];
      case 'arcane_summons':
        return const [Color(0xFF0F0B1E), Color(0xFF1E1035), Color(0xFF3B0764)];
      case 'clove_s_ruse':
        return const [Color(0xFF160D27), Color(0xFF28114B), Color(0xFF4C1D95)];
      case 'deck_the_halls':
        return const [Color(0xFF052E16), Color(0xFF14532D), Color(0xFF7F1D1D)];
      case 'doodlebob_takeover':
        return const [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF3F3F46)];
      case 'dragon_dance':
        return const [Color(0xFF450A0A), Color(0xFF7F1D1D), Color(0xFF9A3412)];
      case 'dreamy':
        return const [Color(0xFF1E1B4B), Color(0xFF2E1065), Color(0xFF4A044E)];
      case 'feelin_90s':
        return const [Color(0xFF172554), Color(0xFF3B0764), Color(0xFF701A75)];
      case 'feelin_mischievous':
        return const [Color(0xFF0A0A0A), Color(0xFF18181B), Color(0xFF14532D)];
      case 'feelin_pizzazz':
        return const [Color(0xFF1C1917), Color(0xFF451A03), Color(0xFF78350F)];
      case 'fellowship_of_the_spring':
        return const [Color(0xFF052E16), Color(0xFF064E3B), Color(0xFF065F46)];
      case 'forgotten_treasure':
        return const [Color(0xFF082F49), Color(0xFF0C4A6E), Color(0xFF451A03)];
      case 'fortune_flurry':
        return const [Color(0xFF450A0A), Color(0xFF7F1D1D), Color(0xFF78350F)];
      case 'goozilla':
        return const [Color(0xFF052E16), Color(0xFF064E3B), Color(0xFF14532D)];
      case 'handsome_squidward':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'haunted_man_o_war':
        return const [Color(0xFF064E3B), Color(0xFF0F172A), Color(0xFF022C22)];
      case 'heartzilla':
        return const [Color(0xFF4C0519), Color(0xFF701A75), Color(0xFF831843)];
      case 'jolly_roger':
        return const [Color(0xFF09090B), Color(0xFF18181B), Color(0xFF27272A)];
      case 'ki_detonate':
        return const [Color(0xFF1C1917), Color(0xFF451A03), Color(0xFF78350F)];
      case 'lilypad_life':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF065F46)];
      case 'mastery':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF78350F)];
      case 'midnight_celebration':
        return const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF3B0764)];
      case 'midnight_lilypad_life':
        return const [Color(0xFF082F49), Color(0xFF0C4A6E), Color(0xFF022C22)];
      case 'monster_pop':
        return const [Color(0xFF4A044E), Color(0xFF701A75), Color(0xFF1E1B4B)];
      case 'muddy_lilypad_life':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF14532D)];
      case 'nice_profile':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'nightrunner':
        return const [Color(0xFF0F172A), Color(0xFF3B0764), Color(0xFF701A75)];
      case 'petal_serenade':
        return const [Color(0xFF4A044E), Color(0xFF701A75), Color(0xFF831843)];
      case 'rock_slide':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF44403C)];
      case 'saya':
        return const [Color(0xFF3B0764), Color(0xFF4A044E), Color(0xFF831843)];
      case 'shooting_stars':
        return const [Color(0xFF0B0F19), Color(0xFF111827), Color(0xFF1E1B4B)];
      case 'snowy_shenanigans':
        return const [Color(0xFF082F49), Color(0xFF0C4A6E), Color(0xFF1E293B)];
      case 'space_evader':
        return const [Color(0xFF09090B), Color(0xFF18181B), Color(0xFF052E16)];
      case 'spirit_flame':
        return const [Color(0xFF082F49), Color(0xFF0C4A6E), Color(0xFF1E1B4B)];
      case 'spring_bloom':
        return const [Color(0xFF052E16), Color(0xFF064E3B), Color(0xFF1E1B4B)];
      case 'study_spot':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF1E293B)];
      case 'supernova':
        return const [Color(0xFF450A0A), Color(0xFF7F1D1D), Color(0xFF3B0764)];
      case 'sushi_mania':
        return const [Color(0xFF1C1917), Color(0xFF431407), Color(0xFF052E16)];
      case 'the_immortal_clove':
        return const [Color(0xFF1E1B4B), Color(0xFF2E1065), Color(0xFF4C1D95)];
      case 'tocotoco':
        return const [Color(0xFF4A044E), Color(0xFF701A75), Color(0xFF082F49)];
      case 'turbo_drive':
        return const [Color(0xFF09090B), Color(0xFF1C1917), Color(0xFF450A0A)];
      case 'twilight':
        return const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF2E1065)];
      case 'twinkle_trails':
        return const [Color(0xFF1C1917), Color(0xFF2E1065), Color(0xFF4C1D95)];
      case 'uplink_error':
        return const [Color(0xFF09090B), Color(0xFF18181B), Color(0xFF082F49)];
      case 'vengeance':
        return const [Color(0xFF09090B), Color(0xFF1C1917), Color(0xFF450A0A)];
      case 'vortex':
        return const [Color(0xFF09090B), Color(0xFF1E1035), Color(0xFF2E1065)];
      case 'wake_up':
        return const [Color(0xFF1C1917), Color(0xFF451A03), Color(0xFF0C4A6E)];
      case 'watercolors':
        return const [Color(0xFF0F172A), Color(0xFF0C4A6E), Color(0xFF4A044E)];
case 'akuma_s_wrath':
        return const [Color(0xFF1C0A0A), Color(0xFF380808), Color(0xFF5A0808)];
      case 'arcane_epiphany':
        return const [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF2E1065)];
      case 'aurora_dreams':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF1E1B4B)];
      case 'autumn_equinox':
        return const [Color(0xFF1C1917), Color(0xFF451A03), Color(0xFF78350F)];
      case 'beholder':
        return const [Color(0xFF180A2E), Color(0xFF2E0854), Color(0xFF4C0842)];
      case 'blazing_ghoulish_graffiti':
        return const [Color(0xFF1C0A00), Color(0xFF431407), Color(0xFF7C2D12)];
      case 'bubble_tea_bliss':
        return const [Color(0xFF1C140D), Color(0xFF382314), Color(0xFF54341B)];
      case 'bubblegum_zombie_slime':
        return const [Color(0xFF1F0B18), Color(0xFF3D1030), Color(0xFF5E1449)];
      case 'chocolate_discord_os':
        return const [Color(0xFF1C1410), Color(0xFF331E15), Color(0xFF4D2B1C)];
      case 'classic_street_fighter':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'clockwork_butterflies':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF451A03)];
      case 'cloud_zeppelin':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF3B0764)];
      case 'deck_the_halls_aurora':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF14532D)];
      case 'deck_the_halls_dusk':
        return const [Color(0xFF1E1035), Color(0xFF2E1065), Color(0xFF4C1D95)];
      case 'deck_the_halls_ember':
        return const [Color(0xFF1C0A00), Color(0xFF431407), Color(0xFF78350F)];
      case 'deck_the_halls_mix':
        return const [Color(0xFF09090B), Color(0xFF18181B), Color(0xFF1E293B)];
      case 'ekko_s_aeroglider_stunts':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF0F172A)];
      case 'enchanted_forest':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF065F46)];
      case 'flutter_and_frolic':
        return const [Color(0xFF1E1B4B), Color(0xFF2E1065), Color(0xFF4A044E)];
      case 'fog_of_war':
        return const [Color(0xFF09090B), Color(0xFF18181B), Color(0xFF27272A)];
      case 'heartzilla_purple':
        return const [Color(0xFF1E1035), Color(0xFF2E1065), Color(0xFF4A044E)];
      case 'infernal_dark_omens':
        return const [Color(0xFF1C0A00), Color(0xFF3B0B0B), Color(0xFF5A0808)];
      case 'innovator_s_masterwork':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'jinx_and_pow_pow':
        return const [Color(0xFF1E0B1F), Color(0xFF3B0764), Color(0xFF0F172A)];
      case 'kawaii_mode':
        return const [Color(0xFF2E0820), Color(0xFF4A0835), Color(0xFF701A75)];
      case 'koi_garden':
        return const [Color(0xFF022C22), Color(0xFF064E3B), Color(0xFF0F172A)];
      case 'lofi_cat_zoomies_festive':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF14532D)];
      case 'lofi_girl_snow_angel':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'lofi_girl_study_break':
        return const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF451A03)];
      case 'm_bison_s_return':
        return const [Color(0xFF1A0A1C), Color(0xFF380838), Color(0xFF5A0838)];
      case 'mermaid_whisperer':
        return const [Color(0xFF041F38), Color(0xFF063A5E), Color(0xFF0E567A)];
      case 'midnight_dark_omens':
        return const [Color(0xFF05050A), Color(0xFF0D0D1A), Color(0xFF17172E)];
      case 'midnight_zombie_slime':
        return const [Color(0xFF061524), Color(0xFF0B253D), Color(0xFF103657)];
      case 'mimic':
        return const [Color(0xFF1A0E08), Color(0xFF381D10), Color(0xFF522A16)];
      case 'mooncap_forest_blue':
        return const [Color(0xFF07142E), Color(0xFF0C244F), Color(0xFF133670)];
      case 'mooncap_forest_pink':
        return const [Color(0xFF240A1F), Color(0xFF421037), Color(0xFF61144E)];
      case 'neon_ghoulish_graffiti':
        return const [Color(0xFF0D1824), Color(0xFF152A3D), Color(0xFF1B3C54)];
      case 'ocean_flowers':
        return const [Color(0xFF05242E), Color(0xFF0A3C4D), Color(0xFF10546B)];
      case 'of_ink_and_steel':
        return const [Color(0xFF121214), Color(0xFF1F1F24), Color(0xFF2E2E36)];
      case 'oni_s_curse':
        return const [Color(0xFF071426), Color(0xFF0C2442), Color(0xFF11355C)];
      case 'paint_the_town_blue':
        return const [Color(0xFF081C30), Color(0xFF0D3052), Color(0xFF124370)];
      case 'penguins_on_ice':
        return const [Color(0xFF0A1826), Color(0xFF10283D), Color(0xFF173854)];
      case 'plankton_splat':
        return const [Color(0xFF0A1C0E), Color(0xFF123319), Color(0xFF1A4724)];
      case 'plushie_party':
        return const [Color(0xFF261021), Color(0xFF421C39), Color(0xFF5E2752)];
      case 'portal_beyond_blue':
        return const [Color(0xFF07142E), Color(0xFF0B2452), Color(0xFF103473)];
      case 'portal_beyond_purple':
        return const [Color(0xFF160A26), Color(0xFF271042), Color(0xFF3A1761)];
      case 'red_dragon':
        return const [Color(0xFF210808), Color(0xFF3D0E0E), Color(0xFF591414)];
      case 'sakura_katana':
        return const [Color(0xFF240A18), Color(0xFF3E122B), Color(0xFF57183D)];
      case 'scarlet_fall_foliage':
        return const [Color(0xFF210808), Color(0xFF3B0E0E), Color(0xFF541414)];
      case 'snowy_shenanigans_giddy':
        return const [Color(0xFF0C1724), Color(0xFF14273B), Color(0xFF1C3652)];
      case 'snowy_shenanigans_jolly':
        return const [Color(0xFF0C1724), Color(0xFF14273B), Color(0xFF1C3652)];
      case 'snowy_shenanigans_smooch':
        return const [Color(0xFF1A0E21), Color(0xFF2E173B), Color(0xFF421E52)];
      case 'snowy_shenanigans_suave':
        return const [Color(0xFF0C1724), Color(0xFF14273B), Color(0xFF1C3652)];
      case 'spirit_of_the_kitsune':
        return const [Color(0xFF081C26), Color(0xFF0E3042), Color(0xFF14435C)];
      case 'street_fighter_6':
        return const [Color(0xFF1A1208), Color(0xFF33230F), Color(0xFF4A3215)];
      case 'sun_and_moon':
        return const [Color(0xFF141026), Color(0xFF241C42), Color(0xFF34285E)];
      case 'sunrise_grove':
        return const [Color(0xFF1F1208), Color(0xFF3D230E), Color(0xFF593314)];
      case 'twilight_grove':
        return const [Color(0xFF160A24), Color(0xFF281140), Color(0xFF3B185C)];
      case 'twist_of_luck':
        return const [Color(0xFF1A1506), Color(0xFF33290A), Color(0xFF4D3D0E)];
      case 'vct_supernova':
        return const [Color(0xFF1F1608), Color(0xFF3D2B0F), Color(0xFF573E15)];
      case 'wonder_construction':
        return const [Color(0xFF1C1408), Color(0xFF38270E), Color(0xFF523913)];
      case 'woodland_fall_foliage':
        return const [Color(0xFF1A1408), Color(0xFF33260F), Color(0xFF4A3715)];
      case 'yoru_dimensional_rip':
        return const [Color(0xFF081024), Color(0xFF0E1D40), Color(0xFF142959)];
      case 'zombie_slime':
      default:
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF022C22)];
    }
  }

  Color _getEffectAccentColor(String effectKey) {
    final k = effectKey.toLowerCase().replaceAll('-', '_');
    switch (k) {
      case 'cloud_nine':
        return const Color(0xFFEC4899);
      case 'falling_stars':
        return const Color(0xFF38BDF8);
      case 'la_llorona':
        return const Color(0xFFA855F7);
      case 'boost_relic':
        return const Color(0xFFF59E0B);
      case 'cyberspace':
        return const Color(0xFF06B6D4);
      case 'hydro_blast':
        return const Color(0xFF0EA5E9);
      case 'shatter':
        return const Color(0xFF818CF8);
      case 'magic_hearts':
        return const Color(0xFFF43F5E);
      case 'sakura_dreams':
        return const Color(0xFFF472B6);
      case 'power_surge':
        return const Color(0xFFEAB308);
      case 'shuriken_strike':
        return const Color(0xFFEF4444);
      case 'mystic_vines':
        return const Color(0xFF10B981);
      case 'pixie_dust':
        return const Color(0xFFFBBF24);
      case 'discord_os':
        return const Color(0xFF6366F1);
      case 'breakfast_plate':
        return const Color(0xFFF97316);
      case 'ghoulish_graffiti':
        return const Color(0xFFA855F7);
      case 'dark_omens':
        return const Color(0xFFDC2626);
      case 'fall_foliage':
        return const Color(0xFFD97706);
case 'all_nighter':
        return const Color(0xFFF59E0B);
      case 'arcane_summons':
        return const Color(0xFFA855F7);
      case 'clove_s_ruse':
        return const Color(0xFFC084FC);
      case 'deck_the_halls':
        return const Color(0xFFEF4444);
      case 'doodlebob_takeover':
        return const Color(0xFFE4E4E7);
      case 'dragon_dance':
        return const Color(0xFFF59E0B);
      case 'dreamy':
        return const Color(0xFFF472B6);
      case 'feelin_90s':
        return const Color(0xFF06B6D4);
      case 'feelin_mischievous':
        return const Color(0xFF4ADE80);
      case 'feelin_pizzazz':
        return const Color(0xFFFBBF24);
      case 'fellowship_of_the_spring':
        return const Color(0xFF34D399);
      case 'forgotten_treasure':
        return const Color(0xFFF59E0B);
      case 'fortune_flurry':
        return const Color(0xFFFACC15);
      case 'goozilla':
        return const Color(0xFF22C55E);
      case 'handsome_squidward':
        return const Color(0xFF38BDF8);
      case 'haunted_man_o_war':
        return const Color(0xFF2DD4BF);
      case 'heartzilla':
        return const Color(0xFFF43F5E);
      case 'jolly_roger':
        return const Color(0xFFDC2626);
      case 'ki_detonate':
        return const Color(0xFFFACC15);
      case 'lilypad_life':
        return const Color(0xFF10B981);
      case 'mastery':
        return const Color(0xFFF59E0B);
      case 'midnight_celebration':
        return const Color(0xFFA855F7);
      case 'midnight_lilypad_life':
        return const Color(0xFF2DD4BF);
      case 'monster_pop':
        return const Color(0xFFF43F5E);
      case 'muddy_lilypad_life':
        return const Color(0xFF84CC16);
      case 'nice_profile':
        return const Color(0xFF38BDF8);
      case 'nightrunner':
        return const Color(0xFF06B6D4);
      case 'petal_serenade':
        return const Color(0xFFF472B6);
      case 'rock_slide':
        return const Color(0xFFA8A29E);
      case 'saya':
        return const Color(0xFFF472B6);
      case 'shooting_stars':
        return const Color(0xFF38BDF8);
      case 'snowy_shenanigans':
        return const Color(0xFF38BDF8);
      case 'space_evader':
        return const Color(0xFF22C55E);
      case 'spirit_flame':
        return const Color(0xFF0EA5E9);
      case 'spring_bloom':
        return const Color(0xFF10B981);
      case 'study_spot':
        return const Color(0xFFF59E0B);
      case 'supernova':
        return const Color(0xFFF97316);
      case 'sushi_mania':
        return const Color(0xFFF97316);
      case 'the_immortal_clove':
        return const Color(0xFFA855F7);
      case 'tocotoco':
        return const Color(0xFFF43F5E);
      case 'turbo_drive':
        return const Color(0xFFEF4444);
      case 'twilight':
        return const Color(0xFF818CF8);
      case 'twinkle_trails':
        return const Color(0xFFFBBF24);
      case 'uplink_error':
        return const Color(0xFF06B6D4);
      case 'vengeance':
        return const Color(0xFFDC2626);
      case 'vortex':
        return const Color(0xFFA855F7);
      case 'wake_up':
        return const Color(0xFFF59E0B);
      case 'watercolors':
        return const Color(0xFFEC4899);
case 'akuma_s_wrath':
        return const Color(0xFFEF4444);
      case 'arcane_epiphany':
        return const Color(0xFF818CF8);
      case 'aurora_dreams':
        return const Color(0xFF34D399);
      case 'autumn_equinox':
        return const Color(0xFFF97316);
      case 'beholder':
        return const Color(0xFFA855F7);
      case 'blazing_ghoulish_graffiti':
        return const Color(0xFFF97316);
      case 'bubble_tea_bliss':
        return const Color(0xFFD97706);
      case 'bubblegum_zombie_slime':
        return const Color(0xFFF43F5E);
      case 'chocolate_discord_os':
        return const Color(0xFFB45309);
      case 'classic_street_fighter':
        return const Color(0xFFFACC15);
      case 'clockwork_butterflies':
        return const Color(0xFFF59E0B);
      case 'cloud_zeppelin':
        return const Color(0xFF38BDF8);
      case 'deck_the_halls_aurora':
        return const Color(0xFF10B981);
      case 'deck_the_halls_dusk':
        return const Color(0xFFA855F7);
      case 'deck_the_halls_ember':
        return const Color(0xFFEA580C);
      case 'deck_the_halls_mix':
        return const Color(0xFFEC4899);
      case 'ekko_s_aeroglider_stunts':
        return const Color(0xFF2DD4BF);
      case 'enchanted_forest':
        return const Color(0xFF34D399);
      case 'flutter_and_frolic':
        return const Color(0xFFF472B6);
      case 'fog_of_war':
        return const Color(0xFF94A3B8);
      case 'heartzilla_purple':
        return const Color(0xFFC084FC);
      case 'infernal_dark_omens':
        return const Color(0xFFEF4444);
      case 'innovator_s_masterwork':
        return const Color(0xFFF59E0B);
      case 'jinx_and_pow_pow':
        return const Color(0xFF06B6D4);
      case 'kawaii_mode':
        return const Color(0xFFF472B6);
      case 'koi_garden':
        return const Color(0xFFF97316);
      case 'lofi_cat_zoomies_festive':
        return const Color(0xFF22C55E);
      case 'lofi_girl_snow_angel':
        return const Color(0xFF38BDF8);
      case 'lofi_girl_study_break':
        return const Color(0xFFF59E0B);
      case 'm_bison_s_return':
        return const Color(0xFFE11D48);
      case 'mermaid_whisperer':
        return const Color(0xFF22D3EE);
      case 'midnight_dark_omens':
        return const Color(0xFF818CF8);
      case 'midnight_zombie_slime':
        return const Color(0xFF38BDF8);
      case 'mimic':
        return const Color(0xFFD97706);
      case 'mooncap_forest_blue':
        return const Color(0xFF60A5FA);
      case 'mooncap_forest_pink':
        return const Color(0xFFF472B6);
      case 'neon_ghoulish_graffiti':
        return const Color(0xFF22D3EE);
      case 'ocean_flowers':
        return const Color(0xFF2DD4BF);
      case 'of_ink_and_steel':
        return const Color(0xFFE2E8F0);
      case 'oni_s_curse':
        return const Color(0xFF38BDF8);
      case 'paint_the_town_blue':
        return const Color(0xFF38BDF8);
      case 'penguins_on_ice':
        return const Color(0xFF38BDF8);
      case 'plankton_splat':
        return const Color(0xFF4ADE80);
      case 'plushie_party':
        return const Color(0xFFF472B6);
      case 'portal_beyond_blue':
        return const Color(0xFF60A5FA);
      case 'portal_beyond_purple':
        return const Color(0xFFA855F7);
      case 'red_dragon':
        return const Color(0xFFEF4444);
      case 'sakura_katana':
        return const Color(0xFFF472B6);
      case 'scarlet_fall_foliage':
        return const Color(0xFFF87171);
      case 'snowy_shenanigans_giddy':
        return const Color(0xFF38BDF8);
      case 'snowy_shenanigans_jolly':
        return const Color(0xFF38BDF8);
      case 'snowy_shenanigans_smooch':
        return const Color(0xFFF472B6);
      case 'snowy_shenanigans_suave':
        return const Color(0xFF38BDF8);
      case 'spirit_of_the_kitsune':
        return const Color(0xFF22D3EE);
      case 'street_fighter_6':
        return const Color(0xFFF59E0B);
      case 'sun_and_moon':
        return const Color(0xFFFACC15);
      case 'sunrise_grove':
        return const Color(0xFFF97316);
      case 'twilight_grove':
        return const Color(0xFFA855F7);
      case 'twist_of_luck':
        return const Color(0xFFFACC15);
      case 'vct_supernova':
        return const Color(0xFFFACC15);
      case 'wonder_construction':
        return const Color(0xFFF59E0B);
      case 'woodland_fall_foliage':
        return const Color(0xFFD97706);
      case 'yoru_dimensional_rip':
        return const Color(0xFF38BDF8);
      case 'bearly_afloat':
        return const Color(0xFFFBBF24);
      case 'capyccino':
        return const Color(0xFFFBBF24);
      case 'close_combat':
        return const Color(0xFFF59E0B);
      case 'cluster':
        return const Color(0xFF38BDF8);
      case 'darth_vader_arrives':
        return const Color(0xFF818CF8);
      case 'deep_dive':
        return const Color(0xFF38BDF8);
      case 'dreamy_blue':
        return const Color(0xFF38BDF8);
      case 'dreamy_green':
        return const Color(0xFF34D399);
      case 'dreamy_pink':
        return const Color(0xFFF472B6);
      case 'dreamy_yellow':
        return const Color(0xFF38BDF8);
      case 'entering_hyperspace':
        return const Color(0xFF818CF8);
      case 'f_in_chat_black':
        return const Color(0xFF38BDF8);
      case 'f_in_chat_white':
        return const Color(0xFF38BDF8);
      case 'farming_town':
        return const Color(0xFF34D399);
      case 'fishing_village':
        return const Color(0xFF38BDF8);
      case 'full_cowling':
        return const Color(0xFFF59E0B);
      case 'giselle':
        return const Color(0xFFC084FC);
      case 'heartstring_theory_blue':
        return const Color(0xFF38BDF8);
      case 'heartstring_theory_red':
        return const Color(0xFFF87171);
      case 'karina':
        return const Color(0xFFC084FC);
      case 'keyboard_cats':
        return const Color(0xFFFBBF24);
      case 'ki_detonate_blue':
        return const Color(0xFF38BDF8);
      case 'ki_detonate_green':
        return const Color(0xFF34D399);
      case 'ki_detonate_red':
        return const Color(0xFFF87171);
      case 'ki_detonate_yellow':
        return const Color(0xFFF59E0B);
      case 'lava_lamp':
        return const Color(0xFFF87171);
      case 'lava_lamp_blue':
        return const Color(0xFFF87171);
      case 'lava_lamp_pink':
        return const Color(0xFFF87171);
      case 'lava_lamp_slime':
        return const Color(0xFFF87171);
      case 'lazy_loaf':
        return const Color(0xFFFBBF24);
      case 'league_of_villains':
        return const Color(0xFFF59E0B);
      case 'lightsaber_mastery_blue':
        return const Color(0xFF818CF8);
      case 'lightsaber_mastery_green':
        return const Color(0xFF818CF8);
      case 'magic_hearts_blue':
        return const Color(0xFF38BDF8);
      case 'magic_hearts_gold':
        return const Color(0xFFF87171);
      case 'magic_mists':
        return const Color(0xFF38BDF8);
      case 'magical_girl_energy':
        return const Color(0xFFF472B6);
      case 'nature_is_healing':
        return const Color(0xFF34D399);
      case 'ningning':
        return const Color(0xFFC084FC);
      case 'nom_kitty_crunch':
        return const Color(0xFFFBBF24);
      case 'pancake_pals':
        return const Color(0xFFFBBF24);
      case 'power_surge_fuchsia':
        return const Color(0xFF38BDF8);
      case 'power_surge_green':
        return const Color(0xFF34D399);
      case 'roses_galore_blue':
        return const Color(0xFF38BDF8);
      case 'roses_galore_red':
        return const Color(0xFFF87171);
      case 'ruby_photo_card':
        return const Color(0xFFF87171);
      case 'science_victory':
        return const Color(0xFF38BDF8);
      case 'shatter_blue':
        return const Color(0xFF38BDF8);
      case 'shatter_purple':
        return const Color(0xFFF59E0B);
      case 'shuriken_strike_blue':
        return const Color(0xFF38BDF8);
      case 'shuriken_strike_yellow':
        return const Color(0xFFF59E0B);
      case 'starfall_tides':
        return const Color(0xFF818CF8);
      case 'starfall_tides_nightshade':
        return const Color(0xFF818CF8);
      case 'starfall_tides_rose':
        return const Color(0xFF818CF8);
      case 'starfall_tides_void':
        return const Color(0xFF818CF8);
      case 'sushi_mania_blue':
        return const Color(0xFF38BDF8);
      case 'sushi_mania_green':
        return const Color(0xFF34D399);
      case 'sushi_mania_pink':
        return const Color(0xFFF472B6);
      case 'sushi_mania_yellow':
        return const Color(0xFFFB923C);
      case 'sweet_copium':
        return const Color(0xFFF472B6);
      case 'tumbleweeds':
        return const Color(0xFF38BDF8);
      case 'winter':
        return const Color(0xFFC084FC);
      case 'wishful_beginnings':
        return const Color(0xFF38BDF8);

      case 'zombie_slime':
      default:
        return const Color(0xFF22C55E);
    }
  }

  List<Color> _getEffectBadgeGradient(String effectKey) {
    final k = effectKey.toLowerCase().replaceAll('-', '_');
    switch (k) {
      case 'cloud_nine':
        return const [Color(0xFFEC4899), Color(0xFFA855F7)];
      case 'falling_stars':
        return const [Color(0xFF38BDF8), Color(0xFF6366F1)];
      case 'la_llorona':
        return const [Color(0xFFA855F7), Color(0xFF6366F1)];
      case 'boost_relic':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'cyberspace':
        return const [Color(0xFF22D3EE), Color(0xFF0284C7)];
      case 'hydro_blast':
        return const [Color(0xFF38BDF8), Color(0xFF0284C7)];
      case 'shatter':
        return const [Color(0xFFA5B4FC), Color(0xFF6366F1)];
      case 'magic_hearts':
        return const [Color(0xFFFB7185), Color(0xFFE11D48)];
      case 'sakura_dreams':
        return const [Color(0xFFF9A8D4), Color(0xFFEC4899)];
      case 'power_surge':
        return const [Color(0xFFFACC15), Color(0xFFCA8A04)];
      case 'shuriken_strike':
        return const [Color(0xFFF87171), Color(0xFFDC2626)];
      case 'mystic_vines':
        return const [Color(0xFF10B981), Color(0xFF059669)];
      case 'pixie_dust':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'discord_os':
        return const [Color(0xFF818CF8), Color(0xFF4F46E5)];
      case 'breakfast_plate':
        return const [Color(0xFFFB923C), Color(0xFFEA580C)];
      case 'ghoulish_graffiti':
        return const [Color(0xFFC084FC), Color(0xFF9333EA)];
      case 'dark_omens':
        return const [Color(0xFFF87171), Color(0xFFDC2626)];
      case 'fall_foliage':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
case 'all_nighter':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'arcane_summons':
        return const [Color(0xFFC084FC), Color(0xFF9333EA)];
      case 'clove_s_ruse':
        return const [Color(0xFFE879F9), Color(0xFFA855F7)];
      case 'deck_the_halls':
        return const [Color(0xFF22C55E), Color(0xFFDC2626)];
      case 'doodlebob_takeover':
        return const [Color(0xFFA1A1AA), Color(0xFF71717A)];
      case 'dragon_dance':
        return const [Color(0xFFF87171), Color(0xFFEA580C)];
      case 'dreamy':
        return const [Color(0xFFF9A8D4), Color(0xFFC084FC)];
      case 'feelin_90s':
        return const [Color(0xFF22D3EE), Color(0xFFF43F5E)];
      case 'feelin_mischievous':
        return const [Color(0xFF22C55E), Color(0xFF16A34A)];
      case 'feelin_pizzazz':
        return const [Color(0xFFFDE047), Color(0xFFD97706)];
      case 'fellowship_of_the_spring':
        return const [Color(0xFF6EE7B7), Color(0xFF059669)];
      case 'forgotten_treasure':
        return const [Color(0xFF38BDF8), Color(0xFFD97706)];
      case 'fortune_flurry':
        return const [Color(0xFFEF4444), Color(0xFFCA8A04)];
      case 'goozilla':
        return const [Color(0xFF4ADE80), Color(0xFF15803D)];
      case 'handsome_squidward':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'haunted_man_o_war':
        return const [Color(0xFF5EEAD4), Color(0xFF0D9488)];
      case 'heartzilla':
        return const [Color(0xFFFB7185), Color(0xFFE11D48)];
      case 'jolly_roger':
        return const [Color(0xFFF87171), Color(0xFFB91C1C)];
      case 'ki_detonate':
        return const [Color(0xFFFDE047), Color(0xFFCA8A04)];
      case 'lilypad_life':
        return const [Color(0xFF34D399), Color(0xFF047857)];
      case 'mastery':
        return const [Color(0xFFFBBF24), Color(0xFFB45309)];
      case 'midnight_celebration':
        return const [Color(0xFF38BDF8), Color(0xFFEC4899)];
      case 'midnight_lilypad_life':
        return const [Color(0xFF38BDF8), Color(0xFF059669)];
      case 'monster_pop':
        return const [Color(0xFFF472B6), Color(0xFF8B5CF6)];
      case 'muddy_lilypad_life':
        return const [Color(0xFFA3E635), Color(0xFF65A30D)];
      case 'nice_profile':
        return const [Color(0xFF38BDF8), Color(0xFF6366F1)];
      case 'nightrunner':
        return const [Color(0xFF22D3EE), Color(0xFFEC4899)];
      case 'petal_serenade':
        return const [Color(0xFFF9A8D4), Color(0xFFEC4899)];
      case 'rock_slide':
        return const [Color(0xFFD6D3D1), Color(0xFF78716C)];
      case 'saya':
        return const [Color(0xFFF9A8D4), Color(0xFFA855F7)];
      case 'shooting_stars':
        return const [Color(0xFF60A5FA), Color(0xFF818CF8)];
      case 'snowy_shenanigans':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'space_evader':
        return const [Color(0xFF4ADE80), Color(0xFF16A34A)];
      case 'spirit_flame':
        return const [Color(0xFF38BDF8), Color(0xFF2563EB)];
      case 'spring_bloom':
        return const [Color(0xFF34D399), Color(0xFF06B6D4)];
      case 'study_spot':
        return const [Color(0xFFFBBF24), Color(0xFF0284C7)];
      case 'supernova':
        return const [Color(0xFFFB923C), Color(0xFFA855F7)];
      case 'sushi_mania':
        return const [Color(0xFFFB923C), Color(0xFF22C55E)];
      case 'the_immortal_clove':
        return const [Color(0xFFC084FC), Color(0xFF7C3AED)];
      case 'tocotoco':
        return const [Color(0xFFFB7185), Color(0xFF38BDF8)];
      case 'turbo_drive':
        return const [Color(0xFFF87171), Color(0xFFDC2626)];
      case 'twilight':
        return const [Color(0xFFA5B4FC), Color(0xFF6366F1)];
      case 'twinkle_trails':
        return const [Color(0xFFFDE047), Color(0xFFA855F7)];
      case 'uplink_error':
        return const [Color(0xFF22D3EE), Color(0xFF0284C7)];
      case 'vengeance':
        return const [Color(0xFFF87171), Color(0xFF991B1B)];
      case 'vortex':
        return const [Color(0xFFC084FC), Color(0xFF6B21A8)];
      case 'wake_up':
        return const [Color(0xFFFBBF24), Color(0xFF38BDF8)];
      case 'watercolors':
        return const [Color(0xFFF472B6), Color(0xFF06B6D4)];
case 'akuma_s_wrath':
        return const [Color(0xFFDC2626), Color(0xFF7F1D1D)];
      case 'arcane_epiphany':
        return const [Color(0xFFA5B4FC), Color(0xFF6366F1)];
      case 'aurora_dreams':
        return const [Color(0xFF6EE7B7), Color(0xFF8B5CF6)];
      case 'autumn_equinox':
        return const [Color(0xFFFB923C), Color(0xFFD97706)];
      case 'beholder':
        return const [Color(0xFFC084FC), Color(0xFF7E22CE)];
      case 'blazing_ghoulish_graffiti':
        return const [Color(0xFFFB923C), Color(0xFFDC2626)];
      case 'bubble_tea_bliss':
        return const [Color(0xFFFBBF24), Color(0xFFB45309)];
      case 'bubblegum_zombie_slime':
        return const [Color(0xFFFB7185), Color(0xFFE11D48)];
      case 'chocolate_discord_os':
        return const [Color(0xFFD97706), Color(0xFF78350F)];
      case 'classic_street_fighter':
        return const [Color(0xFFEF4444), Color(0xFFF59E0B)];
      case 'clockwork_butterflies':
        return const [Color(0xFFFBBF24), Color(0xFFB45309)];
      case 'cloud_zeppelin':
        return const [Color(0xFF7DD3FC), Color(0xFFF59E0B)];
      case 'deck_the_halls_aurora':
        return const [Color(0xFF34D399), Color(0xFF059669)];
      case 'deck_the_halls_dusk':
        return const [Color(0xFFC084FC), Color(0xFF7C3AED)];
      case 'deck_the_halls_ember':
        return const [Color(0xFFF97316), Color(0xFFC2410C)];
      case 'deck_the_halls_mix':
        return const [Color(0xFFF43F5E), Color(0xFF3B82F6)];
      case 'ekko_s_aeroglider_stunts':
        return const [Color(0xFF22D3EE), Color(0xFF10B981)];
      case 'enchanted_forest':
        return const [Color(0xFF6EE7B7), Color(0xFF047857)];
      case 'flutter_and_frolic':
        return const [Color(0xFFF9A8D4), Color(0xFF8B5CF6)];
      case 'fog_of_war':
        return const [Color(0xFF64748B), Color(0xFF334155)];
      case 'heartzilla_purple':
        return const [Color(0xFFE879F9), Color(0xFF9333EA)];
      case 'infernal_dark_omens':
        return const [Color(0xFFF97316), Color(0xFFDC2626)];
      case 'innovator_s_masterwork':
        return const [Color(0xFF38BDF8), Color(0xFFD97706)];
      case 'jinx_and_pow_pow':
        return const [Color(0xFFF43F5E), Color(0xFF06B6D4)];
      case 'kawaii_mode':
        return const [Color(0xFFF9A8D4), Color(0xFFEC4899)];
      case 'koi_garden':
        return const [Color(0xFFFB923C), Color(0xFF10B981)];
      case 'lofi_cat_zoomies_festive':
        return const [Color(0xFF4ADE80), Color(0xFFEF4444)];
      case 'lofi_girl_snow_angel':
        return const [Color(0xFF7DD3FC), Color(0xFF6366F1)];
      case 'lofi_girl_study_break':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'm_bison_s_return':
        return const [Color(0xFFF43F5E), Color(0xFF881337)];
      case 'mermaid_whisperer':
        return const [Color(0xFF67E8F9), Color(0xFF0284C7)];
      case 'midnight_dark_omens':
        return const [Color(0xFFA5B4FC), Color(0xFF4338CA)];
      case 'midnight_zombie_slime':
        return const [Color(0xFF0284C7), Color(0xFF0EA5E9)];
      case 'mimic':
        return const [Color(0xFFF59E0B), Color(0xFF9A3412)];
      case 'mooncap_forest_blue':
        return const [Color(0xFF93C5FD), Color(0xFF2563EB)];
      case 'mooncap_forest_pink':
        return const [Color(0xFFF9A8D4), Color(0xFFDB2777)];
      case 'neon_ghoulish_graffiti':
        return const [Color(0xFF38BDF8), Color(0xFF0891B2)];
      case 'ocean_flowers':
        return const [Color(0xFF5EEAD4), Color(0xFF0D9488)];
      case 'of_ink_and_steel':
        return const [Color(0xFFCBD5E1), Color(0xFF64748B)];
      case 'oni_s_curse':
        return const [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
      case 'paint_the_town_blue':
        return const [Color(0xFF60A5FA), Color(0xFF0284C7)];
      case 'penguins_on_ice':
        return const [Color(0xFF93C5FD), Color(0xFF0284C7)];
      case 'plankton_splat':
        return const [Color(0xFF86EFAC), Color(0xFF16A34A)];
      case 'plushie_party':
        return const [Color(0xFFF9A8D4), Color(0xFFDB2777)];
      case 'portal_beyond_blue':
        return const [Color(0xFF93C5FD), Color(0xFF2563EB)];
      case 'portal_beyond_purple':
        return const [Color(0xFFC084FC), Color(0xFF7E22CE)];
      case 'red_dragon':
        return const [Color(0xFFF87171), Color(0xFFB91C1C)];
      case 'sakura_katana':
        return const [Color(0xFFF9A8D4), Color(0xFFBE185D)];
      case 'scarlet_fall_foliage':
        return const [Color(0xFFEF4444), Color(0xFF991B1B)];
      case 'snowy_shenanigans_giddy':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'snowy_shenanigans_jolly':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'snowy_shenanigans_smooch':
        return const [Color(0xFFF9A8D4), Color(0xFFA855F7)];
      case 'snowy_shenanigans_suave':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'spirit_of_the_kitsune':
        return const [Color(0xFF67E8F9), Color(0xFF0891B2)];
      case 'street_fighter_6':
        return const [Color(0xFFFBBF24), Color(0xFFDC2626)];
      case 'sun_and_moon':
        return const [Color(0xFFFDE047), Color(0xFF818CF8)];
      case 'sunrise_grove':
        return const [Color(0xFFFB923C), Color(0xFFF59E0B)];
      case 'twilight_grove':
        return const [Color(0xFFC084FC), Color(0xFF6B21A8)];
      case 'twist_of_luck':
        return const [Color(0xFFFDE047), Color(0xFFCA8A04)];
      case 'vct_supernova':
        return const [Color(0xFFFDE047), Color(0xFFCA8A04)];
      case 'wonder_construction':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'woodland_fall_foliage':
        return const [Color(0xFFF59E0B), Color(0xFF9A3412)];
      case 'yoru_dimensional_rip':
        return const [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
      case 'bearly_afloat':
        return const [Color(0xFF261410), Color(0xFF42221B), Color(0xFF613327)];
      case 'capyccino':
        return const [Color(0xFF261410), Color(0xFF42221B), Color(0xFF613327)];
      case 'close_combat':
        return const [Color(0xFF1C1008), Color(0xFF381E0C), Color(0xFF572E10)];
      case 'cluster':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'darth_vader_arrives':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'deep_dive':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'dreamy_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'dreamy_green':
        return const [Color(0xFF052414), Color(0xFF0A3D23), Color(0xFF0F5732)];
      case 'dreamy_pink':
        return const [Color(0xFF290A1E), Color(0xFF4A1237), Color(0xFF6E1B51)];
      case 'dreamy_yellow':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'entering_hyperspace':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'f_in_chat_black':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'f_in_chat_white':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'farming_town':
        return const [Color(0xFF052414), Color(0xFF0A3D23), Color(0xFF0F5732)];
      case 'fishing_village':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'full_cowling':
        return const [Color(0xFF1C1008), Color(0xFF381E0C), Color(0xFF572E10)];
      case 'giselle':
        return const [Color(0xFF1A102E), Color(0xFF2D1B4D), Color(0xFF462778)];
      case 'heartstring_theory_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'heartstring_theory_red':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'karina':
        return const [Color(0xFF1A102E), Color(0xFF2D1B4D), Color(0xFF462778)];
      case 'keyboard_cats':
        return const [Color(0xFF261410), Color(0xFF42221B), Color(0xFF613327)];
      case 'ki_detonate_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'ki_detonate_green':
        return const [Color(0xFF052414), Color(0xFF0A3D23), Color(0xFF0F5732)];
      case 'ki_detonate_red':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'ki_detonate_yellow':
        return const [Color(0xFF1C1008), Color(0xFF381E0C), Color(0xFF572E10)];
      case 'lava_lamp':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'lava_lamp_blue':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'lava_lamp_pink':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'lava_lamp_slime':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'lazy_loaf':
        return const [Color(0xFF261410), Color(0xFF42221B), Color(0xFF613327)];
      case 'league_of_villains':
        return const [Color(0xFF1C1008), Color(0xFF381E0C), Color(0xFF572E10)];
      case 'lightsaber_mastery_blue':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'lightsaber_mastery_green':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'magic_hearts_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'magic_hearts_gold':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'magic_mists':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'magical_girl_energy':
        return const [Color(0xFF290A1E), Color(0xFF4A1237), Color(0xFF6E1B51)];
      case 'nature_is_healing':
        return const [Color(0xFF052414), Color(0xFF0A3D23), Color(0xFF0F5732)];
      case 'ningning':
        return const [Color(0xFF1A102E), Color(0xFF2D1B4D), Color(0xFF462778)];
      case 'nom_kitty_crunch':
        return const [Color(0xFF261410), Color(0xFF42221B), Color(0xFF613327)];
      case 'pancake_pals':
        return const [Color(0xFF261410), Color(0xFF42221B), Color(0xFF613327)];
      case 'power_surge_fuchsia':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'power_surge_green':
        return const [Color(0xFF052414), Color(0xFF0A3D23), Color(0xFF0F5732)];
      case 'roses_galore_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'roses_galore_red':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'ruby_photo_card':
        return const [Color(0xFF240A0A), Color(0xFF451010), Color(0xFF6B1414)];
      case 'science_victory':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'shatter_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'shatter_purple':
        return const [Color(0xFF1C1008), Color(0xFF381E0C), Color(0xFF572E10)];
      case 'shuriken_strike_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'shuriken_strike_yellow':
        return const [Color(0xFF1C1008), Color(0xFF381E0C), Color(0xFF572E10)];
      case 'starfall_tides':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'starfall_tides_nightshade':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'starfall_tides_rose':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'starfall_tides_void':
        return const [Color(0xFF0A0A1A), Color(0xFF12122E), Color(0xFF1C1C45)];
      case 'sushi_mania_blue':
        return const [Color(0xFF051829), Color(0xFF082845), Color(0xFF0E3D69)];
      case 'sushi_mania_green':
        return const [Color(0xFF052414), Color(0xFF0A3D23), Color(0xFF0F5732)];
      case 'sushi_mania_pink':
        return const [Color(0xFF290A1E), Color(0xFF4A1237), Color(0xFF6E1B51)];
      case 'sushi_mania_yellow':
        return const [Color(0xFF1E1610), Color(0xFF38271C), Color(0xFF543B2A)];
      case 'sweet_copium':
        return const [Color(0xFF290A1E), Color(0xFF4A1237), Color(0xFF6E1B51)];
      case 'tumbleweeds':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];
      case 'winter':
        return const [Color(0xFF1A102E), Color(0xFF2D1B4D), Color(0xFF462778)];
      case 'wishful_beginnings':
        return const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)];

      case 'zombie_slime':
      default:
        return const [Color(0xFF22C55E), Color(0xFF10B981)];
    }
  }

  Widget _buildLiveEffectPreviewCard(Map<String, dynamic>? effect) {
    final effectKey = effect?['key']?.toString() ?? 'zombie_slime';
    final accentColor = _getEffectAccentColor(effectKey);
    final backdropColors = _getEffectBackdropColors(effectKey);
    final avatarUrl = _currentUser?.avatarUrl ?? '';
    final fullName = _currentUser?.fullName?.isNotEmpty == true
        ? _currentUser!.fullName!
        : (_currentUsername.isNotEmpty ? _currentUsername : 'User');
    final username = _currentUsername.isNotEmpty ? _currentUsername : 'user';

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            // Dark elegant backdrop gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: backdropColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Profile Info Mockup
            Positioned(
              left: 20,
              bottom: 20,
              right: 20,
              child: Row(
                children: [
                  UserAvatarWithFrame(
                    avatarUrl: avatarUrl,
                    framePath: _equippedAdminFrame != 'none' ? _equippedAdminFrame : null,
                    radius: 30,
                    initials: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF38BDF8),
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: accentColor.withOpacity(0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Active Preview: ${effect?['name'] ?? 'Effect'}',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Animated Profile Effect Widget Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: ProfileEffectWidget(
                  key: ValueKey('${effectKey}_$_previewIntroSeed'),
                  effect: effectKey,
                  height: 200,
                  isActive: true,
                ),
              ),
            ),

            // Top-Right Floating "Replay Intro" button
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _previewIntroSeed = DateTime.now().millisecondsSinceEpoch;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.replay_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Replay Intro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectBottomActionBar(BuildContext context, Map<String, dynamic> effect) {
    final effectKey = effect['key']?.toString() ?? '';
    final effectName = effect['name']?.toString() ?? 'Profile Effect';
    final price = (effect['price'] as num?)?.toDouble() ?? 0.0;
    final isEquipped = _equippedProfileEffect == effectKey;
    final isOwned = _ownedEffectKeys.contains(effectKey);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isOwned) ...[
                    Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '${price.toStringAsFixed(0)} KC',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Balance: ${_coinsBalance.toStringAsFixed(0)} KC',
                      style: TextStyle(
                        fontSize: 11,
                        color: _coinsBalance < price ? const Color(0xFFEF4444) : Colors.grey.shade600,
                        fontWeight: _coinsBalance < price ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ] else if (isEquipped) ...[
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Equipped',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active on your profile',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ] else ...[
                    Row(
                      children: const [
                        Icon(Icons.inventory_2_rounded, color: Color(0xFFA855F7), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Owned',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFA855F7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ready to equip',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            if (!isOwned)
              GestureDetector(
                onTap: _isPurchasingEffect ? null : () => _buyProfileEffect(effect),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isPurchasingEffect
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Buy for ${price.toStringAsFixed(0)} KC',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              )
            else if (isEquipped)
              GestureDetector(
                onTap: () => _toggleEquipEffect(effectKey, effectName),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Unequip',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _toggleEquipEffect(effectKey, effectName),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF7E22CE)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Equip Effect',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  final user = _currentUser ?? User(id: '0', username: _currentUsername, raw: const {});
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WalletScreen(user: user)),
                  );
                  _fetchWalletBalance();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFBBF24).withOpacity(0.9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        '${_coinsBalance.toStringAsFixed(0)} KC',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.add_circle_rounded,
                        color: Color(0xFFF59E0B),
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
              // Segmented Tab Selector (4 Tabs)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.9)),
                  ),
                  child: Row(
                    children: [
                      // Tab 0: Postcards
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchTab(0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 0
                                  ? const Color(0xFFA855F7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Postcards',
                              style: TextStyle(
                                color: _activeTabIndex == 0
                                    ? Colors.white
                                    : const Color(0xFF4B5563),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Tab 1: Profile Effects (NEW)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchTab(1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 1
                                  ? const Color(0xFFA855F7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Effects',
                                  style: TextStyle(
                                    color: _activeTabIndex == 1
                                        ? Colors.white
                                        : const Color(0xFF4B5563),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _activeTabIndex == 1
                                        ? Colors.white.withOpacity(0.3)
                                        : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: _activeTabIndex == 1
                                          ? Colors.white
                                          : const Color(0xFF15803D),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Tab 2: Chat Bubbles
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchTab(2),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 2
                                  ? const Color(0xFFA855F7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Bubbles',
                                  style: TextStyle(
                                    color: _activeTabIndex == 2
                                        ? Colors.white
                                        : const Color(0xFF4B5563),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _activeTabIndex == 2
                                        ? Colors.white.withOpacity(0.3)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'VIP',
                                    style: TextStyle(
                                      color: _activeTabIndex == 2
                                          ? Colors.white
                                          : const Color(0xFFD97706),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Tab 3: Owned Items
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchTab(3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 3
                                  ? const Color(0xFFA855F7)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Owned',
                              style: TextStyle(
                                color: _activeTabIndex == 3
                                    ? Colors.white
                                    : const Color(0xFF4B5563),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab 0: Postcards
              if (_activeTabIndex == 0) ...[
                Builder(
                  builder: (context) {
                    final postcards = _visibleProducts
                        .where((p) => !_isBubbleProduct(p.type))
                        .toList();

                    if (_isThemeStateLoading) {
                      return const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFA855F7),
                          ),
                        ),
                      );
                    }

                    if (postcards.isEmpty) {
                      return Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.style_outlined,
                                    size: 36,
                                    color: Color(0xFF9333EA),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Postcard Designs Available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'All old designs have been removed.\nNew postcard designs will be added soon!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live Preview Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Live Postcard Preview',
                                  style: TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildLivePreviewCard(_selectedTheme),
                              ],
                            ),
                          ),
                          // Postcards List Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Text(
                                  'Available Postcards',
                                  style: TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${postcards.length} postcards',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Postcards List
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: postcards.length,
                              itemBuilder: (context, index) {
                                final theme = postcards[index];
                                final isSelected =
                                    _selectedTheme?.key == theme.key;
                                return _ThemeListItem(
                                  theme: theme,
                                  isSelected: isSelected,
                                  isApplied: _isApplied(theme),
                                  isLocked: !_canApplyTheme(theme),
                                  onTap: () => _onSelectTheme(theme),
                                );
                              },
                            ),
                          ),
                          // Bottom Action Bar
                          if (_selectedTheme != null && !_isBubbleProduct(_selectedTheme!.type))
                            _buildBottomActionBar(context, _selectedTheme!),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (_activeTabIndex == 1) ...[
                // Tab 1: Profile Effects
                Expanded(
                  child: _buildEffectsTab(),
                ),
              ] else if (_activeTabIndex == 2) ...[
                // Tab 2: Chat Bubbles
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Chat Bubble Preview',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLivePreviewCard(_selectedTheme),
                    ],
                  ),
                ),

                // Bubbles List Header
                Builder(
                  builder: (context) {
                    final bubbles = _visibleProducts
                        .where((p) => _isBubbleProduct(p.type))
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Chat Bubble Skins',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${bubbles.length} skins',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Bubbles List
                Expanded(
                  child: _isThemeStateLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFA855F7),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final bubbles = _visibleProducts
                                .where((p) => _isBubbleProduct(p.type))
                                .toList();
                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: bubbles.length,
                              itemBuilder: (context, index) {
                                final theme = bubbles[index];
                                final isSelected =
                                    _selectedTheme?.key == theme.key;
                                return _ThemeListItem(
                                  theme: theme,
                                  isSelected: isSelected,
                                  isApplied: _isApplied(theme),
                                  isLocked: !_canApplyTheme(theme),
                                  onTap: () => _onSelectTheme(theme),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Bottom Action Bar
                if (_selectedTheme != null && _isBubbleProduct(_selectedTheme!.type))
                  _buildBottomActionBar(context, _selectedTheme!),
              ] else ...[
                // Tab 2: Owned Items / Frames
                Expanded(
                  child: _buildOwnedItemsTab(),
                ),
              ],
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
                      if (theme.type == ThemeProductType.starlightWhales || theme.isAnimatedPostcard)
                        Positioned.fill(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: CachedNetworkImage(
                                imageUrl: theme.assetPath,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const SizedBox(),
                                errorWidget: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          ),
                        )
                      else if (showCuteHeart)
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
                          child: CachedNetworkImage(
                            imageUrl: '${ApiConfig.postcardUrl(theme.assetPath)}',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            placeholder: (context, url) => const SizedBox(),
                            errorWidget: (context, url, error) => Image.asset(
                              theme.assetPath,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
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
                        if (theme.price > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '${theme.price.toStringAsFixed(0)} KC',
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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

class _EffectListItem extends StatelessWidget {
  const _EffectListItem({
    required this.effect,
    required this.isSelected,
    required this.isEquipped,
    required this.isOwned,
    required this.onTap,
  });

  final Map<String, dynamic> effect;
  final bool isSelected;
  final bool isEquipped;
  final bool isOwned;
  final VoidCallback onTap;

  Color get _accentColor {
    final k = (effect['key']?.toString() ?? '').toLowerCase().replaceAll('-', '_');
    switch (k) {
      case 'cloud_nine':
        return const Color(0xFFEC4899);
      case 'falling_stars':
        return const Color(0xFF38BDF8);
      case 'la_llorona':
        return const Color(0xFFA855F7);
      case 'boost_relic':
        return const Color(0xFFF59E0B);
      case 'cyberspace':
        return const Color(0xFF06B6D4);
      case 'hydro_blast':
        return const Color(0xFF0EA5E9);
      case 'shatter':
        return const Color(0xFF818CF8);
      case 'magic_hearts':
        return const Color(0xFFF43F5E);
      case 'sakura_dreams':
        return const Color(0xFFF472B6);
      case 'power_surge':
        return const Color(0xFFEAB308);
      case 'shuriken_strike':
        return const Color(0xFFEF4444);
      case 'mystic_vines':
        return const Color(0xFF10B981);
      case 'pixie_dust':
        return const Color(0xFFFBBF24);
      case 'discord_os':
        return const Color(0xFF6366F1);
      case 'breakfast_plate':
        return const Color(0xFFF97316);
      case 'ghoulish_graffiti':
        return const Color(0xFFA855F7);
      case 'dark_omens':
        return const Color(0xFFDC2626);
      case 'fall_foliage':
        return const Color(0xFFD97706);
case 'all_nighter':
        return const Color(0xFFF59E0B);
      case 'arcane_summons':
        return const Color(0xFFA855F7);
      case 'clove_s_ruse':
        return const Color(0xFFC084FC);
      case 'deck_the_halls':
        return const Color(0xFFEF4444);
      case 'doodlebob_takeover':
        return const Color(0xFFE4E4E7);
      case 'dragon_dance':
        return const Color(0xFFF59E0B);
      case 'dreamy':
        return const Color(0xFFF472B6);
      case 'feelin_90s':
        return const Color(0xFF06B6D4);
      case 'feelin_mischievous':
        return const Color(0xFF4ADE80);
      case 'feelin_pizzazz':
        return const Color(0xFFFBBF24);
      case 'fellowship_of_the_spring':
        return const Color(0xFF34D399);
      case 'forgotten_treasure':
        return const Color(0xFFF59E0B);
      case 'fortune_flurry':
        return const Color(0xFFFACC15);
      case 'goozilla':
        return const Color(0xFF22C55E);
      case 'handsome_squidward':
        return const Color(0xFF38BDF8);
      case 'haunted_man_o_war':
        return const Color(0xFF2DD4BF);
      case 'heartzilla':
        return const Color(0xFFF43F5E);
      case 'jolly_roger':
        return const Color(0xFFDC2626);
      case 'ki_detonate':
        return const Color(0xFFFACC15);
      case 'lilypad_life':
        return const Color(0xFF10B981);
      case 'mastery':
        return const Color(0xFFF59E0B);
      case 'midnight_celebration':
        return const Color(0xFFA855F7);
      case 'midnight_lilypad_life':
        return const Color(0xFF2DD4BF);
      case 'monster_pop':
        return const Color(0xFFF43F5E);
      case 'muddy_lilypad_life':
        return const Color(0xFF84CC16);
      case 'nice_profile':
        return const Color(0xFF38BDF8);
      case 'nightrunner':
        return const Color(0xFF06B6D4);
      case 'petal_serenade':
        return const Color(0xFFF472B6);
      case 'rock_slide':
        return const Color(0xFFA8A29E);
      case 'saya':
        return const Color(0xFFF472B6);
      case 'shooting_stars':
        return const Color(0xFF38BDF8);
      case 'snowy_shenanigans':
        return const Color(0xFF38BDF8);
      case 'space_evader':
        return const Color(0xFF22C55E);
      case 'spirit_flame':
        return const Color(0xFF0EA5E9);
      case 'spring_bloom':
        return const Color(0xFF10B981);
      case 'study_spot':
        return const Color(0xFFF59E0B);
      case 'supernova':
        return const Color(0xFFF97316);
      case 'sushi_mania':
        return const Color(0xFFF97316);
      case 'the_immortal_clove':
        return const Color(0xFFA855F7);
      case 'tocotoco':
        return const Color(0xFFF43F5E);
      case 'turbo_drive':
        return const Color(0xFFEF4444);
      case 'twilight':
        return const Color(0xFF818CF8);
      case 'twinkle_trails':
        return const Color(0xFFFBBF24);
      case 'uplink_error':
        return const Color(0xFF06B6D4);
      case 'vengeance':
        return const Color(0xFFDC2626);
      case 'vortex':
        return const Color(0xFFA855F7);
      case 'wake_up':
        return const Color(0xFFF59E0B);
      case 'watercolors':
        return const Color(0xFFEC4899);
case 'akuma_s_wrath':
        return const Color(0xFFEF4444);
      case 'arcane_epiphany':
        return const Color(0xFF818CF8);
      case 'aurora_dreams':
        return const Color(0xFF34D399);
      case 'autumn_equinox':
        return const Color(0xFFF97316);
      case 'beholder':
        return const Color(0xFFA855F7);
      case 'blazing_ghoulish_graffiti':
        return const Color(0xFFF97316);
      case 'bubble_tea_bliss':
        return const Color(0xFFD97706);
      case 'bubblegum_zombie_slime':
        return const Color(0xFFF43F5E);
      case 'chocolate_discord_os':
        return const Color(0xFFB45309);
      case 'classic_street_fighter':
        return const Color(0xFFFACC15);
      case 'clockwork_butterflies':
        return const Color(0xFFF59E0B);
      case 'cloud_zeppelin':
        return const Color(0xFF38BDF8);
      case 'deck_the_halls_aurora':
        return const Color(0xFF10B981);
      case 'deck_the_halls_dusk':
        return const Color(0xFFA855F7);
      case 'deck_the_halls_ember':
        return const Color(0xFFEA580C);
      case 'deck_the_halls_mix':
        return const Color(0xFFEC4899);
      case 'ekko_s_aeroglider_stunts':
        return const Color(0xFF2DD4BF);
      case 'enchanted_forest':
        return const Color(0xFF34D399);
      case 'flutter_and_frolic':
        return const Color(0xFFF472B6);
      case 'fog_of_war':
        return const Color(0xFF94A3B8);
      case 'heartzilla_purple':
        return const Color(0xFFC084FC);
      case 'infernal_dark_omens':
        return const Color(0xFFEF4444);
      case 'innovator_s_masterwork':
        return const Color(0xFFF59E0B);
      case 'jinx_and_pow_pow':
        return const Color(0xFF06B6D4);
      case 'kawaii_mode':
        return const Color(0xFFF472B6);
      case 'koi_garden':
        return const Color(0xFFF97316);
      case 'lofi_cat_zoomies_festive':
        return const Color(0xFF22C55E);
      case 'lofi_girl_snow_angel':
        return const Color(0xFF38BDF8);
      case 'lofi_girl_study_break':
        return const Color(0xFFF59E0B);
      case 'm_bison_s_return':
        return const Color(0xFFE11D48);
      case 'mermaid_whisperer':
        return const Color(0xFF22D3EE);
      case 'midnight_dark_omens':
        return const Color(0xFF818CF8);
      case 'midnight_zombie_slime':
        return const Color(0xFF38BDF8);
      case 'mimic':
        return const Color(0xFFD97706);
      case 'mooncap_forest_blue':
        return const Color(0xFF60A5FA);
      case 'mooncap_forest_pink':
        return const Color(0xFFF472B6);
      case 'neon_ghoulish_graffiti':
        return const Color(0xFF22D3EE);
      case 'ocean_flowers':
        return const Color(0xFF2DD4BF);
      case 'of_ink_and_steel':
        return const Color(0xFFE2E8F0);
      case 'oni_s_curse':
        return const Color(0xFF38BDF8);
      case 'paint_the_town_blue':
        return const Color(0xFF38BDF8);
      case 'penguins_on_ice':
        return const Color(0xFF38BDF8);
      case 'plankton_splat':
        return const Color(0xFF4ADE80);
      case 'plushie_party':
        return const Color(0xFFF472B6);
      case 'portal_beyond_blue':
        return const Color(0xFF60A5FA);
      case 'portal_beyond_purple':
        return const Color(0xFFA855F7);
      case 'red_dragon':
        return const Color(0xFFEF4444);
      case 'sakura_katana':
        return const Color(0xFFF472B6);
      case 'scarlet_fall_foliage':
        return const Color(0xFFF87171);
      case 'snowy_shenanigans_giddy':
        return const Color(0xFF38BDF8);
      case 'snowy_shenanigans_jolly':
        return const Color(0xFF38BDF8);
      case 'snowy_shenanigans_smooch':
        return const Color(0xFFF472B6);
      case 'snowy_shenanigans_suave':
        return const Color(0xFF38BDF8);
      case 'spirit_of_the_kitsune':
        return const Color(0xFF22D3EE);
      case 'street_fighter_6':
        return const Color(0xFFF59E0B);
      case 'sun_and_moon':
        return const Color(0xFFFACC15);
      case 'sunrise_grove':
        return const Color(0xFFF97316);
      case 'twilight_grove':
        return const Color(0xFFA855F7);
      case 'twist_of_luck':
        return const Color(0xFFFACC15);
      case 'vct_supernova':
        return const Color(0xFFFACC15);
      case 'wonder_construction':
        return const Color(0xFFF59E0B);
      case 'woodland_fall_foliage':
        return const Color(0xFFD97706);
      case 'yoru_dimensional_rip':
        return const Color(0xFF38BDF8);
      case 'zombie_slime':
      default:
        return const Color(0xFF22C55E);
    }
  }

  List<Color> get _badgeGradient {
    final k = (effect['key']?.toString() ?? '').toLowerCase().replaceAll('-', '_');
    switch (k) {
      case 'cloud_nine':
        return const [Color(0xFFEC4899), Color(0xFFA855F7)];
      case 'falling_stars':
        return const [Color(0xFF38BDF8), Color(0xFF6366F1)];
      case 'la_llorona':
        return const [Color(0xFFA855F7), Color(0xFF6366F1)];
      case 'boost_relic':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'cyberspace':
        return const [Color(0xFF22D3EE), Color(0xFF0284C7)];
      case 'hydro_blast':
        return const [Color(0xFF38BDF8), Color(0xFF0284C7)];
      case 'shatter':
        return const [Color(0xFFA5B4FC), Color(0xFF6366F1)];
      case 'magic_hearts':
        return const [Color(0xFFFB7185), Color(0xFFE11D48)];
      case 'sakura_dreams':
        return const [Color(0xFFF9A8D4), Color(0xFFEC4899)];
      case 'power_surge':
        return const [Color(0xFFFACC15), Color(0xFFCA8A04)];
      case 'shuriken_strike':
        return const [Color(0xFFF87171), Color(0xFFDC2626)];
      case 'mystic_vines':
        return const [Color(0xFF10B981), Color(0xFF059669)];
      case 'pixie_dust':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'discord_os':
        return const [Color(0xFF818CF8), Color(0xFF4F46E5)];
      case 'breakfast_plate':
        return const [Color(0xFFFB923C), Color(0xFFEA580C)];
      case 'ghoulish_graffiti':
        return const [Color(0xFFC084FC), Color(0xFF9333EA)];
      case 'dark_omens':
        return const [Color(0xFFF87171), Color(0xFFDC2626)];
      case 'fall_foliage':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
case 'all_nighter':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'arcane_summons':
        return const [Color(0xFFC084FC), Color(0xFF9333EA)];
      case 'clove_s_ruse':
        return const [Color(0xFFE879F9), Color(0xFFA855F7)];
      case 'deck_the_halls':
        return const [Color(0xFF22C55E), Color(0xFFDC2626)];
      case 'doodlebob_takeover':
        return const [Color(0xFFA1A1AA), Color(0xFF71717A)];
      case 'dragon_dance':
        return const [Color(0xFFF87171), Color(0xFFEA580C)];
      case 'dreamy':
        return const [Color(0xFFF9A8D4), Color(0xFFC084FC)];
      case 'feelin_90s':
        return const [Color(0xFF22D3EE), Color(0xFFF43F5E)];
      case 'feelin_mischievous':
        return const [Color(0xFF22C55E), Color(0xFF16A34A)];
      case 'feelin_pizzazz':
        return const [Color(0xFFFDE047), Color(0xFFD97706)];
      case 'fellowship_of_the_spring':
        return const [Color(0xFF6EE7B7), Color(0xFF059669)];
      case 'forgotten_treasure':
        return const [Color(0xFF38BDF8), Color(0xFFD97706)];
      case 'fortune_flurry':
        return const [Color(0xFFEF4444), Color(0xFFCA8A04)];
      case 'goozilla':
        return const [Color(0xFF4ADE80), Color(0xFF15803D)];
      case 'handsome_squidward':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'haunted_man_o_war':
        return const [Color(0xFF5EEAD4), Color(0xFF0D9488)];
      case 'heartzilla':
        return const [Color(0xFFFB7185), Color(0xFFE11D48)];
      case 'jolly_roger':
        return const [Color(0xFFF87171), Color(0xFFB91C1C)];
      case 'ki_detonate':
        return const [Color(0xFFFDE047), Color(0xFFCA8A04)];
      case 'lilypad_life':
        return const [Color(0xFF34D399), Color(0xFF047857)];
      case 'mastery':
        return const [Color(0xFFFBBF24), Color(0xFFB45309)];
      case 'midnight_celebration':
        return const [Color(0xFF38BDF8), Color(0xFFEC4899)];
      case 'midnight_lilypad_life':
        return const [Color(0xFF38BDF8), Color(0xFF059669)];
      case 'monster_pop':
        return const [Color(0xFFF472B6), Color(0xFF8B5CF6)];
      case 'muddy_lilypad_life':
        return const [Color(0xFFA3E635), Color(0xFF65A30D)];
      case 'nice_profile':
        return const [Color(0xFF38BDF8), Color(0xFF6366F1)];
      case 'nightrunner':
        return const [Color(0xFF22D3EE), Color(0xFFEC4899)];
      case 'petal_serenade':
        return const [Color(0xFFF9A8D4), Color(0xFFEC4899)];
      case 'rock_slide':
        return const [Color(0xFFD6D3D1), Color(0xFF78716C)];
      case 'saya':
        return const [Color(0xFFF9A8D4), Color(0xFFA855F7)];
      case 'shooting_stars':
        return const [Color(0xFF60A5FA), Color(0xFF818CF8)];
      case 'snowy_shenanigans':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'space_evader':
        return const [Color(0xFF4ADE80), Color(0xFF16A34A)];
      case 'spirit_flame':
        return const [Color(0xFF38BDF8), Color(0xFF2563EB)];
      case 'spring_bloom':
        return const [Color(0xFF34D399), Color(0xFF06B6D4)];
      case 'study_spot':
        return const [Color(0xFFFBBF24), Color(0xFF0284C7)];
      case 'supernova':
        return const [Color(0xFFFB923C), Color(0xFFA855F7)];
      case 'sushi_mania':
        return const [Color(0xFFFB923C), Color(0xFF22C55E)];
      case 'the_immortal_clove':
        return const [Color(0xFFC084FC), Color(0xFF7C3AED)];
      case 'tocotoco':
        return const [Color(0xFFFB7185), Color(0xFF38BDF8)];
      case 'turbo_drive':
        return const [Color(0xFFF87171), Color(0xFFDC2626)];
      case 'twilight':
        return const [Color(0xFFA5B4FC), Color(0xFF6366F1)];
      case 'twinkle_trails':
        return const [Color(0xFFFDE047), Color(0xFFA855F7)];
      case 'uplink_error':
        return const [Color(0xFF22D3EE), Color(0xFF0284C7)];
      case 'vengeance':
        return const [Color(0xFFF87171), Color(0xFF991B1B)];
      case 'vortex':
        return const [Color(0xFFC084FC), Color(0xFF6B21A8)];
      case 'wake_up':
        return const [Color(0xFFFBBF24), Color(0xFF38BDF8)];
      case 'watercolors':
        return const [Color(0xFFF472B6), Color(0xFF06B6D4)];
case 'akuma_s_wrath':
        return const [Color(0xFFDC2626), Color(0xFF7F1D1D)];
      case 'arcane_epiphany':
        return const [Color(0xFFA5B4FC), Color(0xFF6366F1)];
      case 'aurora_dreams':
        return const [Color(0xFF6EE7B7), Color(0xFF8B5CF6)];
      case 'autumn_equinox':
        return const [Color(0xFFFB923C), Color(0xFFD97706)];
      case 'beholder':
        return const [Color(0xFFC084FC), Color(0xFF7E22CE)];
      case 'blazing_ghoulish_graffiti':
        return const [Color(0xFFFB923C), Color(0xFFDC2626)];
      case 'bubble_tea_bliss':
        return const [Color(0xFFFBBF24), Color(0xFFB45309)];
      case 'bubblegum_zombie_slime':
        return const [Color(0xFFFB7185), Color(0xFFE11D48)];
      case 'chocolate_discord_os':
        return const [Color(0xFFD97706), Color(0xFF78350F)];
      case 'classic_street_fighter':
        return const [Color(0xFFEF4444), Color(0xFFF59E0B)];
      case 'clockwork_butterflies':
        return const [Color(0xFFFBBF24), Color(0xFFB45309)];
      case 'cloud_zeppelin':
        return const [Color(0xFF7DD3FC), Color(0xFFF59E0B)];
      case 'deck_the_halls_aurora':
        return const [Color(0xFF34D399), Color(0xFF059669)];
      case 'deck_the_halls_dusk':
        return const [Color(0xFFC084FC), Color(0xFF7C3AED)];
      case 'deck_the_halls_ember':
        return const [Color(0xFFF97316), Color(0xFFC2410C)];
      case 'deck_the_halls_mix':
        return const [Color(0xFFF43F5E), Color(0xFF3B82F6)];
      case 'ekko_s_aeroglider_stunts':
        return const [Color(0xFF22D3EE), Color(0xFF10B981)];
      case 'enchanted_forest':
        return const [Color(0xFF6EE7B7), Color(0xFF047857)];
      case 'flutter_and_frolic':
        return const [Color(0xFFF9A8D4), Color(0xFF8B5CF6)];
      case 'fog_of_war':
        return const [Color(0xFF64748B), Color(0xFF334155)];
      case 'heartzilla_purple':
        return const [Color(0xFFE879F9), Color(0xFF9333EA)];
      case 'infernal_dark_omens':
        return const [Color(0xFFF97316), Color(0xFFDC2626)];
      case 'innovator_s_masterwork':
        return const [Color(0xFF38BDF8), Color(0xFFD97706)];
      case 'jinx_and_pow_pow':
        return const [Color(0xFFF43F5E), Color(0xFF06B6D4)];
      case 'kawaii_mode':
        return const [Color(0xFFF9A8D4), Color(0xFFEC4899)];
      case 'koi_garden':
        return const [Color(0xFFFB923C), Color(0xFF10B981)];
      case 'lofi_cat_zoomies_festive':
        return const [Color(0xFF4ADE80), Color(0xFFEF4444)];
      case 'lofi_girl_snow_angel':
        return const [Color(0xFF7DD3FC), Color(0xFF6366F1)];
      case 'lofi_girl_study_break':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'm_bison_s_return':
        return const [Color(0xFFF43F5E), Color(0xFF881337)];
      case 'mermaid_whisperer':
        return const [Color(0xFF67E8F9), Color(0xFF0284C7)];
      case 'midnight_dark_omens':
        return const [Color(0xFFA5B4FC), Color(0xFF4338CA)];
      case 'midnight_zombie_slime':
        return const [Color(0xFF0284C7), Color(0xFF0EA5E9)];
      case 'mimic':
        return const [Color(0xFFF59E0B), Color(0xFF9A3412)];
      case 'mooncap_forest_blue':
        return const [Color(0xFF93C5FD), Color(0xFF2563EB)];
      case 'mooncap_forest_pink':
        return const [Color(0xFFF9A8D4), Color(0xFFDB2777)];
      case 'neon_ghoulish_graffiti':
        return const [Color(0xFF38BDF8), Color(0xFF0891B2)];
      case 'ocean_flowers':
        return const [Color(0xFF5EEAD4), Color(0xFF0D9488)];
      case 'of_ink_and_steel':
        return const [Color(0xFFCBD5E1), Color(0xFF64748B)];
      case 'oni_s_curse':
        return const [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
      case 'paint_the_town_blue':
        return const [Color(0xFF60A5FA), Color(0xFF0284C7)];
      case 'penguins_on_ice':
        return const [Color(0xFF93C5FD), Color(0xFF0284C7)];
      case 'plankton_splat':
        return const [Color(0xFF86EFAC), Color(0xFF16A34A)];
      case 'plushie_party':
        return const [Color(0xFFF9A8D4), Color(0xFFDB2777)];
      case 'portal_beyond_blue':
        return const [Color(0xFF93C5FD), Color(0xFF2563EB)];
      case 'portal_beyond_purple':
        return const [Color(0xFFC084FC), Color(0xFF7E22CE)];
      case 'red_dragon':
        return const [Color(0xFFF87171), Color(0xFFB91C1C)];
      case 'sakura_katana':
        return const [Color(0xFFF9A8D4), Color(0xFFBE185D)];
      case 'scarlet_fall_foliage':
        return const [Color(0xFFEF4444), Color(0xFF991B1B)];
      case 'snowy_shenanigans_giddy':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'snowy_shenanigans_jolly':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'snowy_shenanigans_smooch':
        return const [Color(0xFFF9A8D4), Color(0xFFA855F7)];
      case 'snowy_shenanigans_suave':
        return const [Color(0xFF7DD3FC), Color(0xFF0284C7)];
      case 'spirit_of_the_kitsune':
        return const [Color(0xFF67E8F9), Color(0xFF0891B2)];
      case 'street_fighter_6':
        return const [Color(0xFFFBBF24), Color(0xFFDC2626)];
      case 'sun_and_moon':
        return const [Color(0xFFFDE047), Color(0xFF818CF8)];
      case 'sunrise_grove':
        return const [Color(0xFFFB923C), Color(0xFFF59E0B)];
      case 'twilight_grove':
        return const [Color(0xFFC084FC), Color(0xFF6B21A8)];
      case 'twist_of_luck':
        return const [Color(0xFFFDE047), Color(0xFFCA8A04)];
      case 'vct_supernova':
        return const [Color(0xFFFDE047), Color(0xFFCA8A04)];
      case 'wonder_construction':
        return const [Color(0xFFFBBF24), Color(0xFFD97706)];
      case 'woodland_fall_foliage':
        return const [Color(0xFFF59E0B), Color(0xFF9A3412)];
      case 'yoru_dimensional_rip':
        return const [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
      case 'zombie_slime':
      default:
        return const [Color(0xFF22C55E), Color(0xFF10B981)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = effect['name']?.toString() ?? 'Profile Effect';
    final desc = effect['description']?.toString() ?? '';
    final price = (effect['price'] as num?)?.toDouble() ?? 0.0;
    final isVip = effect['isVip'] == true;
    final loopUrl = effect['loopUrl']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.92)
              : Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _accentColor
                : Colors.white.withOpacity(0.6),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _accentColor.withOpacity(0.18)
                  : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Effect animated thumbnail preview
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accentColor.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: Colors.white24,
                      ),
                      Image.network(
                        loopUrl,
                        fit: BoxFit.cover,
                        width: 70,
                        height: 70,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.auto_awesome,
                          color: _accentColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, description & badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _badgeGradient,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Status Pill
                    if (isEquipped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'EQUIPPED',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isOwned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.inventory_2_rounded, color: Color(0xFFA855F7), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'OWNED',
                              style: TextStyle(
                                color: Color(0xFF7E22CE),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              '${price.toStringAsFixed(0)} KC',
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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
