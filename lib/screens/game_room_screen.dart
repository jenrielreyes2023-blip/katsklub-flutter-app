import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'memory_match_screen.dart';
import 'flappy_kat_game_screen.dart';
import 'connect_four_game_screen.dart';
import 'uno_game_screen.dart';
import 'guess_the_song_screen.dart';


class GameRoomScreen extends StatefulWidget {
  final User user;

  const GameRoomScreen({required this.user, super.key});

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  int _matchHighScore = 999;
  int _flappyHighScore = 0;
  int _connect4HighScore = 0;
  int _unoWins = 0;
  int _guessSongHighScore = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = widget.user.username ?? "anonymous";
      setState(() {
        _matchHighScore = prefs.getInt('game_highscore_$username') ?? 999;
        _flappyHighScore = prefs.getInt('flappy_highscore_$username') ?? 0;
        _connect4HighScore = prefs.getInt('connect4_max_streak_$username') ?? 0;
        _unoWins = prefs.getInt('uno_wins_$username') ?? 0;
        _guessSongHighScore = prefs.getInt('guess_song_highscore_$username') ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToGame(Widget destination) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    ).then((_) {
      // Reload scores when returning to dashboard
      _loadHighScores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1D2C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Kats Arcade',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F1D2C), Color(0xFF0F0E17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a Game to Play:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Game 1: Memory Match
                    _buildGameCard(
                      title: 'Kats Memory Match',
                      description: 'Match pairs of cute cat cards in the fewest moves possible.',
                      icon: Icons.grid_on_rounded,
                      color: const Color(0xFFFF8A00),
                      statLabel: _matchHighScore == 999 ? 'No record yet' : 'Best: $_matchHighScore moves',
                      statIcon: Icons.emoji_events_rounded,
                      onTap: () => _navigateToGame(MemoryMatchScreen(user: widget.user)),
                    ),

                    const SizedBox(height: 20),

                    // Game 2: Flappy Kat
                    _buildGameCard(
                      title: 'Flappy Kat Adventure',
                      description: 'Tap to flap and fly through obstacles. Plays using your profile avatar!',
                      icon: Icons.pets_rounded,
                      color: const Color(0xFFFF5E3A),
                      statLabel: 'Best Score: $_flappyHighScore pts',
                      statIcon: Icons.bolt_rounded,
                      onTap: () => _navigateToGame(FlappyKatGameScreen(user: widget.user)),
                    ),

                    const SizedBox(height: 20),

                    // Game 3: Kats Connect Four
                    _buildGameCard(
                      title: 'Kats Connect Four',
                      description: 'Drop cat paw tokens to form a line of 4. Play vs the Cat Bot AI or local PvP!',
                      icon: Icons.grid_4x4_rounded,
                      color: const Color(0xFF00D1FF),
                      statLabel: 'Best Streak: $_connect4HighScore wins',
                      statIcon: Icons.local_fire_department_rounded,
                      onTap: () => _navigateToGame(ConnectFourGameScreen(user: widget.user)),
                    ),

                    const SizedBox(height: 20),

                    // Game 4: Kats Uno Duel
                    _buildGameCard(
                      title: 'Kats Uno Duel',
                      description: 'Match colors and values to clear your deck. Face off against the Cat Bot in a 1v1 Uno duel!',
                      icon: Icons.style_rounded,
                      color: const Color(0xFFFF5E3A),
                      statLabel: 'Total Wins: $_unoWins wins',
                      statIcon: Icons.emoji_events_rounded,
                      onTap: () => _navigateToGame(UnoGameScreen(user: widget.user)),
                    ),

                    const SizedBox(height: 20),

                    // Game 5: Kats Song Guesser
                    _buildGameCard(
                      title: 'Kats Song Guesser',
                      description: 'Listen to a 30s preview and buzz in to guess using your voice or keyboard!',
                      icon: Icons.music_note_rounded,
                      color: const Color(0xFFD400FF),
                      statLabel: 'Best Score: $_guessSongHighScore pts',
                      statIcon: Icons.emoji_events_rounded,
                      onTap: () => _navigateToGame(GuessTheSongScreen(user: widget.user)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String statLabel,
    required IconData statIcon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Abstract glowing color spot in background
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Best Score Tag
                            Row(
                              children: [
                                Icon(statIcon, color: const Color(0xFFFFD700), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  statLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Play Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
