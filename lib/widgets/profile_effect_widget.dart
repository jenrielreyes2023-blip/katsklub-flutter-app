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
/// - First-frame detection via [ImageStreamListener]: Intro countdown starts ONLY when the
///   animation is actually rendered on screen, ensuring the user always sees the full intro.
/// - Stable base layer for the loop animation: Never re-created or hitch-reset.
/// - Smooth [AnimatedOpacity] transition from intro to ambient loop.
/// - Unmounts intro after fade-out to immediately free GPU texture memory.
/// - Smooth bottom edge shader mask fade into profile content.
/// - Wrapped in [IgnorePointer] so all profile buttons, avatar, cover, and links remain 100% interactive.
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
  bool _introFirstFrameReady = false;
  bool _introFadeOut = false;
  bool _introDone = false;

  Timer? _introTimer;
  ImageStream? _introStream;
  ImageStreamListener? _streamListener;
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
      _cleanUpStream();
      _setupEffect();
    }
  }

  void _setupEffect() {
    _cleanUpStream();
    _config = ProfileEffectConfig.resolve(widget.effect);

    if (_config == null) {
      _introDone = true;
      return;
    }

    _introDone = false;
    _introFadeOut = false;
    _introFirstFrameReady = false;

    final config = _config!;
    _loopProvider = CachedNetworkImageProvider(config.loopUrl);

    if (config.introDuration > Duration.zero && config.introUrl != config.loopUrl) {
      _introProvider = CachedNetworkImageProvider(config.introUrl);
      _listenForIntroFirstFrame(_introProvider!, config);
    } else {
      _introDone = true;
    }
  }

  void _listenForIntroFirstFrame(
    ImageProvider provider,
    ProfileEffectConfig config,
  ) {
    final stream = provider.resolve(ImageConfiguration.empty);
    _introStream = stream;

    _streamListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!mounted) return;
        if (!_introFirstFrameReady) {
          setState(() {
            _introFirstFrameReady = true;
          });

          // Start the intro timer ONLY when the first frame has successfully decoded and displayed!
          _introTimer?.cancel();
          _introTimer = Timer(config.introDuration, () {
            if (!mounted) return;
            setState(() {
              _introFadeOut = true;
            });
          });
        }
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        debugPrint('ProfileEffect intro load error: $error');
        if (!mounted) return;
        setState(() {
          _introDone = true;
        });
      },
    );

    stream.addListener(_streamListener!);
  }

  void _cleanUpStream() {
    _introTimer?.cancel();
    _introTimer = null;
    if (_introStream != null && _streamListener != null) {
      _introStream!.removeListener(_streamListener!);
    }
    _introStream = null;
    _streamListener = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache both loop and intro into memory
    if (_loopProvider != null) {
      precacheImage(_loopProvider!, context).catchError((_) {});
    }
    if (_introProvider != null) {
      precacheImage(_introProvider!, context).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _cleanUpStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const SizedBox.shrink();
    }

    final double effectiveHeight = widget.height ?? 420.h;

    Widget effectContent = SizedBox(
      width: double.infinity,
      height: effectiveHeight,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Layer 1: Ambient Loop (25 FPS, always active and stable, zero hitching)
          Image(
            image: _loopProvider ?? CachedNetworkImageProvider(config.loopUrl),
            width: double.infinity,
            height: effectiveHeight,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

          // Layer 2: Intro Animation (Plays on top, then fades out smoothly to reveal loop)
          if (!_introDone && _introProvider != null)
            AnimatedOpacity(
              opacity: (_introFirstFrameReady && !_introFadeOut) ? 1.0 : 0.0,
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
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );

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
