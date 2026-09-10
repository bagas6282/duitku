import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../widgets/transaction_tile.dart';
import '../dashboard/show_month_picker.dart';
import 'transaction_editor.dart';
import '../../core/strings.dart';

/// Transactions tab: searchable, filterable, grouped by day.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _search = TextEditingController();
  TxType? _typeFilter;
  int? _categoryFilter;
  int? _walletFilter;

  bool get _hasFilter =>
      _typeFilter != null || _categoryFilter != null || _walletFilter != null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Transaction> _filtered(AppState state) {
    final q = _search.text.trim().toLowerCase();
    return state.transactions.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter) {
        return false;
      }
      if (_walletFilter != null && t.walletId != _walletFilter) return false;
      if (q.isNotEmpty) {
        final note = t.note?.toLowerCase() ?? '';
        final catName = state.categoryOf(t.categoryId)?.name.toLowerCase() ?? '';
        if (!note.contains(q) && !catName.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
      _walletFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final items = _filtered(state);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: context.tr('Search notes and categories'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MonthChip(state: state),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: !_hasFilter,
                      onTap: _clearFilters,
                    ),
                    _FilterChip(
                      label: context.tr('Expense'),
                      selected: _typeFilter == TxType.expense,
                      color: AppColors.expense,
                      onTap: () => setState(() {
                        _typeFilter = _typeFilter == TxType.expense
                            ? null
                            : TxType.expense;
                      }),
                    ),
                    _FilterChip(
                      label: context.tr('Income'),
                      selected: _typeFilter == TxType.income,
                      color: AppColors.mint,
                      onTap: () => setState(() {
                        _typeFilter = _typeFilter == TxType.income
                            ? null
                            : TxType.income;
                      }),
                    ),
                    if (state.categories.length > 1) ...[
                      const _ChipDivider(),
                      for (final c in state.categories.take(8))
                        _FilterChip(
                          label: context.tr(c.name),
                          selected: _categoryFilter == c.id,
                          color: AppColors.categorical[
                              c.colorIndex % AppColors.categorical.length],
                          onTap: () => setState(() {
                            _categoryFilter =
                                _categoryFilter == c.id ? null : c.id;
                          }),
                        ),
                    ],
                    if (state.wallets.length > 1) ...[
                      const _ChipDivider(),
                      for (final w in state.wallets)
                        _FilterChip(
                          label: context.tr(w.name),
                          selected: _walletFilter == w.id,
                          color: AppColors.info,
                          onTap: () => setState(() {
                            _walletFilter =
                                _walletFilter == w.id ? null : w.id;
                          }),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyState(
                  hasFilter: _hasFilter || _search.text.isNotEmpty,
                  onClear: () {
                    _search.clear();
                    _clearFilters();
                  },
                )
              : _GroupedList(
                  items: items,
                  state: state,
                  onTap: (t) => _openEditor(t, state),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                '${items.length} shown',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const Spacer(),
              if (_hasFilter)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: Text(context.tr('Clear filters')),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditor(Transaction t, AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionEditor(initial: t),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mint.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => showMonthPicker(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: AppColors.mint,
              ),
              const SizedBox(width: 6),
              Text(
                Formatters.monthShort(state.month),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final accent = color ?? AppColors.mint;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.16) : fg.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : fg.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.items,
    required this.state,
    required this.onTap,
  });

  final List<Transaction> items;
  final AppState state;
  final void Function(Transaction) onTap;

  @override
  Widget build(BuildContext context) {
    // Group by calendar day so the list reads as a statement.
    final groups = <String, List<Transaction>>{};
    for (final t in items) {
      final key = Formatters.dayKey(t.date);
      groups.putIfAbsent(key, () => []).add(t);
    }

    final orderedKeys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: orderedKeys.length,
      itemBuilder: (context, i) {
        final key = orderedKeys[i];
        final dayItems = groups[key]!;
        final dayTotal = dayItems.fold<num>(
          0,
          (sum, t) => sum + (t.type == TxType.income ? t.amount : -t.amount),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, 4),
              child: Row(
                children: [
                  Text(
                    Formatters.dayHeader(dayItems.first.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.signedCurrency(dayTotal),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dayTotal >= 0 ? AppColors.mint : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 2,
                ),
                child: Column(
                  children: [
                    for (final t in dayItems)
                      TransactionTile(
                        transaction: t,
                        categoryName:
                            context.tr(state.categoryOf(t.categoryId)?.name ?? '—'),
                        icon: _icon(state.categoryOf(t.categoryId)),
                        color: _color(state.categoryOf(t.categoryId)),
                        onTap: () => onTap(t),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _icon(Category? c) {
    if (c == null) return Icons.swap_horiz_rounded;
    return IconData(c.iconCode, fontFamily: 'MaterialIcons');
  }

  Color _color(Category? c) {
    if (c == null) return AppColors.info;
    return AppColors.categorical[c.colorIndex % AppColors.categorical.length];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter, required this.onClear});

  final bool hasFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter ? Icons.search_off_rounded : Icons.receipt_long_outlined,
            size: 34,
            color: muted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasFilter ? context.tr('Nothing matches those filters') : context.tr('No transactions yet'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted),
          ),
          if (hasFilter) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onClear, child: Text(context.tr('Clear filters'))),
          ],
        ],
      ),
    );
  }
}
