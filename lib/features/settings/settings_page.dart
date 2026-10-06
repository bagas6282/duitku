import 'dart:io';
import '../../core/transitions.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/csv.dart';
import '../../core/formatters.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models/transaction.dart';
import '../../data/models/user.dart';
import 'category_manager.dart';
import 'passcode_setup.dart';
import 'recurring_editor.dart';
import 'wallet_manager.dart';

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
        if (state.currentUser != null) ...[
          _AccountCard(
            user: state.currentUser!,
            onLogout: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar dari Akun?'),
                  content: const Text(
                    'Anda akan keluar dari akun ini. Data keuangan lokal tetap aman tersimpan di perangkat.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await state.logout();
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
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
                  AppPageRoute(
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
              AppPageRoute(builder: (_) => const WalletManager()),
            ),
          ),
          _TapRow(
            label: context.tr('Categories'),
            subtitle: '${state.categories.length} buckets',
            icon: Icons.category_outlined,
            onTap: () => Navigator.of(context).push(
              AppPageRoute(builder: (_) => const CategoryManager()),
            ),
          ),
          _TapRow(
            label: context.tr('Recurring transactions'),
            subtitle: '${state.recurring.length} rules',
            icon: Icons.repeat_rounded,
            onTap: () => Navigator.of(context).push(
              AppPageRoute(builder: (_) => const RecurringList()),
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
                'Duitku 1.5.4',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4),
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
                      .withOpacity(0.32),
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
    // Capture translations before the first await so they remain valid
    // if the widget is unmounted while the export is in progress.
    final subjectLabel = context.tr('Duitku backup');
    final successMsg = context.tr('Backup ready to share');
    final failMsg = context.tr('Export failed');
    try {
      final file = await state.exportBackup();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subjectLabel,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failMsg: $e')));
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

    // Capture translation before the restore await in case the widget unmounts.
    final successMsg = context.tr('Backup restored');
    final failMsg = context.tr('Import failed');
    try {
      await state.importBackup(File(path));
      messenger.showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failMsg: $e')));
    }
  }

  Future<void> _exportCsv(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    // Build the translated header row and all data rows before the first await
    // so context stays valid throughout. Rows are built from already-loaded
    // state, so no DB round-trip is needed here.
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
    final csvSubject = context.tr('Duitku CSV');
    final successMsg = context.tr('CSV ready to share');
    final failMsg = context.tr('Export failed');
    // Names may contain commas or quotes; Csv.encode escapes them properly
    // instead of mangling the text (and misaligning every column after it).
    final csv = Csv.encode(rows);

    try {
      final dir = await state.getApplicationDocumentsDirectoryPath();
      final file = File(
        '$dir/duitku-${state.monthKey}.csv',
      );
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], subject: csvSubject);

      messenger.showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$failMsg: $e')));
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.tr('Delete all')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final successMsg = context.tr('All data deleted');
    await state.wipeEverything();
    messenger.showSnackBar(
      SnackBar(content: Text(successMsg)),
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
        Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

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
        Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

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
        Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final accent = danger ? AppColors.danger : muted;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 21, color: accent),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: danger ? AppColors.danger : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: muted),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: muted.withOpacity(0.6),
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
          Icon(icon, size: 21, color: fg.withOpacity(0.5)),
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
              color: fg.withOpacity(0.05),
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
                              : fg.withOpacity(0.6),
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
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Recurring'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          AppPageRoute(builder: (_) => const RecurringEditor()),
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
                      AppPageRoute(
                        builder: (_) => RecurringEditor(initial: r),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.categorical[
                              (cat?.colorIndex ?? 0) %
                                  AppColors.categorical.length]
                          .withOpacity(0.16),
                      child: Icon(
                        r.type == TxType.income
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 18,
                        color: r.type == TxType.income
                            ? AppColors.mint
                            : AppColors.danger,
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
                            final deletedMsg = context.tr('Recurring rule deleted');
                            await state.deleteRecurring(r.id);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(deletedMsg),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.onLogout,
  });

  final UserModel user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.void2 : AppColors.frostCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.mint.withAlpha(40),
            child: Text(
              user.initials,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.mint,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textMuted : AppColors.textMutedL,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            tooltip: 'Keluar',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
