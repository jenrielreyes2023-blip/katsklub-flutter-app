import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Configuration definition for a profile effect.
class ProfileEffectConfig {
  final String id;
  final String name;
  final String introUrl;
  final String loopUrl;
  final Duration introDuration;
  final double aspectRatio;

  const ProfileEffectConfig({
    required this.id,
    required this.name,
    required this.introUrl,
    required this.loopUrl,
    this.introDuration = const Duration(milliseconds: 2880),
    this.aspectRatio = 450 / 880,
  });

  static const Map<String, ProfileEffectConfig> registry = {
    'zombie_slime': ProfileEffectConfig(
      id: 'zombie_slime',
      name: 'Zombie Slime',
      introUrl: 'https://media.katsklub.top/effects/zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'zombie-slime': ProfileEffectConfig(
      id: 'zombie-slime',
      name: 'Zombie Slime',
      introUrl: 'https://media.katsklub.top/effects/zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
  };

  /// Resolves an effect key or URL to a ProfileEffectConfig
  static ProfileEffectConfig? resolve(String? effectKey) {
    if (effectKey == null || effectKey.trim().isEmpty || effectKey == 'none') {
      return null;
    }
    final key = effectKey.trim().toLowerCase();
    if (registry.containsKey(key)) {
      return registry[key];
    }
    // If it's a direct URL to a WebP or APNG
    if (effectKey.startsWith('http://') || effectKey.startsWith('https://')) {
      return ProfileEffectConfig(
        id: effectKey,
        name: 'Custom Effect',
        introUrl: effectKey,
        loopUrl: effectKey,
        introDuration: Duration.zero,
      );
    }
    return null;
  }
}

/// A high-performance, non-intrusive animated profile effect overlay.
///
/// Features:
/// - Plays entrance [intro] animation once, then seamlessly transitions to infinite [loop].
/// - Bottom edge uses smooth shader mask fading into the background.
/// - Completely wrapped in [IgnorePointer] so profile buttons, avatar, cover, and links remain 100% interactive.
class ProfileEffectWidget extends StatefulWidget {
  const ProfileEffectWidget({
    required this.effect,
    this.height,
    this.applyBottomFade = true,
    super.key,
  });

  final String effect;
  final double? height;
  final bool applyBottomFade;

  @override
  State<ProfileEffectWidget> createState() => _ProfileEffectWidgetState();
}

class _ProfileEffectWidgetState extends State<ProfileEffectWidget> {
  ProfileEffectConfig? _config;
  bool _showingIntro = true;
  bool _introUnmounted = false;
  Timer? _introTimer;
  Timer? _unmountTimer;

  @override
  void initState() {
    super.initState();
    _initEffect();
  }

  @override
  void didUpdateWidget(ProfileEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _initEffect();
    }
  }

  void _initEffect() {
    _introTimer?.cancel();
    _unmountTimer?.cancel();
    _config = ProfileEffectConfig.resolve(widget.effect);

    if (_config == null) {
      _showingIntro = false;
      _introUnmounted = true;
      return;
    }

    if (_config!.introDuration > Duration.zero) {
      _showingIntro = true;
      _introUnmounted = false;
      _introTimer = Timer(_config!.introDuration, () {
        if (mounted) {
          setState(() {
            _showingIntro = false;
          });
          // After crossfade finishes (250ms), unmount intro to release texture memory immediately
          _unmountTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _introUnmounted = true;
              });
            }
          });
        }
      });
    } else {
      _showingIntro = false;
      _introUnmounted = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache the loop animation so the crossfade to loop is instantaneous
    if (_config != null && _config!.loopUrl.isNotEmpty) {
      precacheImage(NetworkImage(_config!.loopUrl), context);
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _unmountTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const SizedBox.shrink();
    }

    final double effectiveHeight = widget.height ?? 420.h;

    Widget effectContent;
    if (_introUnmounted) {
      // Intro is fully unmounted and discarded from memory; only the lightweight 537KB loop is active
      effectContent = Image.network(
        config.loopUrl,
        width: double.infinity,
        height: effectiveHeight,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      effectContent = SizedBox(
        width: double.infinity,
        height: effectiveHeight,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _showingIntro
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Image.network(
            config.introUrl,
            width: double.infinity,
            height: effectiveHeight,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          secondChild: Image.network(
            config.loopUrl,
            width: double.infinity,
            height: effectiveHeight,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    if (widget.applyBottomFade) {
      effectContent = ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.70, 0.90, 1.0],
            colors: [
              Colors.white,
              Colors.white,
              Color(0x88FFFFFF),
              Colors.transparent,
            ],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: effectContent,
      );
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: effectContent,
      ),
    );
  }
}
