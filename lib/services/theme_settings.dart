import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  static const String _sunriseThemeKey = 'katsklub_sunrise_theme_applied';
  static const String _oceanThemeKey = 'katsklub_ocean_theme_applied';
  static const String _beeThemeKey = 'katsklub_bee_theme_applied';
  static const String _geminiRogerHunterThemeKey =
      'katsklub_gemini_roger_hunter_theme_applied';
  static const String _geminiRogerWolfThemeKey =
      'katsklub_gemini_roger_wolf_theme_applied';

  static final ValueNotifier<bool> isSunriseApplied =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isOceanApplied = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isBeeApplied = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isGeminiRogerHunterApplied =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isGeminiRogerWolfApplied =
      ValueNotifier<bool>(false);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isSunriseApplied.value = prefs.getBool(_sunriseThemeKey) ?? false;
      isOceanApplied.value = prefs.getBool(_oceanThemeKey) ?? false;
      isBeeApplied.value = prefs.getBool(_beeThemeKey) ?? false;
      isGeminiRogerHunterApplied.value =
          prefs.getBool(_geminiRogerHunterThemeKey) ?? false;
      isGeminiRogerWolfApplied.value =
          prefs.getBool(_geminiRogerWolfThemeKey) ?? false;
    } catch (_) {
      isSunriseApplied.value = false;
      isOceanApplied.value = false;
      isBeeApplied.value = false;
      isGeminiRogerHunterApplied.value = false;
      isGeminiRogerWolfApplied.value = false;
    }
  }

  static Future<void> _clearOtherThemes(SharedPreferences prefs) async {
    await prefs.setBool(_sunriseThemeKey, false);
    await prefs.setBool(_oceanThemeKey, false);
    await prefs.setBool(_beeThemeKey, false);
    await prefs.setBool(_geminiRogerHunterThemeKey, false);
    await prefs.setBool(_geminiRogerWolfThemeKey, false);
    isSunriseApplied.value = false;
    isOceanApplied.value = false;
    isBeeApplied.value = false;
    isGeminiRogerHunterApplied.value = false;
    isGeminiRogerWolfApplied.value = false;
  }

  static void _clearOtherThemesInMemory() {
    isSunriseApplied.value = false;
    isOceanApplied.value = false;
    isBeeApplied.value = false;
    isGeminiRogerHunterApplied.value = false;
    isGeminiRogerWolfApplied.value = false;
  }

  static Future<void> setSunriseApplied(bool applied) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (applied) {
        await _clearOtherThemes(prefs);
        await prefs.setBool(_sunriseThemeKey, true);
        isSunriseApplied.value = true;
      } else {
        await prefs.setBool(_sunriseThemeKey, false);
        isSunriseApplied.value = false;
      }
    } catch (_) {
      if (applied) {
        _clearOtherThemesInMemory();
        isSunriseApplied.value = true;
      } else {
        isSunriseApplied.value = false;
      }
    }
  }

  static Future<void> setOceanApplied(bool applied) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (applied) {
        await _clearOtherThemes(prefs);
        await prefs.setBool(_oceanThemeKey, true);
        isOceanApplied.value = true;
      } else {
        await prefs.setBool(_oceanThemeKey, false);
        isOceanApplied.value = false;
      }
    } catch (_) {
      if (applied) {
        _clearOtherThemesInMemory();
        isOceanApplied.value = true;
      } else {
        isOceanApplied.value = false;
      }
    }
  }

  static Future<void> setBeeApplied(bool applied) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (applied) {
        await _clearOtherThemes(prefs);
        await prefs.setBool(_beeThemeKey, true);
        isBeeApplied.value = true;
      } else {
        await prefs.setBool(_beeThemeKey, false);
        isBeeApplied.value = false;
      }
    } catch (_) {
      if (applied) {
        _clearOtherThemesInMemory();
        isBeeApplied.value = true;
      } else {
        isBeeApplied.value = false;
      }
    }
  }

  static Future<void> setGeminiRogerHunterApplied(bool applied) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (applied) {
        await _clearOtherThemes(prefs);
        await prefs.setBool(_geminiRogerHunterThemeKey, true);
        isGeminiRogerHunterApplied.value = true;
      } else {
        await prefs.setBool(_geminiRogerHunterThemeKey, false);
        isGeminiRogerHunterApplied.value = false;
      }
    } catch (_) {
      if (applied) {
        _clearOtherThemesInMemory();
        isGeminiRogerHunterApplied.value = true;
      } else {
        isGeminiRogerHunterApplied.value = false;
      }
    }
  }

  static Future<void> setGeminiRogerWolfApplied(bool applied) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (applied) {
        await _clearOtherThemes(prefs);
        await prefs.setBool(_geminiRogerWolfThemeKey, true);
        isGeminiRogerWolfApplied.value = true;
      } else {
        await prefs.setBool(_geminiRogerWolfThemeKey, false);
        isGeminiRogerWolfApplied.value = false;
      }
    } catch (_) {
      if (applied) {
        _clearOtherThemesInMemory();
        isGeminiRogerWolfApplied.value = true;
      } else {
        isGeminiRogerWolfApplied.value = false;
      }
    }
  }
}
