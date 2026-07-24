import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/message_sound_service.dart';

class MemoryMatchScreen extends StatefulWidget {
  final User user;

  const MemoryMatchScreen({required this.user, super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  bool _isLoading = true;
  double _loadProgress = 0.0;
  String _loadStatus = 'Initializing game board...';
  int _highScore = 999;

  final List<String> _imageUrls = [
    'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1526336024174-e58f5cdd8e13?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1548247416-ec66f4900b2e?w=500&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500&auto=format&fit=crop',
  ];

  late List<int> _cardValues;
  late List<bool> _cardFlipped;
  late List<bool> _cardMatched;

  int? _selectedCardIndex;
  bool _canFlip = true;
  int _moves = 0;
  int _matchesFound = 0;

  @override
  void initState() {
    super.initState();
    _startPreloading();
  }

  Future<void> _startPreloading() async {
    setState(() {
      _loadProgress = 0.1;
      _loadStatus = 'Loading player achievements...';
    });

    await MessageSoundService.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final scoreKey = 'game_highscore_${widget.user.username ?? "anonymous"}';
      setState(() {
        _highScore = prefs.getInt(scoreKey) ?? 999;
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _loadProgress = 0.3;
      _loadStatus = 'Downloading card textures (0%)...';
    });

    int cachedCount = 0;
    for (int i = 0; i < _imageUrls.length; i++) {
      if (!mounted) return;
      try {
        final provider = CachedNetworkImageProvider(_imageUrls[i]);
        await precacheImage(provider, context);
      } catch (e) {
        debugPrint('Failed to cache image $i: $e');
      }
      cachedCount++;
      if (!mounted) return;
      setState(() {
        _loadProgress = 0.3 + (cachedCount / _imageUrls.length) * 0.6;
        _loadStatus = 'Downloading card textures (${((cachedCount / _imageUrls.length) * 100).toInt()}%)...';
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;
    setState(() {
      _loadProgress = 1.0;
      _loadStatus = 'Shuffling card deck...';
    });

    _initializeGame();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeGame() {
    _cardValues = List.generate(_imageUrls.length * 2, (index) => index % _imageUrls.length);
    _cardValues.shuffle(math.Random());

    _cardFlipped = List.generate(_cardValues.length, (_) => false);
    _cardMatched = List.generate(_cardValues.length, (_) => false);

    _selectedCardIndex = null;
    _canFlip = true;
    _moves = 0;
    _matchesFound = 0;
  }

  void _onCardTap(int index) {
    if (!_canFlip || _cardFlipped[index] || _cardMatched[index]) return;

    MessageSoundService.playOutgoing();

    setState(() {
      _cardFlipped[index] = true;
    });

    if (_selectedCardIndex == null) {
      _selectedCardIndex = index;
    } else {
      _moves++;
      final prevIndex = _selectedCardIndex!;
      _selectedCardIndex = null;

      if (_cardValues[prevIndex] == _cardValues[index]) {
        MessageSoundService.playIncoming();
        setState(() {
          _cardMatched[prevIndex] = true;
          _cardMatched[index] = true;
          _matchesFound++;
        });

        if (_matchesFound == _imageUrls.length) {
          _handleWin();
        }
      } else {
        _canFlip = false;
        Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          setState(() {
            _cardFlipped[prevIndex] = false;
            _cardFlipped[index] = false;
            _canFlip = true;
          });
        });
      }
    }
  }

  Future<void> _handleWin() async {
    final isNewHighScore = _moves < _highScore;
    if (isNewHighScore) {
      setState(() {
        _highScore = _moves;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final scoreKey = 'game_highscore_${widget.user.username ?? "anonymous"}';
        await prefs.setInt(scoreKey, _moves);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

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
                  color: const Color(0xFFFF8A00).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFF8A00),
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Matches Complete!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You completed the deck in $_moves moves.',
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
                        'Play Again',
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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Kats Match Game',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1F2937),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFF8A00)),
            onPressed: () {
              setState(() {
                _initializeGame();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('MOVES', _moves.toString(), Icons.directions_run_rounded),
                    Container(width: 1, height: 28, color: const Color(0xFFE5E7EB)),
                    _buildStatItem(
                      'BEST RECORD',
                      _highScore == 999 ? '-' : '$_highScore moves',
                      Icons.emoji_events_rounded,
                      iconColor: const Color(0xFFFFC107),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cardValues.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final value = _cardValues[index];
                    final isFlipped = _cardFlipped[index] || _cardMatched[index];
                    return _MemoryCard(
                      imageUrl: _imageUrls[value],
                      isFlipped: isFlipped,
                      isMatched: _cardMatched[index],
                      onTap: () => _onCardTap(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color iconColor = const Color(0xFFFF8A00)}) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ],
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
                    color: const Color(0xFFFF8A00).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF8A00).withValues(alpha: 0.2), width: 2),
                  ),
                  child: const Icon(
                    Icons.grid_on_rounded,
                    color: Color(0xFFFF8A00),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'KATS MEMORY MATCH',
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
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

class _MemoryCard extends StatelessWidget {
  final String imageUrl;
  final bool isFlipped;
  final bool isMatched;
  final VoidCallback onTap;

  const _MemoryCard({
    required this.imageUrl,
    required this.isFlipped,
    required this.isMatched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          final rotate = Tween(begin: math.pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              final isBack = child?.key == const ValueKey('back');
              return Transform(
                transform: Matrix4.rotationY(isBack ? rotate.value : rotate.value + math.pi)
                  ..setEntry(3, 2, 0.002),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: isFlipped
            ? Container(
                key: const ValueKey('front'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isMatched ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                    width: isMatched ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              )
            : Container(
                key: const ValueKey('back'),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF374151), Color(0xFF1F2937)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.pets_rounded,
                    color: Color(0xFFFF8A00),
                    size: 28,
                  ),
                ),
              ),
      ),
    );
  }
}
