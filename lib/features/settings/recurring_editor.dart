import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/money_input.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/budget.dart';
import '../../data/models/transaction.dart';
import '../../core/strings.dart';

/// Creates or edits a recurring rule.
///
/// A rule is a template: it does not move money by itself. The app posts a real
/// transaction each time the schedule comes due, so the ledger and the rule
/// stay independent — editing or deleting a rule never rewrites history.
class RecurringEditor extends StatefulWidget {
  const RecurringEditor({super.key, this.initial});

  final RecurringRule? initial;

  @override
  State<RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<RecurringEditor> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  late TxType _type = widget.initial?.type ?? TxType.expense;
  late int _categoryId = widget.initial?.categoryId ?? 0;
  late int _walletId = widget.initial?.walletId ?? 0;
  late RecurFreq _frequency = widget.initial?.frequency ?? RecurFreq.monthly;
  late int _dayOfMonth = widget.initial?.dayOfMonth ?? 1;
  late int _weekday = widget.initial?.weekday ?? DateTime.monday;
  late DateTime _nextRunAt = widget.initial?.nextRunAt ?? _defaultNextRun();
  bool _saving = false;
  bool _defaultsApplied = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _amount.text = Formatters.thousands(initial.amount);
      _note.text = initial.note;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultsApplied || widget.initial != null) return;
    _defaultsApplied = true;

    // Seed the pickers with real rows on first build. Saving a rule that
    // points at category 0 would create an entry no screen can render.
    final state = context.read<AppState>();
    final cats = state.categoriesFor(_type);
    _categoryId = cats.isEmpty ? 0 : cats.first.id;
    _walletId = state.wallets.isEmpty ? 0 : state.wallets.first.id;
  }

  /// The first occurrence comfortably in the future.
  ///
  /// Defaulting to "now" would make a brand-new rule immediately overdue and
  /// post a transaction the moment it is saved.
  static DateTime _defaultNextRun() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  num get _parsed =>
      num.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _save(AppState state) async {
    if (_parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter an amount first'))),
      );
      return;
    }
    if (_categoryId == 0 || _walletId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Pick a category and a wallet'))),
      );
      return;
    }

    setState(() => _saving = true);

    final rule = RecurringRule(
      id: widget.initial?.id ?? 0,
      type: _type,
      amount: _parsed,
      categoryId: _categoryId,
      walletId: _walletId,
      frequency: _frequency,
      nextRunAt: _nextRunAt,
      dayOfMonth: _dayOfMonth,
      weekday: _weekday,
      note: _note.text.trim(),
      active: widget.initial?.active ?? true,
    );

    try {
      final existing = widget.initial;
      if (existing == null || existing.id == 0) {
        await state.addRecurring(rule);
      } else {
        await state.updateRecurring(rule);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${context.tr('Could not save')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    final cats = state.categoriesFor(_type);
    final wallets = state.wallets;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null ? context.tr('New recurring') : context.tr('Edit recurring'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<TxType>(
            segments: [
              ButtonSegment(
                value: TxType.expense,
                label: Text(context.tr('Expense')),
                icon: Icon(Icons.north_east_rounded, size: 16),
              ),
              ButtonSegment(
                value: TxType.income,
                label: Text(context.tr('Income')),
                icon: Icon(Icons.south_west_rounded, size: 16),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              // Income and expense use disjoint category sets; reselect so the
              // dropdown never points at a category of the wrong direction.
              final next = state.categoriesFor(_type);
              _categoryId = next.isEmpty ? 0 : next.first.id;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: context.tr('Amount'),
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            value:
                cats.any((c) => c.id == _categoryId) ? _categoryId : null,
            decoration: InputDecoration(labelText: context.tr('Category')),
            items: [
              for (final c in cats)
                DropdownMenuItem(value: c.id, child: Text(context.tr(c.name))),
            ],
            onChanged: (v) => setState(() => _categoryId = v ?? 0),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            value:
                wallets.any((w) => w.id == _walletId) ? _walletId : null,
            decoration: InputDecoration(labelText: context.tr('Wallet')),
            items: [
              for (final w in wallets)
                DropdownMenuItem(value: w.id, child: Text(context.tr(w.name))),
            ],
            onChanged: (v) => setState(() => _walletId = v ?? 0),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<RecurFreq>(
            value: _frequency,
            decoration: InputDecoration(labelText: context.tr('Repeats')),
            items: [
              DropdownMenuItem(
                value: RecurFreq.weekly,
                child: Text(context.tr('Every week')),
              ),
              DropdownMenuItem(
                value: RecurFreq.monthly,
                child: Text(context.tr('Every month')),
              ),
            ],
            onChanged: (v) => setState(() => _frequency = v ?? _frequency),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_frequency == RecurFreq.monthly)
            DropdownButtonFormField<int>(
              value: _dayOfMonth,
              decoration: InputDecoration(
                labelText: context.tr('Day of month'),
                helperText: context.tr('Short months use their last day'),
              ),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('Day $d')),
              ],
              onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
            )
          else
            DropdownButtonFormField<int>(
              value: _weekday,
              decoration: InputDecoration(labelText: context.tr('Day of week')),
              items: [
                DropdownMenuItem(value: DateTime.monday, child: Text(context.tr('Monday'))),
                DropdownMenuItem(
                  value: DateTime.tuesday,
                  child: Text(context.tr('Tuesday')),
                ),
                DropdownMenuItem(
                  value: DateTime.wednesday,
                  child: Text(context.tr('Wednesday')),
                ),
                DropdownMenuItem(
                  value: DateTime.thursday,
                  child: Text(context.tr('Thursday')),
                ),
                DropdownMenuItem(value: DateTime.friday, child: Text(context.tr('Friday'))),
                DropdownMenuItem(
                  value: DateTime.saturday,
                  child: Text(context.tr('Saturday')),
                ),
                DropdownMenuItem(value: DateTime.sunday, child: Text(context.tr('Sunday'))),
              ],
              onChanged: (v) => setState(() => _weekday = v ?? 1),
            ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Next occurrence')),
            subtitle: Text(
              Formatters.dayHeader(_nextRunAt),
              style: TextStyle(fontSize: 12, color: muted),
            ),
            trailing: const Icon(Icons.calendar_today_rounded, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _nextRunAt,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() {
                  _nextRunAt = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    _nextRunAt.hour,
                    _nextRunAt.minute,
                  );
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'e.g. Netflix',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : () => _save(state),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('Save rule')),
          ),
        ],
      ),
    );
  }
}
