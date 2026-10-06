import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/formatters.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../budget/budget_editor.dart';
import '../budget/budget_page.dart';
import '../receipt/receipt_scan_launcher.dart';
import '../shell/home_shell.dart';
import '../widgets/balance_hero.dart';
import '../widgets/budget_bar.dart';
import '../widgets/charts.dart';
import '../widgets/transaction_tile.dart';
import 'show_month_picker.dart';

/// Home tab: balance hero, quick stats, category donut, budget progress and
/// the latest transactions.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.currentUser != null
                    ? 'Halo, ${state.currentUser!.name.trim().split(' ').first} 👋'
                    : 'Duitku',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (state.currentUser != null)
                Text(
                  'Kelola keuanganmu dengan bijak',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.tr('Scan receipt'),
              icon: const Icon(Icons.document_scanner_outlined, color: AppColors.mint),
              onPressed: () => ReceiptScanLauncher.launch(context),
            ),
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            120,
          ),
          sliver: SliverList.list(
            children: [
              BalanceHero(
                balance: state.totalBalance,
                income: state.periodIncome,
                expense: state.periodExpense,
                periodLabel: state.isDaily
                    ? '${Formatters.dayHeader(state.selectedDate)} · ${Formatters.dateShort(state.selectedDate)}'
                    : Formatters.monthYear(state.month),
                isDaily: state.isDaily,
                onToggleMode: (daily) {
                  state.setPeriodMode(
                    daily ? PeriodMode.daily : PeriodMode.monthly,
                  );
                },
                onPrevious: () => state.shiftPeriod(-1),
                onNext: () => state.shiftPeriod(1),
                onTapPick: () async {
                  if (state.isDaily) {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      await state.setSelectedDate(picked);
                    }
                  } else {
                    await showMonthPicker(context);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(
                title: state.isDaily
                    ? '${context.tr('Spending')} (${Formatters.dateShort(state.selectedDate)})'
                    : context.tr('Spending by category'),
                trailing: state.periodExpense > 0
                    ? '${state.periodTransactions.where((t) => t.type == TxType.expense).length} entries'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _CategoryCard(state: state),
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(
                title: context.tr('Budget'),
                trailing: null,
              ),
              const SizedBox(height: AppSpacing.sm),
              _BudgetCard(state: state),
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(
                title: context.tr('Recent'),
                trailing: state.recent.isEmpty ? null : context.tr('Last 8'),
              ),
              const SizedBox(height: AppSpacing.xs),
              _RecentCard(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // Roll the selected period expenses up per category.
    final txs = state.periodTransactions;
    final totals = <int, num>{};
    for (final t in txs) {
      if (t.type != TxType.expense) continue;
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final slices = <DonutSlice>[];
    for (final e in entries) {
      final cat = state.categoryOf(e.key);
      slices.add(
        DonutSlice(
          label: context.tr(cat?.name ?? 'Uncategorized'),
          value: e.value,
          color: AppColors
              .categorical[(cat?.colorIndex ?? 0) % AppColors.categorical.length],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            CategoryDonut(
              slices: slices,
              centerLabel: context.tr('Spent'),
              centerValue: _money(state.periodExpense),
            ),
            if (slices.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.08),
              ),
              const SizedBox(height: AppSpacing.md),
              DonutLegend(slices: slices, total: state.monthExpense),
            ],
          ],
        ),
      ),
    );
  }

  String _money(num v) {
    if (v >= 1000000) return 'Rp${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'Rp${(v / 1000).toStringAsFixed(0)}K';
    return 'Rp${v.toStringAsFixed(0)}';
  }
}

/// Wraps the budget summary in a cached future.
///
/// Creating the future inside `build` restarted it on every rebuild, so the
/// card sat on a spinner forever instead of ever showing the numbers.
class _BudgetCard extends StatefulWidget {
  const _BudgetCard({required this.state});

  final AppState state;

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard> {
  Future<List<BudgetProgress>>? _future;
  int _revision = -1;
  int _dataRev = -1;

  /// True until the first snapshot lands, successful or not, so the card can
  /// never stay behind a spinner.
  bool _firstLoad = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeReload(force: _future == null);
  }

  @override
  void didUpdateWidget(covariant _BudgetCard old) {
    super.didUpdateWidget(old);
    // A different AppState instance means different data entirely.
    if (!identical(old.state, widget.state)) _maybeReload(force: true);
  }

  void _maybeReload({bool force = false}) {
    final state = widget.state;
    // Two inputs: budget edits (budgetsRevision) and transaction edits —
    // adding a single expense already changes how much of a cap is used, and
    // that was invisible here before dataRevision existed.
    if (!force &&
        state.budgetsRevision == _revision &&
        state.dataRevision == _dataRev) {
      return;
    }
    _revision = state.budgetsRevision;
    _dataRev = state.dataRevision;
    _future = state.budgetProgress();
  }

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    _maybeReload();

    return FutureBuilder<List<BudgetProgress>>(
      future: _future,
      builder: (context, snap) {
        // Earlier reads may already have succeeded, so a refresh must not tear
        // the card back down to a spinner — that would unmount the "Set a
        // budget" button mid-tap, which is exactly what made it feel dead.
        if (snap.connectionState == ConnectionState.done) _firstLoad = false;
        if (_firstLoad && !snap.hasData) {
          return const Card(
            child: SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final items = snap.data ?? const <BudgetProgress>[];
        if (items.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  // Deliberately not Icons.savings_*: the piggy bank reads as a
                  // savings goal, and a monthly spending cap is not one.
                  Icon(Icons.donut_large_rounded, size: 30, color: muted),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('No budgets set for this month'),
                    style: TextStyle(fontSize: 13.5, color: muted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    // Opens the budget editor directly instead of navigating to
                    // the Budget tab. The previous `pushNamed('/budget')` threw
                    // because no named routes are registered, so the button did
                    // nothing at all when tapped.
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute(builder: (_) => const BudgetEditor()),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.tr('Set a budget')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(160, 42),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                for (final p in items.take(4))
                  _BudgetRow(progress: p),
                if (items.length > 4) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    // Full page rather than the tab: the tab is behind the
                    // shell, and this button lives inside a pushed route.
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute(
                        builder: (_) => const BudgetScaffold(),
                      ),
                    ),
                    child: Text('+${items.length - 4} more budgets'),
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

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final cat = progress.category;
    final icon = cat == null
        ? Icons.label_outline_rounded
        : AppIcons.fromCode(cat.iconCode);
    return BudgetBar(
      label: context.tr(cat?.name ?? 'Uncategorized'),
      icon: icon,
      spent: progress.spent,
      limit: progress.limit,
      colorIndex: cat?.colorIndex ?? 0,
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    final items = state.isDaily
        ? state.periodTransactions.take(8).toList()
        : state.recent;

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 30, color: muted),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr(
                  state.isDaily
                      ? 'No transactions for this date'
                      : 'No transactions this month',
                ),
                style: TextStyle(fontSize: 13.5, color: muted),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Tap Add to record your first one'),
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            for (final t in items)
              TransactionTile(
                transaction: t,
                categoryName: context.tr(state.categoryOf(t.categoryId)?.name ?? '—'),
                icon: _iconFor(state.categoryOf(t.categoryId)),
                color: _colorFor(state.categoryOf(t.categoryId)),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(Category? c) {
    if (c == null) return Icons.swap_horiz_rounded;
    return AppIcons.fromCode(c.iconCode);
  }

  Color _colorFor(Category? c) {
    if (c == null) return AppColors.info;
    return AppColors.categorical[c.colorIndex % AppColors.categorical.length];
  }
}
