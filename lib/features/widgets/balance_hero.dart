import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/strings.dart';

/// The hero card on the dashboard.
///
/// Supports both Daily (Per Tanggal) and Monthly (Per Bulan) calculations.
class BalanceHero extends StatelessWidget {
  const BalanceHero({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    required this.periodLabel,
    this.periodSublabel,
    required this.isDaily,
    required this.onToggleMode,
    this.onPrevious,
    this.onNext,
    this.onTapPick,
  });

  final num balance;
  final num income;
  final num expense;
  final String periodLabel;
  final String? periodSublabel;
  final bool isDaily;
  final ValueChanged<bool> onToggleMode;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTapPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.textPrimaryDark : Colors.white;
    final muted = fg.withValues(alpha: 0.62);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.inkSoft : AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented switch: [ Harian ] [ Bulanan ]
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SegmentItem(
                          label: context.tr('Daily (Per Date)'),
                          icon: Icons.today_rounded,
                          selected: isDaily,
                          onTap: () => onToggleMode(true),
                          fg: fg,
                        ),
                      ),
                      Expanded(
                        child: _SegmentItem(
                          label: context.tr('Monthly (Per Month)'),
                          icon: Icons.calendar_month_rounded,
                          selected: !isDaily,
                          onTap: () => onToggleMode(false),
                          fg: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _NavButton(
                icon: Icons.calendar_today_rounded,
                fg: fg,
                onTap: onTapPick,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Stepper: < [Date or Month label] >
          _PeriodStepper(
            label: periodLabel,
            onPrevious: onPrevious,
            onNext: onNext,
            onTap: onTapPick,
            fg: fg,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('Total balance'),
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(balance),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money(balance),
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.05,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey('in-$income-$isDaily'),
                    child: _Delta(
                      label: 'In',
                      value: income,
                      color: AppColors.mint,
                      muted: muted,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 34, color: fg.withValues(alpha: 0.14)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey('out-$expense-$isDaily'),
                    child: _Delta(
                      label: 'Out',
                      value: expense,
                      color: AppColors.expense,
                      muted: muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _money(num value) => _fmt(value);
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.fg,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? fg.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: selected ? fg : fg.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? fg : fg.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp${buf.toString()}';
}

class _PeriodStepper extends StatelessWidget {
  const _PeriodStepper({
    required this.label,
    required this.fg,
    this.onPrevious,
    this.onNext,
    this.onTap,
  });

  final String label;
  final Color fg;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 20,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrevious, fg: fg),
        const SizedBox(width: AppSpacing.sm),
        _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext, fg: fg),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.fg, this.onTap});

  final IconData icon;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fg.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
  });

  final String label;
  final num value;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _fmt(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
