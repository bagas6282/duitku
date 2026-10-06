import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/budget.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../../data/models/wallet.dart';
import 'goal_editor.dart';
import '../../core/strings.dart';

/// Goals tab: savings targets with progress rings.
class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Text(
                context.tr('Savings goals'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.goals.isEmpty
              ? _Empty(muted: muted)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    120,
                  ),
                  itemCount: state.goals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final g = state.goals[i];
                    return _GoalCard(
                      goal: g,
                      onTap: () => _open(context, g),
                      onContribute: () => _contribute(context, state, g),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _open(BuildContext context, [SavingsGoal? goal]) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => GoalEditor(initial: goal)),
    );
  }

  Future<void> _contribute(
    BuildContext context,
    AppState state,
    SavingsGoal goal,
  ) async {
    final result = await showModalBottomSheet<_FundResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FundSheet(goal: goal, state: state),
    );
    if (result == null || !context.mounted) return;

    // Pre-capture translations before async operations so context access
    // stays within a known-mounted synchronous window.
    final addFundsLabel = context.tr('Add funds');
    final goalNameLabel = context.tr(goal.name);
    final goalReachedLabel = context.tr('Goal reached');

    String message;
    if (result.viaTransaction) {
      // A wallet movement: the user asked for the goal to be filled out of a
      // real balance, so the transaction is the source of truth and the goal
      // takes only what it can hold.
      final added = await state.contributeToGoal(goal.id, result.amount);
      await state.addTransaction(
        Transaction(
          id: 0,
          walletId: result.walletId!,
          categoryId: result.categoryId!,
          type: result.isIncome ? TxType.income : TxType.expense,
          amount: result.amount,
          note: '$addFundsLabel: ${goal.name}',
          date: DateTime.now(),
        ),
      );
      final credited = added < result.amount ? added : result.amount;
      message = '${Formatters.currency(credited)} → $goalNameLabel';
    } else {
      final added = await state.contributeToGoal(goal.id, result.amount);
      message = added < result.amount
          ? '$goalReachedLabel — ${Formatters.currency(added)}'
          : '${Formatters.currency(added)} → $goalNameLabel';
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onContribute,
  });

  final SavingsGoal goal;
  final VoidCallback onTap;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);
    final accent =
        AppColors.categorical[goal.colorIndex % AppColors.categorical.length];
    final months = goal.monthsToDeadline();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _Ring(ratio: goal.ratio, color: accent),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(goal.name),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Formatters.currency(goal.savedAmount)} of '
                      '${Formatters.currency(goal.targetAmount)}',
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${(goal.ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (months != null)
                          Text(
                            months <= 0
                                ? context.tr('Deadline passed')
                                : '$months month${months == 1 ? '' : 's'} left',
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (!goal.isComplete)
                IconButton.filledTonal(
                  tooltip: context.tr('Add money'),
                  onPressed: onContribute,
                  icon: const Icon(Icons.add_rounded, size: 20),
                )
              else
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.mint,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final track =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.09);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            // A flag reads as "goal", which is what this ring measures; the
            // piggy bank it used to be read as "money" and looked like a bug.
            Icon(
              Icons.flag_rounded,
              size: 19,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the funding sheet hands back to the page.
class _FundResult {
  const _FundResult.manual(this.amount)
      : viaTransaction = false,
        walletId = null,
        categoryId = null,
        isIncome = false;

  const _FundResult.transaction({
    required this.amount,
    required int this.walletId,
    required int this.categoryId,
    required this.isIncome,
  }) : viaTransaction = true;

  final num amount;

  /// True when the money must also be booked as a real wallet transaction.
  final bool viaTransaction;

  final int? walletId;
  final int? categoryId;
  final bool isIncome;
}

/// Fills a goal, either by topping up its own counter or by moving real money
/// out of a wallet.
///
/// The two are genuinely different — a manual top-up is bookkeeping and does
/// not touch any balance, while a transaction moves money and must not be
/// counted twice — so they are presented as two explicit modes rather than a
/// checkbox, and the explanatory line under the amount says which one is in
/// force.
class _FundSheet extends StatefulWidget {
  const _FundSheet({required this.goal, required this.state});

  final SavingsGoal goal;
  final AppState state;

  @override
  State<_FundSheet> createState() => _FundSheetState();
}

class _FundSheetState extends State<_FundSheet> {
  final _amount = TextEditingController();

  /// Defaults to the honest path: money has to come from somewhere.
  bool _fromWallet = true;
  bool _isIncome = false;
  int? _walletId;
  int? _categoryId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  num get _parsed {
    final d = _amount.text.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? 0 : (num.tryParse(d) ?? 0);
  }

  /// A top-up is filed as an expense and a payout as income, so each needs a
  /// category whose type matches the transaction.
  List<Category> get _categories =>
      widget.state.categoriesFor(_isIncome ? TxType.income : TxType.expense);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);

    final wallets = widget.state.wallets;
    final categories = _categories;
    final walletId =
        _walletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    final categoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : (categories.isNotEmpty ? categories.first.id : null);

    // A wallet transfer is only possible with both a wallet and a matching
    // category; without them the sheet falls back to a manual top-up instead
    // of offering a choice that cannot be completed.
    final canUseWallet = wallets.isNotEmpty && categories.isNotEmpty;

    final canSave = _parsed > 0 &&
        (!_fromWallet || (canUseWallet && walletId != null && categoryId != null));

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.tr('Add funds')} · ${context.tr(widget.goal.name)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.currency(widget.goal.remaining)} '
              '${context.tr('to reach the target')}',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 17),
                  label: Text(context.tr('From wallet')),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.edit_note_rounded, size: 17),
                  label: Text(context.tr('Manual')),
                ),
              ],
              selected: {_fromWallet && canUseWallet},
              onSelectionChanged: canUseWallet
                  ? (s) => setState(() => _fromWallet = s.first)
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _amount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final p in const [100000, 250000, 500000])
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _amount.text = Formatters.thousands(p),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(Formatters.compact(p)),
                  ),
                OutlinedButton(
                  onPressed: () => setState(
                    () => _amount.text = Formatters.thousands(
                      widget.goal.remaining.round(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(context.tr('Fill target')),
                ),
              ],
            ),
            if (_fromWallet && canUseWallet) ...[
              const SizedBox(height: AppSpacing.lg),
              _FieldLabel(context.tr('Wallet'), muted: muted),
              const SizedBox(height: AppSpacing.sm),
              _WalletPicker(
                wallets: wallets,
                selectedId: walletId,
                onSelect: (id) => setState(() => _walletId = id),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FieldLabel(context.tr('Category'), muted: muted),
              const SizedBox(height: AppSpacing.sm),
              _CategoryPicker(
                categories: categories,
                selectedId: categoryId,
                onSelect: (id) => setState(() => _categoryId = id),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(
                  _fromWallet && canUseWallet
                      ? Icons.info_outline_rounded
                      : Icons.edit_note_rounded,
                  size: 16,
                  color: muted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _fromWallet && canUseWallet
                        ? context.tr(
                            'The goal is credited from the chosen wallet, so the balance stays true.',
                          )
                        : context.tr(
                            'Adds to the goal without touching any wallet balance.',
                          ),
                    style: TextStyle(fontSize: 12, color: muted, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: !canSave
                  ? null
                  : () => Navigator.pop(
                        context,
                        _fromWallet && canUseWallet
                            ? _FundResult.transaction(
                                amount: _parsed,
                                walletId: walletId!,
                                categoryId: categoryId!,
                                isIncome: _isIncome,
                              )
                            : _FundResult.manual(_parsed),
                      ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(context.tr('Add funds')),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// Horizontal wallet chooser used by the funding sheet.
class _WalletPicker extends StatelessWidget {
  const _WalletPicker({
    required this.wallets,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Wallet> wallets;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: wallets.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final w = wallets[i];
          final on = w.id == selectedId;
          return ChoiceChip(
            label: Text(context.tr(w.name)),
            selected: on,
            onSelected: (_) => onSelect(w.id),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? theme.colorScheme.onSurface : null,
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal category chooser used by the funding sheet.
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
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final c = categories[i];
          return ChoiceChip(
            avatar: Icon(
              Icons.circle,
              size: 12,
              color: AppColors.categorical[
                  c.colorIndex % AppColors.categorical.length],
            ),
            label: Text(context.tr(c.name)),
            selected: c.id == selectedId,
            onSelected: (_) => onSelect(c.id),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.muted});

  final String text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: muted,
      ),
    );
  }
}

/// Formats digits with thousand separators as the user types.
class _ThousandsFormatter extends TextInputFormatter {
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

class _Empty extends StatelessWidget {
  const _Empty({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 36, color: muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr('No goals yet'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Set a target — emergency fund, a laptop, a trip — and watch it fill up.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: muted, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                AppPageRoute(builder: (_) => const GoalEditor()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('Create a goal')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(190, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
