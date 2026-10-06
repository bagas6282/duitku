import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/budget.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../../core/strings.dart';

/// Add/edit a monthly category budget.
class BudgetEditor extends StatefulWidget {
  const BudgetEditor({super.key, this.initial});

  final Budget? initial;

  @override
  State<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<BudgetEditor> {
  final _amount = TextEditingController();
  int? _categoryId;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    if (b != null) {
      _categoryId = b.categoryId;
      _amount.text = Formatters.thousands(b.limitAmount);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  num get _parsed {
    final digits = _amount.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return num.tryParse(digits) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);

    // Budgets only make sense against expenses.
    final cats = state.categoriesFor(TxType.expense);
    final categoryId = cats.any((c) => c.id == _categoryId)
        ? _categoryId
        : (cats.isNotEmpty ? cats.first.id : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.tr('Edit budget') : context.tr('New budget')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: context.tr('Delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(state),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            context.tr('MONTHLY LIMIT'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text(
                'Rp',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _amount,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_MoneyFormatter()],
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.2),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final preset in const [500000, 1000000, 2000000, 5000000])
                _Preset(
                  label: Formatters.compact(preset),
                  onTap: () => setState(
                    () => _amount.text = Formatters.thousands(preset),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('CATEGORY'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CategoryPicker(
            categories: cats,
            selectedId: categoryId,
            onSelect: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_parsed > 0) _Preview(limit: _parsed),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            // The condition must be evaluated here, not inside a closure: a
            // closure is always a non-null onPressed, so the button stayed
            // enabled and tapping it with no amount ran the null branch.
            onPressed: _saving || _parsed <= 0 || categoryId == null
                ? null
                : () => _save(state, categoryId),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? context.tr('Save changes') : context.tr('Add budget')),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppState state, int categoryId) async {
    setState(() => _saving = true);
    final budget = Budget(
      id: widget.initial?.id,
      categoryId: categoryId,
      monthKey: state.monthKey,
      limitAmount: _parsed,
    );

    try {
      await state.saveBudget(budget);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${context.tr('Could not save')}: $e')));
    }
  }

  Future<void> _confirmDelete(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete budget?')),
        content: Text(context.tr('Spending history is kept.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    final id = widget.initial?.id;
    if (ok != true || id == null) return;
    await state.deleteBudget(id);
    if (mounted) Navigator.pop(context);
  }
}

class _MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = Formatters.thousands(num.tryParse(digits) ?? 0);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: fg.withOpacity(0.05),
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
              fontWeight: FontWeight.w600,
              color: fg.withOpacity(0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final c in categories)
          GestureDetector(
            onTap: () => onSelect(c.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selectedId == c.id
                    ? AppColors
                        .categorical[c.colorIndex % AppColors.categorical.length]
                        .withOpacity(0.18)
                    : fg.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selectedId == c.id
                      ? AppColors.categorical[
                          c.colorIndex % AppColors.categorical.length]
                      : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.fromCode(c.iconCode),
                    size: 16,
                    color: AppColors
                        .categorical[c.colorIndex % AppColors.categorical.length],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(c.name),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.limit});

  final num limit;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.mint.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'That is about ${Formatters.currency((limit / 30).round())} a day '
              'over a 30-day month.',
              style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
