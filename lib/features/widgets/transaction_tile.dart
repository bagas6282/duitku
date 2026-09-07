import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/transaction.dart';
import '../../core/strings.dart';

/// One row in a transaction list.
///
/// The leading tile carries the category color, the title carries the note
/// (falling back to the category name), and the trailing amount carries the
/// sign — three separate channels so the row stays scannable at a glance.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.categoryName,
    required this.icon,
    required this.color,
    this.onTap,
    this.dense = false,
  });

  final Transaction transaction;
  final String categoryName;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final note = transaction.note;
    final title = (note != null && note.isNotEmpty)
        ? note
        : (transaction.isTransfer ? context.tr('Transfer') : categoryName);

    final amountColor = switch (transaction.type) {
      TxType.income => AppColors.mint,
      TxType.expense => isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight,
      TxType.transfer => AppColors.info,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: dense ? AppSpacing.sm : AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$categoryName · ${Formatters.dateShort(transaction.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _signed(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: amountColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _signed() {
    final v = _groupped(transaction.amount);
    return switch (transaction.type) {
      TxType.income => '+Rp$v',
      TxType.expense => '-Rp$v',
      TxType.transfer => 'Rp$v',
    };
  }

  String _groupped(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Date separator shown between groups in the list.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label, required this.total});

  final String label;
  final num total;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
        left: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: muted,
            ),
          ),
          const Spacer(),
          Text(
            '−Rp${_groupped(total)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _groupped(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
