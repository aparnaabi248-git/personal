import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/custom_button.dart';

class AddTransactionScreen extends StatefulWidget {
  /// When non-null, the screen runs in "edit" mode.
  final TransactionModel? editTransaction;

  /// Pre-selected direction, e.g. `'Income'` from the dashboard shortcut.
  final String? initialType;

  const AddTransactionScreen({
    super.key,
    this.editTransaction,
    this.initialType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static const String _income = 'Income';
  static const String _expense = 'Expense';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _transactionType = _expense;
  late String _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  static const List<String> _expenseCategories = <String>[
    'Food',
    'Travel',
    'Shopping',
    'Medical',
    'Education',
    'Entertainment',
    'Bills',
    'Others',
  ];

  static const List<String> _incomeCategories = <String>[
    'Salary',
    'Business',
    'Bonus',
    'Investment',
    'Gift',
    'Others',
  ];

  bool get _isEdit => widget.editTransaction != null;

  List<String> get _categories =>
      _transactionType == _income ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();

    // The dashboard passes 'Income' or 'Expense' to preselect the direction.
    final String initial = widget.initialType ?? _expense;
    if (initial == _income || initial == _expense) {
      _transactionType = initial;
    }
    _selectedCategory = _categories.first;

    final TransactionModel? tx = widget.editTransaction;
    if (tx != null) {
      _amountController.text = tx.amount.toStringAsFixed(2);
      _noteController.text = tx.note;
      _transactionType = tx.type;
      // Guard against a stored category that is no longer in the list.
      _selectedCategory = _categories.contains(tx.category)
          ? tx.category
          : _categories.first;
      _selectedDate = tx.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // A future-dated transaction is almost always a typo.
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    final FinanceProvider provider = context.read<FinanceProvider>();
    setState(() => _isSaving = true);

    final String note = _noteController.text.trim();

    try {
      if (_isEdit) {
        await provider.editTransaction(
          TransactionModel(
            id: widget.editTransaction!.id,
            amount: amount,
            category: _selectedCategory,
            type: _transactionType,
            note: note,
            date: _selectedDate,
          ),
        );
      } else {
        await provider.addTransaction(
          TransactionModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            amount: amount,
            category: _selectedCategory,
            type: _transactionType,
            note: note,
            date: _selectedDate,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Transaction updated'
                : 'Transaction saved as ${provider.money(amount)}',
          ),
          backgroundColor: _isEdit ? Colors.blue : Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();

    return AppShell(
      title: _isEdit ? 'Edit Transaction' : 'Add Transaction',
      activeRoute: '/addTransaction',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Income / Expense selector
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: _expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment<String>(
                    value: _income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: <String>{_transactionType},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    _transactionType = selection.first;
                    _selectedCategory = _categories.first;
                  });
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Text(
                    provider.currency.symbol,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                validator: (value) {
                  final String text = (value ?? '').trim();
                  if (text.isEmpty) return 'Enter an amount';
                  final double? parsed = double.tryParse(text);
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories
                    .map((String c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(110, 40),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _pickDate,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              CustomButton(
                text: _isEdit ? 'Update Transaction' : 'Save Transaction',
                icon: Icons.save,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}