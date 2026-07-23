// Smoke test: with no stored token, the app boots through the AuthGate to the
// login screen. A mocked HTTP client ensures it never touches the network.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:korvexa/main.dart';

void main() {
  setUp(() {
    // No stored tokens -> the app should route to login.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Korvexa boots to the login screen when unauthenticated',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({}), 200, headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(KorvexaApp(httpClient: mockClient));
    await tester.pumpAndSettle();

    // AuthGate resolves to unauthenticated -> LoginScreen.
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text("Don't have an account? Register"), findsOneWidget);
  });
}
