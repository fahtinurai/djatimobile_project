import 'package:flutter/material.dart';

// Auth
import 'package:djatimobile_project/pages/auth/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DJATI Mobile',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFF9A825),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const LoginPage(),
    );
  }
}
