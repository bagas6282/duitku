import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../dashboard/show_month_picker.dart';
import 'budget_editor.dart';
import '../../core/strings.dart';

/// The Budget screen pushed as a route of its own, with an app bar.
///
/// Needed because the dashboard can be a pushed route itself, where switching
/// the shell's tab is not possible.
class BudgetScaffold extends StatelessWidget {
  const BudgetScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Budgets'))),
      body: const BudgetPage(),
    );
  }
}

/// Budget tab: monthly caps per category with live progress.
///
/// Stateful because the progress list is asynchronous. The future is created
/// once per data change rather than inside `build`: calling
/// `state.budgetProgress()` there would mint a new Future on every rebuild, so
/// the FutureBuilder would reset to its waiting state and the screen would sit
/// on a spinner forever.
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  Future<List<BudgetProgress>>? _progress;

  /// Signature of the data the current [_progress] was built from. When the
  /// visible month, the caps, or the spending change, the future is rebuilt;
  /// otherwise it is reused and the list stays put instead of flickering.
  String? _signature;

  /// True until the first snapshot arrives, successful or not. Guarantees the
  /// screen cannot end up permanently behind a spinner.
  bool _firstLoad = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeReload();
  }

  void _maybeReload() {
    final state = context.watch<AppState>();
    // dataRevision, not the row count: editing an amount changes what the
    // progress bars must show without changing how many rows exist.
    final signature = '${state.monthKey}|${state.dataRevision}|'
        '${state.budgetsRevision}';
    if (signature == _signature && _progress != null) return;
    _signature = signature;
    _progress = state.budgetProgress();
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluated on every notifyListeners; cheap, and it decides whether the
    // cached future is still the right one.
    _maybeReload();

    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return FutureBuilder<List<BudgetProgress>>(
      future: _progress,
      builder: (context, snap) {
        // A snapshot of any kind — data or error — means the first read is
        // over, so the spinner is never gated on `hasData` alone.
        if (snap.connectionState == ConnectionState.done) _firstLoad = false;
        final items = snap.data ?? const <BudgetProgress>[];
        final totalLimit = items.fold<num>(0, (s, p) => s + p.limit);
        final totalSpent = items.fold<num>(0, (s, p) => s + p.spent);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: _Header(
                monthLabel: Formatters.monthYear(state.month),
                onPickMonth: () => showMonthPicker(context),
                totalLimit: totalLimit,
                totalSpent: totalSpent,
                hasAny: items.isNotEmpty,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              // Only the very first read may show a spinner: `hasData` is false
              // on error too, so gating on it alone left the user stuck when
              // the read failed. Once anything has arrived, a refresh must not
              // tear the list down either.
              child: (_firstLoad && !snap.hasData)
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: state.refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          120,
                        ),
                        children: [
                          if (items.isEmpty)
                            _Empty(
                              message: muted,
                              hasError: snap.hasError,
                            )
                          else ...[
                            for (final p in items) _BudgetCardItem(progress: p),
                            const SizedBox(height: AppSpacing.lg),
                            // Only shown with caps present: the empty state has
                            // its own, larger button, and rendering both made
                            // the screen show two identical "Add budget"
                            // controls.
                            OutlinedButton.icon(
                              onPressed: () => _openEditor(context, state),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(context.tr('Add budget')),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openEditor(BuildContext context, AppState state) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const BudgetEditor()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.monthLabel,
    required this.onPickMonth,
    required this.totalLimit,
    required this.totalSpent,
    required this.hasAny,
  });

  final String monthLabel;
  final VoidCallback onPickMonth;
  final num totalLimit;
  final num totalSpent;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);
    final remaining = totalLimit - totalSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('Budgets'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: TextButton.icon(
                onPressed: onPickMonth,
                icon: const Icon(Icons.calendar_month_rounded, size: 17),
                label: Text(
                  monthLabel,
                  softWrap: false,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasAny) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.07),
              ),
            ),
            child: Row(
              children: [
                _Stat(
                  label: context.tr('Budgeted'),
                  value: Formatters.currency(totalLimit),
                  color: theme.colorScheme.onSurface,
                ),
                _Stat(
                  label: context.tr('Spent'),
                  value: Formatters.currency(totalSpent),
                  color: AppColors.danger,
                ),
                _Stat(
                  label: remaining >= 0 ? 'Left' : 'Over',
                  value: Formatters.currency(remaining.abs()),
                  color: remaining >= 0 ? AppColors.mint : AppColors.danger,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCardItem extends StatelessWidget {
  const _BudgetCardItem({required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);
    final cat = progress.category;
    final accent = AppColors
        .categorical[(cat?.colorIndex ?? 0) % AppColors.categorical.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.of(context).push(
            AppPageRoute(
              builder: (_) => BudgetEditor(initial: progress.budget),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        cat == null
                            ? Icons.label_outline_rounded
                            : AppIcons.fromCode(cat.iconCode),
                        size: 19,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(cat?.name ?? 'Uncategorized'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${Formatters.currency(progress.spent)} of '
                            '${Formatters.currency(progress.limit)}',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    _PercentBadge(ratio: progress.ratio),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.ratio.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.forRatio(progress.ratio),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      progress.remaining >= 0
                          ? '${Formatters.currency(progress.remaining)} left'
                          : '${Formatters.currency(progress.remaining.abs())} over',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: progress.remaining >= 0
                            ? AppColors.mint
                            : AppColors.danger,
                      ),
                    ),
                    const Spacer(),
                    if (progress.daysLeftInMonth != null)
                      Text(
                        '${progress.daysLeftInMonth} days left',
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forRatio(ratio);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${(ratio * 100).round()}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, this.hasError = false});

  final Color message;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError
                  ? Icons.error_outline_rounded
                  : Icons.pie_chart_outline_rounded,
              size: 36,
              color: message,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasError
                  ? context.tr('Could not load budgets')
                  : context.tr('No budgets for this month'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: message,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Set a cap per category and Duitku will track it for you.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: message),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                AppPageRoute(builder: (_) => const BudgetEditor()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('Add budget')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
