import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';

/// Collects a new passcode, then confirms it.
class PasscodeSetup extends StatefulWidget {
  const PasscodeSetup({super.key});

  @override
  State<PasscodeSetup> createState() => _PasscodeSetupState();
}

class _PasscodeSetupState extends State<PasscodeSetup> {
  String _first = '';
  String _entry = '';
  String? _error;
  bool _confirming = false;

  void _tap(String d) {
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == 4) _advance();
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _advance() async {
    if (!_confirming) {
      setState(() {
        _first = _entry;
        _entry = '';
        _confirming = true;
      });
      return;
    }

    if (_entry != _first) {
      setState(() {
        _error = context.tr('Codes did not match — start again');
        _entry = '';
        _first = '';
        _confirming = false;
      });
      return;
    }

    await context.read<AppState>().setPin(_entry);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Passcode set'))),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      appBar: AppBar(
        title: Text(_confirming ? context.tr('Confirm passcode') : context.tr('Create passcode')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _confirming
                      ? context.tr('Enter the same four digits again')
                      : context.tr('Pick four digits you will remember'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: muted),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _entry.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: filled ? 16 : 13,
                      height: filled ? 16 : 13,
                      decoration: BoxDecoration(
                        color: filled
                            ? AppColors.mint
                            : theme.colorScheme.onSurface
                                .withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                SizedBox(
                  height: 40,
                  child: _error == null
                      ? null
                      : Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Pad(onDigit: _tap, onBackspace: _backspace),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: fg.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: onTap ?? () => onDigit(label),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 58,
                  child: Center(
                    child: child ??
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d)]),
        Row(
          children: [
            key('', onTap: () {}, child: const SizedBox.shrink()),
            key('0'),
            key(
              '',
              onTap: onBackspace,
              child: Icon(
                Icons.backspace_outlined,
                size: 20,
                color: fg.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
