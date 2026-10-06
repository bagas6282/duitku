import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/transaction.dart';
import '../../core/strings.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final note = transaction.note;
    final title = (note != null && note.isNotEmpty)
        ? note
        : (transaction.isTransfer ? context.tr('Transfer') : categoryName);

    final isIncome   = transaction.type == TxType.income;
    final isTransfer = transaction.type == TxType.transfer;

    final amountColor = isIncome
        ? AppColors.mint
        : isTransfer
            ? AppColors.info
            : (isDark ? const Color(0xFFFF6B6B) : AppColors.danger);

    final sign = isIncome ? '+' : isTransfer ? '' : '−';

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
            // Icon kategori
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: color),
            ),

            const SizedBox(width: AppSpacing.md),

            // Judul + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:   14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isDark ? AppColors.textHi : AppColors.textHiL,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$categoryName · ${Formatters.dateShort(transaction.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textMuted : AppColors.textMutedL,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Nominal
            Text(
              '$sign${Formatters.currency(transaction.amount)}',
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
