// Basic Flutter widget smoke test: the app boots to its home screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:korvexa/main.dart';

void main() {
  testWidgets('Korvexa app boots to the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KorvexaApp());

    expect(find.text('Korvexa'), findsOneWidget);
  });
}
