import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/csv.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/transaction.dart';
import 'category_manager.dart';
import 'passcode_setup.dart';
import 'recurring_editor.dart';
import 'wallet_manager.dart';
import '../../core/strings.dart';

/// Settings: appearance, security, data, and the record-keeping bits the
/// report needs (wallets, categories, export).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr('Settings'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(context.tr('Appearance'), children: [
          _SegmentedRow(
            label: context.tr('Theme'),
            icon: Icons.brightness_6_rounded,
            options: [context.tr('System'), context.tr('Light'), context.tr('Dark')],
            selectedIndex: switch (state.themeMode) {
              ThemeMode.light => 1,
              ThemeMode.dark => 2,
              ThemeMode.system => 0,
            },
            onSelected: (i) => state.setThemeMode(
              switch (i) {
                1 => ThemeMode.light,
                2 => ThemeMode.dark,
                _ => ThemeMode.system,
              },
            ),
          ),
          _SegmentedRow(
            label: context.tr('Language'),
            icon: Icons.translate_rounded,
            options: [context.tr('Indonesia'), context.tr('English')],
            selectedIndex: state.localeCode == 'en' ? 1 : 0,
            onSelected: (i) => state.setLocale(i == 1 ? 'en' : 'id'),
          ),
        ],),
        const SizedBox(height: AppSpacing.md),
        _Section(context.tr('Security'), children: [
          _SwitchRow(
            label: context.tr('Passcode lock'),
            subtitle: state.pinEnabled
                ? context.tr('A 4-digit code is required to open Duitku')
                : context.tr('Not set'),
            icon: Icons.lock_outline_rounded,
            value: state.pinEnabled,
            onChanged: (v) async {
              if (v) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PasscodeSetup(),
                  ),
                );
              } else {
                await state.setPin(null);
              }
            },
          ),
          _SwitchRow(
            label: context.tr('Fingerprint unlock'),
            subtitle: state.pinEnabled
                ? context.tr('Use biometrics instead of typing the code')
                : context.tr('Set a passcode first'),
            icon: Icons.fingerprint_rounded,
            value: state.biometricEnabled,
            enabled: state.pinEnabled,
            onChanged: (v) => state.setBiometricEnabled(v),
          ),
        ],),
        const SizedBox(height: AppSpacing.md),
        _Section(context.tr('Records'), children: [
          _TapRow(
            label: context.tr('Wallets'),
            subtitle: '${state.wallets.length} accounts',
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletManager()),
            ),
          ),
          _TapRow(
            label: context.tr('Categories'),
            subtitle: '${state.categories.length} buckets',
            icon: Icons.category_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryManager()),
            ),
          ),
          _TapRow(
            label: context.tr('Recurring transactions'),
            subtitle: '${state.recurring.length} rules',
            icon: Icons.repeat_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringList()),
            ),
          ),
        ],),
        const SizedBox(height: AppSpacing.md),
        _Section('Data', children: [
          _TapRow(
            label: context.tr('Export backup'),
            subtitle: context.tr('Save a copy of the database'),
            icon: Icons.upload_file_rounded,
            onTap: () => _export(context, state),
          ),
          _TapRow(
            label: context.tr('Import backup'),
            subtitle: context.tr('Restore from a .db file'),
            icon: Icons.download_rounded,
            onTap: () => _import(context, state),
          ),
          _TapRow(
            label: context.tr('Export CSV'),
            subtitle: context.tr('Spreadsheet of this month'),
            icon: Icons.table_chart_outlined,
            onTap: () => _exportCsv(context, state),
          ),
          _TapRow(
            label: context.tr('Reset all data'),
            subtitle: context.tr('Delete every transaction and start over'),
            icon: Icons.delete_forever_outlined,
            danger: true,
            onTap: () => _reset(context, state),
          ),
        ],),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Column(
            children: [
              Text(
                'Duitku 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('All data stays on this device'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await state.exportBackup();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: context.tr('Duitku backup'),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Backup ready to share'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Import backup?')),
        content: Text(
          context.tr(
            'Everything currently in Duitku will be replaced by the file you pick.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Choose file')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    try {
      await state.importBackup(File(path));
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Backup restored'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _exportCsv(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final rows = <List<String>>[
        ['Date', 'Type', context.tr('Category'), context.tr('Wallet'), context.tr('Amount'), 'Note'],
      ];
      for (final t in state.transactions) {
        rows.add([
          Formatters.date(t.date),
          t.type.name,
          context.tr(state.categoryOf(t.categoryId)?.name ?? ''),
          context.tr(state.walletOf(t.walletId)?.name ?? ''),
          t.amount.toString(),
          t.note ?? '',
        ]);
      }
      // Names may contain commas or quotes; Csv.encode escapes them properly
      // instead of mangling the text (and misaligning every column after it).
      final csv = Csv.encode(rows);

      final dir = await state.getApplicationDocumentsDirectoryPath();
      final file = File(
        '$dir/duitku-${state.monthKey}.csv',
      );
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], subject: context.tr('Duitku CSV'));

      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('CSV ready to share'))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _reset(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Reset everything?')),
        content: const Text(
          'Every transaction, budget and goal will be deleted. Wallets and '
          'categories return to their defaults. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: Text(context.tr('Delete all')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await state.wipeEverything();
    messenger.showSnackBar(
      SnackBar(content: Text(context.tr('All data deleted'))),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, size: 21, color: muted),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: muted),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppColors.mint,
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final accent = danger ? AppColors.expense : muted;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 21, color: accent),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: danger ? AppColors.expense : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: muted),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: muted.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.icon,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 21, color: fg.withValues(alpha: 0.5)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selectedIndex == i
                            ? AppColors.mint
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        options[i],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: selectedIndex == i
                              ? Colors.white
                              : fg.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recurring rules: create, edit, enable/disable and delete.
///
/// A rule is only a template — [AppState] posts a real transaction whenever
/// one comes due — so editing or deleting a rule never rewrites history.
class RecurringList extends StatelessWidget {
  const RecurringList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Recurring'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecurringEditor()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('New rule')),
      ),
      body: state.recurring.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, size: 34, color: muted),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('No recurring rules'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Rules are created from a transaction by marking it as '
                        'repeating. They post automatically when due.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.recurring.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final r = state.recurring[i];
                final cat = state.categoryOf(r.categoryId);
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecurringEditor(initial: r),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.categorical[
                              (cat?.colorIndex ?? 0) %
                                  AppColors.categorical.length]
                          .withValues(alpha: 0.16),
                      child: Icon(
                        r.type == TxType.income
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 18,
                        color: r.type == TxType.income
                            ? AppColors.mint
                            : AppColors.expense,
                      ),
                    ),
                    title: Text(
                      context.tr(cat?.name ?? 'Recurring'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        // A paused rule should read as inactive at a glance.
                        color: r.active ? null : muted,
                      ),
                    ),
                    subtitle: Text(
                      '${Formatters.currency(r.amount)} · '
                      '${r.frequency.name}'
                      '${r.active ? ' · next ${Formatters.date(r.nextRunAt)}' : ' · paused'}'
                      '${r.note.isEmpty ? '' : ' · ${r.note}'}',
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: r.active,
                          onChanged: (v) =>
                              state.updateRecurring(r.copyWith(active: v)),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(context.tr('Delete rule?')),
                                content: Text(
                                  context.tr('Transactions it already created are kept.'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(context.tr('Cancel')),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(context.tr('Delete')),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            await state.deleteRecurring(r.id);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(context.tr('Recurring rule deleted')),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
