import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final Map<String, dynamic>? initialUser;

  @override
  State<KatsKlubApp> createState() => _KatsKlubAppState();
}

class _KatsKlubAppState extends State<KatsKlubApp> {
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
  }

  void _handleLogin(Map<String, dynamic> user) {
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
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: _currentUser == null
          ? LoginScreen(
              authService: widget.authService,
              onLoginSuccess: _handleLogin,
            )
          : HomeScreen(
              user: _currentUser!,
              onLogout: _handleLogout,
            ),
    );
  }
}
