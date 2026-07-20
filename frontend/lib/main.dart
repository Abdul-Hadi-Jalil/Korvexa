import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'providers/labels_provider.dart';
import 'providers/projects_provider.dart';
import 'providers/upcoming_provider.dart';
import 'screens/home_shell.dart';
import 'services/api_client.dart';
import 'services/labels_service.dart';
import 'services/me_service.dart';
import 'services/projects_service.dart';

void main() {
  runApp(const KorvexaApp());
}

class KorvexaApp extends StatelessWidget {
  /// Overridable for widget tests so they never hit the real network.
  final http.Client? httpClient;

  const KorvexaApp({super.key, this.httpClient});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Shared across the app; per-project state (the board) is scoped to
        // its own screen instead -- see BoardScreen.
        Provider<ApiClient>(create: (_) => ApiClient(httpClient: httpClient)),
        ChangeNotifierProvider<ProjectsProvider>(
          create: (context) => ProjectsProvider(ProjectsService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider<UpcomingProvider>(
          create: (context) => UpcomingProvider(MeService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider<LabelsProvider>(
          create: (context) => LabelsProvider(LabelsService(context.read<ApiClient>())),
        ),
      ],
      child: MaterialApp(
        title: 'Korvexa',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
