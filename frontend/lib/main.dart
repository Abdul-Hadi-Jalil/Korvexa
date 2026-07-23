import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'providers/labels_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/projects_provider.dart';
import 'providers/upcoming_provider.dart';
import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/labels_service.dart';
import 'services/me_service.dart';
import 'services/notifications_service.dart';
import 'services/projects_service.dart';
import 'services/session.dart';
import 'services/token_storage.dart';

void main() {
  runApp(const KorvexaApp());
}

class KorvexaApp extends StatefulWidget {
  /// Overridable for widget tests so they never hit the real network.
  final http.Client? httpClient;

  const KorvexaApp({super.key, this.httpClient});

  @override
  State<KorvexaApp> createState() => _KorvexaAppState();
}

class _KorvexaAppState extends State<KorvexaApp> {
  late final SessionController _session;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    // Build the object graph once: session holds auth/tenancy state, the API
    // client reads tokens/workspace from it and refreshes on 401, and the
    // session uses the client (attached below) to load /auth/me + workspaces.
    _session = SessionController(TokenStorage());
    _api = ApiClient(session: _session, httpClient: widget.httpClient);
    _session.attach(_api);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: _session),
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider<ProjectsProvider>(
          create: (context) => ProjectsProvider(ProjectsService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider<UpcomingProvider>(
          create: (context) => UpcomingProvider(MeService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider<LabelsProvider>(
          create: (context) => LabelsProvider(LabelsService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (context) => NotificationsProvider(NotificationsService(context.read<ApiClient>())),
        ),
      ],
      child: MaterialApp(
        title: 'Korvexa',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
