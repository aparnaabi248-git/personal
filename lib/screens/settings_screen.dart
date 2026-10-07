import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../providers/finance_provider.dart';
import '../widgets/app_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();

    return AppShell(
      title: 'Settings',
      activeRoute: '/settings',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Preferences',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Daily spending reminders'),
            value: provider.notificationsEnabled,
            onChanged: provider.setNotificationsEnabled,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency'),
            subtitle: Text(provider.currency.label),
            trailing: DropdownButton<CurrencyOption>(
              value: provider.currency,
              underline: const SizedBox(),
              items: CurrencyOption.all
                  .map((CurrencyOption c) => DropdownMenuItem<CurrencyOption>(
                        value: c,
                        child: Text(c.symbol, style: const TextStyle(fontSize: 18)),
                      ))
                  .toList(),
              onChanged: (CurrencyOption? value) {
                if (value != null) provider.saveCurrency(value);
              },
            ),
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.teal),
            title: const Text('Load Sample Data'),
            subtitle: const Text('Fill the app with demo entries to explore'),
            onTap: () => _confirmLoadSample(context, provider),
          ),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Clear All Data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Delete all transactions, budget & profile'),
            onTap: () => _confirmClearData(context, provider),
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'About',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About App'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Personal Finance Tracker',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Personal Finance Tracker',
            ),
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                title: const Text('Privacy Policy'),
                content: const Text(
                  'Your financial data is stored locally on this device only. '
                  'Nothing is uploaded, and no information is shared with '
                  'third parties. Uninstalling the app removes all stored data.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.help, color: Colors.blue),
            title: const Text('Help & Support'),
            subtitle: const Text('Usage tips and troubleshooting'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                title: const Text('Help & Support'),
                content: const Text(
                  '• Add entries from Home → Add Transaction.\n'
                  '• Set a monthly limit in Budget to track overspending.\n'
                  '• Reports shows category breakdowns and a 6-month trend.\n'
                  '• All data lives on this device — no account server needed.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Your data stays on this device'),
            onTap: () => _confirmLogout(context, provider),
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text(
              'Personal Finance Tracker\nVersion 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _confirmLoadSample(
    BuildContext context,
    FinanceProvider provider,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Load Sample Data'),
        content: Text(
          provider.transactions.isEmpty
              ? 'This adds demo income and expense entries so you can explore '
                  'the charts and reports.'
              : 'This replaces your current transactions with demo entries.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await provider.loadSampleData();
    messenger.showSnackBar(
      const SnackBar(content: Text('Sample data loaded')),
    );
  }

  Future<void> _confirmClearData(
    BuildContext context,
    FinanceProvider provider,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This permanently deletes all transactions, your budget and your '
          'profile. This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await provider.clearAllData();
    messenger.showSnackBar(
      const SnackBar(content: Text('All financial data cleared')),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    FinanceProvider provider,
  ) async {
    final NavigatorState navigator = Navigator.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Log out of this device? Your transactions and budget stay saved '
          'and you can log back in at any time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await provider.logout();
    navigator.pushNamedAndRemoveUntil('/login', (Route<void> route) => false);
  }
}