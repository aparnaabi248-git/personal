import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_tracker/main.dart';
import 'package:personal_finance_tracker/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // An account already exists, so the login flow has something to check.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_email': 'test@example.com',
      'registered_password': 'password123',
      'registered_name': 'Tester',
      'isLoggedIn': false,
    });
  });

  /// Runs the body at a desktop size so the persistent sidebar is present.
  ///
  /// Below `AppShell.kBreakpoint` navigation moves into a drawer, which these
  /// tests deliberately do not cover.
  Future<void> withDesktopViewport(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await body();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
  }

  /// Switches section through the sidebar.
  Future<void> openSidebarItem(WidgetTester tester, String label) async {
    final Finder tile = find.text(label);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  

  testWidgets('Registering then signing in reaches the home screen',
      (WidgetTester tester) async {
    // Start with no account at all.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    // Guard: we must genuinely be on the login screen for this flow.
    expect(find.text('Login to continue'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Tester');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');

    final Finder submit = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    // Registration returns to login, where the new account can be used.
    expect(find.text('Login to continue'), findsOneWidget);

    await signIn(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Wrong password is rejected', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'wrongpassword',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('Every sidebar section opens its screen',
      (WidgetTester tester) async {
    await withDesktopViewport(tester, () async {
      await tester.pumpWidget(const PersonalFinanceTracker());
      await tester.pumpAndSettle();

      await signIn(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await openSidebarItem(tester, 'Transactions');
      expect(find.widgetWithText(AppBar, 'Transaction History'), findsOneWidget);

      await openSidebarItem(tester, 'Budget');
      expect(find.widgetWithText(AppBar, 'Monthly Budget'), findsOneWidget);

      await openSidebarItem(tester, 'Reports');
      expect(find.widgetWithText(AppBar, 'Financial Reports'), findsOneWidget);

      await openSidebarItem(tester, 'Profile');
      expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);

      await openSidebarItem(tester, 'Settings');
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

      await openSidebarItem(tester, 'Overview');
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('A saved transaction is added and shown in history',
      (WidgetTester tester) async {
    await withDesktopViewport(tester, () async {
      await tester.pumpWidget(const PersonalFinanceTracker());
      await tester.pumpAndSettle();
      await signIn(tester);

      await openSidebarItem(tester, 'Transactions');

      // Add one via the floating action button.
      await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.add));
      await tester.pumpAndSettle();

      // Field order on this screen: amount, then note.
      await tester.enterText(find.byType(TextFormField).at(0), '250');
      await tester.enterText(find.byType(TextFormField).at(1), 'Team lunch');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
      expect(find.textContaining('Team lunch'), findsOneWidget);
      // Once in the row itself, once in the running totals strip.
      expect(find.textContaining('-₹250'), findsWidgets);
    });
  });

  testWidgets('A transaction can be deleted from the history screen',
      (WidgetTester tester) async {
    await withDesktopViewport(tester, () async {
      await tester.pumpWidget(const PersonalFinanceTracker());
      await tester.pumpAndSettle();
      await signIn(tester);

      await openSidebarItem(tester, 'Transactions');
      expect(find.text('No transactions yet'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '99');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Transaction'));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);

      // Open the row's action menu, then choose Delete.
      final Finder menu = find.byIcon(Icons.more_vert);
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      final Finder delete = find.text('Delete');
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();

      // Confirm in the dialog.
      expect(find.text('Delete Transaction'), findsOneWidget);
      final Finder confirm = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet'), findsOneWidget);
    });
  });

  testWidgets('Dashboard renders its sections, tiles and charts with data',
      (WidgetTester tester) async {
    // Seed six months of entries so the bar, line and donut charts all have
    // something to draw.
    final DateTime now = DateTime.now();
    final List<Map<String, Object>> seed = <Map<String, Object>>[];
    for (int back = 5; back >= 0; back--) {
      final DateTime month = DateTime(now.year, now.month - back, 1);
      void add(
        String id,
        double amount,
        String category,
        String type,
      ) {
        seed.add(<String, Object>{
          'id': '$id$back',
          'amount': amount,
          'category': category,
          'type': type,
          'note': '',
          'date': DateTime(month.year, month.month, 5).toIso8601String(),
        });
      }

      add('salary', 85000, 'Salary', 'Income');
      add('rent', 24000, 'Bills', 'Expense');
      add('food', 6400, 'Food', 'Expense');
      add('travel', 3200, 'Travel', 'Expense');
    }

    SharedPreferences.setMockInitialValues(<String, Object>{
      'registered_email': 'test@example.com',
      'registered_password': 'password123',
      'registered_name': 'Tester',
      'isLoggedIn': true,
      'monthly_budget': 50000.0,
      'transactions': seed
          .map((Map<String, Object> t) => jsonEncode(t))
          .toList(growable: false),
    });

    await withDesktopViewport(tester, () async {
      await tester.pumpWidget(const PersonalFinanceTracker());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Total Revenues'), findsOneWidget);

      for (final String label in <String>[
        'My Balance',
        'Recent activities',
        'Monthly Income',
        'Monthly Expense',
        'Avg. Income',
        'Avg. Expense',
        'Earning Summary',
        'All Expenses',
      ]) {
        // The dashboard is a lazy ListView, so later sections are not built
        // until they are scrolled into range.
        final Finder section = find.text(label);
        if (section.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            section,
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(section, findsOneWidget, reason: 'missing "$label"');
      }

      // All three chart widgets built without throwing.
      expect(find.byType(BarChart), findsWidgets);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
    });
  });

  testWidgets('Backing out of a section returns to Overview, not out of the app',
      (WidgetTester tester) async {
    await withDesktopViewport(tester, () async {
      await tester.pumpWidget(const PersonalFinanceTracker());
      await tester.pumpAndSettle();
      await signIn(tester);

      await openSidebarItem(tester, 'Transactions');
      expect(find.widgetWithText(AppBar, 'Transaction History'), findsOneWidget);

      // System back pops to the dashboard, which stays at the stack root.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Overview'), findsOneWidget);
    });
  });

  testWidgets('Switching between sections never stacks up routes',
      (WidgetTester tester) async {
    await withDesktopViewport(tester, () async {
      await tester.pumpWidget(const PersonalFinanceTracker());
      await tester.pumpAndSettle();
      await signIn(tester);

      await openSidebarItem(tester, 'Transactions');
      await openSidebarItem(tester, 'Budget');
      await openSidebarItem(tester, 'Reports');

      expect(find.widgetWithText(AppBar, 'Financial Reports'), findsOneWidget);

      // Overview plus the current section, and nothing in between.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('The narrow layout hides the sidebar behind a menu button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PersonalFinanceTracker());
    await tester.pumpAndSettle();
    await signIn(tester);

    // Sidebar items are off-canvas until the drawer opens.
    expect(find.text('Transactions'), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
  });
}
