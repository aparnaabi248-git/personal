import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_tracker/models/currency.dart';
import 'package:personal_finance_tracker/models/transaction_model.dart';
import 'package:personal_finance_tracker/models/user_model.dart';
import 'package:personal_finance_tracker/providers/finance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

TransactionModel tx({
  required double amount,
  String category = 'Food',
  String type = 'Expense',
  String note = '',
  DateTime? date,
  String? id,
}) {
  return TransactionModel(
    id: id ?? amount.toString(),
    amount: amount,
    category: category,
    type: type,
    note: note,
    date: date ?? DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Money formatting', () {
    test('groups thousands and always shows two decimals', () {
      final FinanceProvider provider = FinanceProvider();
      expect(provider.money(1234.56), '₹1,234.56');
      expect(provider.money(0), '₹0.00');
      expect(provider.money(-500), '-₹500.00');
      expect(provider.money(1000000), '₹1,000,000.00');
    });

    test('short format rounds to whole units', () {
      final FinanceProvider provider = FinanceProvider();
      expect(provider.moneyShort(1234.56), '₹1,235');
    });

    test('respects the selected currency', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();
      await provider.saveCurrency(
        CurrencyOption.all.firstWhere((c) => c.code == 'USD'),
      );

      expect(provider.money(1234.5), r'$1,234.50');
    });

    test('signed format marks direction', () async {
      final FinanceProvider provider = FinanceProvider();
      expect(provider.moneySigned(500, true), '+₹500');
      expect(provider.moneySigned(500, false), '-₹500');
      // Direction sign never doubles up with a negative value's own sign.
      expect(provider.moneySigned(-500, true), '+₹500');
    });
  });

  group('Totals', () {
    test('income, expense and balance are computed separately', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      await provider.addTransaction(tx(amount: 1000, type: 'Income'));
      await provider.addTransaction(tx(amount: 250));
      await provider.addTransaction(tx(amount: 100));

      expect(provider.totalIncome, 1000);
      expect(provider.totalExpense, 350);
      expect(provider.balance, 650);
    });

    test('transactions stay sorted newest first', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      final DateTime now = DateTime.now();
      await provider.addTransaction(
        tx(amount: 1, date: now.subtract(const Duration(days: 5)), id: 'old'),
      );
      await provider.addTransaction(
        tx(amount: 2, date: now, id: 'new'),
      );

      expect(provider.transactions.first.id, 'new');
    });

    test('edit and delete update the totals', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      await provider.addTransaction(tx(amount: 300, id: 'a'));
      expect(provider.totalExpense, 300);

      await provider.editTransaction(
        TransactionModel(
          id: 'a',
          amount: 120,
          category: 'Food',
          type: 'Expense',
          note: '',
          date: DateTime.now(),
        ),
      );
      expect(provider.totalExpense, 120);

      await provider.deleteTransaction('a');
      expect(provider.totalExpense, 0);
      expect(provider.transactions, isEmpty);
    });
  });

  group('Budget tracking', () {
    test('only the current month counts towards the budget', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      final DateTime now = DateTime.now();
      final DateTime lastMonth = DateTime(now.year, now.month - 1, 15);

      await provider.addTransaction(tx(amount: 400, date: lastMonth));
      await provider.addTransaction(tx(amount: 150, date: now));

      await provider.saveBudget(1000);

      expect(provider.totalExpense, 550, reason: 'all-time total');
      expect(provider.currentMonthExpense, 150, reason: 'current month only');
      expect(provider.budgetProgress, 0.15);
      expect(provider.isOverBudget, isFalse);
    });

    test('overspending is detected', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();
      await provider.saveBudget(100);
      await provider.addTransaction(tx(amount: 250));

      expect(provider.isOverBudget, isTrue);
      expect(provider.budgetProgress, 1.0, reason: 'progress is clamped at 1');
    });

    test('no budget means zero progress instead of a divide by zero',
        () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();
      await provider.addTransaction(tx(amount: 100));

      expect(provider.budgetProgress, 0);
      expect(provider.isOverBudget, isFalse);
    });

    test('category breakdown is scoped to the current month', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      final DateTime now = DateTime.now();
      await provider.addTransaction(
        tx(amount: 500, category: 'Food', date: DateTime(now.year, now.month - 1)),
      );
      await provider.addTransaction(
        tx(amount: 100, category: 'Food', date: now),
      );
      await provider.addTransaction(
        tx(amount: 50, category: 'Travel', date: now),
      );

      expect(provider.expenseByCategory['Food'], 600, reason: 'all-time');
      expect(provider.expenseByCategoryThisMonth['Food'], 100);
      expect(provider.expenseByCategoryThisMonth['Travel'], 50);
    });
  });

  group('Monthly trend', () {
    test('returns six months ending with the current month', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      final List<MonthlyTotal> trend = provider.monthlyTrend();
      expect(trend.length, 6);
      expect(trend.last.income, 0);
    });

    test('places income and expense in the correct buckets', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      final DateTime now = DateTime.now();
      await provider.addTransaction(tx(amount: 900, type: 'Income', date: now));
      await provider.addTransaction(tx(amount: 300, date: now));
      await provider.addTransaction(
        tx(amount: 200, date: DateTime(now.year, now.month - 1)),
      );

      final List<MonthlyTotal> trend = provider.monthlyTrend();
      expect(trend.last.income, 900);
      expect(trend.last.expense, 300);
      expect(trend[trend.length - 2].expense, 200);
      expect(trend.first.income, 0);
    });
  });

  group('Persistence', () {
    test('transactions, budget and profile survive a reload', () async {
      final FinanceProvider first = FinanceProvider();
      await first.loadAll();
      await first.addTransaction(tx(amount: 750, note: 'Groceries'));
      await first.saveBudget(4000);
      await first.saveUser(
        UserModel(
          id: '1',
          name: 'Asha',
          email: 'asha@example.com',
          phone: '1234567890',
          address: 'Pune',
        ),
      );

      // A fresh provider reads from the same storage.
      final FinanceProvider second = FinanceProvider();
      await second.loadAll();

      expect(second.transactions.single.amount, 750);
      expect(second.transactions.single.note, 'Groceries');
      expect(second.monthlyBudget, 4000);
      expect(second.user.name, 'Asha');
      expect(second.user.address, 'Pune');
    });

    test('a corrupt record is skipped instead of breaking the load', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'transactions': <String>['not-json', '{"id":"ok","amount":10,'
            '"category":"Food","type":"Expense","note":"",'
            '"date":"2026-01-05T00:00:00.000"}'],
      });

      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();

      expect(provider.transactions.length, 1);
      expect(provider.transactions.single.id, 'ok');
      expect(provider.hasLoaded, isTrue);
    });

    test('clearAllData wipes finances but keeps the account usable',
        () async {
      // Seed credentials so we can prove they survive a data wipe.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'registered_email': 'asha@example.com',
        'registered_password': 'password123',
        'registered_name': 'Asha',
        'isLoggedIn': true,
      });

      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();
      await provider.addTransaction(tx(amount: 100));
      await provider.saveBudget(500);
      await provider.saveUser(
        UserModel(
          id: '1',
          name: 'Asha',
          email: 'asha@example.com',
          phone: '',
          address: '',
        ),
      );

      await provider.clearAllData();

      expect(provider.transactions, isEmpty);
      expect(provider.monthlyBudget, 0);
      expect(provider.user.name, isEmpty);

      // Credentials survive, so the user stays signed in.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('registered_email'), 'asha@example.com');
      expect(prefs.getBool('isLoggedIn'), isTrue);
    });

    test('logout ends the session without deleting data', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();
      await provider.addTransaction(tx(amount: 100));

      await provider.logout();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isFalse);
      expect(provider.transactions.length, 1, reason: 'data is preserved');
    });
  });

  group('Sample data', () {
    test('produces transactions and a usable budget', () async {
      final FinanceProvider provider = FinanceProvider();
      await provider.loadAll();
      await provider.loadSampleData();

      expect(provider.transactions, isNotEmpty);
      expect(provider.monthlyBudget, greaterThan(0));
      expect(provider.totalIncome, greaterThan(provider.totalExpense));
    });
  });
}