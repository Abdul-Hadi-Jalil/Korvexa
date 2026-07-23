import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Routes between the login screen and the app based on session status,
/// kicking off `bootstrap()` (restore tokens from secure storage) on start.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SessionController>().status;
    return switch (status) {
      SessionStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
      SessionStatus.unauthenticated => const LoginScreen(),
      SessionStatus.authenticated => const HomeShell(),
    };
  }
}
