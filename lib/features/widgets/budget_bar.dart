import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Horizontal budget bar: label, spent/limit, and a colored fill.
///
/// Fill color shifts mint → amber → red as the cap approaches, so the state
/// reads before the number does.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.label,
    required this.icon,
    required this.spent,
    required this.limit,
    this.colorIndex = 0,
  });

  final String label;
  final IconData icon;
  final num spent;
  final num limit;
  final int colorIndex;

  double get ratio => limit <= 0 ? 0 : (spent / limit).clamp(0.0, 1.0);
  double get rawRatio => limit <= 0 ? 0 : spent / limit;
  num get remaining => (limit - spent).clamp(0, limit);
  bool get over => spent > limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final fill = AppColors.forRatio(rawRatio);
    final catColor =
        AppColors.categorical[colorIndex % AppColors.categorical.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: catColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${_money(spent)} / ${_money(limit)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: over ? AppColors.expense : muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: muted.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(fill),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? 'Over by ${_money(spent - limit)}'
                : '${_money(remaining)} left',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: over ? AppColors.expense : muted,
            ),
          ),
        ],
      ),
    );
  }

  String _money(num value) {
    final s = value.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp${buf.toString()}';
  }
}

/// Small stat chip used across summary rows.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
