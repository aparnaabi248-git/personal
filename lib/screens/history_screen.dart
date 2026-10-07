import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'All'; // 'All' | 'Income' | 'Expense'

  @override
  void initState() {
    super.initState();
    // The top-bar search hands its query over through the provider, so the
    // history screen opens already filtered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String incoming = context.read<FinanceProvider>().globalSearch;
      if (incoming.isNotEmpty) {
        _searchController.text = incoming;
        setState(() => _searchQuery = incoming);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filtered(List<TransactionModel> transactions) {
    final String query = _searchQuery.trim().toLowerCase();

    return transactions.where((TransactionModel tx) {
      final bool matchesSearch = query.isEmpty ||
          tx.category.toLowerCase().contains(query) ||
          tx.note.toLowerCase().contains(query);
      final bool matchesFilter =
          _filterType == 'All' || tx.type == _filterType;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _confirmDelete(TransactionModel tx) async {
    final FinanceProvider provider = context.read<FinanceProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Delete "${tx.category}" of ${provider.money(tx.amount)}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await provider.deleteTransaction(tx.id);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Transaction deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _editTransaction(TransactionModel tx) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddTransactionScreen(editTransaction: tx),
      ),
    );
  }

  void _showDetails(TransactionModel tx) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Transaction Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Category', tx.category),
            _detailRow('Amount', context.read<FinanceProvider>().money(tx.amount)),
            _detailRow('Type', tx.type),
            _detailRow(
              'Date',
              '${tx.date.day}/${tx.date.month}/${tx.date.year}',
            ),
            if (tx.note.isNotEmpty) _detailRow('Note', tx.note),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final List<TransactionModel> visible = _filtered(provider.transactions);

    // Totals for whatever is currently visible, not for all transactions.
    final double visibleIncome = visible
        .where((TransactionModel t) => t.type == 'Income')
        .fold<double>(0, (double s, TransactionModel t) => s + t.amount);
    final double visibleExpense = visible
        .where((TransactionModel t) => t.type == 'Expense')
        .fold<double>(0, (double s, TransactionModel t) => s + t.amount);

    return AppShell(
      title: 'Transaction History',
      activeRoute: '/history',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const AddTransactionScreen()),
        ),
        backgroundColor: AppColors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (String v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by category or note',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
              ),
            ),

            const SizedBox(height: 10),

            // Filter chips
            Row(
              children: <String>['All', 'Income', 'Expense'].map((String type) {
                final bool selected = _filterType == type;
                final Color chipColor = type == 'Income'
                    ? AppColors.income.withValues(alpha: 0.18)
                    : type == 'Expense'
                        ? AppColors.expense.withValues(alpha: 0.18)
                        : AppColors.indigo.withValues(alpha: 0.18);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: selected,
                    selectedColor: chipColor,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filterType = type),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            if (visible.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${visible.length} item${visible.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '+${provider.moneyShort(visibleIncome)}  '
                        '-${provider.moneyShort(visibleExpense)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty && _filterType == 'All'
                                ? Icons.receipt_long
                                : Icons.search_off,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isEmpty && _filterType == 'All'
                                ? 'No transactions yet'
                                : 'No matching transactions',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.grey),
                          ),
                          if (_searchQuery.isEmpty && _filterType == 'All')
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Tap Add to record your first entry.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int index) {
                        final TransactionModel tx = visible[index];

                        return TransactionCard(
                          category: tx.category,
                          date:
                              '${tx.date.day}/${tx.date.month}/${tx.date.year}'
                              '${tx.note.isNotEmpty ? '  •  ${tx.note}' : ''}',
                          amount: tx.amount,
                          type: tx.type,
                          onTap: () => _showDetails(tx),
                          onEdit: () => _editTransaction(tx),
                          onDelete: () => _confirmDelete(tx),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}