import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: .75, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is already logged in on this device! Skip login completely.
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;
        if (doc.exists) {
          final role = doc.data()?['role']?.toString().toLowerCase();
          if (role == 'admin') {
            Navigator.pushReplacementNamed(context, '/adminDashboard');
            return;
          } else if (role == 'staff') {
            Navigator.pushReplacementNamed(context, '/staffDashboard');
            return;
          }
        }
      } catch (e) {
        debugPrint('Persistent auth check error: $e');
      }

      // Default to customer Home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Not logged in -> Show login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF202D4C), Color(0xFF0A0F1E), Color(0xFF060810)],
              ),
            ),
          ),

          // Decorative blurred light circles.
          Positioned(
            top: -100,
            right: -100,
            child: _glow(const Color(0x33F5A623), 280),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: _glow(const Color(0x225078FF), 300),
          ),

          // This Center keeps the logo and text in the true screen center.
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFD375), Color(0xFFF5A623)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF5A623).withOpacity(.38),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.confirmation_number_rounded,
                          size: 46,
                          color: Color(0xFF1A1000),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'QueueLess',
                        style: TextStyle(
                          color: Color(0xFFFAFAF7),
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Skip the line. Not the turn.',
                        style: TextStyle(color: Color(0xFFAEB6C8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // The loader stays at the bottom without shifting the centered logo.
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 34),
                child: SizedBox(
                  width: 110,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: Color(0xFFF5A623),
                    backgroundColor: Color(0x335A6178),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
