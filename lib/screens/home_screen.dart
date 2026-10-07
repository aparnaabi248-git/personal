import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

/// The colourful overview dashboard.
///
/// Layout mirrors a typical analytics console: a row of gradient stat tiles,
/// then a balance/activity/chart band, then two wider analysis cards. Every
/// band collapses to a single column on narrow screens.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Content width at which the dashboard shows its stat tiles in one row and
  /// balances/revenues/activity side by side.
  ///
  /// Measured against the body width, which excludes the 250px sidebar.
  static const double _wideBreakpoint = 1100;

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();

    final List<MonthlyTotal> trend = provider.monthlyTrend();
    final MonthlyTotal current = trend.isEmpty
        ? const MonthlyTotal(label: '', income: 0, expense: 0)
        : trend.last;
    final MonthlyTotal previous = trend.length < 2
        ? const MonthlyTotal(label: '', income: 0, expense: 0)
        : trend[trend.length - 2];

    return AppShell(
      title: 'Overview',
      activeRoute: '/home',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/addTransaction'),
        backgroundColor: AppColors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
      body: provider.isLoading && !provider.hasLoaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool veryWide =
                    constraints.maxWidth >= _wideBreakpoint;

                return RefreshIndicator(
                  onRefresh: provider.loadAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(22),
                    children: <Widget>[
                      const _PageHeading(),
                      const SizedBox(height: 20),

                      // Stat tiles
                      _StatTileRow(
                        compact: !veryWide,
                        tiles: <Widget>[
                          _GradientStat(
                            label: 'Monthly Income',
                            value: provider.moneyShort(current.income),
                            delta: _delta(current.income, previous.income),
                            upIsGood: true,
                            gradient: AppGradients.violetBlue,
                          ),
                          _GradientStat(
                            label: 'Monthly Expense',
                            value: provider.moneyShort(current.expense),
                            delta: _delta(current.expense, previous.expense),
                            upIsGood: false,
                            gradient: AppGradients.orangeCoral,
                          ),
                          _GradientStat(
                            label: 'Avg. Income',
                            value: provider.moneyShort(provider.averageMonthlyIncome),
                            delta: _delta(current.income, previous.income),
                            upIsGood: true,
                            gradient: AppGradients.blueCyan,
                          ),
                          _GradientStat(
                            label: 'Avg. Expense',
                            value:
                                provider.moneyShort(provider.averageMonthlyExpense),
                            delta: _delta(current.expense, previous.expense),
                            upIsGood: false,
                            gradient: AppGradients.tealGreen,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Balance / revenues / activity
                      if (veryWide)
                        Row(
                          // `start` rather than `stretch`: the three cards
                          // hold different amounts of data, so forcing one
                          // height would either clip or leave dead space.
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                              SizedBox(
                                width: 300,
                                child: _BalanceColumn(provider: provider),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 3,
                                child: _RevenuesCard(
                                  title: 'Total Revenues',
                                  trend: trend,
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 300,
                                child: _RecentActivityCard(provider: provider),
                              ),
                            ],
                        )
                      else ...<Widget>[
                        _BalanceColumn(provider: provider),
                        const SizedBox(height: 20),
                        _RevenuesCard(title: 'Total Revenues', trend: trend),
                        const SizedBox(height: 20),
                        _RecentActivityCard(provider: provider),
                      ],

                      const SizedBox(height: 20),

                      // Analysis cards
                      _EarningsCard(provider: provider, trend: trend),
                      const SizedBox(height: 20),
                      _ExpensesCard(provider: provider),

                      const SizedBox(height: 90),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Month-over-month change as a fraction, guarded against a zero base.
  static double _delta(double now, double before) {
    if (before <= 0) return 0;
    return (now - before) / before;
  }
}

/// Greeting line above the tiles.
class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final DateTime now = DateTime.now();

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                provider.user.name.isEmpty
                    ? 'Welcome back'
                    : 'Hello, ${provider.user.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Here is what is happening with your money today.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          '${_monthName(now.month)} ${now.year}',
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static String _monthName(int month) {
    const List<String> names = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

// --------------------------------------------------------------------
// Stat tiles
// --------------------------------------------------------------------

class _StatTileRow extends StatelessWidget {
  final List<Widget> tiles;
  final bool compact;

  const _StatTileRow({required this.tiles, required this.compact});

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      // Not `stretch`: this Row sits in a ListView, so its height is
      // unbounded. `IntrinsicHeight` gives the tiles a common height without
      // requiring a bounded parent.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 18),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: <Widget>[
        for (final Widget tile in tiles)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 62) / 2,
            child: tile,
          ),
      ],
    );
  }
}

/// A gradient KPI tile: label, value and a signed change chip.
class _GradientStat extends StatelessWidget {
  final String label;
  final String value;
  final double delta;
  final bool upIsGood;
  final LinearGradient gradient;

  const _GradientStat({
    required this.label,
    required this.value,
    required this.delta,
    required this.upIsGood,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final bool rising = delta >= 0;
    final bool good = rising == upIsGood;
    final String sign = rising ? '+' : '-';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$sign${(delta.abs() * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: good ? Colors.white : const Color(0xFFFFE0E0),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// Balance column
// --------------------------------------------------------------------

class _BalanceColumn extends StatelessWidget {
  final FinanceProvider provider;

  const _BalanceColumn({required this.provider});

  @override
  Widget build(BuildContext context) {
    final double balance = provider.balance;
    final bool positive = balance >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'My Balance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'View history',
                    icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                    onPressed: () => Navigator.pushNamed(context, '/history'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                provider.money(balance),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: positive ? AppColors.ink : AppColors.expense,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                provider.totalIncome > 0
                    ? 'Savings rate ${(balance / provider.totalIncome * 100).toStringAsFixed(1)}%'
                    : 'Add income to start tracking',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _BalanceAction(
                      label: 'Add Income',
                      icon: Icons.add,
                      color: AppColors.indigo,
                      onTap: () => _openAdd(context, isIncome: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BalanceAction(
                      label: 'Add Expense',
                      icon: Icons.remove,
                      color: AppColors.coral,
                      onTap: () => _openAdd(context, isIncome: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Income', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    provider.moneyShort(provider.currentMonthIncome),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.income,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('This month', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: AppColors.income,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAdd(BuildContext context, {required bool isIncome}) {
    Navigator.pushNamed(
      context,
      '/addTransaction',
      arguments: isIncome ? 'Income' : 'Expense',
    );
  }
}

class _BalanceAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BalanceAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------
// Surfaces
// --------------------------------------------------------------------

/// The white rounded panel every dashboard card sits on.
class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F1F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[child],
      ),
    );
  }
}

/// Card title with an optional trailing action.
class _CardTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _CardTitle({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// --------------------------------------------------------------------
// Revenues bar chart
// --------------------------------------------------------------------

class _RevenuesCard extends StatelessWidget {
  final String title;
  final List<MonthlyTotal> trend;

  const _RevenuesCard({required this.title, required this.trend});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();

    double peak = 0;
    for (final MonthlyTotal m in trend) {
      if (m.income > peak) peak = m.income;
      if (m.expense > peak) peak = m.expense;
    }

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(
            title: title,
            subtitle: 'Income vs expense, last 6 months',
            trailing: Wrap(
              spacing: 14,
              children: <Widget>[
                _LegendDot(color: AppColors.purple, label: 'Income'),
                _LegendDot(color: AppColors.orange, label: 'Expense'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 230,
            child: trend.isEmpty
                ? const _ChartEmpty()
                : BarChart(
                    BarChartData(
                      maxY: peak <= 0 ? 100 : peak * 1.25,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: peak <= 0 ? 20 : peak / 3,
                        getDrawingHorizontalLine: (double value) => FlLine(
                          color: const Color(0xFFF0F1F8),
                          strokeWidth: 1,
                        ),
                      ),
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
                            reservedSize: 28,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int index = value.toInt();
                              if (index < 0 || index >= trend.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  trend[index].label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List<BarChartGroupData>.generate(
                        trend.length,
                        (int i) => BarChartGroupData(
                          x: i,
                          barRods: <BarChartRodData>[
                            _rod(trend[i].income, AppColors.purple),
                            _rod(trend[i].expense, AppColors.orange),
                          ],
                          barsSpace: 4,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'All-time income ${provider.moneyShort(provider.totalIncome)}  •  '
            'expense ${provider.moneyShort(provider.totalExpense)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static BarChartRodData _rod(double value, Color color) {
    return BarChartRodData(
      toY: value,
      color: color,
      width: 9,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(5),
        topRight: Radius.circular(5),
      ),
    );
  }
}

// --------------------------------------------------------------------
// Recent activity
// --------------------------------------------------------------------

class _RecentActivityCard extends StatelessWidget {
  final FinanceProvider provider;

  const _RecentActivityCard({required this.provider});

  static IconData _iconFor(String category) {
    switch (category) {
      case 'Food':
        return Icons.fastfood;
      case 'Travel':
        return Icons.directions_bus;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Medical':
        return Icons.medical_services;
      case 'Education':
        return Icons.school;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills':
        return Icons.receipt;
      case 'Salary':
        return Icons.work;
      case 'Business':
        return Icons.business;
      case 'Investment':
        return Icons.trending_up;
      default:
        return Icons.account_balance_wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TransactionModel> items = provider.recentTransactions;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(
            title: 'Recent activities',
            trailing: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('See all'),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            for (final TransactionModel tx in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _iconFor(tx.category),
                        size: 18,
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tx.note.isEmpty ? tx.category : tx.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.moneySigned(tx.amount, tx.type == 'Income'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tx.type == 'Income'
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// Earnings line chart
// --------------------------------------------------------------------

class _EarningsCard extends StatelessWidget {
  final FinanceProvider provider;
  final List<MonthlyTotal> trend;

  const _EarningsCard({required this.provider, required this.trend});

  @override
  Widget build(BuildContext context) {
    double peak = 0;
    for (final MonthlyTotal m in trend) {
      if (m.income > peak) peak = m.income;
      if (m.expense > peak) peak = m.expense;
    }

    final String label = trend.isEmpty
        ? ''
        : '${_longMonth(trend.first.label)} — ${_longMonth(trend.last.label)}';

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(
            title: 'Earning Summary',
            subtitle: label,
            trailing: Wrap(
              spacing: 14,
              children: <Widget>[
                _LegendDot(color: AppColors.purple, label: 'Income'),
                _LegendDot(color: AppColors.orange, label: 'Expense'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 240,
            child: trend.isEmpty
                ? const _ChartEmpty()
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: peak <= 0 ? 100 : peak * 1.3,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: peak <= 0 ? 20 : peak / 3,
                        getDrawingHorizontalLine: (double value) => FlLine(
                          color: const Color(0xFFF0F1F8),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
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
                            interval: 1,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int index = value.toInt();
                              if (index < 0 || index >= trend.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  trend[index].label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: const LineTouchData(enabled: true),
                      lineBarsData: <LineChartBarData>[
                        _line(
                          values: trend
                              .map((MonthlyTotal m) => m.income)
                              .toList(),
                          color: AppColors.purple,
                          fill: AppColors.purple,
                        ),
                        _line(
                          values: trend
                              .map((MonthlyTotal m) => m.expense)
                              .toList(),
                          color: AppColors.orange,
                          fill: AppColors.orange,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static LineChartBarData _line({
    required List<double> values,
    required Color color,
    required Color fill,
  }) {
    return LineChartBarData(
      spots: List<FlSpot>.generate(
        values.length,
        (int i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      curveSmoothness: 0.28,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            fill.withValues(alpha: 0.28),
            fill.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }

  /// Expands the short `Mon 26` trend label into `Mon 2026`.
  static String _longMonth(String short) {
    final List<String> parts = short.split(' ');
    return parts.length == 2 ? '${parts[0]} 20${parts[1]}' : short;
  }
}

// --------------------------------------------------------------------
// Expenses donut
// --------------------------------------------------------------------

class _ExpensesCard extends StatelessWidget {
  final FinanceProvider provider;

  const _ExpensesCard({required this.provider});

  static const List<Color> _palette = <Color>[
    AppColors.purple,
    AppColors.orange,
    AppColors.cyan,
    AppColors.pink,
    AppColors.teal,
    AppColors.blue,
    AppColors.violet,
  ];

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> rows =
        provider.expenseByCategory.entries.toList()
          ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
              b.value.compareTo(a.value));
    // Five slices plus an "Other" bucket keeps the donut readable.
    final List<MapEntry<String, double>> top =
        rows.length <= 5 ? rows : rows.take(5).toList();
    final double otherTotal = rows
        .skip(5)
        .fold<double>(0, (double s, MapEntry<String, double> e) => s + e.value);
    final double total = provider.totalExpense;

    final List<MapEntry<String, double>> slices = <MapEntry<String, double>>[
      ...top,
      if (otherTotal > 0)
        MapEntry<String, double>('Other', otherTotal),
    ];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(
            title: 'All Expenses',
            subtitle: 'Spending split by category',
            trailing: Text(
              provider.moneyShort(total),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.coral,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (slices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No expenses recorded yet',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool sideBySide = constraints.maxWidth >= 560;

                final Widget chart = SizedBox(
                  height: 210,
                  width: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 58,
                          startDegreeOffset: -90,
                          sections: List<PieChartSectionData>.generate(
                            slices.length,
                            (int i) {
                              return PieChartSectionData(
                                value: slices[i].value,
                                color: _palette[i % _palette.length],
                                radius: 34,
                                showTitle: false,
                              );
                            },
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            provider.moneyShort(total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final Widget legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < slices.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              slices[i].key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              total <= 0
                                  ? '0%'
                                  : '${(slices[i].value / total * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );

                if (sideBySide) {
                  return Row(
                    children: <Widget>[
                      chart,
                      const SizedBox(width: 26),
                      Expanded(child: legend),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    Center(child: chart),
                    const SizedBox(height: 16),
                    legend,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------
// Shared bits
// --------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No data for this period',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}