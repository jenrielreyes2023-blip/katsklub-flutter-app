import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/message_sound_service.dart';

class FlappyKatGameScreen extends StatefulWidget {
  final User user;

  const FlappyKatGameScreen({required this.user, super.key});

  @override
  State<FlappyKatGameScreen> createState() => _FlappyKatGameScreenState();
}

class _FlappyKatGameScreenState extends State<FlappyKatGameScreen> {
  // Preloading state
  bool _isLoading = true;
  double _loadProgress = 0.0;
  String _loadStatus = 'Loading game engine...';
  int _highScore = 0;

  // Game Loop variables
  Timer? _gameTimer;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // Bird physics
  double _birdY = 0.0; // Starts at center (Y goes from -1.0 to 1.0)
  double _velocity = 0.0;
  final double _gravity = 0.006;
  final double _jumpForce = -0.13;
  double _hoverAngle = 0.0; // Hovering motion in main menu

  // Pipe configurations (Pipes move from X = 1.4 to -1.4)
  late List<double> _pipeX;
  late List<double> _pipeGapY; // Center of the gap (random between -0.4 and 0.4)
  final double _pipeGapHeight = 0.55; // Vertical space between top and bottom pipe
  final double _pipeWidth = 0.25;

  // Parallax clouds
  late List<double> _cloudX;
  late List<double> _cloudY;
  late List<double> _cloudScale;

  int _score = 0;

  @override
  void initState() {
    super.initState();
    _startPreloading();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  // Pre-load resources
  Future<void> _startPreloading() async {
    setState(() {
      _loadProgress = 0.2;
      _loadStatus = 'Loading best score...';
    });

    await MessageSoundService.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final scoreKey = 'flappy_highscore_${widget.user.username ?? "anonymous"}';
      setState(() {
        _highScore = prefs.getInt(scoreKey) ?? 0;
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _loadProgress = 0.5;
      _loadStatus = 'Pre-caching player avatar...';
    });

    final avatarUrl = widget.user.avatarUrl?.trim() ?? '';
    if (avatarUrl.isNotEmpty) {
      try {
        final provider = CachedNetworkImageProvider(avatarUrl);
        await precacheImage(provider, context);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _loadProgress = 1.0;
      _loadStatus = 'Calibrating pipes...';
    });

    _initializeGame();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeGame() {
    _birdY = 0.0;
    _velocity = 0.0;
    _score = 0;
    _isGameOver = false;
    _isPlaying = false;

    // Two pipes spaced out
    _pipeX = [1.2, 2.0];
    _pipeGapY = [
      _randomGapCenter(),
      _randomGapCenter(),
    ];

    // Three parallax clouds at random positions
    _cloudX = [-0.2, 0.4, 0.9];
    _cloudY = [-0.6, -0.4, -0.7];
    _cloudScale = [1.0, 1.3, 0.8];
  }

  double _randomGapCenter() {
    // Return a random number between -0.45 and 0.45
    return (math.Random().nextDouble() * 0.9) - 0.45;
  }

  void _startGame() {
    _gameTimer?.cancel();
    _isPlaying = true;
    _gameTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      _updatePhysics();
    });
  }

  void _updatePhysics() {
    setState(() {
      // 1. Move parallax clouds slowly to the left
      for (int i = 0; i < _cloudX.length; i++) {
        _cloudX[i] -= 0.002 * _cloudScale[i];
        if (_cloudX[i] < -1.5) {
          _cloudX[i] = 1.5;
          _cloudY[i] = -0.5 - (math.Random().nextDouble() * 0.4);
        }
      }

      // 2. Apply gravity to bird
      _velocity += _gravity;
      _birdY += _velocity;

      // Ceiling limit
      if (_birdY < -1.0) {
        _birdY = -1.0;
        _velocity = 0.0;
      }

      // 3. Move pipes to the left
      for (int i = 0; i < _pipeX.length; i++) {
        _pipeX[i] -= 0.012; // Speed

        // Check if pipe passed the bird (bird is fixed at X = -0.3)
        // Check for score boundary crossing
        final oldX = _pipeX[i] + 0.012;
        if (oldX >= -0.3 && _pipeX[i] < -0.3) {
          _score++;
          MessageSoundService.playIncoming();
        }

        // Reset pipe if it goes off-screen
        if (_pipeX[i] < -1.4) {
          _pipeX[i] = 1.4;
          _pipeGapY[i] = _randomGapCenter();
        }

        // 4. Collision Detection
        // Bird X width: about 0.12 (-0.36 to -0.24)
        // Pipe X boundaries: [pipeX - pipeWidth/2, pipeX + pipeWidth/2]
        final pipeLeft = _pipeX[i] - (_pipeWidth / 2);
        final pipeRight = _pipeX[i] + (_pipeWidth / 2);
        const birdLeft = -0.36;
        const birdRight = -0.24;

        if (pipeLeft < birdRight && pipeRight > birdLeft) {
          // Bird Y: check if it hits the top or bottom pipe
          final gapTop = _pipeGapY[i] - (_pipeGapHeight / 2);
          final gapBottom = _pipeGapY[i] + (_pipeGapHeight / 2);

          // Bird height bounds: _birdY - 0.06 to _birdY + 0.06
          final birdTop = _birdY - 0.06;
          final birdBottom = _birdY + 0.06;

          if (birdTop < gapTop || birdBottom > gapBottom) {
            _handleGameOver();
          }
        }
      }

      // 5. Ground crash check
      if (_birdY > 0.95) {
        _handleGameOver();
      }
    });
  }

  void _jump() {
    if (_isGameOver) return;

    if (!_isPlaying) {
      _startGame();
    }

    MessageSoundService.playOutgoing();
    setState(() {
      _velocity = _jumpForce;
    });
  }

  void _handleGameOver() {
    _gameTimer?.cancel();
    _isPlaying = false;
    _isGameOver = true;
    MessageSoundService.playOutgoing();

    final isNewHighScore = _score > _highScore;
    if (isNewHighScore) {
      _highScore = _score;
      SharedPreferences.getInstance().then((prefs) {
        final scoreKey = 'flappy_highscore_${widget.user.username ?? "anonymous"}';
        prefs.setInt(scoreKey, _score);
      });
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5E3A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: Color(0xFFFF5E3A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Ouch! Game Over',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored $_score points.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              if (isNewHighScore)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Color(0xFF10B981), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'NEW HIGH SCORE! 🏆',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        minimumSize: const Size(0, 46),
                      ),
                      child: const Text(
                        'Exit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _initializeGame();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A00),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(0, 46),
                      ),
                      child: const Text(
                        'Restart',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    // Hover animation height offsets when not playing
    double displayedBirdY = _birdY;
    if (!_isPlaying && !_isGameOver) {
      _hoverAngle += 0.05;
      displayedBirdY = 0.1 * math.sin(_hoverAngle);
    }

    return Scaffold(
      body: GestureDetector(
        onTap: _jump,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF7E5F), // Coral
                Color(0xFFFEB47B), // Peach
                Color(0xFF86A8E7), // Light Blue sky at the bottom
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Parallax Clouds
              for (int i = 0; i < _cloudX.length; i++)
                Positioned(
                  left: (MediaQuery.of(context).size.width * (_cloudX[i] + 1) / 2) - (60 * _cloudScale[i]),
                  top: MediaQuery.of(context).size.height * (_cloudY[i] + 1) / 2,
                  child: Opacity(
                    opacity: 0.35,
                    child: Icon(
                      Icons.cloud_rounded,
                      color: Colors.white,
                      size: 90 * _cloudScale[i],
                    ),
                  ),
                ),

              // Pipes
              for (int i = 0; i < _pipeX.length; i++) ...[
                // Top Pipe
                _buildPipeWidget(
                  x: _pipeX[i],
                  gapCenterY: _pipeGapY[i],
                  isTop: true,
                ),
                // Bottom Pipe
                _buildPipeWidget(
                  x: _pipeX[i],
                  gapCenterY: _pipeGapY[i],
                  isTop: false,
                ),
              ],

              // Bird (User Avatar or Fallback Cat Icon)
              Positioned(
                // Bird X coordinate is fixed at 30% of screen width (-0.3 normalized)
                left: (MediaQuery.of(context).size.width * 0.7 / 2) - 24,
                top: (MediaQuery.of(context).size.height * (displayedBirdY + 1) / 2) - 24,
                child: Transform.rotate(
                  angle: _isPlaying ? (_velocity * 3).clamp(-0.4, 0.7) : 0,
                  child: _buildBirdAvatar(),
                ),
              ),

              // Top HUD
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    // Score
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_score',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // High Score Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$_highScore',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Play / Jump instruction text at start
              if (!_isPlaying && !_isGameOver)
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 120),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.touch_app_rounded, color: Colors.white, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'TAP TO FLY',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Avoid the structural pipes!',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
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
  }

  Widget _buildPipeWidget({
    required double x,
    required double gapCenterY,
    required bool isTop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Convert coordinates from normalized (-1.0 to 1.0) to pixels
    final pipeWidthPixels = screenWidth * _pipeWidth;
    final pipeLeftPixels = (screenWidth * (x + 1) / 2) - (pipeWidthPixels / 2);

    final gapTopYPixels = (screenHeight * (gapCenterY - _pipeGapHeight / 2 + 1) / 2);
    final gapBottomYPixels = (screenHeight * (gapCenterY + _pipeGapHeight / 2 + 1) / 2);

    double top;
    double height;

    if (isTop) {
      top = 0;
      height = gapTopYPixels;
    } else {
      top = gapBottomYPixels;
      height = screenHeight - gapBottomYPixels;
    }

    return Positioned(
      left: pipeLeftPixels,
      top: top,
      width: pipeWidthPixels,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isTop
                ? [const Color(0xFF10B981), const Color(0xFF047857)]
                : [const Color(0xFF047857), const Color(0xFF065F46)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: const Color(0xFF064E3B), width: 2),
          borderRadius: isTop
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : const BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: Offset(isTop ? 4 : -4, 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirdAvatar() {
    final avatarUrl = widget.user.avatarUrl?.trim() ?? '';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A00),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(
                  Icons.pets_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              )
            : const Icon(
                Icons.pets_rounded,
                color: Colors.white,
                size: 24,
              ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F1D2C), Color(0xFF0F0E17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5E3A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF5E3A).withValues(alpha: 0.2), width: 2),
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    color: Color(0xFFFF5E3A),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'FLAPPY KAT ADVENTURE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadStatus,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 40),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: _loadProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5E3A)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
