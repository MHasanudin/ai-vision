// Basic smoke test for the AI Vision app.
//
// Verifies that the app builds and renders the home screen without crashing.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_vision/main.dart';

void main() {
  testWidgets('App builds and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Verify the home screen renders with the app title.
    expect(find.text('AI Vision'), findsWidgets);
  });
}
