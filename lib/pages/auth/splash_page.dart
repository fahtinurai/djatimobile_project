import 'package:flutter/material.dart';
import 'dart:async';

import 'login_page.dart';
import 'package:djatimobile_project/navigation/main_navigation.dart';
import 'package:djatimobile_project/core/services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 25.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutExpo),
    );

    Timer(const Duration(milliseconds: 500), () {
      _controller.forward().then((_) {
        _checkLoginStatus();
      });
    });
  }

  Future<void> _checkLoginStatus() async {
    final token = await AuthService.getToken();
    final role = await AuthService.getRole();

    if (!mounted) return;

    if (token != null && token.isNotEmpty && role != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainNavigation(userRole: role),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
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
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFF9A825),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}