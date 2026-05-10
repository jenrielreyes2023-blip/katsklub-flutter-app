import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'http_overrides_stub.dart' if (dart.library.io) 'http_overrides.dart';
import 'models/user.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.white,
    ),
  );
  configureHttpOverrides();
  final authService = AuthService();
  final currentUser = await authService.getCurrentUser();

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
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
  }

  void _handleLogin(User user) {
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _handleLogout() async {
    await widget.authService.logout();
    if (!mounted) return;

    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KatsKlub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      home: _currentUser == null
          ? LoginScreen(
              authService: widget.authService,
              onLoginSuccess: _handleLogin,
            )
          : AppShell(
              user: _currentUser!,
              onLogout: _handleLogout,
            ),
    );
  }
}
