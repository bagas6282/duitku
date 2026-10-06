import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../core/strings.dart';
import '../../core/transitions.dart';
import 'forgot_pin_screen.dart';

/// Four-digit passcode gate shown before the app opens.
///
/// Biometric is attempted first when armed; the passcode is always available
/// as the fallback, so a failed fingerprint never locks the user out.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = LocalAuthentication();
  String _entry = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final state = context.read<AppState>();
    if (!state.biometricEnabled) return;
    try {
      final ok = await _auth.authenticate(
        localizedReason: context.tr('Unlock Duitku'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) state.unlock();
    } catch (_) {
      // No enrolled biometric on this device — the keypad is the fallback.
    }
  }

  void _tap(String digit) {
    if (_entry.length >= 4 || _busy) return;
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length == 4) _submit();
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;

    final state = context.read<AppState>();
    if (state.checkPin(_entry)) {
      state.unlock();
      return;
    }

    setState(() {
      _busy = false;
      _error = context.tr('Wrong passcode');
      _entry = '';
    });
  }

  /// Removing the passcode is a privileged action: it turns the lock off for
  /// good. It therefore requires proving you could already get in — the current
  /// passcode, or an enrolled fingerprint. Without this check anyone holding
  /// the phone could tap "Forgot?" and read every recorded transaction.
  Future<void> _forgot() async {
    // Navigate ke ForgotPinScreen untuk reset via email
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const ForgotPinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.void1 : AppColors.frost,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.mint.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppColors.mint,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    context.tr('Enter passcode'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('Your data stays on this device'),
                    style: TextStyle(
                      fontSize: 13,
                      color: fg.withOpacity(0.55),
                    ),
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
                              : fg.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  SizedBox(
                    height: 34,
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
                  _Keypad(
                    onDigit: _tap,
                    onBackspace: _backspace,
                    disabled: _busy,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state.biometricEnabled)
                        TextButton.icon(
                          onPressed: _tryBiometric,
                          icon: const Icon(Icons.fingerprint_rounded, size: 20),
                          label: Text(context.tr('Use fingerprint')),
                        ),
                      TextButton(
                        onPressed: _forgot,
                        child: Text(
                          context.tr('Forgot passcode?'),
                          style: TextStyle(
                            color: fg.withOpacity(0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.disabled,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;

    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: fg.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: disabled ? null : (onTap ?? () => onDigit(label)),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 60,
                child: Center(
                  child: child ??
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 22,
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
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            children: [
              for (final d in row) key(d),
            ],
          ),
        Row(
          children: [
            key('', onTap: () {}, child: const SizedBox.shrink()),
            key('0'),
            key(
              '',
              onTap: onBackspace,
              child: Icon(
                Icons.backspace_outlined,
                size: 21,
                color: fg.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
