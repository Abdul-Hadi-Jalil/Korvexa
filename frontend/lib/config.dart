import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Picks the API base URL for the current platform.
///
/// Override at build/run time with `--dart-define=API_BASE_URL=http://host:port`.
/// Without an override: web/desktop talk to localhost directly; the Android
/// emulator needs `10.0.2.2` to reach the host machine's localhost.
class AppConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {
      // Platform isn't available on every target; fall through to default.
    }
    return 'http://127.0.0.1:8000';
  }
}
