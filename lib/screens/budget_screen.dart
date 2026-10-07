import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../widgets/app_shell.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _budgetController = TextEditingController();
  bool _isSaving = false;

  late final FinanceProvider _provider;

  /// Set once the stored budget has been copied into the field, so a later
  /// provider notification cannot overwrite what the user is typing.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<FinanceProvider>();
    // The provider loads asynchronously, so the saved budget may not be
    // available on the first frame. Listening means the field fills in as soon
    // as the value arrives, instead of staying blank.
    _provider.addListener(_prefillFromStore);
    _prefillFromStore();
  }

  void _prefillFromStore() {
    if (_prefilled) return;
    final double saved = _provider.monthlyBudget;
    if (saved <= 0) return;
    _prefilled = true;
    _budgetController.text = saved.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _provider.removeListener(_prefillFromStore);
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final double? budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) return;

    final FinanceProvider provider = context.read<FinanceProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);

    await provider.saveBudget(budget);

    if (!mounted) return;
    setState(() => _isSaving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Monthly budget set to ${provider.money(budget)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();

    final double monthlyBudget = provider.monthlyBudget;
    final double spent = provider.currentMonthExpense;
    final double remaining = monthlyBudget - spent;
    final double progress = provider.budgetProgress;
    final bool isOver = provider.isOverBudget;
    final bool hasBudget = monthlyBudget > 0;

    final Color progressColor = !hasBudget
        ? Colors.grey
        : progress >= 1.0
            ? Colors.red
            : progress >= 0.75
                ? Colors.orange
                : Colors.green;

    // Month-scoped: this card is labelled "this month", so it must not include
    // expenses from previous months.
    final Map<String, double> byCategory = provider.expenseByCategoryThisMonth;
    final List<MapEntry<String, double>> categoryRows = byCategory.entries
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));

    return AppShell(
      title: 'Monthly Budget',
      activeRoute: '/budget',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Monthly Budget',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _budgetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monthly Budget',
                  prefixIcon: Text(
                    provider.currency.symbol,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                validator: (String? value) {
                  final String text = (value ?? '').trim();
                  if (text.isEmpty) return 'Enter your monthly budget';
                  final double? parsed = double.tryParse(text);
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed <= 0) return 'Budget must be greater than zero';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveBudget,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text(
                    'Save Budget',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Budget Summary',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasBudget
                            ? 'Current calendar month'
                            : 'Set a budget to start tracking',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 20),

                      _summaryTile(
                        icon: Icons.account_balance_wallet,
                        color: Colors.blue,
                        label: 'Monthly Budget',
                        value: hasBudget ? provider.money(monthlyBudget) : '—',
                      ),

                      const Divider(),

                      _summaryTile(
                        icon: Icons.money_off,
                        color: Colors.red,
                        label: 'Spent This Month',
                        value: provider.money(spent),
                      ),

                      if (hasBudget) ...[
                        const Divider(),

                        _summaryTile(
                          icon: isOver ? Icons.warning : Icons.savings,
                          color: isOver ? Colors.red : Colors.green,
                          label: isOver ? 'Over Budget By' : 'Remaining',
                          value: provider.money(remaining.abs()),
                          valueColor: isOver ? Colors.red : Colors.green,
                        ),

                        const SizedBox(height: 24),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 14,
                            backgroundColor: Colors.grey.shade300,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isOver
                                  ? '⚠️ Budget exceeded!'
                                  : '${(progress * 100).toStringAsFixed(1)}% used',
                              style: TextStyle(
                                color: isOver ? Colors.red : Colors.grey,
                                fontWeight: isOver
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              '${((1 - progress) * 100).clamp(0, 100).toStringAsFixed(1)}% left',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Where the Money Went (This Month)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (categoryRows.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.inbox_outlined,
                            color: Colors.grey.shade500),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No expenses recorded this month yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...categoryRows.map((MapEntry<String, double> entry) {
                  final double share =
                      spent <= 0 ? 0 : entry.value / spent;
                  final double ofBudget = hasBudget
                      ? (entry.value / monthlyBudget).clamp(0.0, 1.0)
                      : 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${provider.moneyShort(entry.value)}  '
                                '(${(share * 100).toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: share,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.orange),
                            ),
                          ),
                          if (hasBudget) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${(ofBudget * 100).toStringAsFixed(0)}% of budget',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: valueColor ?? Colors.black87,
          fontSize: 15,
        ),
      ),
    );
  }
}