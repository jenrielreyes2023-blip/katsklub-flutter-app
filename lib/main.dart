import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'http_overrides_stub.dart' if (dart.library.io) 'http_overrides.dart';
import 'models/user.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'screens/youtube_search_screen.dart';
import 'screens/youtube_player_screen.dart';
import 'services/auth_service.dart';
import 'services/conversation_theme.dart';
import 'services/feed_service.dart';
import 'services/global_audio_player_service.dart';
import 'utils/update_checker.dart';
import 'providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/user_avatar_with_frame.dart';

void _configureImageCache() {
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      256 * 1024 * 1024; // 256MB
}

void _disableDebugPaintOverlays() {
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;
}

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _disableDebugPaintOverlays();
  if (!kIsWeb) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.katsklub.app.channel.audio',
        androidNotificationChannelName: 'KatsKlub Audio Playback',
        androidNotificationOngoing: true,
      );
    } catch (_) {}
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  _configureImageCache();
  configureHttpOverrides();
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedFrame = prefs.getString('admin_equipped_frame');
    if (savedFrame != null && savedFrame.isNotEmpty) {
      equippedAdminFrameNotifier.value = savedFrame;
    }
  } catch (_) {}
  final authService = AuthService();
  User? currentUser;
  try {
    currentUser = await authService.getCurrentUser();
  } catch (e) {
    debugPrint('Error getting current user on launch: $e');
  }

  runApp(
    KatsKlubApp(
      authService: authService,
      initialUser: currentUser,
    ),
  );
}

class KatsKlubApp extends StatefulWidget {
  const KatsKlubApp({
    required this.authService,
    required this.initialUser,
    super.key,
  });

  final AuthService authService;
  final User? initialUser;

  @override
  State<KatsKlubApp> createState() => _KatsKlubAppState();
}

class _KatsKlubAppState extends State<KatsKlubApp> {
  final GlobalAudioPlayerService _audioPlayerService =
      GlobalAudioPlayerService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates();
    });
  }

  Future<void> _handleLogin(User user) async {
    await FeedService.ensureRealtimeSync();
    if (!mounted) return;

    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _handleLogout() async {
    await widget.authService.logout();
    await ConversationThemeStore.clear();
    await FeedService.resetRealtimeSync();
    if (!mounted) return;

    setState(() {
      _currentUser = null;
    });
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GlobalAudioPlayerService>.value(
          value: _audioPlayerService,
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ScreenUtilInit(
            designSize: const Size(360, 690),
            minTextAdapt: true,
            splitScreenMode: true,
            fontSizeResolver: (fontSize, instance) {
              final scale = instance.scaleWidth <= 0 ? 1.0 : instance.scaleWidth;
              final scaled = fontSize * scale;
              return scaled <= 0 ? fontSize.toDouble() : scaled.toDouble();
            },
            builder: (context, child) {
              return MaterialApp(
                navigatorKey: UpdateChecker.navigatorKey,
                title: 'KatsKlub',
                debugShowCheckedModeBanner: false,
                themeMode: themeProvider.themeMode,
                theme: ThemeData(
                  useMaterial3: true,
                  fontFamily: 'SF Pro Rounded',
                  fontFamilyFallback: const [
                    'Apple Color Emoji',
                    'Noto Color Emoji',
                    'Segoe UI Emoji',
                    'EmojiOne Color',
                  ],
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFFFF7A59),
                    primary: const Color(0xFFFF7A59),
                    secondary: const Color(0xFF111827),
                    surface: Colors.white,
                    onSurface: const Color(0xFF1C1E21),
                    brightness: Brightness.light,
                  ),
                  scaffoldBackgroundColor: Colors.white,
                  dialogTheme: const DialogThemeData(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    titleTextStyle: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                    contentTextStyle: TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  cardTheme: const CardThemeData(
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                  ),
                  bottomSheetTheme: const BottomSheetThemeData(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                  ),
                  textTheme: const TextTheme(
                    bodyLarge: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    bodyMedium: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    bodySmall: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    titleLarge: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    titleMedium: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    labelLarge: TextStyle(
                      color: Color(0xFF1C1E21),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.white,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                      systemNavigationBarColor: Colors.white,
                      systemNavigationBarIconBrightness: Brightness.dark,
                    ),
                  ),
                  snackBarTheme: const SnackBarThemeData(
                    behavior: SnackBarBehavior.fixed,
                    backgroundColor: Color(0xFF111827),
                    contentTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  fontFamily: 'SF Pro Rounded',
                  fontFamilyFallback: const [
                    'Apple Color Emoji',
                    'Noto Color Emoji',
                    'Segoe UI Emoji',
                    'EmojiOne Color',
                  ],
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFFFF7A59),
                    primary: const Color(0xFFFF7A59),
                    secondary: const Color(0xFFE5E7EB),
                    surface: const Color(0xFF18191A),
                    onSurface: Colors.white,
                    brightness: Brightness.dark,
                  ),
                  scaffoldBackgroundColor: const Color(0xFF18191A),
                  dialogTheme: const DialogThemeData(
                    backgroundColor: Color(0xFF242526),
                    surfaceTintColor: Colors.transparent,
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                    contentTextStyle: TextStyle(
                      color: Color(0xFFB0B3B8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  cardTheme: const CardThemeData(
                    color: Color(0xFF242526),
                    surfaceTintColor: Colors.transparent,
                  ),
                  bottomSheetTheme: const BottomSheetThemeData(
                    backgroundColor: Color(0xFF242526),
                    surfaceTintColor: Colors.transparent,
                  ),
                  textTheme: const TextTheme(
                    bodyLarge: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    bodyMedium: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    bodySmall: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    titleLarge: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    titleMedium: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    labelLarge: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF18191A),
                    foregroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Color(0xFF18191A),
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                      systemNavigationBarColor: Color(0xFF18191A),
                      systemNavigationBarIconBrightness: Brightness.light,
                    ),
                  ),
                  snackBarTheme: const SnackBarThemeData(
                    behavior: SnackBarBehavior.fixed,
                    backgroundColor: Color(0xFF1F2937),
                    contentTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                builder: (context, widget) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.3),
                      ),
                    ),
                    child: widget!,
                  );
                },
                routes: {
                  '/youtube': (context) => const YouTubeSearchScreen(),
                  '/youtube/search': (context) => const YouTubeSearchScreen(),
                },
                onGenerateRoute: (settings) {
                  if (settings.name == '/youtube/player') {
                    final args = settings.arguments as Map<String, dynamic>?;
                    return MaterialPageRoute(
                      builder: (_) => YouTubePlayerScreen(
                        videoId: args?['videoId'] ?? '',
                        title: args?['title'],
                        author: args?['author'],
                        thumbnail: args?['thumbnail'],
                        streamUrl: args?['streamUrl'],
                      ),
                    );
                  }
                  return null;
                },
                home: child,
              );
            },
            child: _currentUser == null
                ? LoginScreen(
                    authService: widget.authService,
                    onLoginSuccess: (user) {
                      _handleLogin(user);
                    },
                  )
                : AppShell(
                    user: _currentUser!,
                    onLogout: _handleLogout,
                  ),
          );
        },
      ),
    );
  }
}
