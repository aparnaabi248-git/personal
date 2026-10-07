import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

/// Central state provider — all screens read from and write to this single
/// source of truth. Data is persisted to SharedPreferences so it survives
/// app restarts (local-first, no backend required).
class FinanceProvider extends ChangeNotifier {
  // ------------------------------------------------------------------
  // Persistence keys
  // ------------------------------------------------------------------

  static const _kTransactions = 'transactions';
  static const _kMonthlyBudget = 'monthly_budget';
  static const _kUser = 'user';
  static const _kCurrency = 'currency_code';
  static const _kNotifications = 'notifications';

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------

  List<TransactionModel> _transactions = <TransactionModel>[];
  double _monthlyBudget = 0;
  UserModel _user = UserModel(
    id: '1',
    name: '',
    email: '',
    phone: '',
    address: '',
  );
  CurrencyOption _currency = CurrencyOption.all.first;
  bool _notificationsEnabled = true;

  bool _isLoading = false;

  /// True once the first successful read from disk has finished. Screens use
  /// this to avoid showing an endless loading spinner on every re-entry.
  bool _hasLoaded = false;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Guards against "used after dispose" when an async write resolves late.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------------
  // Getters
  // ------------------------------------------------------------------

  List<TransactionModel> get transactions => List<TransactionModel>.unmodifiable(_transactions);
  double get monthlyBudget => _monthlyBudget;
  UserModel get user => _user;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  CurrencyOption get currency => _currency;
  bool get notificationsEnabled => _notificationsEnabled;

  double get totalIncome => _sumWhere((t) => t.type == 'Income');
  double get totalExpense => _sumWhere((t) => t.type == 'Expense');
  double get balance => totalIncome - totalExpense;

  /// Income + expense for the current calendar month.
  double get currentMonthIncome => _sumWhere(_isThisMonth, type: 'Income');
  double get currentMonthExpense => _sumWhere(_isThisMonth, type: 'Expense');

  double get budgetProgress {
    if (_monthlyBudget <= 0) return 0;
    return (currentMonthExpense / _monthlyBudget).clamp(0.0, 1.0);
  }

  bool get isOverBudget => _monthlyBudget > 0 && currentMonthExpense > _monthlyBudget;

  /// Query handed down from the top bar; the History screen consumes it.
  String _globalSearch = '';
  String get globalSearch => _globalSearch;

  void setGlobalSearch(String query) {
    if (_globalSearch == query) return;
    _globalSearch = query;
    _notify();
  }

  // ------------------------------------------------------------------
  // Trend-derived averages (used by the dashboard stat tiles)
  // ------------------------------------------------------------------

  /// Average income per month across the trend window.
  ///
  /// Averaging over the whole window (not only months that have data) keeps
  /// the number stable instead of inflating as entries are added.
  double get averageMonthlyIncome {
    final List<MonthlyTotal> trend = monthlyTrend();
    if (trend.isEmpty) return 0;
    final double sum = trend.fold<double>(0, (double s, MonthlyTotal m) => s + m.income);
    return sum / trend.length;
  }

  /// Average expense per month across the trend window.
  double get averageMonthlyExpense {
    final List<MonthlyTotal> trend = monthlyTrend();
    if (trend.isEmpty) return 0;
    final double sum = trend.fold<double>(0, (double s, MonthlyTotal m) => s + m.expense);
    return sum / trend.length;
  }

  /// The five newest transactions, newest first.
  List<TransactionModel> get recentTransactions =>
      _transactions.take(5).toList(growable: false);

  // ------------------------------------------------------------------
  // Money formatting
  // ------------------------------------------------------------------

  /// Full precision, e.g. `₹1,250.50`.
  String money(double value) => _money(value, decimals: 2);

  /// Whole-unit amount, e.g. `₹1,251` — used in dense cards and lists.
  String moneyShort(double value) => _money(value, decimals: 0);

  /// Signed variant used for transactions: `+₹500` / `-₹200`.
  ///
  /// The sign reflects the transaction direction, so it is derived separately
  /// from the value's own sign to avoid ever rendering `+-₹…`.
  String moneySigned(double value, bool isIncome) =>
      '${isIncome ? '+' : '-'}${_money(value.abs(), decimals: 0)}';

  String _money(double value, {required int decimals}) {
    final bool isNegative = value < 0;
    final String body = _group(value.abs().toStringAsFixed(decimals));

    // The symbol leads the digits, and any minus sign goes in front of it.
    return '${isNegative ? '-' : ''}${_currency.symbol}$body';
  }

  static String _group(String digits) {
    final int dot = digits.indexOf('.');
    final String whole = dot == -1 ? digits : digits.substring(0, dot);
    final String frac = dot == -1 ? '' : digits.substring(dot);

    final StringBuffer out = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    return '${out.toString()}$frac';
  }

  // ------------------------------------------------------------------
  // Aggregation helpers
  // ------------------------------------------------------------------

  bool _isThisMonth(TransactionModel t) {
    final DateTime now = DateTime.now();
    return t.date.year == now.year && t.date.month == now.month;
  }

  double _sumWhere(
    bool Function(TransactionModel) test, {
    String? type,
  }) {
    return _transactions
        .where((t) => test(t) && (type == null || t.type == type))
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  Map<String, double> _totalsByCategory(
    bool Function(TransactionModel) test, {
    required String type,
  }) {
    final Map<String, double> map = <String, double>{};
    for (final TransactionModel t
        in _transactions.where((t) => test(t) && t.type == type)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  /// All-time expense breakdown by category (for reports).
  Map<String, double> get expenseByCategory =>
      _totalsByCategory((_) => true, type: 'Expense');

  /// All-time income breakdown by category (for reports).
  Map<String, double> get incomeByCategory =>
      _totalsByCategory((_) => true, type: 'Income');

  /// Expense breakdown restricted to the current calendar month.
  /// The budget screen labels this "this month", so it must actually be
  /// month-scoped.
  Map<String, double> get expenseByCategoryThisMonth =>
      _totalsByCategory(_isThisMonth, type: 'Expense');

  /// Income/expense totals for the last [months] calendar months, oldest
  /// first. Feeds the trend chart in Reports.
  List<MonthlyTotal> monthlyTrend({int months = 6}) {
    final DateTime now = DateTime.now();
    final List<MonthlyTotal> out = <MonthlyTotal>[];

    for (int back = months - 1; back >= 0; back--) {
      final DateTime cursor = DateTime(now.year, now.month - back);
      final DateTime next = DateTime(now.year, now.month - back + 1);

      double income = 0;
      double expense = 0;
      for (final TransactionModel t in _transactions) {
        final bool inRange =
            !t.date.isBefore(cursor) && t.date.isBefore(next);
        if (!inRange) continue;
        if (t.type == 'Income') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }

      out.add(MonthlyTotal(
        label: '${_monthName(cursor.month)} ${cursor.year % 100}',
        income: income,
        expense: expense,
      ));
    }
    return out;
  }

  static String _monthName(int month) {
    const List<String> names = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  // ------------------------------------------------------------------
  // Load from SharedPreferences
  // ------------------------------------------------------------------

  Future<void> loadAll() async {
    _isLoading = true;
    _notify();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final List<String> txJson =
          prefs.getStringList(_kTransactions) ?? <String>[];

      final List<TransactionModel> parsed = <TransactionModel>[];
      for (final String raw in txJson) {
        try {
          parsed.add(
            TransactionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          );
        } catch (_) {
          // Skip a single corrupt record instead of failing the whole load.
        }
      }
      _transactions = _sortByDateDesc(parsed);

      _monthlyBudget = prefs.getDouble(_kMonthlyBudget) ?? 0;
      _currency = CurrencyOption.fromCode(prefs.getString(_kCurrency));
      _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;

      final String? userJson = prefs.getString(_kUser);
      if (userJson != null) {
        try {
          _user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        } catch (_) {
          // Keep the empty default user if the stored blob is unreadable.
        }
      }
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      _notify();
    }
  }

  static List<TransactionModel> _sortByDateDesc(List<TransactionModel> items) {
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  // ------------------------------------------------------------------
  // Transactions
  // ------------------------------------------------------------------

  Future<void> addTransaction(TransactionModel tx) async {
    _transactions.insert(0, tx);
    _sortByDateDesc(_transactions);
    await _saveTransactions();
    _notify();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _saveTransactions();
    _notify();
  }

  Future<void> editTransaction(TransactionModel updated) async {
    final int idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    _transactions[idx] = updated;
    _sortByDateDesc(_transactions);
    await _saveTransactions();
    _notify();
  }

  Future<void> _saveTransactions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kTransactions,
      _transactions.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  // ------------------------------------------------------------------
  // Budget
  // ------------------------------------------------------------------

  Future<void> saveBudget(double budget) async {
    _monthlyBudget = budget;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMonthlyBudget, budget);
    _notify();
  }

  // ------------------------------------------------------------------
  // Settings
  // ------------------------------------------------------------------

  Future<void> saveCurrency(CurrencyOption option) async {
    _currency = option;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, option.code);
    _notify();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
    _notify();
  }

  // ------------------------------------------------------------------
  // User / Profile
  // ------------------------------------------------------------------

  Future<void> saveUser(UserModel user) async {
    _user = user;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    _notify();
  }

  /// Ends the session but keeps the account and all financial data, so the
  /// user can log back in without registering again.
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    _notify();
  }

  /// Deletes transactions, budget and profile. The stored account credentials
  /// are intentionally preserved so the user stays signed in.
  Future<void> clearAllData() async {
    _transactions = <TransactionModel>[];
    _monthlyBudget = 0;
    _user = UserModel(id: '1', name: '', email: '', phone: '', address: '');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTransactions);
    await prefs.remove(_kMonthlyBudget);
    await prefs.remove(_kUser);
    _notify();
  }

  /// Fills the app with a small demo data set so the charts and reports can be
  /// explored before any real entries exist.
  Future<void> loadSampleData() async {
    final DateTime now = DateTime.now();
    final List<TransactionModel> samples = <TransactionModel>[
      TransactionModel(
        id: 'seed-salary',
        amount: 85000,
        category: 'Salary',
        type: 'Income',
        note: 'Monthly salary',
        date: DateTime(now.year, now.month, 1),
      ),
      TransactionModel(
        id: 'seed-freelance',
        amount: 12000,
        category: 'Business',
        type: 'Income',
        note: 'Freelance project',
        date: DateTime(now.year, now.month, 8),
      ),
      TransactionModel(
        id: 'seed-rent',
        amount: 24000,
        category: 'Bills',
        type: 'Expense',
        note: 'House rent',
        date: DateTime(now.year, now.month, 2),
      ),
      TransactionModel(
        id: 'seed-groceries',
        amount: 6400,
        category: 'Food',
        type: 'Expense',
        note: 'Groceries',
        date: DateTime(now.year, now.month, 5),
      ),
      TransactionModel(
        id: 'seed-travel',
        amount: 3200,
        category: 'Travel',
        type: 'Expense',
        note: 'Fuel and metro',
        date: DateTime(now.year, now.month, 9),
      ),
      TransactionModel(
        id: 'seed-shopping',
        amount: 4800,
        category: 'Shopping',
        type: 'Expense',
        note: 'Winter clothes',
        date: DateTime(now.year, now.month, 11),
      ),
      TransactionModel(
        id: 'seed-health',
        amount: 1500,
        category: 'Medical',
        type: 'Expense',
        note: 'Pharmacy',
        date: DateTime(now.year, now.month, 12),
      ),
      TransactionModel(
        id: 'seed-ott',
        amount: 649,
        category: 'Entertainment',
        type: 'Expense',
        note: 'Streaming subscription',
        date: DateTime(now.year, now.month, 14),
      ),
    ];

    _transactions = _sortByDateDesc(samples);
    await _saveTransactions();

    if (_monthlyBudget <= 0) {
      _monthlyBudget = 50000;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kMonthlyBudget, _monthlyBudget);
    }

    _notify();
  }
}

/// One bar in the monthly trend chart.
class MonthlyTotal {
  final String label;
  final double income;
  final double expense;

  const MonthlyTotal({
    required this.label,
    required this.income,
    required this.expense,
  });
}