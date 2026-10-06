import 'package:flutter/material.dart';
import '../../core/transitions.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../services/email_service.dart';
import '../../services/email_validator_service.dart';
import 'otp_verification_screen.dart';

/// Layar untuk reset PIN yang lupa.
/// 
/// Flow: input email → kirim OTP → verifikasi OTP → set PIN baru.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;


  @override
  void dispose() {
    _emailCtrl.dispose();
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

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim().toLowerCase();
    
    setState(() => _loading = true);

    // Cek apakah email terdaftar
    final state = context.read<AppState>();
    final userExists = await state.checkEmailExists(email);
    
    if (!mounted) return;
    
    if (!userExists) {
      setState(() => _loading = false);
      _showError('Email tidak terdaftar di sistem.');
      return;
    }

    // Minta server kirim OTP ke email user
    final sendResult = await EmailService.requestOtp(
      email: email,
      purpose: 'reset PIN',
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!sendResult.ok) {
      _showError(sendResult.error ?? 'Gagal mengirim OTP. Coba lagi.');
      return;
    }

    // Navigate ke layar verifikasi OTP — verifikasi dilakukan server-side
    final verified = await Navigator.push<String>(
      context,
      AppPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: email,
          purpose: 'reset_pin',
          onResendOtp: () => EmailService.requestOtp(
            email: email,
            purpose: 'reset PIN',
          ),
          onVerifyOtp: (code) => EmailService.verifyOtp(
            email: email,
            code: code,
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (verified == 'verified') {
      // OTP benar — arahkan ke set PIN baru
      _showResetPinDialog(email);
    }
  }

  void _showResetPinDialog(String email) {
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buat PIN Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan PIN baru (4-6 digit angka)',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN Baru',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Kembali ke lock screen
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final pin = newPinCtrl.text.trim();
                final confirm = confirmPinCtrl.text.trim();

                if (pin.length < 4 || pin.length > 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('PIN harus 4-6 digit'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                if (pin != confirm) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Konfirmasi PIN tidak cocok'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }

                // Set PIN baru
                final state = context.read<AppState>();
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                final navDialog = Navigator.of(ctx);
                
                await state.resetPinWithEmail(email: email, newPin: pin);
                
                navDialog.pop(); // Close dialog
                nav.pop(); // Kembali ke lock screen
                
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ PIN berhasil direset! Silakan login.'),
                    backgroundColor: AppColors.mint,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: isDark ? AppColors.void1 : AppColors.frost,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lupa PIN'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.mint.withAlpha(35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.mint,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Reset PIN Anda',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      'Masukkan email yang terdaftar. Kami akan mengirim kode OTP untuk verifikasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: fg.withAlpha(150),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email Input
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Terdaftar',
                        hintText: 'nama@email.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (val) {
                        return EmailValidatorService.validateEmail(val);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    FilledButton.icon(
                      onPressed: _loading ? null : _sendOtp,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _loading ? 'Mengirim...' : 'Kirim Kode OTP',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mint,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? AppColors.void2 
                            : AppColors.frostCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: fg.withAlpha(30),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: fg.withAlpha(150),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Kode OTP akan dikirim ke email Anda dan berlaku selama 5 menit.',
                              style: TextStyle(
                                fontSize: 12,
                                color: fg.withAlpha(150),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
