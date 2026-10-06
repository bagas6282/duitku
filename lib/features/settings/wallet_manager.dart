import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/wallet.dart';
import '../../core/strings.dart';

/// Manage wallets: add, rename, change opening balance, delete.
class WalletManager extends StatelessWidget {
  const WalletManager({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Wallets'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add wallet')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          100,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.mint.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.mint,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Total balance'),
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                    Text(
                      Formatters.currency(state.totalBalance),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final w in state.wallets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.categorical[
                              w.colorIndex % AppColors.categorical.length]
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      AppIcons.wallet(w.name),
                      size: 19,
                      color: AppColors.categorical[
                          w.colorIndex % AppColors.categorical.length],
                    ),
                  ),
                  title: Text(
                    context.tr(w.name),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Opening ${Formatters.currency(w.openingBalance)}',
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                  trailing: Text(
                    Formatters.currency(state.balanceOf(w.id)),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => _openEditor(context, w),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, [Wallet? wallet]) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => WalletEditor(initial: wallet)),
    );
  }
}

class WalletEditor extends StatefulWidget {
  const WalletEditor({super.key, this.initial});

  final Wallet? initial;

  @override
  State<WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends State<WalletEditor> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  int _colorIndex = 0;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    if (w != null) {
      _name.text = w.name;
      _opening.text = Formatters.thousands(w.openingBalance);
      _colorIndex = w.colorIndex;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  num get _openingValue {
    final d = _opening.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return 0;
    final v = num.tryParse(d) ?? 0;
    // A leading minus in the raw field means the wallet starts in the red.
    return _opening.text.trimLeft().startsWith('-') ? -v : v;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.tr('Edit wallet') : context.tr('New wallet')),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(state),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'NAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: 'e.g. BCA, GoPay, Cash',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('OPENING BALANCE'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _opening,
            keyboardType: TextInputType.numberWithOptions(signed: true),
            inputFormatters: [_SignedMoneyFormatter()],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              hintText: '0',
              helperText: context.tr('What the wallet holds today, before Duitku records'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.tr('COLOR'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < AppColors.categorical.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.categorical[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorIndex == i
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _saving || _name.text.trim().isEmpty
                ? null
                : () => _save(state),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
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
                : Text(_isEditing ? context.tr('Save changes') : context.tr('Add wallet')),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppState state) async {
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await state.updateWallet(
          widget.initial!.copyWith(
            name: _name.text.trim(),
            openingBalance: _openingValue,
            colorIndex: _colorIndex,
          ),
        );
      } else {
        await state.addWallet(_name.text.trim(), _openingValue, _colorIndex);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${context.tr('Could not save')}: $e')));
    }
  }

  Future<void> _confirmDelete(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete wallet?')),
        content: Text(
          context.tr('Transactions recorded against this wallet are deleted with it.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteWallet(widget.initial!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

class _SignedMoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final negative = newValue.text.trimLeft().startsWith('-');
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text =
        (negative ? '-' : '') + Formatters.thousands(num.tryParse(digits) ?? 0);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
