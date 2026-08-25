import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

@immutable
class ConversationTheme {
  const ConversationTheme({
    required this.id,
    required this.label,
    required this.background,
    required this.ownBubble,
    required this.ownBubbleText,
    required this.otherBubble,
    required this.otherBubbleText,
    required this.accent,
    this.ownBubbleGradient,
  });

  final String id;
  final String label;
  final Color background;
  final Color ownBubble;
  final Color ownBubbleText;
  final Color otherBubble;
  final Color otherBubbleText;
  final Color accent;
  final List<Color>? ownBubbleGradient;

  static const ConversationTheme classic = ConversationTheme(
    id: 'classic',
    label: 'Classic',
    background: Color(0xFFF7F8FA),
    ownBubble: Color(0xFF111827),
    ownBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: Color(0xFF111827),
    accent: Color(0xFF111827),
  );

  static const ConversationTheme ocean = ConversationTheme(
    id: 'ocean',
    label: 'Ocean',
    background: Color(0xFFEAF4FF),
    ownBubble: Color(0xFF2563EB),
    ownBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: Color(0xFF0F172A),
    accent: Color(0xFF2563EB),
  );

  static const ConversationTheme sunset = ConversationTheme(
    id: 'sunset',
    label: 'Sunset',
    background: Color(0xFFFFF4EC),
    ownBubble: Color(0xFFF97316),
    ownBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: Color(0xFF3F2210),
    accent: Color(0xFFF97316),
    ownBubbleGradient: [Color(0xFFFB7185), Color(0xFFF97316)],
  );

  static const ConversationTheme bubbleDream = ConversationTheme(
    id: 'bubble_dream',
    label: 'Bubble Dream',
    background: Color(0xFFF5F3FF),
    ownBubble: Color(0xFF8B5CF6),
    ownBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: Color(0xFF4C1D95),
    accent: Color(0xFF8B5CF6),
    ownBubbleGradient: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  );

  static const ConversationTheme emerald = ConversationTheme(
    id: 'emerald',
    label: 'Emerald',
    background: Color(0xFFF0FDF4),
    ownBubble: Color(0xFF10B981),
    ownBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: Color(0xFF064E3B),
    accent: Color(0xFF10B981),
    ownBubbleGradient: [Color(0xFF34D399), Color(0xFF059669)],
  );

  static const ConversationTheme crimson = ConversationTheme(
    id: 'crimson',
    label: 'Crimson',
    background: Color(0xFFFFF1F2),
    ownBubble: Color(0xFFE11D48),
    ownBubbleText: Colors.white,
    otherBubble: Colors.white,
    otherBubbleText: Color(0xFF881337),
    accent: Color(0xFFE11D48),
    ownBubbleGradient: [Color(0xFFFB7185), Color(0xFFE11D48)],
  );

  static const ConversationTheme cyberpunk = ConversationTheme(
    id: 'cyberpunk',
    label: 'Cyberpunk',
    background: Color(0xFF0D0221),
    ownBubble: Color(0xFF00F0FF),
    ownBubbleText: Color(0xFF0D0221),
    otherBubble: Color(0xFF261447),
    otherBubbleText: Color(0xFFFF007F),
    accent: Color(0xFF00F0FF),
    ownBubbleGradient: [Color(0xFF00F0FF), Color(0xFFFF007F)],
  );

  static const ConversationTheme midnight = ConversationTheme(
    id: 'midnight',
    label: 'Midnight',
    background: Color(0xFF0F172A),
    ownBubble: Color(0xFF6366F1),
    ownBubbleText: Colors.white,
    otherBubble: Color(0xFF1E293B),
    otherBubbleText: Color(0xFFE2E8F0),
    accent: Color(0xFF6366F1),
    ownBubbleGradient: [Color(0xFF818CF8), Color(0xFF4F46E5)],
  );

  ConversationTheme resolveForBrightness(Brightness brightness) {
    if (brightness != Brightness.dark) return this;
    switch (id) {
      case 'classic':
        return const ConversationTheme(
          id: 'classic',
          label: 'Classic',
          background: Color(0xFF0F0F10),
          ownBubble: Color(0xFFFF7A45),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF242526),
          otherBubbleText: Color(0xFFE4E6EB),
          accent: Color(0xFFFF7A45),
        );
      case 'ocean':
        return const ConversationTheme(
          id: 'ocean',
          label: 'Ocean',
          background: Color(0xFF0F0F10),
          ownBubble: Color(0xFF3B82F6),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF242526),
          otherBubbleText: Color(0xFFE4E6EB),
          accent: Color(0xFF3B82F6),
        );
      case 'sunset':
        return const ConversationTheme(
          id: 'sunset',
          label: 'Sunset',
          background: Color(0xFF0F0F10),
          ownBubble: Color(0xFFF97316),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF242526),
          otherBubbleText: Color(0xFFE4E6EB),
          accent: Color(0xFFF97316),
          ownBubbleGradient: [Color(0xFFFB7185), Color(0xFFF97316)],
        );
      case 'bubble_dream':
        return const ConversationTheme(
          id: 'bubble_dream',
          label: 'Bubble Dream',
          background: Color(0xFF0F0F10),
          ownBubble: Color(0xFF8B5CF6),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF242526),
          otherBubbleText: Color(0xFFE4E6EB),
          accent: Color(0xFF8B5CF6),
          ownBubbleGradient: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
        );
      case 'emerald':
        return const ConversationTheme(
          id: 'emerald',
          label: 'Emerald',
          background: Color(0xFF0F0F10),
          ownBubble: Color(0xFF10B981),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF242526),
          otherBubbleText: Color(0xFFE4E6EB),
          accent: Color(0xFF10B981),
          ownBubbleGradient: [Color(0xFF34D399), Color(0xFF059669)],
        );
      case 'crimson':
        return const ConversationTheme(
          id: 'crimson',
          label: 'Crimson',
          background: Color(0xFF0F0F10),
          ownBubble: Color(0xFFE11D48),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF242526),
          otherBubbleText: Color(0xFFE4E6EB),
          accent: Color(0xFFE11D48),
          ownBubbleGradient: [Color(0xFFFB7185), Color(0xFFE11D48)],
        );
      case 'cyberpunk':
        return const ConversationTheme(
          id: 'cyberpunk',
          label: 'Cyberpunk',
          background: Color(0xFF0D0221),
          ownBubble: Color(0xFF00F0FF),
          ownBubbleText: Color(0xFF0D0221),
          otherBubble: Color(0xFF261447),
          otherBubbleText: Color(0xFFFF007F),
          accent: Color(0xFF00F0FF),
          ownBubbleGradient: [Color(0xFF00F0FF), Color(0xFFFF007F)],
        );
      case 'midnight':
        return const ConversationTheme(
          id: 'midnight',
          label: 'Midnight',
          background: Color(0xFF0F172A),
          ownBubble: Color(0xFF6366F1),
          ownBubbleText: Colors.white,
          otherBubble: Color(0xFF1E293B),
          otherBubbleText: Color(0xFFE2E8F0),
          accent: Color(0xFF6366F1),
          ownBubbleGradient: [Color(0xFF818CF8), Color(0xFF4F46E5)],
        );
      default:
        return this;
    }
  }

  static const List<ConversationTheme> presets = [
    classic,
    ocean,
    sunset,
    bubbleDream,
    emerald,
    crimson,
    cyberpunk,
    midnight,
  ];

  static ConversationTheme byId(String? id) {
    for (final t in presets) {
      if (t.id == id) return t;
    }
    return classic;
  }
}

class ConversationThemeStore {
  ConversationThemeStore._();

  static const String _prefsKey = 'conversation_themes_v1';
  static const String _globalBubbleThemeKey = 'global_bubble_theme_v1';

  static final ValueNotifier<Map<int, String>> _selections =
      ValueNotifier<Map<int, String>>(<int, String>{});
  static bool _initialized = false;

  static String _activeBubbleThemeId = '';
  static final ValueNotifier<String> activeBubbleTheme = ValueNotifier<String>('');

  static ValueListenable<Map<int, String>> get selections => _selections;

  static String get activeBubbleThemeId => _activeBubbleThemeId;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeBubbleThemeId = prefs.getString(_globalBubbleThemeKey) ?? '';
      activeBubbleTheme.value = _activeBubbleThemeId;

      final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
      final map = <int, String>{};
      for (final entry in raw) {
        final idx = entry.indexOf(':');
        if (idx <= 0) continue;
        final id = int.tryParse(entry.substring(0, idx));
        final themeId = entry.substring(idx + 1);
        if (id != null && id > 0 && themeId.isNotEmpty) {
          map[id] = themeId;
        }
      }
      _selections.value = map;

      // Sync with cached user profile
      try {
        final user = await AuthService().getSavedUser();
        final serverThemeId = (user?.bubbleTheme ?? '').trim().toLowerCase();
        if (serverThemeId != _activeBubbleThemeId) {
          _activeBubbleThemeId = serverThemeId;
          activeBubbleTheme.value = serverThemeId;
          if (serverThemeId.isEmpty) {
            await prefs.remove(_globalBubbleThemeKey);
          } else {
            await prefs.setString(_globalBubbleThemeKey, serverThemeId);
          }
        }
      } catch (_) {}
    } catch (_) {
      _selections.value = <int, String>{};
    }
  }

  static ConversationTheme themeFor(int threadId) {
    final id = _selections.value[threadId];
    if (id != null && id.isNotEmpty) {
      return ConversationTheme.byId(id);
    }
    if (_activeBubbleThemeId.isNotEmpty) {
      return ConversationTheme.byId(_activeBubbleThemeId);
    }
    return ConversationTheme.classic;
  }

  static Future<void> setTheme(int threadId, String themeId) async {
    if (threadId <= 0) return;
    final next = Map<int, String>.from(_selections.value);
    next[threadId] = themeId;
    _selections.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        next.entries.map((e) => '${e.key}:${e.value}').toList(),
      );
    } catch (_) {
      // best-effort; in-memory selection still updated
    }
  }

  static Future<void> setGlobalBubbleTheme(String themeId) async {
    _activeBubbleThemeId = themeId;
    activeBubbleTheme.value = themeId;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (themeId.isEmpty) {
        await prefs.remove(_globalBubbleThemeKey);
      } else {
        await prefs.setString(_globalBubbleThemeKey, themeId);
      }
    } catch (_) {}
    // Trigger notifier update to refresh DM screen
    final current = Map<int, String>.from(_selections.value);
    _selections.value = current;
  }

  static Future<void> clear() async {
    _activeBubbleThemeId = '';
    activeBubbleTheme.value = '';
    _selections.value = <int, String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_globalBubbleThemeKey);
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
