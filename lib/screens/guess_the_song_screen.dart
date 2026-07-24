import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/user.dart';
import '../services/message_sound_service.dart';
import '../services/game_sound_service.dart';
import '../services/global_audio_player_service.dart';

class GuessTheSongScreen extends StatefulWidget {
  final User user;

  const GuessTheSongScreen({required this.user, super.key});

  @override
  State<GuessTheSongScreen> createState() => _GuessTheSongScreenState();
}

class _GuessTheSongScreenState extends State<GuessTheSongScreen>
    with TickerProviderStateMixin {
  // Services & Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Pre-loading states
  bool _isLoading = true;
  String _loadingStatus = 'Fetching top hit lists...';
  double _loadingProgress = 0.0;

  // Game Setup Mode
  bool _isModeSelected = false;
  int _gameMode = 1; // 1 = Solo, 2 = 2-Player Duel (Local PvP)

  // Playlist & Progress
  List<Map<String, dynamic>> _playlist = [];
  int _currentRound = 0; // 0 to 4
  bool _gameEnded = false;

  // Scores
  int _score = 0; // Solo score
  int _highScore = 0; // Solo high score
  int _p1Score = 0; // P1 score (2-Player)
  int _p2Score = 0; // P2 score (2-Player)

  // Round Specific States
  static const int _roundDurationSeconds = 30;
  Map<String, dynamic>? _currentSong;
  bool _isPlaying = false;
  bool _hasGuessed = false;
  bool _isGuessingMode = false;
  bool _guessResult = false;
  int _secondsRemaining = 30;
  Timer? _countdownTimer;

  // PvP lockouts & split-turns
  bool _p1LockedOut = false;
  bool _p2LockedOut = false;
  int? _activeGuesser; // 1 or 2
  int? _pendingGuessTapPlayer;

  // Seating & Voice Chat Simulation
  bool _p1MicMuted = false;
  bool _p2MicMuted = false;
  bool _p1Speaking = false;
  bool _p2Speaking = false;
  Timer? _voiceChatSimTimer;

  // Mute state backups for active buzzer override
  bool _savedP1MicMuted = false;
  bool _savedP2MicMuted = false;

  // Guessing & Voice states
  bool _speechAvailable = false;
  bool _isListening = false;
  String _speechTranscription = "";
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  // Buzz countdown
  int _buzzSecondsRemaining = 7;
  Timer? _buzzTimer;

  // Animations
  late AnimationController _discAnimationController;
  late AnimationController _voicePulseController;

  // Static Fallback Playlist (in case iTunes API fails or device is offline)
  final List<Map<String, dynamic>> _fallbackSongs = [
    {
      'trackName': 'Blinding Lights',
      'artistName': 'The Weeknd',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/9c/e2/3e/9ce23eac-b7d1-e6e7-1473-b3c373b5d275/mzaf_10332857448378770742.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/21/df/b8/21dfb871-3a05-1a87-c7cc-cf8353bf4a92/20UMGIM10300.rgb.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'Stay',
      'artistName': 'The Kid LAROI & Justin Bieber',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/8b/6e/de/8b6ede83-149a-e1d9-e938-4e0046b0ee69/mzaf_14099516805822363539.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/71/2a/e5/712ae5fb-4fc5-115f-5198-d8f99e3943fe/21UMGIM41846.rgb.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'Shape of You',
      'artistName': 'Ed Sheeran',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/36/53/78/365378c8-7ff6-69d1-d2f1-61b6f00cfd8e/mzaf_11308365287019313936.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/5a/09/a4/5a09a473-b778-d4fa-d5fa-5f10b77dc4e0/190295893113.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'Uptown Funk',
      'artistName': 'Mark Ronson & Bruno Mars',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/71/eb/64/71eb64bf-8025-a13f-cc54-c9b0cf25e2e8/mzaf_14488349887701467439.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/bf/25/b2/bf25b2f8-9a2f-7c15-f5b2-32a8740c06a3/886444857410.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'Bad Guy',
      'artistName': 'Billie Eilish',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/d5/4b/f7/d54bf768-e423-74ec-86f3-ffadca3b2fb7/mzaf_12674251264426543169.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/6b/df/b8/6bdfb871-3a05-1a87-c7cc-cf8353bf4a92/20UMGIM10300.rgb.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'Flowers',
      'artistName': 'Miley Cyrus',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview123/v4/0d/16/27/0d162758-c2b6-dc7c-87b6-160de6f1e84a/mzaf_638063231454592209.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music113/v4/3d/8c/ec/3d8cec72-4d22-11ef-7bf7-ee47cb5c8a4a/886444857410.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'As It Was',
      'artistName': 'Harry Styles',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview112/v4/bc/d2/df/bcd2df46-5c5f-bb46-e5ef-5c7a421b4a1b/mzaf_13596706915003328225.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/04/b8/ec/04b8ecf3-4c9f-d31e-4c74-e866fb7d30bf/190295893113.jpg/150x150bb.jpg'
    },
    {
      'trackName': 'Dynamite',
      'artistName': 'BTS',
      'previewUrl':
          'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/be/89/6e/be896e00-244e-a10c-9860-23a1059f131a/mzaf_12411993414902120042.plus.aac.p.m4a',
      'artworkUrl':
          'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/10/7c/ec/107cecf2-4c9f-d31e-4c74-e866fb7d30bf/8809634384501.jpg/150x150bb.jpg'
    }
  ];

  @override
  void initState() {
    super.initState();

    _discAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _voicePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Configure audio player to allow mixing with other audio
    _configureAudioSession();

    _initGameAndSpeech();
    _startVoiceChatSimulation();
  }

  Future<void> _configureAudioSession() async {
    try {
      // Set audio session to allow mixing with other sounds
      await _audioPlayer.setVolume(1.0);
      debugPrint('Audio session configured for mixing');
    } catch (e) {
      debugPrint('Error configuring audio session: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _buzzTimer?.cancel();
    _voiceChatSimTimer?.cancel();
    _audioPlayer.dispose();
    _discAnimationController.dispose();
    _voicePulseController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initGameAndSpeech() async {
    setState(() {
      _isLoading = true;
      _loadingProgress = 0.1;
      _loadingStatus = 'Initializing speech recognizer...';
    });

    await MessageSoundService.ensureInitialized();
    await GameSoundService.ensureInitialized();

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech Status: $status');
          if (status == 'notListening' && _isListening) {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('Speech Error: $error');
          setState(() => _isListening = false);
        },
      );
      setState(() => _speechAvailable = available);
    } catch (e) {
      debugPrint('Speech Init Failed: $e');
      setState(() => _speechAvailable = false);
    }

    setState(() {
      _loadingProgress = 0.4;
      _loadingStatus = 'Fetching current high scores...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = widget.user.username ?? "anonymous";
      _highScore = prefs.getInt('guess_song_highscore_$username') ?? 0;
    } catch (_) {}

    setState(() {
      _loadingProgress = 0.6;
      _loadingStatus = 'Fetching hits from Apple Music...';
    });

    await _loadSongsFromITunes();
  }

  void _startVoiceChatSimulation() {
    final random = math.Random();
    _voiceChatSimTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isModeSelected || _gameEnded || _isGuessingMode) return;
      setState(() {
        // Player 1 (user) speaking simulation (if unmuted)
        if (!_p1MicMuted) {
          _p1Speaking = random.nextDouble() > 0.4;
        } else {
          _p1Speaking = false;
        }

        // Player 2 (opponent) dynamic voice chat state simulation
        if (_gameMode == 2) {
          if (random.nextDouble() > 0.93) {
            _p2MicMuted = !_p2MicMuted;
            if (_p2MicMuted) _p2Speaking = false;
          }

          if (!_p2MicMuted) {
            _p2Speaking = random.nextDouble() > 0.35;
          } else {
            _p2Speaking = false;
          }
        } else {
          _p2Speaking = false;
          _p2MicMuted = true;
        }
      });
    });
  }

  Future<void> _loadSongsFromITunes() async {
    final List<String> searchTerms = [
      'taylor swift',
      'the weeknd',
      'billie eilish',
      'bruno mars',
      'katy perry',
      'dua lipa',
      'ed sheeran',
      'maroon 5',
      'justin bieber',
      'ariana grande',
      'coldplay',
      'lady gaga'
    ];

    final random = math.Random();
    final term1 = searchTerms[random.nextInt(searchTerms.length)];
    String term2 = searchTerms[random.nextInt(searchTerms.length)];
    while (term1 == term2) {
      term2 = searchTerms[random.nextInt(searchTerms.length)];
    }

    List<Map<String, dynamic>> fetchedSongs = [];

    Future<void> queryApi(String term) async {
      try {
        final url = Uri.parse(
            'https://itunes.apple.com/search?term=${Uri.encodeComponent(term)}&entity=song&limit=25');
        final response =
            await http.get(url).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List?;
          if (results != null) {
            for (var result in results) {
              final trackName = result['trackName'] as String?;
              final artistName = result['artistName'] as String?;
              final previewUrl = result['previewUrl'] as String?;
              final artworkUrl = result['artworkUrl100'] as String?;

              if (trackName != null &&
                  artistName != null &&
                  previewUrl != null &&
                  artworkUrl != null) {
                fetchedSongs.add({
                  'trackName': trackName,
                  'artistName': artistName,
                  'previewUrl': previewUrl,
                  'artworkUrl': artworkUrl.replaceAll('100x100bb', '300x300bb'),
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('iTunes search failed for term $term: $e');
      }
    }

    await queryApi(term1);

    if (mounted) {
      setState(() {
        _loadingProgress = 0.8;
        _loadingStatus = 'Curating playlist...';
      });
    }

    await queryApi(term2);

    if (fetchedSongs.length < 5) {
      fetchedSongs.addAll(_fallbackSongs);
    }

    fetchedSongs.shuffle(random);

    final Set<String> seenTracks = {};
    _playlist = [];
    for (var song in fetchedSongs) {
      final nameLower = song['trackName'].toString().toLowerCase();
      if (!seenTracks.contains(nameLower)) {
        seenTracks.add(nameLower);
        _playlist.add(song);
      }
      if (_playlist.length >= 5) break;
    }

    if (_playlist.length < 5) {
      for (var song in _fallbackSongs) {
        final nameLower = song['trackName'].toString().toLowerCase();
        if (!seenTracks.contains(nameLower)) {
          seenTracks.add(nameLower);
          _playlist.add(song);
        }
        if (_playlist.length >= 5) break;
      }
    }

    while (_playlist.length < 5) {
      _playlist.add(_fallbackSongs[random.nextInt(_fallbackSongs.length)]);
    }

    _playlist = _playlist.sublist(0, 5);

    if (mounted) {
      setState(() {
        _loadingProgress = 1.0;
        _loadingStatus = 'Ready!';
        _isLoading = false;
      });
    }
  }

  void _selectGameMode(int mode) {
    setState(() {
      _gameMode = mode;
      _isModeSelected = true;
      _p1Score = 0;
      _p2Score = 0;
      _score = 0;
      _p2MicMuted = (mode == 1);
    });
    _startRound(0);
  }

  Future<void> _startRound(int roundIndex) async {
    _countdownTimer?.cancel();
    _buzzTimer?.cancel();

    if (roundIndex >= 5) {
      _finishGame();
      return;
    }

    setState(() {
      _currentRound = roundIndex;
      _currentSong = _playlist[roundIndex];
      _secondsRemaining = _roundDurationSeconds;
      _hasGuessed = false;
      _isGuessingMode = false;
      _guessResult = false;
      _isPlaying = false;
      _speechTranscription = "";
      _p1LockedOut = false;
      _p2LockedOut = false;
      _activeGuesser = null;
      _pendingGuessTapPlayer = null;
      _textController.clear();
    });

    _discAnimationController.reset();

    try {
      final globalPlayer = context.read<GlobalAudioPlayerService>();
      if (globalPlayer.playing) {
        await globalPlayer.setPlaying(false);
      }
    } catch (e) {
      debugPrint('Could not pause global background music: $e');
    }

    try {
      await _audioPlayer.stop();
      final previewUrl = _currentSong!['previewUrl'] as String;

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(previewUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
            'Accept': '*/*',
          },
          tag: MediaItem(
            id: 'guess_song_${_currentRound}_${DateTime.now().millisecondsSinceEpoch}',
            album: 'Kats Song Guesser',
            title: 'Mystery Song',
            artist: 'Who is singing?',
            artUri: Uri.parse(_currentSong!['artworkUrl'] as String),
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
        _discAnimationController.repeat();
        _startTimer();
      }

      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio track: $e');
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
        _startTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Audio stream loading failed: $e. Continuing round...'),
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFFFF5E3A),
          ),
        );
      }
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          _isPlaying = false;
          _audioPlayer.pause();
          _discAnimationController.stop();
          if (!_hasGuessed) {
            _handleTimeOut();
          }
        }
      });
    });
  }

  void _handleTimeOut() {
    GameSoundService.playTimeout();
    setState(() {
      _hasGuessed = true;
      _guessResult = false;
    });
  }

  bool _isPlayerLockedOut(int player) {
    return _gameMode == 2 &&
        ((player == 1 && _p1LockedOut) || (player == 2 && _p2LockedOut));
  }

  int _nextBuzzerPlayer() {
    if (_gameMode == 1) {
      return 1;
    }
    if (_p1LockedOut && !_p2LockedOut) {
      return 2;
    }
    if (_p2LockedOut && !_p1LockedOut) {
      return 1;
    }
    return _pendingGuessTapPlayer ?? 1;
  }

  bool get _canUseGuessButton {
    return _isPlaying &&
        !_hasGuessed &&
        !_isGuessingMode &&
        (_gameMode == 1 || !(_p1LockedOut && _p2LockedOut));
  }

  Future<void> _beginBuzzForPlayer(int player) async {
    await _audioPlayer.pause();
    _countdownTimer?.cancel();
    _discAnimationController.stop();

    MessageSoundService.playOutgoing();

    setState(() {
      _isPlaying = false;
    });
    _selectActiveGuesser(player);
  }

  void _buzz() async {
    if (!_canUseGuessButton) {
      return;
    }

    final player = _nextBuzzerPlayer();
    _pendingGuessTapPlayer = null;
    await _beginBuzzForPlayer(player);
  }

  void _selectActiveGuesser(int player) {
    // Save current mic states
    _savedP1MicMuted = _p1MicMuted;
    _savedP2MicMuted = _p2MicMuted;

    setState(() {
      _activeGuesser = player;
      _isGuessingMode = true;

      // Auto Mute the non-guessing player & Unmute the guesser
      if (player == 1) {
        _p1MicMuted = false;
        _p1Speaking = true;
        _p2MicMuted = true;
        _p2Speaking = false;
      } else {
        _p2MicMuted = false;
        _p2Speaking = true;
        _p1MicMuted = true;
        _p1Speaking = false;
      }

      _buzzSecondsRemaining = 7;
      _speechTranscription = "";
      _textController.clear();
    });
    _startBuzzTimer();
    _startSpeechListening();
  }

  void _startBuzzTimer() {
    _buzzTimer?.cancel();
    _buzzTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_buzzSecondsRemaining > 0) {
          _buzzSecondsRemaining--;
        } else {
          _submitGuess();
        }
      });
    });
  }

  void _startSpeechListening() async {
    if (!_speechAvailable) {
      try {
        final available = await _speech.initialize();
        setState(() => _speechAvailable = available);
      } catch (_) {}
    }

    if (_speechAvailable && mounted) {
      setState(() {
        _isListening = true;
      });

      try {
        await _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _speechTranscription = result.recognizedWords;
              _textController.text = _speechTranscription;
            });
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 7),
            pauseFor: const Duration(seconds: 2),
            partialResults: true,
          ),
        );
      } catch (e) {
        debugPrint('Listen error: $e');
        if (mounted) setState(() => _isListening = false);
      }
    }
  }

  void _stopSpeechListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _submitGuess() {
    _buzzTimer?.cancel();
    _stopSpeechListening();

    final userGuess = _textController.text.trim();
    final songTitle = _currentSong!['trackName'] as String;
    final songArtist = _currentSong!['artistName'] as String;

    final isCorrect = _checkGuess(userGuess, songTitle, songArtist);

    // Restore saved mic mute states
    setState(() {
      _p1MicMuted = _savedP1MicMuted;
      _p2MicMuted = _savedP2MicMuted;
      _p1Speaking = false;
      _p2Speaking = false;
    });

    if (isCorrect) {
      GameSoundService.playCorrect();

      int pointsEarned = 100 + (_secondsRemaining * 10);
      if (_gameMode == 1) {
        _score += pointsEarned;
      } else {
        if (_activeGuesser == 1) {
          _p1Score += pointsEarned;
        } else {
          _p2Score += pointsEarned;
        }
      }

      setState(() {
        _isGuessingMode = false;
        _hasGuessed = true;
        _guessResult = true;
        _isPlaying = true;
        _activeGuesser = null;
      });

      _audioPlayer.play();
      _discAnimationController.repeat();
      _startTimer();
    } else {
      GameSoundService.playWrong();

      if (_gameMode == 2) {
        if (_activeGuesser == 1) {
          _p1LockedOut = true;
        } else {
          _p2LockedOut = true;
        }

        if (_p1LockedOut && _p2LockedOut) {
          setState(() {
            _isGuessingMode = false;
            _hasGuessed = true;
            _guessResult = false;
            _isPlaying = true;
            _activeGuesser = null;
          });
          _audioPlayer.play();
          _discAnimationController.repeat();
          _startTimer();
        } else {
          setState(() {
            _isGuessingMode = false;
            _isPlaying = true;
            _activeGuesser = null;
          });
          _audioPlayer.play();
          _discAnimationController.repeat();
          _startTimer();
        }
      } else {
        setState(() {
          _isGuessingMode = false;
          _hasGuessed = true;
          _guessResult = false;
          _isPlaying = true;
          _activeGuesser = null;
        });

        _audioPlayer.play();
        _discAnimationController.repeat();
        _startTimer();
      }
    }
  }

  bool _checkGuess(String guess, String title, String artist) {
    String clean(String s) {
      s = s.toLowerCase();
      s = s.replaceAll(RegExp(r'\(.*?\)'), '');
      s = s.replaceAll(RegExp(r'\[.*?\]'), '');
      s = s.split('-')[0];
      s = s.replaceAll(RegExp(r"[^a-z0-9\s]"), '');
      s = s.replaceAll(RegExp(r'\s+'), ' ');
      return s.trim();
    }

    final cleanGuess = clean(guess);
    final cleanTitle = clean(title);
    final cleanArtist = clean(artist);

    if (cleanGuess.isEmpty) return false;
    if (cleanGuess == cleanTitle || cleanGuess == cleanArtist) return true;
    if (cleanTitle.contains(cleanGuess) && cleanGuess.length >= 3) return true;
    if (cleanGuess.contains(cleanTitle) && cleanTitle.length >= 3) return true;

    final guessWords =
        cleanGuess.split(' ').where((w) => w.length > 2).toList();
    final titleWords =
        cleanTitle.split(' ').where((w) => w.length > 2).toList();

    if (guessWords.isNotEmpty && titleWords.isNotEmpty) {
      int matchCount = 0;
      for (var word in guessWords) {
        if (titleWords.contains(word)) {
          matchCount++;
        }
      }
      if (matchCount / titleWords.length >= 0.6) return true;
    }

    return false;
  }

  void _toggleMic(int playerNumber) {
    if (_isGuessingMode) {
      return; // Disable manual mute override during active guessing
    }
    setState(() {
      if (playerNumber == 1) {
        _p1MicMuted = !_p1MicMuted;
        if (_p1MicMuted) _p1Speaking = false;
      } else {
        _p2MicMuted = !_p2MicMuted;
        if (_p2MicMuted) _p2Speaking = false;
      }
    });
    MessageSoundService.playOutgoing();
  }

  void _finishGame() async {
    _countdownTimer?.cancel();
    _buzzTimer?.cancel();
    await _audioPlayer.stop();

    if (_gameMode == 1) {
      final isNewHighScore = _score > _highScore;
      if (isNewHighScore) {
        _highScore = _score;
        try {
          final prefs = await SharedPreferences.getInstance();
          final username = widget.user.username ?? "anonymous";
          await prefs.setInt('guess_song_highscore_$username', _score);
        } catch (_) {}
      }
    }

    GameSoundService.playResults();

    setState(() {
      _gameEnded = true;
    });
  }

  void _resetGame() {
    setState(() {
      _isLoading = true;
      _gameEnded = false;
      _isModeSelected = false;
      _score = 0;
      _p1Score = 0;
      _p2Score = 0;
      _currentRound = 0;
      _playlist = [];
    });
    _loadSongsFromITunes();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (!_isModeSelected) {
      return _buildModeSelectionScreen();
    }

    if (_gameEnded) {
      return _buildGameOverScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Background Gradient Mesh
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B0B2E), Color(0xFF0F0E17)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Outer UI
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              children: [
                _buildScoreHeader(),

                const Spacer(flex: 1),

                // Visualizer Core with Flanking Voice Chat Seats
                _buildVisualizerAndSeatsRow(),

                const Spacer(flex: 1),

                if (_isPlaying) _buildAudioVisualizerWaves(),

                const SizedBox(height: 24),

                _buildActionArea(),

                const Spacer(flex: 2),
              ],
            ),
          ),

          if (_isGuessingMode) _buildGuessingOverlay(),
        ],
      ),
    );
  }

  // Loading View
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D1B26), Color(0xFF0F0E17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD400FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFD400FF).withValues(alpha: 0.3),
                        width: 2),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Color(0xFFD400FF),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'Kats Song Guesser',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadingStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loadingProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD400FF), Color(0xFF00D1FF)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
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

  // Mode Selection Screen
  Widget _buildModeSelectionScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B0B2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Select Mode',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B0B2E), Color(0xFF0F0E17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFFD400FF),
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'KATS SONG GUESSER',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your game mode to start playing!',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              _buildModeButton(
                title: 'Solo Challenge',
                description:
                    'Play alone, beat your own record, and climb the scoreboard!',
                icon: Icons.person_rounded,
                color: const Color(0xFF00D1FF),
                onTap: () => _selectGameMode(1),
              ),
              const SizedBox(height: 24),
              _buildModeButton(
                title: '2-Player Duel',
                description:
                    'One shared buzzer! Buzz first to guess, or steal if the opponent gets it wrong!',
                icon: Icons.people_rounded,
                color: const Color(0xFFFF5E3A),
                onTap: () => _selectGameMode(2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 16,
              spreadRadius: 1,
            )
          ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1B0B2E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _gameMode == 1 ? 'Song Guesser: Solo' : 'Song Guesser: PvP Duel',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        if (_gameMode == 1)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Best: $_highScore',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget _buildScoreHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1435),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFD400FF).withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD400FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Round ${_currentRound + 1}/5',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFFE040FB),
              ),
            ),
          ),
          if (_gameMode == 1)
            Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFFFCC00), size: 20),
                const SizedBox(width: 4),
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  'P1: $_p1Score',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFFFF5E3A),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'vs',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'P2: $_p2Score',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF00D1FF),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMusicPlayerCore() {
    final showAnswer = _hasGuessed || _secondsRemaining == 0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: _secondsRemaining / _roundDurationSeconds,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _secondsRemaining <= 10
                        ? const Color(0xFFFF5E3A)
                        : const Color(0xFFD400FF),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _discAnimationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _discAnimationController.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: showAnswer
                    ? _buildAlbumArtworkCover()
                    : _buildVinylRecordPlaceholder(),
              ),
              if (!showAnswer)
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_secondsRemaining}s',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _secondsRemaining <= 10
                            ? const Color(0xFFFF5E3A)
                            : Colors.white,
                      ),
                    ),
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVinylRecordPlaceholder() {
    return Container(
      width: 146,
      height: 146,
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD400FF).withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 1,
          )
        ],
      ),
      child: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFD400FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF0F0E17), width: 6),
          ),
          child: const Center(
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArtworkCover() {
    final artworkUrl = _currentSong?['artworkUrl'] as String? ?? '';

    return Container(
      width: 146,
      height: 146,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              _guessResult ? const Color(0xFF2ECC71) : const Color(0xFFFF5E3A),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: (_guessResult
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFFFF5E3A))
                .withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(73),
        child: CachedNetworkImage(
          imageUrl: artworkUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFF1E1D2C),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF1E1D2C),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildSongMetadataReveal() {
    final trackName = _currentSong?['trackName'] as String? ?? '';
    final artistName = _currentSong?['artistName'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _guessResult
              ? const Color(0xFF2ECC71).withValues(alpha: 0.3)
              : const Color(0xFFFF5E3A).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _guessResult
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
                  : const Color(0xFFFF5E3A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _guessResult ? 'ANSWER CORRECT!' : 'INCORRECT / TIME\'S UP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: _guessResult
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFFFF5E3A),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trackName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            artistName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF8A00),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioVisualizerWaves() {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(15, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            width: 4,
            height: math.max(
                6.0,
                (math.sin(DateTime.now().millisecondsSinceEpoch / 150.0 +
                            index) +
                        1.2) *
                    10.0),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD400FF),
                  const Color(0xFFD400FF).withValues(alpha: 0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          );
        }),
      ),
    );
  }

  void _rememberGuessTapSide(TapDownDetails details) {
    if (_gameMode != 2 || _p1LockedOut || _p2LockedOut) {
      return;
    }
    _pendingGuessTapPlayer = details.localPosition.dx < 55 ? 1 : 2;
  }

  Widget _buildActionArea() {
    if (_hasGuessed || _secondsRemaining == 0) {
      final isLastRound = _currentRound >= 4;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSongMetadataReveal(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _startRound(_currentRound + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD400FF),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFFD400FF).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastRound ? 'See Results' : 'Next Song',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final bool p1Disabled = _gameMode == 2 && _p1LockedOut;
    final bool p2Disabled = _gameMode == 2 && _p2LockedOut;
    final bool isGuessDisabled = !_canUseGuessButton;
    final String actionHint = _gameMode == 2
        ? (p1Disabled || p2Disabled)
            ? 'Steal chance: ${p1Disabled ? 'Player 2' : 'Player 1'} can still guess!'
            : '⚡ RACE TO PRESS! First to tap wins the mic! ⚡'
        : 'Tap GUESS as soon as the music plays!';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'WHO IS SINGING?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          actionHint,
          style: TextStyle(
            fontSize: 11,
            color: _gameMode == 2 && !p1Disabled && !p2Disabled
                ? const Color(0xFFFFD700)
                : const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (_gameMode == 2 && !p1Disabled && !p2Disabled)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5E3A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFF5E3A).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'P1 LEFT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF5E3A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.compare_arrows_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D1FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00D1FF).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'P2 RIGHT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00D1FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        GestureDetector(
          onTapDown: isGuessDisabled ? null : _rememberGuessTapSide,
          onTap: isGuessDisabled ? null : _buzz,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: isGuessDisabled
                  ? const Color(0xFF2E2B3C)
                  : const Color(0xFFFF0055),
              shape: BoxShape.circle,
              boxShadow: [
                if (!isGuessDisabled)
                  BoxShadow(
                    color: const Color(0xFFFF0055).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                  )
              ],
              border: Border.all(
                color: isGuessDisabled
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.2),
                width: 3.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flash_on_rounded,
                    color: isGuessDisabled
                        ? const Color(0xFF5A5868)
                        : Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'GUESS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isGuessDisabled
                          ? const Color(0xFF5A5868)
                          : Colors.white,
                    ),
                  ),
                  if (_gameMode == 2 && (p1Disabled || p2Disabled))
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        p1Disabled ? 'P2 MIC' : 'P1 MIC',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _playerAvatarUrl(int playerNumber) {
    if (playerNumber == 1) {
      return widget.user.avatarUrl ??
          'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=150&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=150&auto=format&fit=crop';
  }

  String _playerDisplayName(int playerNumber) {
    if (playerNumber == 1) {
      return widget.user.username ?? 'Player 1';
    }
    return 'KatFriend';
  }

  Widget _buildActiveGuesserAvatarButton(Color activeColor) {
    final playerNumber = _activeGuesser ?? 1;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color:
                    activeColor.withValues(alpha: _isListening ? 0.45 : 0.25),
                blurRadius: _isListening ? 32 : 18,
                spreadRadius: _isListening ? 8 : 2,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: _playerAvatarUrl(playerNumber),
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: const Color(0xFF1E1B2E)),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.person, color: Colors.white30),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isListening ? const Color(0xFF2ECC71) : activeColor,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0F0E17), width: 2),
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuessingOverlay() {
    final activeColor = _gameMode == 1
        ? const Color(0xFFD400FF)
        : (_activeGuesser == 1
            ? const Color(0xFFFF5E3A)
            : const Color(0xFF00D1FF));

    final headerText = _gameMode == 1
        ? 'BUZZER TRIGGERED!'
        : 'BUZZER: PLAYER $_activeGuesser!';

    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    headerText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: activeColor,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_buzzSecondsRemaining}s',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: activeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 1),
              GestureDetector(
                onTap: () {
                  if (_isListening) {
                    _stopSpeechListening();
                  } else {
                    _startSpeechListening();
                  }
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isListening ? activeColor : const Color(0xFF1E1A3C),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isListening)
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 8,
                        )
                    ],
                    border: Border.all(
                      color: _isListening
                          ? Colors.white
                          : activeColor.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: _buildActiveGuesserAvatarButton(activeColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isListening
                    ? '${_playerDisplayName(_activeGuesser ?? 1)} is guessing...'
                    : 'Tap ${_playerDisplayName(_activeGuesser ?? 1)} avatar to speak',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isListening ? activeColor : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B0B2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: activeColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(
                  children: [
                    if (_speechTranscription.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          '"$_speechTranscription"',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your song or artist guess...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitGuess(),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _buzzTimer?.cancel();
                        _stopSpeechListening();

                        // Restore mute states upon cancel/give up
                        setState(() {
                          _p1MicMuted = _savedP1MicMuted;
                          _p2MicMuted = _savedP2MicMuted;
                          _p1Speaking = false;
                          _p2Speaking = false;
                        });

                        if (_gameMode == 2) {
                          if (_activeGuesser == 1) {
                            _p1LockedOut = true;
                          } else {
                            _p2LockedOut = true;
                          }

                          if (_p1LockedOut && _p2LockedOut) {
                            setState(() {
                              _isGuessingMode = false;
                              _hasGuessed = true;
                              _guessResult = false;
                              _isPlaying = true;
                              _activeGuesser = null;
                            });
                            _audioPlayer.play();
                            _discAnimationController.repeat();
                            _startTimer();
                          } else {
                            setState(() {
                              _isGuessingMode = false;
                              _isPlaying = true;
                              _activeGuesser = null;
                            });
                            _audioPlayer.play();
                            _discAnimationController.repeat();
                            _startTimer();
                          }
                        } else {
                          setState(() {
                            _isGuessingMode = false;
                            _isPlaying = true;
                            _startTimer();
                            _audioPlayer.play();
                            _discAnimationController.repeat();
                            _activeGuesser = null;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF9CA3AF), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text(
                        'Give Up',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitGuess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text(
                        'Submit Guess',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Game over report screen
  Widget _buildGameOverScreen() {
    final winScore = _score;
    final isNewRecord = winScore > _highScore;

    final p1Win = _p1Score > _p2Score;
    final tie = _p1Score == _p2Score;
    final winningColor = tie
        ? const Color(0xFFD400FF)
        : (p1Win ? const Color(0xFFFF5E3A) : const Color(0xFF00D1FF));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B0B2E), Color(0xFF0F0E17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: winningColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: winningColor.withValues(alpha: 0.3), width: 3),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: winningColor,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _gameMode == 1 ? 'GAME COMPLETED!' : 'DUEL FINISHED!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                if (_gameMode == 1)
                  Text(
                    isNewRecord
                        ? '🎉 AMAZING! NEW HIGH SCORE! 🎉'
                        : 'Well played! Try again to beat your record.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2ECC71),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    tie
                        ? '🤝 IT\'S A TIE SCORE DUEL! 🤝'
                        : (p1Win
                            ? '🥇 PLAYER 1 VICTORY! 🏆'
                            : '🥇 PLAYER 2 VICTORY! 🏆'),
                    style: TextStyle(
                      fontSize: 14,
                      color: winningColor,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const Spacer(flex: 1),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1435),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: winningColor.withValues(alpha: 0.15), width: 2),
                  ),
                  child: _gameMode == 1
                      ? Column(
                          children: [
                            const Text(
                              'YOUR FINAL SCORE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF9CA3AF),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$winScore',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const Divider(
                                color: Colors.white10,
                                height: 24,
                                thickness: 1.5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Personal Best',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${math.max(_highScore, winScore)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFFD700),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Accuracy',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(_score / 800 * 100).clamp(0, 100).toInt()}%',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF00D1FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          ],
                        )
                      : Column(
                          children: [
                            const Text(
                              'FINAL SCORES',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF9CA3AF),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Player 1 (Orange)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFFF5E3A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$_p1Score',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 40,
                                  width: 1.5,
                                  color: Colors.white10,
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Player 2 (Cyan)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00D1FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$_p2Score',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const Spacer(flex: 2),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: winningColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(0, 52),
                        ),
                        child: Text(
                          'Arcade Lobby',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: winningColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: winningColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(0, 52),
                        ),
                        child: const Text(
                          'Play Again',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Visualizer and side-seats alignment row
  Widget _buildVisualizerAndSeatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Left Seat: Player 1
        Expanded(child: _buildVoiceChatSeat(playerNumber: 1)),

        // Visualizer Stack (Center)
        _buildMusicPlayerCore(),

        // Right Seat: Player 2
        Expanded(child: _buildVoiceChatSeat(playerNumber: 2)),
      ],
    );
  }

  // Voice Chat Seat Widget with pulsed speaking animations
  Widget _buildVoiceChatSeat({required int playerNumber}) {
    final bool isSoloP2 = _gameMode == 1 && playerNumber == 2;
    if (isSoloP2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            ),
            child: const Icon(Icons.person_add_disabled_rounded,
                color: Colors.white30, size: 22),
          ),
          const SizedBox(height: 8),
          const Text(
            'Empty Seat',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white30,
            ),
          ),
        ],
      );
    }

    final bool isMuted = playerNumber == 1 ? _p1MicMuted : _p2MicMuted;
    final bool isSpeaking = playerNumber == 1 ? _p1Speaking : _p2Speaking;
    final bool isLockedOut = _isPlayerLockedOut(playerNumber);
    final bool isStealTurn = _gameMode == 2 && (_p1LockedOut || _p2LockedOut);
    final bool isNextMic = isStealTurn &&
        _canUseGuessButton &&
        _nextBuzzerPlayer() == playerNumber;

    // Check if this player is the active guesser
    final bool isGuesser = _isGuessingMode && _activeGuesser == playerNumber;

    // Animate size of avatar: 76 when guessing, otherwise 56
    final double avatarSize = isGuesser ? 76.0 : 56.0;

    final Color playerColor =
        playerNumber == 1 ? const Color(0xFFFF5E3A) : const Color(0xFF00D1FF);

    final String avatarUrl = playerNumber == 1
        ? (widget.user.avatarUrl ??
            'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=150&auto=format&fit=crop')
        : 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=150&auto=format&fit=crop';

    final String name =
        playerNumber == 1 ? (widget.user.username ?? 'Player 1') : 'KatFriend';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _gameMode == 2 ? null : () => _toggleMic(playerNumber),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring 1 (active speaking visual waves)
              if (!isMuted && isSpeaking)
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.6).animate(
                    CurvedAnimation(
                        parent: _voicePulseController, curve: Curves.easeOut),
                  ),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: playerColor.withValues(
                            alpha: (1.0 - _voicePulseController.value) * 0.4),
                        width: isGuesser ? 3.5 : 2.5,
                      ),
                    ),
                  ),
                ),

              // Pulse ring 2
              if (!isMuted && isSpeaking)
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                    CurvedAnimation(
                      parent: _voicePulseController,
                      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                    ),
                  ),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: playerColor.withValues(
                            alpha: (1.0 - _voicePulseController.value) * 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                ),

              // Avatar Circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMuted
                        ? Colors.white24
                        : (isSpeaking
                            ? playerColor
                            : playerColor.withValues(alpha: 0.4)),
                    width: isGuesser ? 3.5 : 2.5,
                  ),
                  boxShadow: [
                    if (!isMuted && isSpeaking)
                      BoxShadow(
                        color: playerColor.withValues(alpha: 0.3),
                        blurRadius: isGuesser ? 20 : 12,
                        spreadRadius: isGuesser ? 3 : 1,
                      )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFF1E1B2E)),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person, color: Colors.white30),
                  ),
                ),
              ),

              // Mute indicator badge overlay
              Positioned(
                bottom: isGuesser ? 3 : 0,
                right: isGuesser ? 3 : 0,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: isMuted
                        ? const Color(0xFFFF0055)
                        : const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0F0E17), width: 1.5),
                  ),
                  child: Icon(
                    isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: isGuesser ? 12 : 10,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Seat user details
        Text(
          name,
          style: TextStyle(
            fontSize: isGuesser ? 11 : 10,
            fontWeight: FontWeight.w800,
            color: isMuted
                ? Colors.white30
                : (isGuesser ? playerColor : Colors.white70),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        Text(
          isGuesser
              ? 'MIC ON'
              : isLockedOut
                  ? 'Locked'
                  : isNextMic
                      ? 'Ready'
                      : (isMuted
                          ? 'Muted'
                          : (isSpeaking ? 'Speaking...' : 'Joined')),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: isGuesser
                ? const Color(0xFFFFD700)
                : isLockedOut
                    ? const Color(0xFFFF0055)
                    : isNextMic
                        ? playerColor
                        : (isMuted
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isSpeaking ? playerColor : Colors.white38)),
          ),
        ),
      ],
    );
  }
}
