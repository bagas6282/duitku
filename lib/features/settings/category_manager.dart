import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/category.dart';
import '../../core/strings.dart';

/// Manage spending and income categories.
class CategoryManager extends StatelessWidget {
  const CategoryManager({super.key});

  /// A small, deliberately opinionated icon set — enough to cover personal
  /// finance without turning the picker into a wall of glyphs.
  static const List<IconData> icons = [
    Icons.restaurant_rounded,
    Icons.local_cafe_rounded,
    Icons.shopping_bag_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.bolt_rounded,
    Icons.wifi_rounded,
    Icons.phone_android_rounded,
    Icons.medical_services_rounded,
    Icons.health_and_safety_rounded,
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.more_horiz_rounded,
    Icons.payments_rounded,
    Icons.savings_rounded,
    Icons.sports_esports_rounded,
    Icons.movie_rounded,
    Icons.fitness_center_rounded,
    Icons.pets_rounded,
    Icons.flight_rounded,
    Icons.card_giftcard_rounded,
    Icons.work_rounded,
    Icons.trending_up_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.receipt_long_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    final expenses = state.categories.where((c) => !c.isIncome).toList();
    final incomes = state.categories.where((c) => c.isIncome).toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Categories'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add category')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          100,
        ),
        children: [
          _GroupHeader(label: context.tr('Expense'), count: expenses.length, muted: muted),
          for (final c in expenses) _CategoryTile(category: c),
          const SizedBox(height: AppSpacing.lg),
          _GroupHeader(label: context.tr('Income'), count: incomes.length, muted: muted),
          for (final c in incomes) _CategoryTile(category: c),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const CategoryEditor()),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.muted,
  });

  final String label;
  final int count;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, AppSpacing.sm),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final accent = AppColors
        .categorical[category.colorIndex % AppColors.categorical.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 2,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              AppIcons.fromCode(category.iconCode),
              size: 18,
              color: accent,
            ),
          ),
          title: Text(
            context.tr(category.name),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
          trailing: IconButton(
            tooltip: context.tr('Archive'),
            icon: Icon(
              Icons.archive_outlined,
              size: 19,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.4),
            ),
            onPressed: () => _confirmArchive(context, state),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.tr('Archive')} ${context.tr(category.name)}?'),
        content: const Text(
          'Past transactions keep their category. It just stops appearing in '
          'the pickers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Archive')),
          ),
        ],
      ),
    );
    if (ok == true) await state.archiveCategory(category.id);
  }
}

class CategoryEditor extends StatefulWidget {
  const CategoryEditor({super.key});

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final _name = TextEditingController();
  bool _isIncome = false;
  int _iconCode = CategoryManager.icons.first.codePoint;
  int _colorIndex = 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    final accent = _isIncome
        ? AppColors.mint
        : AppColors.categorical[_colorIndex % AppColors.categorical.length];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('New category'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                _DirectionTab(
                  label: context.tr('Expense'),
                  active: !_isIncome,
                  color: AppColors.danger,
                  onTap: () => setState(() => _isIncome = false),
                ),
                _DirectionTab(
                  label: context.tr('Income'),
                  active: _isIncome,
                  color: AppColors.mint,
                  onTap: () => setState(() => _isIncome = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'NAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: 'e.g. Groceries',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'ICON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final icon in CategoryManager.icons)
                GestureDetector(
                  onTap: () => setState(() => _iconCode = icon.codePoint),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _iconCode == icon.codePoint
                          ? accent.withOpacity(0.18)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: _iconCode == icon.codePoint
                            ? accent
                            : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: _iconCode == icon.codePoint ? accent : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('COLOR'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < AppColors.categorical.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.categorical[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorIndex == i
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _saving || _name.text.trim().isEmpty
                ? null
                : () => _save(state),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
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
                : Text(context.tr('Add category')),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppState state) async {
    setState(() => _saving = true);
    try {
      await state.addCategory(
        _name.text.trim(),
        _iconCode,
        _colorIndex,
        isIncome: _isIncome,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${context.tr('Could not save')}: $e')));
    }
  }
}

class _DirectionTab extends StatelessWidget {
  const _DirectionTab({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          margin: const EdgeInsets.all(4),
          height: 40,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : fg.withOpacity(0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
