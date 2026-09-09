import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money_input.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../../data/models/wallet.dart';
import '../../core/strings.dart';
import 'package:image_picker/image_picker.dart';
import '../receipt/receipt_scanner_service.dart';

/// Add/edit sheet for one transaction.
///
/// Amount uses a big numeric field rather than a keypad so the system keyboard
/// (and the user's own habits) apply. Type toggles recolour the whole sheet,
/// which makes expense/income unmistakable at a glance.
class TransactionEditor extends StatefulWidget {
  const TransactionEditor({
    super.key,
    this.initial,
    this.linkedGoalId,
    this.initialAmount,
    this.initialNote,
    this.initialDate,
    this.initialCategoryId,
  });

  final Transaction? initial;
  final int? linkedGoalId;
  final num? initialAmount;
  final String? initialNote;
  final DateTime? initialDate;
  final int? initialCategoryId;

  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _scrollController = ScrollController();
  final _amountFocus = FocusNode();
  final _scannerService = ReceiptScannerService();

  late TxType _type;
  int? _walletId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _scanning = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _type = t.type;
      _walletId = t.walletId;
      _categoryId = t.categoryId;
      _date = t.date;
      _note.text = t.note ?? '';
      _amount.text = Formatters.thousands(t.amount);
    } else {
      _type = TxType.expense;
      _walletId = null;
      _categoryId = widget.initialCategoryId;
      _date = widget.initialDate ?? DateTime.now();
      _note.text = widget.initialNote ?? '';
      _amount.text = widget.initialAmount != null && widget.initialAmount! > 0
          ? Formatters.thousands(widget.initialAmount!)
          : '';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _amountFocus.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  num get _parsedAmount {
    final digits = _amount.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return num.tryParse(digits) ?? 0;
  }

  Color get _accent =>
      _type == TxType.income ? AppColors.mint : AppColors.expense;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    final wallets = state.wallets;
    final categories = state.categoriesFor(_type);
    final walletId = _walletId ??
        (wallets.isNotEmpty ? wallets.first.id : null);

    // Keep the category valid when the type flips.
    final categoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : (categories.isNotEmpty ? categories.first.id : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.tr('Edit transaction') : context.tr('New transaction')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('Scan receipt'),
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
            onPressed: _saving || _scanning ? null : () => _showScanSourceSheet(state),
          ),
          if (_isEditing)
            IconButton(
              tooltip: context.tr('Delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(state),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      // Pinned, never scrolled away: the whole point is that adding a
      // transaction must not require hunting for the button first.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: _parsedAmount > 0
                ? [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: FilledButton(
            onPressed: _saving
                ? null
                : () => _handleSaveTap(state, walletId, categoryId),
            style: FilledButton.styleFrom(
              backgroundColor: _parsedAmount > 0
                  ? _accent
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: _parsedAmount > 0
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              minimumSize: const Size.fromHeight(52),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _parsedAmount > 0
                            ? Icons.check_circle_rounded
                            : Icons.arrow_upward_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _isEditing
                            ? context.tr('Save changes')
                            : context.tr('Add transaction'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _TypeToggle(
            value: _type,
            onChanged: (t) => setState(() {
              _type = t;
              // Reset so the list below repopulates for the new type.
              _categoryId = null;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!_isEditing) ...[
            InkWell(
              onTap: _saving || _scanning ? null : () => _showScanSourceSheet(state),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: _accent.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Scan receipt automatically'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('Snap a photo to fill amount & merchant'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _accent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Label(context.tr('Amount'), muted: muted),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: _saving || _scanning ? null : () => _showScanSourceSheet(state),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: _accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.document_scanner_rounded, size: 14, color: _accent),
                      const SizedBox(width: 5),
                      Text(
                        context.tr('Scan receipt'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _AmountField(
            controller: _amount,
            focusNode: _amountFocus,
            accent: _accent,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label(context.tr('Category'), muted: muted),
          const SizedBox(height: AppSpacing.sm),
          _CategoryGrid(
            categories: categories,
            selectedId: categoryId,
            onSelect: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (wallets.length > 1) ...[
            _Label(context.tr('Wallet'), muted: muted),
            const SizedBox(height: AppSpacing.sm),
            _WalletRow(
              wallets: wallets,
              selectedId: walletId,
              onSelect: (id) => setState(() => _walletId = id),
              accent: _accent,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          _Label('Date', muted: muted),
          const SizedBox(height: AppSpacing.sm),
          _DateRow(
            date: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Label('Note', muted: muted),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            maxLength: 120,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Optional — what was this for?',
              counterText: '',
            ),
          ),
          // The save button lives in the Scaffold's bottomNavigationBar, not
          // here: inside the ListView it scrolled away with the content, so
          // people had to scroll to reach it. Pinned to the bottom it is always
          // on screen and always one tap away.
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _showScanSourceSheet(AppState state) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
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
                    color: _accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: _accent),
                ),
                title: Text(ctx.tr('Take photo')),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_rounded, color: _accent),
                ),
                title: Text(ctx.tr('Choose from gallery')),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null && mounted) {
      await _processReceiptScan(source, state);
    }
  }

  Future<void> _processReceiptScan(ImageSource source, AppState state) async {
    setState(() => _scanning = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
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
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final result = await _scannerService.scanReceipt(source: source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result == null || !result.hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('No text found on receipt')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        if (result.amount != null && result.amount! > 0) {
          _amount.text = Formatters.thousands(result.amount!);
        }
        if (result.date != null) {
          _date = result.date!;
        }
        if (result.merchantName != null && result.merchantName!.isNotEmpty) {
          if (_note.text.trim().isEmpty) {
            _note.text = result.merchantName!;
          }
        }
        if (result.suggestedCategory != null) {
          final categories = state.categoriesFor(_type);
          for (final c in categories) {
            if (c.name.toLowerCase() == result.suggestedCategory!.toLowerCase()) {
              _categoryId = c.id;
              break;
            }
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.amount != null
                ? '${context.tr('Receipt scanned successfully')}: Rp ${Formatters.thousands(result.amount!)}'
                : context.tr('Receipt scanned successfully'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Failed to scan receipt')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  void _handleSaveTap(AppState state, int? walletId, int? categoryId) {
    if (_saving) return;
    if (_parsedAmount <= 0) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      _amountFocus.requestFocus();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Enter an amount first')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (categoryId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Pick a category and a wallet')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _save(state, walletId, categoryId);
  }

  Future<void> _save(AppState state, int? walletId, int? categoryId) async {
    if (walletId == null || categoryId == null) return;
    setState(() => _saving = true);

    final goalId = widget.linkedGoalId;

    final tx = Transaction(
      id: widget.initial?.id,
      walletId: walletId,
      categoryId: categoryId,
      type: _type,
      amount: _parsedAmount,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      date: _date,
      recurringId: widget.initial?.recurringId,
      createdAt: widget.initial?.createdAt,
    );

    try {
      if (goalId != null && !_isEditing) {
        // Filing straight into a goal is a single step: the transaction is the
        // goal top-up, so writing it here and crediting the goal afterwards
        // would double the movement. The goal takes only what it can hold, so
        // the shortfall goes back to the wallet as a fresh transaction rather
        // than silently vanishing.
        final added = await state.contributeToGoal(goalId, _parsedAmount);
        final shortfall = _parsedAmount - added;
        if (shortfall > 0) {
          await state.addTransaction(
            tx.withAmount(shortfall, newNote: _goalShortfallNote(tx.note)),
          );
        }
      } else if (_isEditing) {
        await state.updateTransaction(tx);
      } else {
        await state.addTransaction(tx);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Could not save')}: $e')),
      );
    }
  }

  /// Marks the leftover of an over-funded goal so it is not mistaken for a
  /// deliberate expense when the user reviews their history.
  String _goalShortfallNote(String? original) {
    final note = original?.trim();
    return note == null || note.isEmpty
        ? 'Goal already at target — kept as a normal transaction'
        : '$note — beyond the goal, kept as a normal transaction';
  }

  Future<void> _confirmDelete(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete transaction?')),
        content: Text(context.tr('This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    final id = widget.initial?.id;
    if (ok != true || id == null) return;

    final removed = await state.deleteTransaction(id);
    if (!mounted) return;

    // Grab the messenger before popping: once this route is gone,
    // `ScaffoldMessenger.of(context)` would search a dead subtree and the
    // Undo snackbar would never appear.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    // Undo: a mis-tap on Delete should not cost the user a record.
    if (removed != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.tr('Transaction deleted')),
          action: SnackBarAction(
            label: context.tr('Undo'),
            onPressed: () => state.restoreTransaction(removed),
          ),
        ),
      );
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.muted});

  final String text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: muted,
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final TxType value;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    Widget seg(TxType type, String label, Color accent) {
      final active = value == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(4),
            height: 42,
            decoration: BoxDecoration(
              color: active ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : fg.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          seg(TxType.expense, context.tr('Expense'), AppColors.expense),
          seg(TxType.income, context.tr('Income'), AppColors.mint),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.accent,
    required this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Rp',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsInputFormatter()],
            autofocus: false,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: -1,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: fg.withValues(alpha: 0.22),
                letterSpacing: -1,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    if (categories.isEmpty) {
      return Text(
        context.tr('No categories for this type yet.'),
        style: TextStyle(
          fontSize: 13,
          color: fg.withValues(alpha: 0.5),
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final c in categories)
          GestureDetector(
            onTap: () => onSelect(c.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: selectedId == c.id
                    ? AppColors
                        .categorical[c.colorIndex % AppColors.categorical.length]
                        .withValues(alpha: 0.18)
                    : fg.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selectedId == c.id
                      ? AppColors.categorical[
                          c.colorIndex % AppColors.categorical.length]
                      : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    IconData(c.iconCode, fontFamily: 'MaterialIcons'),
                    size: 16,
                    color: AppColors
                        .categorical[c.colorIndex % AppColors.categorical.length],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.tr(c.name),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.wallets,
    required this.selectedId,
    required this.onSelect,
    required this.accent,
  });

  final List<Wallet> wallets;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final w in wallets)
          GestureDetector(
            onTap: () => onSelect(w.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selectedId == w.id
                    ? accent.withValues(alpha: 0.16)
                    : fg.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selectedId == w.id ? accent : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Text(
                context.tr(w.name),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    Future<void> pick() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2010),
        lastDate: DateTime(DateTime.now().year + 5),
      );
      if (picked != null) {
        onChanged(
          DateTime(picked.year, picked.month, picked.day, date.hour, date.minute),
        );
      }
    }

    // Stacked, not side by side. All three side by side needed more width than
    // a 390dp phone has once the date was spelled out in Indonesian, and the
    // Row overflowed by 168px.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: fg.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: pick,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 13,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 17,
                    color: fg.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      Formatters.longDate(date),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickDay(
                label: context.tr('Today'),
                active: Formatters.isSameDay(date, DateTime.now()),
                onTap: () => onChanged(DateTime.now()),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _QuickDay(
                label: context.tr('Yesterday'),
                active: Formatters.isSameDay(
                  date,
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
                onTap: () => onChanged(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickDay extends StatelessWidget {
  const _QuickDay({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: active
          ? AppColors.mint.withValues(alpha: 0.16)
          : fg.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.mint : fg.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
