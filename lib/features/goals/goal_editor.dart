import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/budget.dart';
import '../../core/strings.dart';

/// Add/edit a savings goal.
class GoalEditor extends StatefulWidget {
  const GoalEditor({super.key, this.initial});

  final SavingsGoal? initial;

  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  DateTime? _deadline;
  int _colorIndex = 0;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    if (g != null) {
      _name.text = g.name;
      _target.text = Formatters.thousands(g.targetAmount);
      _deadline = g.deadline;
      _colorIndex = g.colorIndex;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  num get _targetValue {
    final d = _target.text.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? 0 : (num.tryParse(d) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final accent =
        AppColors.categorical[_colorIndex % AppColors.categorical.length];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.tr('Edit goal') : context.tr('New goal')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: context.tr('Delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(state),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _FieldLabel('Name', muted: muted),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'e.g. Emergency fund',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FieldLabel(context.tr('Target amount'), muted: muted),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _target,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            inputFormatters: [_MoneyFormatter()],
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              hintText: '0',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FieldLabel(context.tr('Deadline'), muted: muted),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ??
                            DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 12),
                      );
                      if (picked != null) {
                        setState(() => _deadline = picked);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 17,
                            color: muted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _deadline == null
                                ? context.tr('No deadline')
                                : Formatters.longDate(_deadline!),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_deadline != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: () => setState(() => _deadline = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: context.tr('Clear'),
                ),
              ],
            ],
          ),
          if (_deadline != null && _targetValue > 0) ...[
            const SizedBox(height: AppSpacing.md),
            _PaceHint(
              target: _targetValue,
              deadline: _deadline!,
              muted: muted,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _FieldLabel(context.tr('Color'), muted: muted),
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
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, size: 20, color: accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _isEditing
                        ? 'Saved so far: '
                            '${Formatters.currency(widget.initial!.savedAmount)}'
                        : context.tr('Add money to this goal any time from the Goals tab.'),
                    style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ||
                    _name.text.trim().isEmpty ||
                    _targetValue <= 0
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
                : Text(_isEditing ? context.tr('Save changes') : context.tr('Create goal')),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppState state) async {
    setState(() => _saving = true);
    final goal = SavingsGoal(
      id: widget.initial?.id ?? 0,
      name: _name.text.trim(),
      targetAmount: _targetValue,
      savedAmount: widget.initial?.savedAmount ?? 0,
      colorIndex: _colorIndex,
      deadline: _deadline,
      done: widget.initial?.done ?? false,
    );

    try {
      await state.saveGoal(goal);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _confirmDelete(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete goal?')),
        content: Text(context.tr('The saved amount will be forgotten.')),
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
    if (ok == true) {
      await state.deleteGoal(widget.initial!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.muted});

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

class _PaceHint extends StatelessWidget {
  const _PaceHint({
    required this.target,
    required this.deadline,
    required this.muted,
  });

  final num target;
  final DateTime deadline;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = (deadline.year - now.year) * 12 + (deadline.month - now.month);
    if (months <= 0) {
      return Text(
        context.tr('That deadline is in the past.'),
        style: TextStyle(fontSize: 12.5, color: muted),
      );
    }
    final perMonth = target / months;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Set aside ${Formatters.currency(perMonth)} a month for '
              '$months month${months == 1 ? '' : 's'} to hit this.',
              style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = Formatters.thousands(num.tryParse(digits) ?? 0);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
