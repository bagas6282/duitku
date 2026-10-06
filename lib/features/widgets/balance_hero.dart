import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/strings.dart';

/// Kartu saldo utama di dashboard.
/// Dark-glass card dengan gradient royal-blue, typography bold headline.
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D1835), const Color(0xFF112040)]
              : [const Color(0xFF1346C8), const Color(0xFF1D5CE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            // Accent circle — dekoratif subtle
            Positioned(
              top: -40,
              right: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mint.withOpacity(0.06),
                ),
              ),
            ),

            // Konten
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle Harian / Bulanan
                  _PeriodToggle(
                    isDaily: isDaily,
                    onToggle: onToggleMode,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Label periode
                  GestureDetector(
                    onTap: onTapPick,
                    child: Row(
                      children: [
                        Text(
                          periodLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.55),
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (onTapPick != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Saldo utama
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (onPrevious != null)
                        _NavArrow(
                          icon: Icons.chevron_left_rounded,
                          onTap: onPrevious!,
                        ),
                      Expanded(
                        child: Text(
                          _fmt(balance),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onNext != null)
                        _NavArrow(
                          icon: Icons.chevron_right_rounded,
                          onTap: onNext!,
                        ),
                    ],
                  ),

                  if (periodSublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      periodSublabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.42),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // Divider tipis
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Pemasukan / Pengeluaran
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.south_west_rounded,
                          label: context.tr('Income'),
                          value: _fmt(income),
                          color: AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.north_east_rounded,
                          label: context.tr('Expense'),
                          value: _fmt(expense),
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(num v) {
    final s = v.abs().toStringAsFixed(0);
    final parts = <String>[];
    var i = s.length;
    while (i > 0) {
      parts.insert(0, s.substring(i > 3 ? i - 3 : 0, i));
      i -= 3;
    }
    final abs = 'Rp ${parts.join('.')}';
    return v < 0 ? '-$abs' : abs;
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.isDaily, required this.onToggle});
  final bool isDaily;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _ToggleItem(label: 'Harian', selected: isDaily, onTap: () => onToggle(true)),
          _ToggleItem(label: 'Bulanan', selected: !isDaily, onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize:   12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:      Colors.white.withOpacity(selected ? 0.95 : 0.5),
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.7)),
      ),
    );
  }
}
