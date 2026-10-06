import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/transaction.dart';
import '../transactions/transaction_editor.dart';
import 'receipt_scanner_service.dart';

/// Helper to trigger receipt scanning from anywhere (Home Shell FAB, Dashboard card, etc.)
class ReceiptScanLauncher {
  ReceiptScanLauncher._();

  static Future<void> launch(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctx.tr('Scan receipt'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.mint),
                ),
                title: Text(ctx.tr('Take photo')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.mint),
                ),
                title: Text(ctx.tr('Choose from gallery')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(context.tr('Scanning receipt...'))),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.fixed,
      ),
    );

    try {
      final service = ReceiptScannerService();
      final result = await service.scanReceipt(source: source);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();

      if (result == null || !result.hasData) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('No text found on receipt')),
            behavior: SnackBarBehavior.fixed,
          ),
        );
        return;
      }

      int? matchedCategoryId;
      if (result.suggestedCategory != null) {
        final categories = state.categoriesFor(TxType.expense);
        for (final c in categories) {
          if (c.name.toLowerCase().contains(result.suggestedCategory!.toLowerCase()) ||
              result.suggestedCategory!.toLowerCase().contains(c.name.toLowerCase())) {
            matchedCategoryId = c.id;
            break;
          }
        }
      }

      await Navigator.of(context).push(
        AppPageRoute(
          builder: (_) => TransactionEditor(
            initialAmount: result.amount,
            initialNote: result.merchantName,
            initialDate: result.date,
            initialCategoryId: matchedCategoryId,
          ),
        ),
      );

      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.tr('Receipt scanned successfully'),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1B8A5A),
            behavior: SnackBarBehavior.fixed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('Failed to scan receipt')),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }
}
