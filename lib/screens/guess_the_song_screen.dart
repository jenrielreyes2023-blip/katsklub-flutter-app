import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:webview_flutter/webview_flutter.dart';
import '../models/user.dart';
import '../services/wallet_service.dart';
import '../services/global_audio_player_service.dart';

/// H5 Guess the Song Game Screen for KatsKlub.
/// Full bridge implementation conforming strictly to AI_NOTES.md (protocol v9).
class GuessTheSongScreen extends StatefulWidget {
  final User user;

  const GuessTheSongScreen({required this.user, super.key});

  @override
  State<GuessTheSongScreen> createState() => _GuessTheSongScreenState();
}

class _GuessTheSongScreenState extends State<GuessTheSongScreen> {
  static const String _gameUrl = 'https://cdn.katsklub.top/games/guess-the-song/index.html';

  late final WebViewController _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isLoading = true;
  double _loadProgress = 0.0;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _selfReady = false;
  int _currentScore = 0;
  String _roomMode = '1v1';

  @override
  void initState() {
    super.initState();
    // Pause any global audio playback while playing music game
    GlobalAudioPlayerService.instance?.setPlaying(false);
    _initSpeech();
    _initWebView();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (err) => debugPrint('[STT Error] $err'),
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _isListening = status == 'listening';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('[STT Init Exception] $e');
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF141024))
      ..addJavaScriptChannel(
        'GameResult',
        onMessageReceived: (JavaScriptMessage message) {
          _handleGameMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadProgress = progress / 100.0);
            }
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
            _injectInitialBridgeData();
          },
        ),
      )
      ..loadRequest(Uri.parse(_gameUrl));
  }

  /// Initial bridge injection per AI_NOTES.md §4a (called on page finish)
  Future<void> _injectInitialBridgeData() async {
    try {
      final username = widget.user.username ?? 'anonymous';
      final fullName = widget.user.fullName?.trim().isNotEmpty == true
          ? widget.user.fullName!
          : username;
      final avatarUrl = widget.user.avatarUrl ?? '';

      // 1. window.setPlayer({name, avatarUrl})
      final playerPayload = jsonEncode({
        'name': fullName,
        'avatarUrl': avatarUrl,
      });
      await _controller.runJavaScript('window.setPlayer($playerPayload);');

      // 2. window.setRoomInfo({isOwner, mode})
      await _controller.runJavaScript(
        'window.setRoomInfo({ isOwner: true, mode: ${jsonEncode(_roomMode)} });',
      );

      // 3. window.setSeats([...])
      _pushSeats();

      // 4. window.setBalance(n)
      try {
        final wallet = await WalletService().fetchBalance();
        final coins = wallet.balanceCents ~/ 100;
        await _controller.runJavaScript('window.setBalance($coins);');
      } catch (_) {
        await _controller.runJavaScript('window.setBalance(0);');
      }
    } catch (e) {
      debugPrint('[Game Initial Bridge Error] $e');
    }
  }

  /// Updates and re-pushes seat tally & ranks per AI_NOTES.md §4a & §7
  void _pushSeats() {
    try {
      final username = widget.user.username ?? 'anonymous';
      final fullName = widget.user.fullName?.trim().isNotEmpty == true
          ? widget.user.fullName!
          : username;
      final avatarUrl = widget.user.avatarUrl ?? '';

      final seatsJson = jsonEncode([
        {
          'name': fullName,
          'avatarUrl': avatarUrl,
          'isSelf': true,
          'ready': _selfReady,
          'score': _currentScore,
        }
      ]);
      _controller.runJavaScript('window.setSeats($seatsJson);');
    } catch (e) {
      debugPrint('[Push Seats Error] $e');
    }
  }

  /// Handles incoming bridge messages from GameResult per AI_NOTES.md §4b
  void _handleGameMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'gameStart':
          // Deck loaded, entering lobby
          _selfReady = false;
          _currentScore = 0;
          _pushSeats();
          break;

        case 'playerReady':
          // Self toggled I'M READY
          HapticFeedback.lightImpact();
          _selfReady = data['ready'] == true;
          _pushSeats();
          break;

        case 'buzzer':
          // Self pressed buzzer: arbitrate & grant turn immediately via setTurn
          HapticFeedback.heavyImpact();
          final player = data['player'] as String? ??
              (widget.user.fullName ?? widget.user.username ?? 'You');
          _controller.runJavaScript(
            'window.setTurn({ isSelf: true, holder: ${jsonEncode(player)} });',
          );
          _startVoiceListening();
          break;

        case 'turnEnd':
          // Turn ended (correct / wrong / timeout)
          _stopVoiceListening();
          break;

        case 'wrongGuess':
          // Anti-spam deduction applied
          HapticFeedback.mediumImpact();
          _currentScore = (data['score'] as num?)?.toInt() ?? _currentScore;
          _pushSeats();
          break;

        case 'roundEnd':
          _stopVoiceListening();
          final won = data['won'] == true;
          if (won) {
            HapticFeedback.lightImpact();
          }
          _currentScore = (data['score'] as num?)?.toInt() ?? _currentScore;
          _pushSeats();
          break;

        case 'gameEnd':
          _stopVoiceListening();
          _onGameEnd(data);
          break;

        case 'setRoomMode':
          final mode = data['mode'] as String? ?? '1v1';
          _roomMode = mode;
          _controller.runJavaScript(
            'window.setRoomInfo({ isOwner: true, mode: ${jsonEncode(mode)} });',
          );
          break;

        case 'inviteFriend':
          _onInvite();
          break;

        case 'toggleMute':
          final muted = data['muted'] == true;
          if (muted) {
            _stopVoiceListening();
          }
          break;

        case 'leaveRoom':
          _onExit();
          break;
      }
    } catch (e) {
      debugPrint('[Game Message Parse Error] $e: $rawJson');
    }
  }

  void _startVoiceListening() {
    if (!_speechAvailable || _speech.isListening) return;

    try {
      _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty && mounted) {
            final encoded = jsonEncode(words);
            _controller.runJavaScript('window.setVoiceTranscript($encoded);');
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 14),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('[Speech Listen Error] $e');
    }
  }

  void _stopVoiceListening() {
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  Future<void> _onGameEnd(Map<String, dynamic> data) async {
    final score = (data['score'] as num?)?.toInt() ?? _currentScore;
    final coins = (data['coinsEarned'] as num?)?.toInt() ?? 0;
    final username = widget.user.username ?? 'anonymous';

    // 1. Record High Score in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guess_song_highscore_$username';
      final prevHigh = prefs.getInt(key) ?? 0;
      if (score > prevHigh) {
        await prefs.setInt(key, score);
      }
    } catch (_) {}

    // 2. Real wallet credit via backend per AI_NOTES.md §4b
    if (coins > 0) {
      try {
        final updatedWallet =
            await WalletService().topUp(amountCents: coins * 100);
        final newCoins = updatedWallet.balanceCents ~/ 100;
        await _controller.runJavaScript('window.setBalance($newCoins);');
      } catch (e) {
        debugPrint('[Wallet Credit Error] $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Awesome game! +$coins Kats Coins credited to your wallet!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF241543),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onInvite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied! Share with friends to play together.'),
        backgroundColor: Color(0xFF241543),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onExit() {
    _stopVoiceListening();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _stopVoiceListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _stopVoiceListening();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF141024),
        body: SafeArea(
          child: Stack(
            children: [
              // Main HTML5 Game WebView
              WebViewWidget(controller: _controller),

              // Loading Spinner
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF141024),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFB388FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading Kats Guess The Song...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_loadProgress > 0 && _loadProgress < 1) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 140,
                              child: LinearProgressIndicator(
                                value: _loadProgress,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF7AD9),
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Discreet Exit Button at top-left
              Positioned(
                top: 8,
                left: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _onExit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              // Listening Indicator (Pulsing microphone when voice recognition is active)
              if (_isListening)
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF69F0AE),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          color: Color(0xFF69F0AE),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Listening...',
                          style: TextStyle(
                            color: Color(0xFF69F0AE),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
}
