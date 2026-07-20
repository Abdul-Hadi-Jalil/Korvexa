import 'package:flutter/material.dart';

void main() {
  runApp(const KorvexaApp());
}

class KorvexaApp extends StatelessWidget {
  const KorvexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Korvexa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Placeholder home screen for Phase 0. Phase 1 replaces this with the
/// projects list (see lib/screens/projects_list_screen.dart).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Korvexa')),
      body: const Center(
        child: Text('Korvexa is scaffolded. Projects are coming in Phase 1.'),
      ),
    );
  }
}
