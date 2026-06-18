import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_config.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezones and notifications
  tz.initializeTimeZones();
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize Firebase if enabled
  if (FirebaseConfig.useFirebase) {
    await Firebase.initializeApp(
      options: FirebaseConfig.androidOptions,
    );
  }

  final authService = AuthService();
  await authService.checkSavedSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'MTC Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E3A8A),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.green,
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 2,
        ),
        useMaterial3: true,
      ),
      home: authService.isLoggedIn
          ? const DashboardScreen()
          : const LoginScreen(),
    );
  }
}
