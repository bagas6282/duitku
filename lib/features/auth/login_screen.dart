import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../services/email_service.dart';
import '../../services/email_validator_service.dart';
import 'otp_verification_screen.dart';

/// Screen for authenticating users (Login / Register / Guest mode).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.mint,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isRegister) {
      if (_passCtrl.text != _confirmPassCtrl.text) {
        _showError('Konfirmasi kata sandi tidak cocok.');
        return;
      }
      
      final email = _emailCtrl.text.trim().toLowerCase();
      
      setState(() => _loading = true);

      // Minta server kirim OTP ke email user
      final sendResult = await EmailService.requestOtp(
        email: email,
        purpose: 'verifikasi akun',
      );
      
      if (!mounted) return;
      setState(() => _loading = false);
      
      if (!sendResult.ok) {
        _showError(sendResult.error ?? 'Gagal mengirim OTP. Coba lagi.');
        return;
      }
      
      // Tampilkan layar OTP — verifikasi langsung via server
      final verified = await Navigator.push<String>(
        context,
        AppPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            purpose: 'register',
            onResendOtp: () => EmailService.requestOtp(
              email: email,
              purpose: 'verifikasi akun',
            ),
            onVerifyOtp: (code) => EmailService.verifyOtp(
              email: email,
              code: code,
            ),
          ),
        ),
      );
      
      if (!mounted) return;
      if (verified != 'verified') return; // user batal
    }

    setState(() => _loading = true);
    final state = context.read<AppState>();

    try {
      if (_isRegister) {
        final err = await state.register(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
        if (!mounted) return;
        if (err != null) {
          _showError(err);
        } else {
          _showSuccess('Akun berhasil dibuat! Selamat datang di Duitku.');
        }
      } else {
        final err = await state.login(
          _emailCtrl.text,
          _passCtrl.text,
        );
        if (!mounted) return;
        if (err != null) {
          _showError(err);
        } else {
          _showSuccess('Berhasil masuk.');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  


  Future<void> _guestLogin() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().continueAsGuest();
      if (!mounted) return;
      _showSuccess('Masuk sebagai Pengguna Tamu.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lupa Kata Sandi?'),
        content: const Text(
          'Duitku menyimpan data akun secara offline & aman di perangkat Anda.\n\n'
          'Jika Anda lupa kata sandi akun lokal, Anda dapat masuk sebagai Tamu atau membuat akun baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted  = isDark ? AppColors.textMuted : AppColors.textMutedL;

    return Scaffold(
      // Background split — atas gelap pakai brand color, bawah surface biasa
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.38,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1835), Color(0xFF112040)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Brand area ───────────────────────────────────
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.royal,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.royal.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Duitku',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegister
                              ? 'Buat akun, mulai lacak keuangan'
                              : 'Selamat datang kembali',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.55),
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Card utama ───────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.void1 : AppColors.frostCard,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E2840)
                                  : const Color(0xFFE0E7F5),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Toggle Masuk / Daftar
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.void2
                                      : const Color(0xFFF2F5FF),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.lg),
                                  ),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    _Tab(
                                      label: 'Masuk',
                                      active: !_isRegister,
                                      isDark: isDark,
                                      onTap: () => setState(() => _isRegister = false),
                                    ),
                                    _Tab(
                                      label: 'Daftar',
                                      active: _isRegister,
                                      isDark: isDark,
                                      onTap: () => setState(() => _isRegister = true),
                                    ),
                                  ],
                                ),
                              ),

                              // Form fields
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_isRegister) ...[
                                      TextFormField(
                                        controller: _nameCtrl,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Lengkap',
                                          hintText: 'mis. Bagas Pradana',
                                          prefixIcon: Icon(Icons.person_outline_rounded),
                                        ),
                                        validator: (v) => (v == null || v.trim().isEmpty)
                                            ? 'Masukkan nama kamu'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'nama@email.com',
                                        prefixIcon: Icon(Icons.mail_outline_rounded),
                                      ),
                                      validator: (v) =>
                                          EmailValidatorService.validateEmail(
                                        v,
                                        isRegistering: _isRegister,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: _obscurePassword,
                                      textInputAction: _isRegister
                                          ? TextInputAction.next
                                          : TextInputAction.done,
                                      onFieldSubmitted: (_) {
                                        if (!_isRegister) _submit();
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Kata Sandi',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined),
                                          onPressed: () => setState(() =>
                                              _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Masukkan kata sandi';
                                        if (_isRegister && v.length < 6) return 'Minimal 6 karakter';
                                        return null;
                                      },
                                    ),
                                    if (_isRegister) ...[
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _confirmPassCtrl,
                                        obscureText: _obscureConfirm,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        decoration: InputDecoration(
                                          labelText: 'Konfirmasi Kata Sandi',
                                          prefixIcon:
                                              const Icon(Icons.lock_reset_rounded),
                                          suffixIcon: IconButton(
                                            icon: Icon(_obscureConfirm
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined),
                                            onPressed: () => setState(() =>
                                                _obscureConfirm = !_obscureConfirm),
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) return 'Konfirmasi kata sandi';
                                          if (v != _passCtrl.text) return 'Kata sandi tidak cocok';
                                          return null;
                                        },
                                      ),
                                    ],
                                    if (!_isRegister) ...[
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _showForgotPasswordDialog,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Lupa kata sandi?',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),

                                    // Submit
                                    FilledButton(
                                      onPressed: _loading ? null : _submit,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _isRegister ? 'Buat Akun' : 'Masuk',
                                            ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Divider
                                    Row(children: [
                                      Expanded(child: Divider(color: isDark ? const Color(0xFF1E2840) : const Color(0xFFE8EDF8))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('atau', style: TextStyle(fontSize: 12.5, color: muted)),
                                      ),
                                      Expanded(child: Divider(color: isDark ? const Color(0xFF1E2840) : const Color(0xFFE8EDF8))),
                                    ]),

                                    const SizedBox(height: 16),

                                    OutlinedButton.icon(
                                      onPressed: _loading ? null : _guestLogin,
                                      icon: const Icon(Icons.person_outline_rounded, size: 18),
                                      label: const Text('Lanjutkan tanpa akun'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'Data tersimpan aman di perangkat kamu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMuted : AppColors.textMutedL,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab toggle helper ────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.void1 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: active
                ? [BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? AppColors.royal
                  : (isDark ? AppColors.textMuted : AppColors.textMutedL),
            ),
          ),
        ),
      ),
    );
  }
}
