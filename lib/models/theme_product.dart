import 'package:flutter/material.dart';

enum ThemeProductType {
  customNameplate,
  starlightWhales,
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
  sagittariusBubble,
}

class ThemeProductData {
  const ThemeProductData({
    this.type = ThemeProductType.customNameplate,
    this.customKey,
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
    this.price = 0.0,
    this.isAnimatedPostcard = false,
  });

  final ThemeProductType type;
  final String? customKey;
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
  final double price;
  final bool isAnimatedPostcard;

  String get key {
    if (customKey != null && customKey!.isNotEmpty) return customKey!;
    return defaultKeyForType(type);
  }

  static String defaultKeyForType(ThemeProductType type) {
    switch (type) {
      case ThemeProductType.customNameplate:
        return 'custom_nameplate';
      case ThemeProductType.starlightWhales:
        return 'starlight_whales';
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
      case ThemeProductType.sagittariusBubble:
        return 'sagittarius';
    }
  }
}
