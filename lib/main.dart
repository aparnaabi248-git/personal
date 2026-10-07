import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/finance_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/history_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/report_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PersonalFinanceTracker());
}

/// Root widget.
///
/// The [FinanceProvider] is installed *inside* the root widget on purpose, so
/// that mounting `PersonalFinanceTracker` in a widget test provides the same
/// dependency tree as the real app.
class PersonalFinanceTracker extends StatelessWidget {
  const PersonalFinanceTracker({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider()..loadAll(),
      child: const _FinanceApp(),
    );
  }
}

class _FinanceApp extends StatefulWidget {
  const _FinanceApp();

  @override
  State<_FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<_FinanceApp> {
  /// Whether the stored session check has finished.
  bool _resolved = false;
  bool _startAtHome = false;

  @override
  void initState() {
    super.initState();
    _resolveStartRoute();
  }

  /// Decides the start destination before the first real route is built.
  ///
  /// A storage layer that hangs or throws must never strand the user on the
  /// splash screen, so both cases fall back to the login route.
  Future<void> _resolveStartRoute() async {
    bool loggedIn = false;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      loggedIn = prefs.getBool('isLoggedIn') ?? false;
    } catch (_) {
      loggedIn = false;
    }

    if (!mounted) return;
    setState(() {
      _startAtHome = loggedIn;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) return const _SplashScreen();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Personal Finance Tracker',

      theme: buildAppTheme(),

      initialRoute: _startAtHome ? '/home' : '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        // The dashboard's "Add Income"/"Add Expense" buttons preselect the
        // type through the route argument.
        '/addTransaction': (context) => AddTransactionScreen(
          initialType: ModalRoute.of(context)?.settings.arguments as String?,
        ),
        '/history': (context) => const HistoryScreen(),
        '/budget': (context) => const BudgetScreen(),
        '/reports': (context) => const ReportScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// Shown for the brief moment it takes to read the stored session.
///
/// Deliberately free of looping animations so the first frame settles.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.purple, AppColors.indigo],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Color(0x29FFFFFF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Personal Finance Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}