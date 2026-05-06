import 'package:flutter/material.dart';
import 'package:trgou/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
} 