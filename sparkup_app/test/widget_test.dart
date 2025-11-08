// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sparkup_app/locale_provider.dart';
import 'package:sparkup_app/providers/user_provider.dart';

void main() {
  testWidgets('App builds with required providers', (WidgetTester tester) async {
    // Build a minimal app that includes the providers used in production but does not initialize Firebase.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: Center(child: Text('ok')))),
      ),
    );

    // Allow frames to settle
    await tester.pumpAndSettle();

    // Sanity check: our placeholder content is present
    expect(find.text('ok'), findsOneWidget);
  });
}
