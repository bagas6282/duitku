import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/transaction.dart';
import '../dashboard/show_month_picker.dart';
import '../widgets/charts.dart';
import '../../core/strings.dart';

/// Charts tab: monthly trend line, income vs expense split, category donut.
class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  int _range = 6; // months of trend history

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      children: [
        Row(
          children: [
            Text(
              context.tr('Insights'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showMonthPicker(context),
              icon: const Icon(Icons.calendar_month_rounded, size: 17),
              label: Text(Formatters.monthYear(state.month)),
              style: TextButton.styleFrom(
                foregroundColor: muted,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Card(
          title: context.tr('This month'),
          child: Row(
            children: [
              _BigStat(
                label: 'In',
                value: state.monthIncome,
                color: AppColors.mint,
              ),
              _BigStat(
                label: 'Out',
                value: state.monthExpense,
                color: AppColors.expense,
              ),
              _BigStat(
                label: context.tr('Net'),
                value: state.monthNet,
                color: state.monthNet >= 0
                    ? AppColors.mint
                    : AppColors.expense,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          title: context.tr('Category breakdown'),
          child: _Breakdown(state: state),
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          title: context.tr('Daily flow'),
          child: _DailyFlow(transactions: state.transactions),
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          title: context.tr('Month by month'),
          trailing: _RangeToggle(
            value: _range,
            onChanged: (v) => setState(() => _range = v),
          ),
          child: _Trend(state: state, months: _range),
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          title: context.tr('Top spending days'),
          child: _TopDays(transactions: state.transactions),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            Formatters.compact(value),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final totals = <int, num>{};
    for (final t in state.transactions) {
      if (t.type != TxType.expense) continue;
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final slices = sorted.map((e) {
      final cat = state.categoryOf(e.key);
      return DonutSlice(
        label: context.tr(cat?.name ?? 'Uncategorized'),
        value: e.value,
        color: AppColors
            .categorical[(cat?.colorIndex ?? 0) % AppColors.categorical.length],
      );
    }).toList();

    return Column(
      children: [
        CategoryDonut(
          slices: slices,
          centerLabel: context.tr('Spent'),
          centerValue: Formatters.compact(state.monthExpense),
        ),
        if (slices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          DonutLegend(slices: slices, total: state.monthExpense),
        ],
      ],
    );
  }
}

class _DailyFlow extends StatelessWidget {
  const _DailyFlow({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    if (transactions.isEmpty) {
      return Text(
        context.tr('No data for this month'),
        style: TextStyle(fontSize: 13, color: muted),
      );
    }

    // Cumulative running balance through the month reads better than raw
    // daily bars when the goal is "am I trending up or down?".
    final byDay = <int, num>{};
    for (final t in transactions) {
      byDay[t.date.day] = (byDay[t.date.day] ?? 0) + t.signedAmount;
    }
    final days = byDay.keys.toList()..sort();

    var running = 0.0;
    final spots = <FlSpot>[];
    for (final d in days) {
      running += (byDay[d] ?? 0).toDouble();
      spots.add(FlSpot(d.toDouble(), running));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final pad = ((maxY - minY).abs() * 0.18).clamp(1000, double.infinity);

    return SizedBox(
      height: 168,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ((maxY - minY + pad * 2) / 4).clamp(1, 1e9),
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                reservedSize: 24,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10.5, color: muted),
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      Formatters.compact(s.y),
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.28,
              barWidth: 2.6,
              color: AppColors.mint,
              dotData: FlDotData(
                show: spots.length <= 12,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.mint,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.mint.withValues(alpha: 0.26),
                    AppColors.mint.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in const [3, 6, 12])
            GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: value == m ? AppColors.mint : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${m}M',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: value == m
                        ? Colors.white
                        : fg.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Trend chart with a cached future.
///
/// Building the future inline restarted the query on every rebuild, so the
/// chart flashed back to a spinner whenever anything else on the page changed.
class _Trend extends StatefulWidget {
  const _Trend({required this.state, required this.months});

  final AppState state;
  final int months;

  @override
  State<_Trend> createState() => _TrendState();
}

class _TrendState extends State<_Trend> {
  Future<List<MonthlyTotal>>? _future;

  /// Identity of the data behind the cached future: the visible month, the
  /// range, and how many transactions exist. Any change means a re-query.
  Object? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeReload();
  }

  void _maybeReload() {
    final key = Object.hash(
      widget.months,
      widget.state.month.year,
      widget.state.month.month,
      widget.state.transactions.length,
    );
    if (key == _key && _future != null) return;
    _key = key;
    _future = widget.state.monthlyTotals(widget.months);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    _maybeReload();

    return FutureBuilder<List<MonthlyTotal>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 170,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snap.data!;
        if (data.isEmpty || data.every((d) => d.income == 0 && d.expense == 0)) {
          return SizedBox(
            height: 120,
            child: Center(
              child: Text(
                context.tr('Not enough history yet'),
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          );
        }

        final maxValue = data
                .map((d) => d.income > d.expense ? d.income : d.expense)
                .reduce((a, b) => a > b ? a : b)
                .toDouble();

        return Column(
          children: [
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxValue * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue <= 0 ? 1 : maxValue / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
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
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              Formatters.monthShort(data[i].month),
                              style: TextStyle(fontSize: 10.5, color: muted),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        Formatters.compact(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: data[i].income.toDouble(),
                            color: AppColors.mint,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: data[i].expense.toDouble(),
                            color: AppColors.expense,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.mint, label: context.tr('Income')),
                SizedBox(width: AppSpacing.lg),
                _LegendDot(color: AppColors.expense, label: context.tr('Expense')),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
      ],
    );
  }
}

class _TopDays extends StatelessWidget {
  const _TopDays({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    final byDay = <String, num>{};
    final dayOf = <String, DateTime>{};
    for (final t in transactions) {
      if (t.type != TxType.expense) continue;
      final key = Formatters.dayKey(t.date);
      byDay[key] = (byDay[key] ?? 0) + t.amount;
      dayOf[key] = t.date;
    }

    final sorted = byDay.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return Text(
        context.tr('No spending recorded yet'),
        style: TextStyle(fontSize: 13, color: muted),
      );
    }

    final top = sorted.take(5).toList();
    final max = top.first.value;
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final e in top)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    Formatters.dateShort(dayOf[e.key]!),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (e.value / max).toDouble()),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.07),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.expense),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  Formatters.currency(e.value),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
