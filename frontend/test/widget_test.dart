// Basic Flutter widget smoke test: the app boots to the home shell with a
// Projects/My Tasks bottom nav, using a mocked HTTP client so it never
// touches the real network.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:korvexa/main.dart';

void main() {
  testWidgets('Korvexa app boots to the home shell', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(KorvexaApp(httpClient: mockClient));
    await tester.pump(); // let the post-frame provider.load() calls settle.

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('My Tasks'), findsOneWidget);
  });
}
