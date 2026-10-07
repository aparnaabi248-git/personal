import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../widgets/app_shell.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  static const Map<String, IconData> _categoryIcons = <String, IconData>{
    'Food': Icons.fastfood,
    'Travel': Icons.directions_bus,
    'Shopping': Icons.shopping_bag,
    'Medical': Icons.medical_services,
    'Education': Icons.school,
    'Entertainment': Icons.movie,
    'Bills': Icons.receipt,
    'Salary': Icons.work,
    'Business': Icons.business,
    'Bonus': Icons.card_giftcard,
    'Investment': Icons.trending_up,
    'Gift': Icons.redeem,
    'Others': Icons.category,
  };

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();

    final double totalIncome = provider.totalIncome;
    final double totalExpense = provider.totalExpense;
    final double savings = provider.balance;
    final Map<String, double> expenseByCategory = provider.expenseByCategory;

    return AppShell(
      title: 'Financial Reports',
      activeRoute: '/reports',
      body: provider.transactions.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(22),
              children: [
                _headline(context, totalIncome, totalExpense),

                const SizedBox(height: 16),

                _balanceCard(context, savings),

                const SizedBox(height: 28),

                const _SectionTitle('Income vs Expense Split'),
                const SizedBox(height: 16),

                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 45,
                      sections: _pieSections(provider, totalIncome, totalExpense),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: Wrap(
                    spacing: 20,
                    children: <Widget>[
                      _legend(Colors.green, 'Income'),
                      _legend(Colors.red, 'Expense'),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const _SectionTitle('Total Comparison'),
                const SizedBox(height: 16),

                SizedBox(
                  height: 200,
                  child: _incomeExpenseBars(context, totalIncome, totalExpense),
                ),

                const SizedBox(height: 28),

                const _SectionTitle('Last 6 Months'),
                const SizedBox(height: 16),

                SizedBox(
                  height: 220,
                  child: _trendChart(context),
                ),

                const SizedBox(height: 28),

                const _SectionTitle('Expense by Category'),
                const SizedBox(height: 12),

                if (expenseByCategory.isEmpty)
                  const Text(
                    'No expenses to break down yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  ..._categoryBreakdown(context, provider, expenseByCategory),

                const SizedBox(height: 24),

                _statsCard(provider),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ------------------------------------------------------------------
  // Sections
  // ------------------------------------------------------------------

  Widget _headline(
    BuildContext context,
    double totalIncome,
    double totalExpense,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            color: Colors.green,
            label: 'Income',
            value: context.read<FinanceProvider>().moneyShort(totalIncome),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_down,
            color: Colors.red,
            label: 'Expense',
            value: context.read<FinanceProvider>().moneyShort(totalExpense),
          ),
        ),
      ],
    );
  }

  Widget _balanceCard(BuildContext context, double savings) {
    final bool positive = savings >= 0;
    final Color color = positive ? Colors.blue : Colors.red;

    return Card(
      color: positive ? Colors.blue.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Icon(Icons.account_balance_wallet, color: color, size: 40),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Current Balance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  context.read<FinanceProvider>().money(savings),
                  style: TextStyle(
                    fontSize: 22,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _pieSections(
    FinanceProvider provider,
    double totalIncome,
    double totalExpense,
  ) {
    final double combined = totalIncome + totalExpense;
    if (combined <= 0) return <PieChartSectionData>[];

    final List<PieChartSectionData> sections = <PieChartSectionData>[];

    if (totalIncome > 0) {
      sections.add(PieChartSectionData(
        value: totalIncome,
        color: Colors.green,
        radius: 70,
        title: '${(totalIncome / combined * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    if (totalExpense > 0) {
      sections.add(PieChartSectionData(
        value: totalExpense,
        color: Colors.red,
        radius: 70,
        title: '${(totalExpense / combined * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    return sections;
  }

  Widget _incomeExpenseBars(
    BuildContext context,
    double totalIncome,
    double totalExpense,
  ) {
    final double peak =
        (totalIncome > totalExpense ? totalIncome : totalExpense) * 1.25;
    final double maxY = peak <= 0 ? 100 : peak;

    return BarChart(
      BarChartData(
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value != 0 && value != 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    value == 0 ? 'Income' : 'Expense',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          BarChartGroupData(
            x: 0,
            barRods: <BarChartRodData>[
              _rod(totalIncome, Colors.green),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: <BarChartRodData>[
              _rod(totalExpense, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendChart(BuildContext context) {
    final List<MonthlyTotal> trend = context.read<FinanceProvider>().monthlyTrend();

    double peak = 0;
    for (final MonthlyTotal m in trend) {
      if (m.income > peak) peak = m.income;
      if (m.expense > peak) peak = m.expense;
    }
    final double maxY = peak <= 0 ? 100 : peak * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= trend.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    trend[index].label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List<BarChartGroupData>.generate(trend.length, (int i) {
          return BarChartGroupData(
            x: i,
            barRods: <BarChartRodData>[
              _rod(trend[i].income, Colors.green, width: 9),
              _rod(trend[i].expense, Colors.red, width: 9),
            ],
          );
        }),
      ),
    );
  }

  BarChartRodData _rod(double value, Color color, {double width = 45}) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: width,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
      ),
    );
  }

  List<Widget> _categoryBreakdown(
    BuildContext context,
    FinanceProvider provider,
    Map<String, double> byCategory,
  ) {
    final double total = provider.totalExpense;
    final List<MapEntry<String, double>> rows = byCategory.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));

    return rows.map((MapEntry<String, double> entry) {
      final double share = total <= 0 ? 0 : entry.value / total;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _categoryIcons[entry.key] ?? Icons.category,
                  color: Colors.deepPurple,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  provider.moneyShort(entry.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(share * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.deepPurple),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _statsCard(FinanceProvider provider) {
    final int count = provider.transactions.length;
    final double sum = provider.transactions.fold<double>(
      0,
      (double s, t) => s + t.amount,
    );
    final double average = count == 0 ? 0 : sum / count;
    final double savingsRate =
        provider.totalIncome <= 0 ? 0 : provider.balance / provider.totalIncome;

    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _statRow('Total Transactions', '$count'),
            _statRow('Average Transaction', provider.money(average)),
            _statRow('Largest Single Entry',
                provider.money(provider.transactions.isEmpty ? 0 : _largest(provider))),
            _statRow(
              'Savings Rate',
              provider.totalIncome <= 0
                  ? '—'
                  : '${(savingsRate * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  static double _largest(FinanceProvider provider) {
    double max = 0;
    for (final t in provider.transactions) {
      if (t.amount > max) max = t.amount;
    }
    return max;
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// --------------------------------------------------------------------
// Small presentational pieces
// --------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.bar_chart, size: 70, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No transactions yet.\nAdd some to see your report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tip: Settings → Load Sample Data fills the app with demo entries.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}