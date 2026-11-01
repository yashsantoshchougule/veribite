import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  // ponytail: entry point with Riverpod ProviderScope, GoRouter routes wired in Phase 6
  runApp(const ProviderScope(child: ScannerApp()));
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Packaged Product Safety Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F9D58)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Safe Consumption Dosage Scanner Initialized'),
        ),
      ),
    );
  }
}
