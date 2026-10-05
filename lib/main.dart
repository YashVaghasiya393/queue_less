import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'Staff/StaffMainScreen.dart';
import 'firebase_options.dart';

import 'BusinessAdmin/AdminLoginScreen.dart';
import 'BusinessAdmin/AdminDashboard.dart'; // Your dashboard file

import 'CustomerHomeScreen.dart';
import 'SplashScreen.dart';
import 'LoginScreen.dart';
import 'SignUpScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const QueueLessApp());
}

class QueueLessApp extends StatelessWidget {
  const QueueLessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Browser: Admin/Staff web login
      // Phone: Customer mobile app
      home: kIsWeb ? const AuthScreen() : const SplashScreen(),

      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),

        // Admin login opens this page.
        '/adminDashboard': (context) => const DashboardScreen(),

        '/staffDashboard': (context) => const StaffMainScreen(),
      },
    );
  }
}