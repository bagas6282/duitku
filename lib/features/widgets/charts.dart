import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/strings.dart';

/// Category breakdown as a donut.
///
/// A donut beats a pie here: the hole holds the total, so the chart answers
/// "how much" and "on what" without a separate label block.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
  });

  /// Value, color and label per slice. Empty list renders an empty state.
  final List<DonutSlice> slices;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    if (slices.isEmpty) {
      return SizedBox(
        height: 190,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.donut_large_rounded, size: 34, color: muted),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('No spending yet'),
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 62,
              startDegreeOffset: -90,
              sections: [
                for (final s in slices)
                  PieChartSectionData(
                    value: s.value.toDouble(),
                    color: s.color,
                    radius: 26,
                    showTitle: false,
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: muted,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                centerValue,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;
}

/// Legend rows under the donut.
class DonutLegend extends StatelessWidget {
  const DonutLegend({super.key, required this.slices, required this.total});

  final List<DonutSlice> slices;
  final num total;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Column(
      children: [
        for (final s in slices.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  total <= 0
                      ? '0%'
                      : '${((s.value / total) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 82,
                  child: Text(
                    _money(s.value),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _money(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp${buf.toString()}';
  }
}

/// Income vs expense over the month, as paired bars per day.
///
/// Paired bars rather than two lines: the daily volume here is low enough
/// that bars read better, and the zero baseline makes deficits obvious.
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.45);

    if (points.isEmpty) {
      return SizedBox(
        height: 170,
        child: Center(
          child: Text(
            context.tr('Nothing to chart yet'),
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
      );
    }

    final maxY = points
        .expand((p) => [p.income, p.expense])
        .fold<num>(0, (a, b) => a > b ? a : b);
    final safeMax = maxY <= 0 ? 1000.0 : maxY.toDouble() * 1.25;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: safeMax,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMax / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: muted.withOpacity(0.25),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  // Label every ~4th bar so the axis does not turn to mush.
                  if (points.length > 8 && i % 4 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[i].label,
                      style: TextStyle(fontSize: 10.5, color: muted),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.void1,
              getTooltipItem: (group, _, rod, index) {
                final p = points[group.x];
                final isIncome = index == 0;
                return BarTooltipItem(
                  '${p.label}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: isIncome
                          ? 'In  ${_money(p.income)}'
                          : 'Out ${_money(p.expense)}',
                      style: TextStyle(
                        color: isIncome ? AppColors.mint : AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: points[i].income.toDouble(),
                    color: AppColors.mint,
                    width: 7,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  BarChartRodData(
                    toY: points[i].expense.toDouble(),
                    color: AppColors.danger,
                    width: 7,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  String _money(num value) {
    if (value >= 1000000) {
      return 'Rp${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return 'Rp${(value / 1000).toStringAsFixed(0)}K';
    return 'Rp${value.toStringAsFixed(0)}';
  }
}

class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final num income;
  final num expense;
}
