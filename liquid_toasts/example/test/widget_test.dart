// Basic smoke test for the example app.

import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_toasts_example/main.dart';

void main() {
  testWidgets('example renders the demo screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Liquid Toasts'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);
  });
}
