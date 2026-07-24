import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/message_sound_service.dart';

class ConnectFourGameScreen extends StatefulWidget {
  final User user;

  const ConnectFourGameScreen({required this.user, super.key});

  @override
  State<ConnectFourGameScreen> createState() => _ConnectFourGameScreenState();
}

class _ConnectFourGameScreenState extends State<ConnectFourGameScreen> {
  static const int rows = 6;
  static const int cols = 7;

  bool _isLoading = true;
  double _loadProgress = 0.0;
  String _loadStatus = 'Initializing board...';

  // High score / stats
  int _winStreak = 0;
  int _maxStreak = 0;

  // Game state
  List<List<int>> _board = List.generate(rows, (_) => List.generate(cols, (_) => 0)); // 0 = empty, 1 = Player, 2 = Opponent (AI/Player 2)
  bool _isPlayerTurn = true;
  bool _isVsAi = true;
  String _difficulty = 'Medium'; // Easy, Medium, Hard
  bool _gameEnded = false;
  String _winnerMessage = '';
  List<math.Point<int>> _winningLine = [];
  List<PlacedToken> _placedTokens = [];

  // Avatars cached
  String? _playerAvatarUrl;
  final String _botAvatarUrl = 'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=500&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _playerAvatarUrl = widget.user.avatarUrl;
    _startPreloading();
  }

  Future<void> _startPreloading() async {
    setState(() {
      _loadProgress = 0.1;
      _loadStatus = 'Loading statistics...';
    });

    await MessageSoundService.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = widget.user.username ?? "anonymous";
      setState(() {
        _winStreak = prefs.getInt('connect4_streak_$username') ?? 0;
        _maxStreak = prefs.getInt('connect4_max_streak_$username') ?? 0;
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _loadProgress = 0.4;
      _loadStatus = 'Caching player profiles...';
    });

    // Pre-cache player avatar if present
    if (_playerAvatarUrl != null && _playerAvatarUrl!.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(_playerAvatarUrl!), context);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _loadProgress = 0.7;
      _loadStatus = 'Downloading bot assets...';
    });

    // Pre-cache bot avatar
    try {
      await precacheImage(CachedNetworkImageProvider(_botAvatarUrl), context);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loadProgress = 1.0;
      _loadStatus = 'Polishing game room...';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  void _resetGame() {
    setState(() {
      _board = List.generate(rows, (_) => List.generate(cols, (_) => 0));
      _isPlayerTurn = true;
      _gameEnded = false;
      _winnerMessage = '';
      _winningLine = [];
      _placedTokens = [];
    });
  }

  // Find the lowest empty row in a column. Returns -1 if column is full.
  int _getLowestEmptyRow(int col) {
    for (int r = rows - 1; r >= 0; r--) {
      if (_board[r][col] == 0) {
        return r;
      }
    }
    return -1;
  }

  void _makeMove(int col) {
    if (_gameEnded || !_isPlayerTurn && _isVsAi) return;

    final row = _getLowestEmptyRow(col);
    if (row == -1) {
      // Column full
      HapticFeedback.vibrate();
      return;
    }

    final currentPlayer = _isPlayerTurn ? 1 : 2;
    HapticFeedback.lightImpact();
    MessageSoundService.playOutgoing();

    setState(() {
      _board[row][col] = currentPlayer;
      _placedTokens.add(PlacedToken(column: col, row: row, player: currentPlayer));
    });

    // Check win
    if (_checkWin(row, col)) {
      _handleWin(currentPlayer);
      return;
    }

    // Check draw
    if (_checkDraw()) {
      _handleDraw();
      return;
    }

    // Switch turns
    setState(() {
      _isPlayerTurn = !_isPlayerTurn;
    });

    // Trigger AI move if single player
    if (_isVsAi && !_isPlayerTurn) {
      Timer(const Duration(milliseconds: 800), () {
        if (!mounted || _gameEnded) return;
        _makeAiMove();
      });
    }
  }

  void _makeAiMove() {
    final col = _getBestMove();
    final row = _getLowestEmptyRow(col);
    if (row == -1) return; // Fallback (shouldn't happen)

    HapticFeedback.lightImpact();
    MessageSoundService.playIncoming();

    setState(() {
      _board[row][col] = 2;
      _placedTokens.add(PlacedToken(column: col, row: row, player: 2));
    });

    if (_checkWin(row, col)) {
      _handleWin(2);
      return;
    }

    if (_checkDraw()) {
      _handleDraw();
      return;
    }

    setState(() {
      _isPlayerTurn = true;
    });
  }

  bool _checkWin(int row, int col) {
    final player = _board[row][col];
    if (player == 0) return false;

    // Directions: Horizontal, Vertical, Diagonal 1 (down-right), Diagonal 2 (up-right)
    final directions = [
      const math.Point(0, 1),  // Horizontal
      const math.Point(1, 0),  // Vertical
      const math.Point(1, 1),  // Diagonal down-right
      const math.Point(-1, 1), // Diagonal up-right
    ];

    for (final dir in directions) {
      final line = <math.Point<int>>[math.Point(row, col)];

      // Check positive direction
      int r = row + dir.x;
      int c = col + dir.y;
      while (r >= 0 && r < rows && c >= 0 && c < cols && _board[r][c] == player) {
        line.add(math.Point(r, c));
        r += dir.x;
        c += dir.y;
      }

      // Check negative direction
      r = row - dir.x;
      c = col - dir.y;
      while (r >= 0 && r < rows && c >= 0 && c < cols && _board[r][c] == player) {
        line.add(math.Point(r, c));
        r -= dir.x;
        c -= dir.y;
      }

      if (line.length >= 4) {
        setState(() {
          _winningLine = line;
        });
        return true;
      }
    }

    return false;
  }

  bool _checkDraw() {
    for (int c = 0; c < cols; c++) {
      if (_board[0][c] == 0) return false;
    }
    return true;
  }

  Future<void> _handleWin(int player) async {
    setState(() {
      _gameEnded = true;
      if (_isVsAi) {
        if (player == 1) {
          _winnerMessage = 'Victory! You defeated Cat Bot!';
          _winStreak++;
          if (_winStreak > _maxStreak) {
            _maxStreak = _winStreak;
          }
        } else {
          _winnerMessage = 'Defeat! Cat Bot wins.';
          _winStreak = 0;
        }
      } else {
        _winnerMessage = player == 1 ? 'Player 1 (🐱) wins!' : 'Player 2 (🐯) wins!';
      }
    });

    HapticFeedback.heavyImpact();

    // Save streak stats if vs AI
    if (_isVsAi) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final username = widget.user.username ?? "anonymous";
        await prefs.setInt('connect4_streak_$username', _winStreak);
        await prefs.setInt('connect4_max_streak_$username', _maxStreak);
      } catch (_) {}
    }

    _showGameOverDialog();
  }

  void _handleDraw() {
    setState(() {
      _gameEnded = true;
      _winnerMessage = "It's a Draw!";
      if (_isVsAi) {
        _winStreak = 0;
      }
    });

    HapticFeedback.mediumImpact();
    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isVictory = _isVsAi && _winnerMessage.contains('Victory');
        final isDefeat = _isVsAi && _winnerMessage.contains('Defeat');

        return AlertDialog(
          backgroundColor: const Color(0xFF1D1B26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isVictory 
                  ? const Color(0xFF00D1FF) 
                  : (isDefeat ? const Color(0xFFFF5E3A) : Colors.white.withValues(alpha: 0.1)),
              width: 2,
            ),
          ),
          title: Text(
            isVictory ? '🎉 Winner! 🎉' : (isDefeat ? '😿 Game Over 😿' : '🤝 Tied Game 🤝'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _winnerMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFD1D5DB),
                ),
              ),
              if (_isVsAi) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Current Streak', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('$_winStreak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Best Streak', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('$_maxStreak', style: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resetGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isVictory ? const Color(0xFF00D1FF) : const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Back to dashboard
              },
              child: const Text('Exit to Arcade', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- AI DECISION LOGIC ---

  int _getBestMove() {
    if (_difficulty == 'Easy') {
      return _getEasyMove();
    } else if (_difficulty == 'Medium') {
      return _getMediumMove();
    } else {
      return _getHardMove();
    }
  }

  int _getEasyMove() {
    // 10% chance to win if win is available, otherwise random
    final winCol = _findImmediateWin(2);
    if (winCol != null && math.Random().nextDouble() < 0.8) {
      return winCol;
    }
    return _getRandomValidMove();
  }

  int _getMediumMove() {
    // 1. Check if we can win in one move
    final winCol = _findImmediateWin(2);
    if (winCol != null) return winCol;

    // 2. Check if we need to block player's immediate win
    final blockCol = _findImmediateWin(1);
    if (blockCol != null) return blockCol;

    // 3. Otherwise, score moves and pick best
    return _getScoredBestMove(2);
  }

  int _getHardMove() {
    // Minimax search of depth 4 with alpha-beta pruning
    final result = _minimax(4, -double.infinity, double.infinity, true);
    if (result.column != -1) {
      return result.column;
    }
    return _getMediumMove();
  }

  int _getRandomValidMove() {
    final validCols = <int>[];
    for (int c = 0; c < cols; c++) {
      if (_board[0][c] == 0) validCols.add(c);
    }
    if (validCols.isEmpty) return 0;
    return validCols[math.Random().nextInt(validCols.length)];
  }

  int? _findImmediateWin(int player) {
    for (int c = 0; c < cols; c++) {
      final r = _getLowestEmptyRow(c);
      if (r != -1) {
        // Mock placement
        _board[r][c] = player;
        final wins = _checkWinInstant(r, c);
        _board[r][c] = 0; // Revert
        if (wins) return c;
      }
    }
    return null;
  }

  bool _checkWinInstant(int row, int col) {
    final player = _board[row][col];
    final directions = [
      const math.Point(0, 1),
      const math.Point(1, 0),
      const math.Point(1, 1),
      const math.Point(-1, 1),
    ];

    for (final dir in directions) {
      int count = 1;
      // Positive
      int r = row + dir.x;
      int c = col + dir.y;
      while (r >= 0 && r < rows && c >= 0 && c < cols && _board[r][c] == player) {
        count++;
        r += dir.x;
        c += dir.y;
      }
      // Negative
      r = row - dir.x;
      c = col - dir.y;
      while (r >= 0 && r < rows && c >= 0 && c < cols && _board[r][c] == player) {
        count++;
        r -= dir.x;
        c -= dir.y;
      }
      if (count >= 4) return true;
    }
    return false;
  }

  int _getScoredBestMove(int aiPlayer) {
    double bestScore = -double.infinity;
    List<int> bestCols = [];

    // Prioritize center columns
    final colOrder = [3, 2, 4, 1, 5, 0, 6];

    for (final c in colOrder) {
      final r = _getLowestEmptyRow(c);
      if (r != -1) {
        _board[r][c] = aiPlayer;
        final score = _scoreBoard(aiPlayer);
        _board[r][c] = 0; // Revert

        if (score > bestScore) {
          bestScore = score;
          bestCols = [c];
        } else if (score == bestScore) {
          bestCols.add(c);
        }
      }
    }

    if (bestCols.isEmpty) return _getRandomValidMove();
    return bestCols[math.Random().nextInt(bestCols.length)];
  }

  // Heuristic evaluation function for the board state
  double _scoreBoard(int aiPlayer) {
    double score = 0;

    // Check center column score bonus
    for (int r = 0; r < rows; r++) {
      if (_board[r][3] == aiPlayer) score += 3.0;
    }

    // Score segments of 4
    // Horizontal
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols - 3; c++) {
        score += _evaluateWindow(
          [_board[r][c], _board[r][c + 1], _board[r][c + 2], _board[r][c + 3]],
          aiPlayer,
        );
      }
    }

    // Vertical
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - 3; r++) {
        score += _evaluateWindow(
          [_board[r][c], _board[r + 1][c], _board[r + 2][c], _board[r + 3][c]],
          aiPlayer,
        );
      }
    }

    // Diagonals down-right
    for (int r = 0; r < rows - 3; r++) {
      for (int c = 0; c < cols - 3; c++) {
        score += _evaluateWindow(
          [_board[r][c], _board[r + 1][c + 1], _board[r + 2][c + 2], _board[r + 3][c + 3]],
          aiPlayer,
        );
      }
    }

    // Diagonals up-right
    for (int r = 3; r < rows; r++) {
      for (int c = 0; c < cols - 3; c++) {
        score += _evaluateWindow(
          [_board[r][c], _board[r - 1][c + 1], _board[r - 2][c + 2], _board[r - 3][c + 3]],
          aiPlayer,
        );
      }
    }

    return score;
  }

  double _evaluateWindow(List<int> window, int aiPlayer) {
    final opponent = aiPlayer == 1 ? 2 : 1;
    int aiCount = window.where((x) => x == aiPlayer).length;
    int oppCount = window.where((x) => x == opponent).length;
    int emptyCount = window.where((x) => x == 0).length;

    if (aiCount == 4) return 1000.0;
    if (aiCount == 3 && emptyCount == 1) return 10.0;
    if (aiCount == 2 && emptyCount == 2) return 2.0;

    if (oppCount == 4) return -1000.0;
    if (oppCount == 3 && emptyCount == 1) return -80.0;
    if (oppCount == 2 && emptyCount == 2) return -4.0;

    return 0.0;
  }

  // Minimax algorithm implementation
  _MinimaxResult _minimax(int depth, double alpha, double beta, bool isMaximizing) {
    final validCols = <int>[];
    for (int c = 0; c < cols; c++) {
      if (_board[0][c] == 0) validCols.add(c);
    }

    // Terminals
    final botWon = _checkWinState(2);
    final playerWon = _checkWinState(1);
    final isTerminal = botWon || playerWon || validCols.isEmpty;

    if (depth == 0 || isTerminal) {
      if (isTerminal) {
        if (botWon) return _MinimaxResult(score: 10000000.0, column: -1);
        if (playerWon) return _MinimaxResult(score: -10000000.0, column: -1);
        return _MinimaxResult(score: 0, column: -1);
      }
      return _MinimaxResult(score: _scoreBoard(2), column: -1);
    }

    if (isMaximizing) {
      double value = -double.infinity;
      int bestCol = -1;
      // Shuffle column priorities to diversify playstyles
      final sortedCols = List<int>.from(validCols)..sort((a, b) => (3 - a).abs().compareTo((3 - b).abs()));

      for (final col in sortedCols) {
        final r = _getLowestEmptyRow(col);
        _board[r][col] = 2;
        final res = _minimax(depth - 1, alpha, beta, false);
        _board[r][col] = 0; // Revert

        if (res.score > value) {
          value = res.score;
          bestCol = col;
        }
        alpha = math.max(alpha, value);
        if (alpha >= beta) break; // Pruning
      }
      return _MinimaxResult(score: value, column: bestCol);
    } else {
      double value = double.infinity;
      int bestCol = -1;
      final sortedCols = List<int>.from(validCols)..sort((a, b) => (3 - a).abs().compareTo((3 - b).abs()));

      for (final col in sortedCols) {
        final r = _getLowestEmptyRow(col);
        _board[r][col] = 1;
        final res = _minimax(depth - 1, alpha, beta, true);
        _board[r][col] = 0; // Revert

        if (res.score < value) {
          value = res.score;
          bestCol = col;
        }
        beta = math.min(beta, value);
        if (alpha >= beta) break; // Pruning
      }
      return _MinimaxResult(score: value, column: bestCol);
    }
  }

  bool _checkWinState(int player) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_board[r][c] == player && _checkWinInstant(r, c)) {
          return true;
        }
      }
    }
    return false;
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0E17),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_4x4_rounded, size: 72, color: Color(0xFF00D1FF)),
                const SizedBox(height: 24),
                const Text(
                  'Kats Connect Four',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _loadProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D1FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final boardPadding = 16.0;
    // Limit width so board does not stretch infinitely on tablets/web
    final maxBoardWidth = math.min(screenWidth - boardPadding * 2, 450.0);
    final cellSize = maxBoardWidth / cols;
    final boardHeight = cellSize * rows;

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
          'Kats Connect 4',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _resetGame,
            tooltip: 'Reset board',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F1D2C), Color(0xFF0F0E17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Header stats & modes
            _buildSettingsPanel(),
            const SizedBox(height: 16),
            // Turn indicator banner
            _buildTurnBanner(),
            const Spacer(),
            // Connect 4 board grid container
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: boardPadding),
                child: SizedBox(
                  width: maxBoardWidth,
                  height: boardHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Layer 1: Placed tokens (behind the plastic frame overlay)
                      ..._placedTokens.map((token) {
                        final isWinningCell = _winningLine.any((p) => p.x == token.row && p.y == token.column);
                        return _AnimatedTokenWidget(
                          key: ValueKey('${token.column}-${token.row}-${token.player}-${token.timestamp.millisecondsSinceEpoch}'),
                          column: token.column,
                          row: token.row,
                          player: token.player,
                          cellSize: cellSize,
                          isWinningCell: isWinningCell,
                          playerAvatarUrl: _playerAvatarUrl,
                          botAvatarUrl: _botAvatarUrl,
                        );
                      }),
                      // Layer 2: The plastic blue cutout board frame overlay on top
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: ConnectFourBoardPainter(
                              rows: rows,
                              cols: cols,
                              cellSize: cellSize,
                              color: const Color(0xFF1B2A4A),
                            ),
                          ),
                        ),
                      ),
                      // Layer 3: Touch input overlay (invisible hitboxes for columns)
                      Positioned.fill(
                        child: Row(
                          children: List.generate(cols, (colIndex) {
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => _makeMove(colIndex),
                                child: Container(
                                  color: Colors.transparent,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Bottom tips
            _buildBottomBar(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mode Select Toggle
            Row(
              children: [
                _buildModeButton(
                  label: 'VS AI',
                  icon: Icons.smart_toy_outlined,
                  isSelected: _isVsAi,
                  onTap: () {
                    setState(() {
                      _isVsAi = true;
                      _resetGame();
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildModeButton(
                  label: 'Local PvP',
                  icon: Icons.people_outline_rounded,
                  isSelected: !_isVsAi,
                  onTap: () {
                    setState(() {
                      _isVsAi = false;
                      _resetGame();
                    });
                  },
                ),
              ],
            ),
            // Difficulty Selector (only when VS AI)
            if (_isVsAi)
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF1D1B26),
                    value: _difficulty,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    items: ['Easy', 'Medium', 'Hard'].map((diff) {
                      String label = 'Medium';
                      Color col = const Color(0xFF00D1FF);
                      if (diff == 'Easy') {
                        label = 'Kitten 😸';
                        col = Colors.green;
                      } else if (diff == 'Medium') {
                        label = 'Hunter 🐯';
                        col = const Color(0xFFFF8A00);
                      } else if (diff == 'Hard') {
                        label = 'Cat Master 🦁';
                        col = const Color(0xFFFF5E3A);
                      }
                      return DropdownMenuItem<String>(
                        value: diff,
                        child: Text(label, style: TextStyle(color: col)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _difficulty = val;
                          _resetGame();
                        });
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D1FF) : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnBanner() {
    final avatarSize = 32.0;

    Widget leftAvatar;
    Widget rightAvatar;

    // Player 1
    if (_playerAvatarUrl != null && _playerAvatarUrl!.isNotEmpty) {
      leftAvatar = CircleAvatar(
        radius: avatarSize / 2,
        backgroundImage: CachedNetworkImageProvider(_playerAvatarUrl!),
      );
    } else {
      leftAvatar = CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: const Color(0xFFFF8A00),
        child: const Text('🐱', style: TextStyle(fontSize: 14)),
      );
    }

    // Opponent
    if (_isVsAi) {
      rightAvatar = CircleAvatar(
        radius: avatarSize / 2,
        backgroundImage: const CachedNetworkImageProvider('https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=500&auto=format&fit=crop'),
      );
    } else {
      rightAvatar = CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: const Color(0xFFFF5E3A),
        child: const Text('🐯', style: TextStyle(fontSize: 14)),
      );
    }

    final isP1Active = _isPlayerTurn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Player 1 widget
          Opacity(
            opacity: isP1Active ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isP1Active ? const Color(0xFFFF8A00).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isP1Active ? const Color(0xFFFF8A00) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  leftAvatar,
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.username ?? 'Player 1',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Text(
                        'Orange Pawn',
                        style: TextStyle(color: Color(0xFFFF8A00), fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'VS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          // Player 2 / AI widget
          Opacity(
            opacity: !isP1Active ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: !isP1Active ? const Color(0xFF00D1FF).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: !isP1Active ? const Color(0xFF00D1FF) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  rightAvatar,
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isVsAi ? 'Cat Bot' : 'Player 2',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        _isVsAi ? 'Blue Pawn' : 'Pink Pawn',
                        style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      children: [
        if (_isVsAi) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF8A00), size: 20),
              const SizedBox(width: 6),
              Text(
                'Win Streak: $_winStreak  |  Best Streak: $_maxStreak',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Tip: Tap any column to drop your cat paw token there. Get four in a row horizontally, vertically, or diagonally to win!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}

// Model representing a placed token
class PlacedToken {
  final int column;
  final int row;
  final int player; // 1 = player 1, 2 = player 2/AI
  final DateTime timestamp;

  PlacedToken({
    required this.column,
    required this.row,
    required this.player,
  }) : timestamp = DateTime.now();
}

// Custom Painter to draw the plastic frame with circles clipped out
class ConnectFourBoardPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;
  final Color color;

  ConnectFourBoardPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Path for the board outline rectangle
    final boardPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ));

    // Subtract circles
    final holesPath = Path();
    final diameter = cellSize * 0.82;
    final radius = diameter / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * cellSize + cellSize / 2;
        final cy = r * cellSize + cellSize / 2;
        holesPath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      }
    }

    final finalPath = Path.combine(PathOperation.difference, boardPath, holesPath);
    canvas.drawPath(finalPath, paint);

    // Draw grid slot inner shadows or subtle borders
    final slotBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * cellSize + cellSize / 2;
        final cy = r * cellSize + cellSize / 2;
        canvas.drawCircle(Offset(cx, cy), radius + 1.0, slotBorderPaint);
      }
    }

    // Outer highlight border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    ), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Stateful Animated Token Widget that drop-animates on create
class _AnimatedTokenWidget extends StatefulWidget {
  final int column;
  final int row;
  final int player;
  final double cellSize;
  final bool isWinningCell;
  final String? playerAvatarUrl;
  final String botAvatarUrl;

  const _AnimatedTokenWidget({
    required this.column,
    required this.row,
    required this.player,
    required this.cellSize,
    required this.isWinningCell,
    required this.playerAvatarUrl,
    required this.botAvatarUrl,
    super.key,
  });

  @override
  State<_AnimatedTokenWidget> createState() => _AnimatedTokenWidgetState();
}

class _AnimatedTokenWidgetState extends State<_AnimatedTokenWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Animates top index coordinate from above (-1.5) to the target row index
    _yAnimation = Tween<double>(
      begin: -1.5 * widget.cellSize,
      end: widget.row * widget.cellSize,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.bounceOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.cellSize * 0.12;
    final tokenSize = widget.cellSize - padding * 2;

    return AnimatedBuilder(
      animation: _yAnimation,
      builder: (context, child) {
        return Positioned(
          left: widget.column * widget.cellSize + padding,
          top: _yAnimation.value + padding,
          width: tokenSize,
          height: tokenSize,
          child: child!,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: widget.player == 1
                ? [const Color(0xFFFFB300), const Color(0xFFFF8A00)] // P1 Orange
                : [const Color(0xFF00D1FF), const Color(0xFF0055FF)], // P2 / AI Blue
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isWinningCell
                  ? (widget.player == 1 ? const Color(0xFFFFB300) : const Color(0xFF00D1FF)).withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.4),
              blurRadius: widget.isWinningCell ? 16 : 4,
              spreadRadius: widget.isWinningCell ? 4 : 0,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dynamic avatar overlayed inside the circle token
              Opacity(
                opacity: 0.35,
                child: widget.player == 1
                    ? (widget.playerAvatarUrl != null && widget.playerAvatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.playerAvatarUrl!,
                            fit: BoxFit.cover,
                            width: tokenSize,
                            height: tokenSize,
                          )
                        : null)
                    : CachedNetworkImage(
                        imageUrl: widget.botAvatarUrl,
                        fit: BoxFit.cover,
                        width: tokenSize,
                        height: tokenSize,
                      ),
              ),
              // Emoji Icon inside the token
              Center(
                child: Text(
                  widget.player == 1 ? '😸' : '🦁',
                  style: TextStyle(
                    fontSize: tokenSize * 0.55,
                    shadows: const [
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 3.0,
                        color: Colors.black45,
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
}

// Mini class for Minimax outcome
class _MinimaxResult {
  final double score;
  final int column;

  _MinimaxResult({required this.score, required this.column});
}
