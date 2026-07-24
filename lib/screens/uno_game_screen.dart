import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/message_sound_service.dart';

enum CardColor { red, blue, green, yellow, wild }

enum CardType { number, skip, reverse, drawTwo, wild, wildDrawFour }

class UnoCard {
  final CardColor color;
  final CardType type;
  final int? value; // 0-9 for numbers
  final String id;

  UnoCard({
    required this.color,
    required this.type,
    this.value,
    required this.id,
  });

  String get displayName {
    switch (type) {
      case CardType.number:
        return '$value';
      case CardType.skip:
        return 'Skip 🚫';
      case CardType.reverse:
        return 'Reverse 🔄';
      case CardType.drawTwo:
        return '+2 🐾';
      case CardType.wild:
        return 'Wild 🌈';
      case CardType.wildDrawFour:
        return '+4 🌟';
    }
  }

  Color get rawColor {
    switch (color) {
      case CardColor.red:
        return const Color(0xFFFF5E3A);
      case CardColor.blue:
        return const Color(0xFF00D1FF);
      case CardColor.green:
        return const Color(0xFF2ECC71);
      case CardColor.yellow:
        return const Color(0xFFF1C40F);
      case CardColor.wild:
        return const Color(0xFF1E1E2C);
    }
  }
}

class UnoGameScreen extends StatefulWidget {
  final User user;

  const UnoGameScreen({required this.user, super.key});

  @override
  State<UnoGameScreen> createState() => _UnoGameScreenState();
}

class _UnoGameScreenState extends State<UnoGameScreen> {
  // Preloading & statistics
  bool _isLoading = true;
  double _loadProgress = 0.0;
  String _loadStatus = 'Shuffling card deck...';
  int _unoWins = 0;
  int _unoMaxStreak = 0;

  // Deck, Hands & Discard Pile
  List<UnoCard> _drawPile = [];
  List<UnoCard> _discardPile = [];
  List<UnoCard> _playerHand = [];
  List<UnoCard> _botHand = [];

  // Active turn indicators
  bool _isPlayerTurn = true;
  CardColor _activeColor = CardColor.red;
  bool _isReversed = false; // Reverse changes arrow highlight direction
  bool _gameEnded = false;
  String _winnerMessage = '';
  
  // Uno Panic system
  bool _playerCalledUno = false;
  bool _showUnoButton = false;

  // Game log to show in the center
  List<String> _gameLog = [];
  
  // Dynamic User Avatar
  String? _playerAvatarUrl;
  final String _botAvatarUrl = 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=500&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _playerAvatarUrl = widget.user.avatarUrl;
    _startPreloading();
  }

  Future<void> _startPreloading() async {
    setState(() {
      _loadProgress = 0.1;
      _loadStatus = 'Loading card deck assets...';
    });

    await MessageSoundService.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = widget.user.username ?? "anonymous";
      setState(() {
        _unoWins = prefs.getInt('uno_wins_$username') ?? 0;
        _unoMaxStreak = prefs.getInt('uno_max_streak_$username') ?? 0;
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _loadProgress = 0.5;
      _loadStatus = 'Preparing card tables...';
    });

    if (_playerAvatarUrl != null && _playerAvatarUrl!.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(_playerAvatarUrl!), context);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _loadProgress = 0.8;
      _loadStatus = 'Caching opponent kittens...';
    });

    try {
      await precacheImage(CachedNetworkImageProvider(_botAvatarUrl), context);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loadProgress = 1.0;
      _loadStatus = 'Dealing cards...';
    });

    _initializeGame();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  void _initializeGame() {
    // Generate a fresh Uno deck
    final List<UnoCard> fullDeck = [];
    int idCounter = 0;

    for (final color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
      // One 0 card per color
      fullDeck.add(UnoCard(color: color, type: CardType.number, value: 0, id: '${idCounter++}'));
      
      // Two 1-9 cards per color
      for (int i = 1; i <= 9; i++) {
        fullDeck.add(UnoCard(color: color, type: CardType.number, value: i, id: '${idCounter++}'));
        fullDeck.add(UnoCard(color: color, type: CardType.number, value: i, id: '${idCounter++}'));
      }

      // Special cards (2 of each per color)
      for (int i = 0; i < 2; i++) {
        fullDeck.add(UnoCard(color: color, type: CardType.skip, id: '${idCounter++}'));
        fullDeck.add(UnoCard(color: color, type: CardType.reverse, id: '${idCounter++}'));
        fullDeck.add(UnoCard(color: color, type: CardType.drawTwo, id: '${idCounter++}'));
      }
    }

    // Wild cards (4 of each)
    for (int i = 0; i < 4; i++) {
      fullDeck.add(UnoCard(color: CardColor.wild, type: CardType.wild, id: '${idCounter++}'));
      fullDeck.add(UnoCard(color: CardColor.wild, type: CardType.wildDrawFour, id: '${idCounter++}'));
    }

    fullDeck.shuffle(math.Random());

    _drawPile = fullDeck;
    _playerHand = [];
    _botHand = [];
    _discardPile = [];
    _gameLog = ['Game started. Match matching color or value!'];
    _isPlayerTurn = true;
    _gameEnded = false;
    _winnerMessage = '';
    _playerCalledUno = false;
    _showUnoButton = false;
    _isReversed = false;

    // Deal 7 cards to each player
    for (int i = 0; i < 7; i++) {
      _playerHand.add(_drawPile.removeLast());
      _botHand.add(_drawPile.removeLast());
    }

    // Flip the first card to start discard pile. Ensure it is not a Wild +4.
    UnoCard startingCard = _drawPile.removeLast();
    while (startingCard.type == CardType.wildDrawFour) {
      _drawPile.insert(0, startingCard);
      _drawPile.shuffle(math.Random());
      startingCard = _drawPile.removeLast();
    }

    _discardPile.add(startingCard);
    _activeColor = startingCard.color == CardColor.wild ? CardColor.red : startingCard.color;

    // If starting card is a special action card, trigger it for player 1 immediately
    if (startingCard.type == CardType.drawTwo) {
      _drawCards(_playerHand, 2);
      _isPlayerTurn = false;
      _gameLog.add('Starting card +2 Paw! Player 1 draws 2 and skips turn.');
      _triggerBotTurnWithDelay();
    } else if (startingCard.type == CardType.skip) {
      _isPlayerTurn = false;
      _gameLog.add('Starting card Skip! Player 1 turn skipped.');
      _triggerBotTurnWithDelay();
    } else if (startingCard.type == CardType.reverse) {
      _isReversed = true;
      _gameLog.add('Starting card Reverse! Direction inverted.');
    }
  }

  void _triggerBotTurnWithDelay() {
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_gameEnded) {
        _makeBotMove();
      }
    });
  }

  // Draw card helper
  void _drawCards(List<UnoCard> hand, int count) {
    for (int i = 0; i < count; i++) {
      if (_drawPile.isEmpty) {
        // Recycle discard pile except the top card
        if (_discardPile.length <= 1) return;
        final top = _discardPile.removeLast();
        _drawPile = List.from(_discardPile)..shuffle(math.Random());
        _discardPile = [top];
        _gameLog.add('Recycled discard pile to draw pile.');
      }
      hand.add(_drawPile.removeLast());
    }
  }

  bool _isPlayable(UnoCard card) {
    if (_discardPile.isEmpty) return true;
    final topCard = _discardPile.last;

    // Wild cards are always playable
    if (card.color == CardColor.wild) return true;

    // Color match
    if (card.color == _activeColor) return true;

    // Number value match
    if (card.type == CardType.number && topCard.type == CardType.number && card.value == topCard.value) {
      return true;
    }

    // Special card type match (e.g. Skip matches Skip)
    if (card.type == topCard.type && card.type != CardType.number) {
      return true;
    }

    return false;
  }

  void _drawCardFromPile() {
    if (!_isPlayerTurn || _gameEnded) return;

    HapticFeedback.lightImpact();
    MessageSoundService.playIncoming();
    setState(() {
      _drawCards(_playerHand, 1);
      final drawnCard = _playerHand.last;
      _gameLog.add('You drew a card (${drawnCard.displayName}).');
      
      // Auto-play drawn card if playable to keep game fast paced
      if (_isPlayable(drawnCard)) {
        _gameLog.add('Drawn card is playable! Auto-playing...');
        _playCard(drawnCard, isPlayer: true);
      } else {
        // End player turn
        _isPlayerTurn = false;
        _triggerBotTurnWithDelay();
      }
    });
  }

  void _playCard(UnoCard card, {required bool isPlayer}) {
    if (_gameEnded) return;

    final hand = isPlayer ? _playerHand : _botHand;
    setState(() {
      hand.removeWhere((c) => c.id == card.id);
      _discardPile.add(card);
      _activeColor = card.color == CardColor.wild ? _activeColor : card.color;
      _gameLog.add('${isPlayer ? "You" : "Cat Bot"} played ${card.displayName}');
    });

    HapticFeedback.mediumImpact();
    if (isPlayer) {
      MessageSoundService.playOutgoing();
    } else {
      MessageSoundService.playIncoming();
    }

    // Check if player has 1 card left and didn't call UNO
    if (isPlayer && _playerHand.length == 1 && !_playerCalledUno) {
      // Auto penalty since they didn't tap UNO button in advance!
      setState(() {
        _drawCards(_playerHand, 2);
        _gameLog.add('⚠️ Penalty! You forgot to call UNO! Draw 2 cards.');
      });
      HapticFeedback.heavyImpact();
    }

    // Check Win
    if (hand.isEmpty) {
      _handleWin(isPlayer);
      return;
    }

    // Trigger UNO button display for next turn if 2 cards left
    if (isPlayer && _playerHand.length == 2) {
      setState(() {
        _showUnoButton = true;
      });
    } else if (isPlayer) {
      setState(() {
        _showUnoButton = false;
        _playerCalledUno = false;
      });
    }

    // Special card actions
    bool skipNextTurn = false;
    int drawCount = 0;

    if (card.type == CardType.skip) {
      skipNextTurn = true;
    } else if (card.type == CardType.reverse) {
      _isReversed = !_isReversed;
      // In 1v1, Reverse acts like Skip
      skipNextTurn = true;
      _gameLog.add('Direction reversed! Opponent skips turn.');
    } else if (card.type == CardType.drawTwo) {
      drawCount = 2;
      skipNextTurn = true;
    } else if (card.type == CardType.wild) {
      if (isPlayer) {
        _showColorPicker((selectedColor) {
          setState(() {
            _activeColor = selectedColor;
            _gameLog.add('You changed active color to ${_colorName(selectedColor)}');
            _isPlayerTurn = false;
            _triggerBotTurnWithDelay();
          });
        });
        return; // Pause turn switching until color chosen
      } else {
        // AI selects color they have most of
        final chosenColor = _getAiMostColor();
        _activeColor = chosenColor;
        _gameLog.add('Cat Bot changed active color to ${_colorName(chosenColor)}');
      }
    } else if (card.type == CardType.wildDrawFour) {
      drawCount = 4;
      skipNextTurn = true;
      if (isPlayer) {
        _showColorPicker((selectedColor) {
          setState(() {
            _activeColor = selectedColor;
            _gameLog.add('You changed active color to ${_colorName(selectedColor)}');
            _drawCards(_botHand, 4);
            _gameLog.add('Cat Bot draws 4 cards and skips turn.');
            // Skip means player retains turn
            _isPlayerTurn = true;
          });
        });
        return;
      } else {
        final chosenColor = _getAiMostColor();
        _activeColor = chosenColor;
        _gameLog.add('Cat Bot changed active color to ${_colorName(chosenColor)}');
        _drawCards(_playerHand, 4);
        _gameLog.add('You draw 4 cards and skip turn.');
        // Skip bot turn means bot plays again
        _triggerBotTurnWithDelay();
        return;
      }
    }

    if (drawCount > 0) {
      final targetHand = isPlayer ? _botHand : _playerHand;
      _drawCards(targetHand, drawCount);
    }

    setState(() {
      if (skipNextTurn) {
        // Active turn remains the same player
        _isPlayerTurn = isPlayer;
      } else {
        _isPlayerTurn = !isPlayer;
      }
    });

    if (!_isPlayerTurn) {
      _triggerBotTurnWithDelay();
    }
  }

  void _callUno() {
    if (_playerHand.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only call UNO when you have 2 cards left!')),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    MessageSoundService.playOutgoing();
    setState(() {
      _playerCalledUno = true;
      _showUnoButton = false;
      _gameLog.add('📣 You shouted "UNO!"');
    });
  }

  // --- BOT/AI PLAY LOGIC ---

  void _makeBotMove() {
    if (_gameEnded || _isPlayerTurn) return;

    // Determine playable cards
    final playableCards = _botHand.where((c) => _isPlayable(c)).toList();

    if (playableCards.isEmpty) {
      // Draw card
      setState(() {
        _drawCards(_botHand, 1);
        final drawnCard = _botHand.last;
        _gameLog.add('Cat Bot drew a card.');
        if (_isPlayable(drawnCard)) {
          _gameLog.add('Cat Bot played drawn ${drawnCard.displayName} card.');
          _playCard(drawnCard, isPlayer: false);
        } else {
          _isPlayerTurn = true;
        }
      });
      return;
    }

    // Play strategy:
    // 1. Play +4 or +2 first if player has few cards to disrupt them
    // 2. Play skips/reverses
    // 3. Play matching numbers
    // 4. Play wild
    UnoCard selectedCard = playableCards.first;

    final hasPlusFour = playableCards.where((c) => c.type == CardType.wildDrawFour).toList();
    final hasPlusTwo = playableCards.where((c) => c.type == CardType.drawTwo).toList();
    final hasSkips = playableCards.where((c) => c.type == CardType.skip || c.type == CardType.reverse).toList();

    if (_playerHand.length <= 3 && hasPlusFour.isNotEmpty) {
      selectedCard = hasPlusFour.first;
    } else if (_playerHand.length <= 3 && hasPlusTwo.isNotEmpty) {
      selectedCard = hasPlusTwo.first;
    } else if (hasSkips.isNotEmpty) {
      selectedCard = hasSkips.first;
    } else {
      // Play numbers or regular wild
      final numbers = playableCards.where((c) => c.type == CardType.number).toList();
      if (numbers.isNotEmpty) {
        selectedCard = numbers.first;
      }
    }

    // Bot call UNO check
    if (_botHand.length == 2) {
      // Bot always calls UNO correctly
      setState(() {
        _gameLog.add('🤖 Cat Bot calls "UNO!"');
      });
    }

    _playCard(selectedCard, isPlayer: false);
  }

  CardColor _getAiMostColor() {
    final counts = {
      CardColor.red: 0,
      CardColor.blue: 0,
      CardColor.green: 0,
      CardColor.yellow: 0,
    };
    for (final c in _botHand) {
      if (c.color != CardColor.wild) {
        counts[c.color] = (counts[c.color] ?? 0) + 1;
      }
    }
    CardColor maxCol = CardColor.red;
    int maxVal = -1;
    counts.forEach((col, val) {
      if (val > maxVal) {
        maxVal = val;
        maxCol = col;
      }
    });
    return maxCol;
  }

  String _colorName(CardColor color) {
    switch (color) {
      case CardColor.red:
        return 'Red 🔴';
      case CardColor.blue:
        return 'Blue 🔵';
      case CardColor.green:
        return 'Green 🟢';
      case CardColor.yellow:
        return 'Yellow 🟡';
      default:
        return 'Wild 🌈';
    }
  }

  void _showColorPicker(Function(CardColor) onSelected) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1B26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          ),
          title: const Text(
            'Select Active Color',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _colorPickerButton(CardColor.red, const Color(0xFFFF5E3A), ctx, onSelected),
              _colorPickerButton(CardColor.blue, const Color(0xFF00D1FF), ctx, onSelected),
              _colorPickerButton(CardColor.green, const Color(0xFF2ECC71), ctx, onSelected),
              _colorPickerButton(CardColor.yellow, const Color(0xFFF1C40F), ctx, onSelected),
            ],
          ),
        );
      },
    );
  }

  Widget _colorPickerButton(CardColor color, Color displayCol, BuildContext dialogCtx, Function(CardColor) onSelected) {
    return GestureDetector(
      onTap: () {
        Navigator.of(dialogCtx).pop();
        onSelected(color);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: displayCol,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: displayCol.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWin(bool isPlayerWon) async {
    setState(() {
      _gameEnded = true;
      if (isPlayerWon) {
        _winnerMessage = 'Victory! You emptied your deck!';
        _unoWins++;
        if (_unoWins > _unoMaxStreak) {
          _unoMaxStreak = _unoWins;
        }
      } else {
        _winnerMessage = 'Defeat! Cat Bot cleared their deck first.';
        _unoWins = 0;
      }
    });

    HapticFeedback.heavyImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = widget.user.username ?? "anonymous";
      await prefs.setInt('uno_wins_$username', _unoWins);
      await prefs.setInt('uno_max_streak_$username', _unoMaxStreak);
    } catch (_) {}

    _showWinDialog(isPlayerWon);
  }

  void _showWinDialog(bool isPlayerWon) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1B26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isPlayerWon ? const Color(0xFF2ECC71) : const Color(0xFFFF5E3A),
              width: 2,
            ),
          ),
          title: Text(
            isPlayerWon ? '🎉 Game Won! 🎉' : '😿 Game Over 😿',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _winnerMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFFD1D5DB)),
              ),
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
                        const Text('Total Wins', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text('$_unoWins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Best Streak', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text('$_unoMaxStreak', style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
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
                backgroundColor: isPlayerWon ? const Color(0xFF2ECC71) : const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Exit to Arcade', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _resetGame() {
    setState(() {
      _initializeGame();
    });
  }

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
                const Icon(Icons.style_rounded, size: 72, color: Color(0xFFFF5E3A)),
                const SizedBox(height: 24),
                const Text(
                  'Kats Uno Duel',
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
                  style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _loadProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5E3A)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          'Kats Uno Duel',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _resetGame,
            tooltip: 'Reset match',
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
            // 1. OPPONENT SECTION (Kitten Bot Hand)
            _buildOpponentArea(),
            
            const Divider(color: Colors.white10, height: 1),

            // 2. DISCARD & DRAW PILE (Center Play Zone)
            Expanded(child: _buildPlayZone()),

            const Divider(color: Colors.white10, height: 1),

            // 3. PLAYER ACTION BAR (UNO Shout Button / Hints)
            if (_showUnoButton) _buildUnoShoutBar(),

            // 4. PLAYER HAND (Bottom Carousel)
            _buildPlayerArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bot profile indicator
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: CachedNetworkImageProvider(_botAvatarUrl),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cat Bot AI 🤖', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    _isPlayerTurn ? 'Waiting for you...' : 'Thinking...',
                    style: TextStyle(
                      color: _isPlayerTurn ? const Color(0xFF9CA3AF) : const Color(0xFF00D1FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Bot cards overlapping deck UI
          Row(
            children: [
              const Icon(Icons.style_outlined, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_botHand.length} cards',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              // Overlapping cards visualization
              SizedBox(
                height: 38,
                width: math.min(100.0, _botHand.length * 10.0 + 20),
                child: Stack(
                  children: List.generate(_botHand.length, (idx) {
                    return Positioned(
                      left: idx * 10.0,
                      child: Container(
                        width: 25,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2A3A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Center(
                          child: Text('🐾', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayZone() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Direction indicator & active color display
          _buildStatusBar(),
          
          // Cards: Discard Pile (face up) vs Draw Pile (face down)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // DRAW PILE (Press to draw card)
              GestureDetector(
                onTap: _drawCardFromPile,
                child: Container(
                  width: 90,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPlayerTurn ? const Color(0xFFFF5E3A).withValues(alpha: 0.5) : Colors.white12,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isPlayerTurn ? const Color(0xFFFF5E3A).withValues(alpha: 0.15) : Colors.black26,
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Text(
                          'DRAW',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            color: const Color(0xFFFF5E3A).withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 28, color: const Color(0xFFFF5E3A).withValues(alpha: 0.8)),
                          const SizedBox(height: 6),
                          Text(
                            '${_drawPile.length} cards',
                            style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              
              // DISCARD PILE (Current top card)
              if (_discardPile.isNotEmpty)
                _buildCardWidget(_discardPile.last, isPlayable: false)
              else
                Container(
                  width: 90,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Empty', style: TextStyle(color: Colors.grey)),
                  ),
                ),
            ],
          ),

          // Scrollable Game Logs (recent plays)
          Container(
            height: 48,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              reverse: true,
              itemCount: _gameLog.length,
              itemBuilder: (ctx, index) {
                final logIndex = _gameLog.length - 1 - index;
                final logText = _gameLog[logIndex];
                final isWarn = logText.contains('Penalty') || logText.contains('UNO');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    logText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: logIndex == _gameLog.length - 1 ? FontWeight.w800 : FontWeight.w500,
                      color: logIndex == _gameLog.length - 1
                          ? (isWarn ? const Color(0xFFFF5E3A) : Colors.white)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    Color indicatorCol = const Color(0xFFFF5E3A);
    if (_activeColor == CardColor.blue) indicatorCol = const Color(0xFF00D1FF);
    if (_activeColor == CardColor.green) indicatorCol = const Color(0xFF2ECC71);
    if (_activeColor == CardColor.yellow) indicatorCol = const Color(0xFFF1C40F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: indicatorCol.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: indicatorCol.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: indicatorCol, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Active Color: ${_colorName(_activeColor).toUpperCase()}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: indicatorCol,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _isReversed ? Icons.west_rounded : Icons.east_rounded,
            size: 16,
            color: indicatorCol,
          ),
        ],
      ),
    );
  }

  Widget _buildUnoShoutBar() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFF5E3A).withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _callUno,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5E3A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text(
            'SHOUT "UNO!"',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF161520),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFFF5E3A),
                    backgroundImage: _playerAvatarUrl != null ? CachedNetworkImageProvider(_playerAvatarUrl!) : null,
                    child: Text(
                      _playerAvatarUrl != null ? '' : '🐱',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Your Deck Hand', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Text(
                '${_playerHand.length} cards',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Cards horizontal lists
          SizedBox(
            height: 155,
            child: _playerHand.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _playerHand.length,
                    itemBuilder: (ctx, index) {
                      final card = _playerHand[index];
                      final playable = _isPlayable(card) && _isPlayerTurn && !_gameEnded;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            if (playable) {
                              _playCard(card, isPlayer: true);
                            } else if (!_isPlayerTurn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Wait for your turn!"), duration: Duration(milliseconds: 600)),
                              );
                            }
                          },
                          child: _buildCardWidget(card, isPlayable: playable, isInteractive: true),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWidget(UnoCard card, {required bool isPlayable, bool isInteractive = false}) {
    Color cardBorderColor = isPlayable ? const Color(0xFF2ECC71) : Colors.white12;
    double offsetTop = isPlayable ? -12.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 90,
      height: 140,
      margin: EdgeInsets.only(top: offsetTop + 12),
      decoration: BoxDecoration(
        color: card.rawColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: isPlayable ? 3.0 : 1.0),
        boxShadow: [
          BoxShadow(
            color: isPlayable ? const Color(0xFF2ECC71).withValues(alpha: 0.3) : Colors.black38,
            blurRadius: isPlayable ? 14 : 4,
            spreadRadius: isPlayable ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner cat-ear outline decoration
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                ),
              ),
            ),
          ),
          
          // Value in corner (top-left)
          Positioned(
            top: 10,
            left: 10,
            child: Text(
              card.displayName.substring(0, math.min(card.displayName.length, 2)).trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),

          // Central Icon / Logo representation
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                _getCardEmoji(card.type),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),

          // Action label on bottom
          Positioned(
            bottom: 10,
            child: Text(
              _getCardLabel(card),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 9,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCardEmoji(CardType type) {
    switch (type) {
      case CardType.number:
        return '😸';
      case CardType.skip:
        return '💤';
      case CardType.reverse:
        return '🌀';
      case CardType.drawTwo:
        return '🐾';
      case CardType.wild:
        return '🌈';
      case CardType.wildDrawFour:
        return '🌟';
    }
  }

  String _getCardLabel(UnoCard card) {
    if (card.type == CardType.number) return 'NUMBER';
    if (card.type == CardType.skip) return 'SKIP';
    if (card.type == CardType.reverse) return 'REVERSE';
    if (card.type == CardType.drawTwo) return 'DRAW TWO';
    if (card.type == CardType.wild) return 'WILD';
    return 'DRAW FOUR';
  }
}
