import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
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
      introUrl: 'https://media.katsklub.top/effects/zombie-slime/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/zombie-slime/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'zombie-slime': ProfileEffectConfig(
      id: 'zombie-slime',
      name: 'Zombie Slime',
      introUrl: 'https://media.katsklub.top/effects/zombie-slime/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/zombie-slime/loop_v2.webp',
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
    // If it's a direct URL to a WebP
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
/// - Reliable intro detection via Flutter's built-in [Image.frameBuilder].
///   The countdown starts strictly when the first frame actually renders on screen,
///   guaranteeing the user always experiences the full intro animation.
/// - Seamless cross-fade transition from intro to ambient idle loop.
/// - Automatically unmounts intro image after fade-out to free GPU texture memory.
/// - Zero-jank performance: Pauses completely when scrolled offscreen ([isActive] = false).
/// - No heavy GPU [ShaderMask] `saveLayer` calls; maintains 60/120 FPS buttery-smooth scrolling.
/// - Wrapped in [IgnorePointer] so all profile buttons, avatar, cover, and links remain 100% interactive.
class ProfileEffectWidget extends StatefulWidget {
  const ProfileEffectWidget({
    required this.effect,
    this.height,
    this.applyBottomFade = false,
    this.isActive = true,
    super.key,
  });

  final String effect;
  final double? height;
  final bool applyBottomFade;
  final bool isActive;

  @override
  State<ProfileEffectWidget> createState() => _ProfileEffectWidgetState();
}

class _ProfileEffectWidgetState extends State<ProfileEffectWidget> {
  ProfileEffectConfig? _config;
  bool _introTimerStarted = false;
  bool _introFadeOut = false;
  bool _introDone = false;

  Timer? _introTimer;
  Timer? _safetyTimeout;
  CachedNetworkImageProvider? _introProvider;
  CachedNetworkImageProvider? _loopProvider;

  @override
  void initState() {
    super.initState();
    _setupEffect();
  }

  @override
  void didUpdateWidget(ProfileEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _cleanupTimers();
      _setupEffect();
    } else if (!oldWidget.isActive && widget.isActive) {
      // Resumed from offscreen: ensure providers are warm
      _warmProviders();
    }
  }

  void _cleanupTimers() {
    _introTimer?.cancel();
    _introTimer = null;
    _safetyTimeout?.cancel();
    _safetyTimeout = null;
  }

  void _warmProviders() {
    final config = _config;
    if (config == null) return;
    _loopProvider ??= CachedNetworkImageProvider(config.loopUrl);
    if (config.introDuration > Duration.zero && config.introUrl != config.loopUrl && !_introDone) {
      _introProvider ??= CachedNetworkImageProvider(config.introUrl);
    }
  }

  void _setupEffect() {
    _cleanupTimers();
    _config = ProfileEffectConfig.resolve(widget.effect);

    if (_config == null) {
      _introDone = true;
      return;
    }

    final config = _config!;
    _loopProvider = CachedNetworkImageProvider(config.loopUrl);

    if (config.introDuration > Duration.zero && config.introUrl != config.loopUrl) {
      _introProvider = CachedNetworkImageProvider(config.introUrl);
      _introDone = false;
      _introFadeOut = false;
      _introTimerStarted = false;

      // Safety timeout: If intro fails to render first frame within 3.5s, fall back to loop directly
      _safetyTimeout = Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        if (!_introTimerStarted && !_introDone) {
          setState(() {
            _introDone = true;
          });
        }
      });
    } else {
      _introProvider = null;
      _introDone = true;
      _introFadeOut = false;
      _introTimerStarted = false;
    }
  }

  void _startIntroCountdown() {
    if (_introTimerStarted || _introDone) return;
    _introTimerStarted = true;
    _safetyTimeout?.cancel();

    final config = _config;
    if (config == null) return;

    _introTimer?.cancel();
    _introTimer = Timer(config.introDuration, () {
      if (!mounted) return;
      setState(() {
        _introFadeOut = true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache both loop and intro into image cache
    if (_loopProvider != null) {
      precacheImage(_loopProvider!, context).catchError((_) {});
    }
    if (_introProvider != null && !_introDone) {
      precacheImage(_introProvider!, context).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _cleanupTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When scrolled offscreen, unmount images completely to pause decode loop and eliminate GPU raster load
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    final config = _config;
    if (config == null) {
      return const SizedBox.shrink();
    }

    final double effectiveHeight = widget.height ?? 460.h;
    final bool hasIntro = !_introDone && _introProvider != null;

    final Widget effectContent = SizedBox(
      width: double.infinity,
      height: effectiveHeight,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Layer 1: Ambient Idle Loop (fades in as intro fades out, or immediately active if no intro)
          AnimatedOpacity(
            opacity: (!hasIntro || _introFadeOut) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            child: Image(
              image: _loopProvider ?? CachedNetworkImageProvider(config.loopUrl),
              width: double.infinity,
              height: effectiveHeight,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // Layer 2: Intro Animation (Starts at 100% opacity, plays from frame 1, then cross-fades out)
          if (hasIntro)
            AnimatedOpacity(
              opacity: _introFadeOut ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              onEnd: () {
                if (_introFadeOut && mounted) {
                  setState(() {
                    _introDone = true;
                  });
                }
              },
              child: Image(
                image: _introProvider!,
                width: double.infinity,
                height: effectiveHeight,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null && !_introTimerStarted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _startIntroCountdown();
                      }
                    });
                  }
                  return child;
                },
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _introDone = true;
                      });
                    }
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
        ],
      ),
    );

    return IgnorePointer(
      child: RepaintBoundary(
        child: effectContent,
      ),
    );
  }
}
