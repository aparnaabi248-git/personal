import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_tracker/main.dart';
import 'package:personal_finance_tracker/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the screens that restore stored values into their form fields.
void main() {
  Future<void> setDesktopViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Budget field shows the stored monthly budget',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_email': 'test@example.com',
      'registered_password': 'password123',
      'isLoggedIn': true,
      'monthly_budget': 42000.0,
    });

    await setDesktopViewport(tester);
    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    await openSection(tester, 'Budget');

    expect(find.widgetWithText(AppBar, 'Monthly Budget'), findsOneWidget);
    // The saved amount is loaded into the input, not just shown on the card.
    expect(find.text('42000'), findsOneWidget);
  });

  testWidgets('Profile fields show the stored profile',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_email': 'test@example.com',
      'registered_password': 'password123',
      'isLoggedIn': true,
      'user': '{"id":"1","name":"Asha","email":"asha@example.com",'
          '"phone":"1234567890","address":"Pune"}',
    });

    await setDesktopViewport(tester);
    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    await openSection(tester, 'Profile');

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Asha'), findsWidgets);
    expect(find.text('asha@example.com'), findsWidgets);
    expect(find.text('1234567890'), findsWidgets);
    expect(find.text('Pune'), findsWidgets);
  });

  testWidgets('Typing in the budget field survives provider updates',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_email': 'test@example.com',
      'registered_password': 'password123',
      'isLoggedIn': true,
      'monthly_budget': 42000.0,
    });

    await setDesktopViewport(tester);
    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    await openSection(tester, 'Budget');

    await tester.enterText(
      find.widgetWithText(TextFormField, '42000'),
      '9999',
    );
    await tester.pumpAndSettle();

    // A later notification must not clobber the value being typed.
    expect(find.text('9999'), findsOneWidget);
    expect(find.text('42000'), findsNothing);
  });
}