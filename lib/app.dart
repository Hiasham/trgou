import 'package:flutter/material.dart';
import 'package:trgou/screens/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Royal Game of Ur',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}