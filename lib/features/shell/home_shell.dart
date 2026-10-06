import 'package:flutter/material.dart';
import '../../core/transitions.dart';
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _fabVisible = true;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollUpdateNotification && n.metrics.axis == Axis.vertical) {
      final delta = n.scrollDelta ?? 0;
      if (delta > 6 && _fabVisible)        setState(() => _fabVisible = false);
      else if (delta < -6 && !_fabVisible) setState(() => _fabVisible = true);
    }
    return false;
  }

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
    if (state == AppLifecycleState.paused) {
      context.read<AppState>().lock();
    }
  }

  Future<void> _addTransaction() async {
    await Navigator.of(context).push(
      AppPageRoute(builder: (_) => const TransactionEditor()),
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
                    AppPageRoute(builder: (_) => const SettingsScaffold()),
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
        child: _AddFab(onPressed: _addTransaction),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ─── FAB premium ─────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.royal, AppColors.royalSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: AppColors.royal.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  context.tr('Add'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
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

// ─── Bottom nav bar premium ───────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.grid_view_rounded,        Icons.grid_view_rounded,        'Beranda'),
    (Icons.receipt_long_outlined,    Icons.receipt_long_rounded,     'Riwayat'),
    (Icons.donut_large_outlined,     Icons.donut_large_rounded,      'Anggaran'),
    (Icons.flag_outlined,            Icons.flag_rounded,             'Target'),
    (Icons.show_chart_rounded,       Icons.insights_rounded,         'Grafik'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.void1 : AppColors.frostCard;
    final border = isDark ? const Color(0xFF1A2036) : const Color(0xFFE4EAF8);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final (iconOff, iconOn, label) = _items[i];
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: _NavItem(
                    icon:     selected ? iconOn : iconOff,
                    label:    label,
                    selected: selected,
                    isDark:   isDark,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
  });

  final IconData icon;
  final String   label;
  final bool     selected;
  final bool     isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor  = AppColors.royal;
    final inactiveColor= isDark ? AppColors.textMuted : AppColors.textMutedL;
    final color        = selected ? activeColor : inactiveColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.royal.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize:   10.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color:      color,
            letterSpacing: 0.1,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

// ─── FAB reveal on scroll ─────────────────────────────────────────────────────

class _ScrollReveal extends StatelessWidget {
  const _ScrollReveal({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

// ─── Settings scaffold ────────────────────────────────────────────────────────

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
