import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_tracker/main.dart';
import 'package:personal_finance_tracker/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  testWidgets('Smoke test - Login page renders', (WidgetTester tester) async {
    // The root widget installs the FinanceProvider itself, so pumping it
    // directly reproduces the real dependency tree.
    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login to continue'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });

  testWidgets('Login validates empty input', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    // Still on the login screen.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}