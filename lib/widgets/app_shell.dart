import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

/// Root of the navigation stack.
///
/// Every section switch keeps this route, so the system back button returns
/// to the dashboard instead of exiting the app.
const String _homeRoute = '/home';

/// One entry in the sidebar.
class _NavItem {
  final String label;
  final IconData icon;
  final String route;

  const _NavItem(this.label, this.icon, this.route);
}

const List<_NavItem> _navItems = <_NavItem>[
  _NavItem('Overview', Icons.grid_view_rounded, _homeRoute),
  _NavItem('Transactions', Icons.swap_horiz_rounded, '/history'),
  _NavItem('Budget', Icons.account_balance_wallet_rounded, '/budget'),
  _NavItem('Reports', Icons.bar_chart_rounded, '/reports'),
  _NavItem('Profile', Icons.person_rounded, '/profile'),
  _NavItem('Settings', Icons.settings_rounded, '/settings'),
];

/// Responsive app chrome: a persistent dark sidebar on wide screens and a
/// drawer on narrow ones, plus the light top bar.
///
/// Screens supply only their body — the shell owns navigation so every screen
/// keeps the same look and the active item stays highlighted.
class AppShell extends StatelessWidget {
  final String title;
  final String activeRoute;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget> actions;

  /// Width at which the sidebar becomes permanently visible.
  static const double kBreakpoint = 1000;

  const AppShell({
    super.key,
    required this.title,
    required this.activeRoute,
    required this.body,
    this.floatingActionButton,
    this.actions = const <Widget>[],
  });

  void _go(BuildContext context, String route) {
    if (route == activeRoute) return;

    // The sidebar is a section switcher, so switching sections replaces the
    // previous one instead of stacking. '/home' is deliberately kept as the
    // root: dropping it too would leave a single-entry stack, and the system
    // back button would exit the app instead of returning to the dashboard.
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (Route<void> route) => route.settings.name == _homeRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= kBreakpoint;

        if (wide) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                _Sidebar(
                  activeRoute: activeRoute,
                  onSelect: (String route) => _go(context, route),
                ),
                Expanded(
                  child: _Content(
                    title: title,
                    actions: actions,
                    showMenu: false,
                    body: body,
                    floatingActionButton: floatingActionButton,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          drawer: Drawer(
            backgroundColor: AppColors.sidebar,
            child: _Sidebar(
              activeRoute: activeRoute,
              onSelect: (String route) {
                Navigator.of(context).pop();
                _go(context, route);
              },
            ),
          ),
          body: _Content(
            title: title,
            actions: actions,
            showMenu: true,
            body: body,
            floatingActionButton: floatingActionButton,
          ),
        );
      },
    );
  }
}

/// The light top bar plus the screen body.
class _Content extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool showMenu;
  final Widget body;
  final Widget? floatingActionButton;

  const _Content({
    required this.title,
    required this.actions,
    required this.showMenu,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final String name = provider.user.name;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        // A real AppBar title keeps screen identity discoverable to both
        // users and automated tests.
        title: Text(title),
        automaticallyImplyLeading: false,
        leading: showMenu
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        actions: <Widget>[
          ...actions,
          // Global search hands off to the History screen, which owns the
          // actual filtering.
          if (MediaQuery.sizeOf(context).width >= 600)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 210,
                height: 40,
                child: TextField(
                  onSubmitted: (String query) {
                    if (query.trim().isEmpty) return;
                    provider.setGlobalSearch(query.trim());
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/history',
                      (Route<void> route) => route.settings.name == _homeRoute,
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Badge(
              backgroundColor: AppColors.pink,
              smallSize: 8,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            tooltip: 'Notifications',
            onPressed: () => _showNotifications(context, provider),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 16),
            child: _Avatar(name: name),
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  void _showNotifications(BuildContext context, FinanceProvider provider) {
    final bool overBudget = provider.isOverBudget;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                if (!provider.notificationsEnabled)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_off_outlined),
                    title: Text('Reminders are turned off'),
                    subtitle: Text('Enable them in Settings.'),
                  )
                else ...<Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      overBudget ? Icons.warning_amber_rounded : Icons.check_circle,
                      color: overBudget ? AppColors.expense : AppColors.income,
                    ),
                    title: Text(
                      overBudget
                          ? 'You are over budget'
                          : 'You are on track',
                    ),
                    subtitle: Text(
                      overBudget
                          ? 'This month is already above your limit.'
                          : 'Spending is within your monthly budget.',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome, color: AppColors.purple),
                    title: Text(
                      '${provider.transactions.length} transactions tracked',
                    ),
                    subtitle: Text(
                      'Balance ${provider.money(provider.balance)}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Circular user avatar with a coloured initial.
class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 17,
      backgroundColor: AppColors.violet.withValues(alpha: 0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: AppColors.purple,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The dark gradient sidebar shown on wide screens and in the drawer.
class _Sidebar extends StatelessWidget {
  final String activeRoute;
  final ValueChanged<String> onSelect;

  const _Sidebar({required this.activeRoute, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final String name = provider.user.name;
    final String email = provider.user.email;

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF232463), AppColors.sidebar],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Brand(),
            const SizedBox(height: 8),
            for (final _NavItem item in _navItems)
              _SidebarTile(
                item: item,
                selected: item.route == activeRoute,
                onTap: () => onSelect(item.route),
              ),
            const Spacer(),
            _UserCard(name: name, email: email),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppGradients.orangeCoral,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pie_chart, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          // Flexible so the wordmark ellipsises instead of overflowing in the
          // narrower drawer.
          const Flexible(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Finance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: 'Tracker',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(
                  item.icon,
                  size: 19,
                  color: selected ? Colors.white : Colors.white60,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
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

/// The account card pinned to the bottom of the sidebar.
class _UserCard extends StatelessWidget {
  final String name;
  final String email;

  const _UserCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.orange,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name.isEmpty ? 'Guest' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      email.isEmpty ? 'Not signed in' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}