// This is a basic Flutter widget test for FluentUp.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fluentup/main.dart';
import 'package:fluentup/providers/chat_provider.dart';

void main() {
  testWidgets('FluentUp Splash Screen Renders test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ChatProvider(),
        child: const MyApp(),
      ),
    );

    // Verify that Splash Screen shows FluentUp.
    expect(find.text('FluentUp'), findsOneWidget);

    // Let the splash screen 2-second delay complete and settle to avoid pending timers error
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
