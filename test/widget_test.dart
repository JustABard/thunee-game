import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunee_game/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ThuneeApp());

    // Verify that the home screen shows
    expect(find.text('THUNEE'), findsOneWidget);
  });
}
