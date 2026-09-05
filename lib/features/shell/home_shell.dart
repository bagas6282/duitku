import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../budget/budget_page.dart';
import '../charts/charts_page.dart';
import '../dashboard/dashboard_page.dart';
import '../goals/goals_page.dart';
import '../settings/settings_page.dart';
import '../transactions/transaction_editor.dart';
import '../transactions/transactions_page.dart';
import '../../core/strings.dart';

/// Root scaffold: four tabs plus a centre action for recording a transaction.
///
/// The add button is a full-width bar above the navigation rather than a FAB —
/// on a phone it is reachable one-handed and never covers the last list row.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  /// Whether the floating add button is showing.
  ///
  /// It slides out of the way while the user reads downwards and returns as
  /// soon as they scroll back up, so it never sits on top of the last row of a
  /// list the user is trying to reach.
  bool _fabVisible = true;

  /// Notified by each tab's scroll view.
  bool _onScroll(ScrollNotification n) {
    // Depth 0 only: the outer view. A notification from a nested horizontal
    // list (the wallet chips, a chart) must not toggle the button.
    if (n.depth != 0) return false;

    // A threshold rather than any delta: a fling arrives as many tiny updates,
    // and reacting to each one made the button flicker mid-gesture.
    if (n is ScrollUpdateNotification &&
        n.metrics.axis == Axis.vertical) {
      final delta = n.scrollDelta ?? 0;
      if (delta > 6 && _fabVisible) {
        setState(() => _fabVisible = false);
      } else if (delta < -6 && !_fabVisible) {
        setState(() => _fabVisible = true);
      }
    }
    // Returning false keeps the notification travelling so RefreshIndicator and
    // the app bar's own scroll behaviour still receive it.
    return false;
  }

  /// Titles follow the selected language, so they are resolved per build
  /// rather than stored once at construction.
  List<String> get _titles => [
        'Duitku',
        context.tr('Transactions'),
        context.tr('Budgets'),
        context.tr('Goals'),
        context.tr('Insights'),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only `paused` means the app actually left the foreground on Android.
    // `inactive` also fires for in-app interruptions — the date picker, the
    // biometric sheet, a permission prompt — and locking on it would demand
    // a passcode in the middle of filling out a form. Hidden is a superset of
    // paused on mobile, so pausing is enough.
    if (state == AppLifecycleState.paused) {
      context.read<AppState>().lock();
    }
  }

  Future<void> _addTransaction() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransactionEditor()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      DashboardPage(),
      TransactionsPage(),
      BudgetPage(),
      GoalsPage(),
      ChartsPage(),
    ];

    return Scaffold(
      appBar: _index == 0
          ? null
          : AppBar(
              title: Text(_titles[_index]),
              actions: [
                IconButton(
                  tooltip: context.tr('Settings'),
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScaffold()),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: IndexedStack(index: _index, children: pages),
      ),
      floatingActionButton: _ScrollReveal(
        visible: _fabVisible,
        child: FloatingActionButton.extended(
          heroTag: 'duitku-fab-add',
          onPressed: _addTransaction,
          backgroundColor: AppColors.mint,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            context.tr('Add'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: context.tr('Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: context.tr('History'),
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: context.tr('Budget'),
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: context.tr('Goals'),
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            selectedIcon: Icon(Icons.insights_rounded),
            label: context.tr('Insights'),
          ),
        ],
      ),
    );
  }
}

/// Slides its child in and out on the vertical axis without unmounting it.
///
/// Kept mounted so the button's own Material state (ripple, focus) survives a
/// scroll, and so a tap in progress is not cancelled by the animation.
class _ScrollReveal extends StatelessWidget {
  const _ScrollReveal({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

/// Settings pushed as its own route, complete with an app bar.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Settings'))),
      body: const SettingsPage(),
    );
  }
}
