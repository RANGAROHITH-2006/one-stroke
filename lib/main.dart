import 'package:flutter/material.dart';
import 'package:singlelinedraw/homescreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Single Line',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const SingleLineGameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

