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
  int _latestScore = 0;

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
            _injectUserData();
          },
        ),
      )
      ..loadRequest(Uri.parse(_gameUrl));
  }

  Future<void> _injectUserData() async {
    try {
      // 1. Player Info
      final username = widget.user.username ?? 'anonymous';
      final fullName = widget.user.fullName?.trim().isNotEmpty == true
          ? widget.user.fullName!
          : username;
      final avatarUrl = widget.user.avatarUrl ?? '';

      final playerPayload = jsonEncode({
        'name': fullName,
        'avatarUrl': avatarUrl,
      });
      await _controller.runJavaScript('window.setPlayer($playerPayload);');

      // 2. Room Mode & Owner
      await _controller.runJavaScript(
          'window.setRoomInfo({ isOwner: true, mode: "1v1" });');

      // 3. User Wallet Balance
      try {
        final wallet = await WalletService().fetchBalance();
        final coins = wallet.balanceCents ~/ 100;
        await _controller.runJavaScript('window.setBalance($coins);');
      } catch (_) {
        await _controller.runJavaScript('window.setBalance(0);');
      }
    } catch (e) {
      debugPrint('[Game Inject Error] $e');
    }
  }

  void _handleGameMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'buzzer':
          HapticFeedback.heavyImpact();
          _startVoiceListening();
          break;

        case 'turnEnd':
          _stopVoiceListening();
          break;

        case 'wrongGuess':
          HapticFeedback.mediumImpact();
          _latestScore = (data['score'] as num?)?.toInt() ?? _latestScore;
          break;

        case 'roundEnd':
          _stopVoiceListening();
          final won = data['won'] == true;
          if (won) {
            HapticFeedback.lightImpact();
          }
          _latestScore = (data['score'] as num?)?.toInt() ?? _latestScore;
          break;

        case 'gameEnd':
          _stopVoiceListening();
          _onGameEnd(data);
          break;

        case 'leaveRoom':
          _onExit();
          break;

        case 'inviteFriend':
          _onInvite();
          break;

        case 'toggleMute':
          // Handled within game UI
          break;

        case 'playerReady':
          HapticFeedback.lightImpact();
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
    final score = (data['score'] as num?)?.toInt() ?? _latestScore;
    final coins = (data['coinsEarned'] as num?)?.toInt() ?? 0;
    final username = widget.user.username ?? 'anonymous';

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'guess_song_highscore_$username';
      final prevHigh = prefs.getInt(key) ?? 0;
      if (score > prevHigh) {
        await prefs.setInt(key, score);
      }
    } catch (_) {}

    if (coins > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Great game! You earned +$coins Kats Coins!',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF241543),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
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
