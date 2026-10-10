import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../services/email_service.dart';

/// Layar untuk input OTP 6 digit dengan countdown timer.
/// 
/// Dipakai untuk verifikasi email saat register dan reset PIN.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.purpose,
    required this.onResendOtp,
    this.onVerifyOtp,
  });

  final String email;
  final String purpose; // 'register' atau 'reset_pin'
  final Future<OtpResult> Function() onResendOtp;

  /// Kalau diisi, verifikasi dilakukan lewat callback ini (server-side).
  /// Kalau null, layar ini hanya mengembalikan kode yang diketik ke pemanggil.
  final Future<OtpResult> Function(String code)? onVerifyOtp;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = 
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = 
      List.generate(6, (_) => FocusNode());
  
  bool _loading = false;
  String? _error;
  int _countdown = 300; // 5 menit dalam detik
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final ctrl in _controllers) {
      ctrl.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 300;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        // Hitung mundur habis: tombol kirim ulang aktif di tick yang sama.
        timer.cancel();
        setState(() {
          _countdown = 0;
          _canResend = true;
        });
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    // Hanya digit yang diterima; sisanya dibuang.
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // Paste atau ketikan lebih dari satu digit: sebarkan ke field berikutnya.
      _fillFrom(index, digits);
      return;
    }
    if (digits != value) {
      _controllers[index].value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    if (digits.length == 1) {
      // Pindah ke field berikutnya
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Digit terakhir — auto submit
        _focusNodes[index].unfocus();
        _submit();
      }
    } else if (digits.isEmpty && index > 0) {
      // Backspace — pindah ke field sebelumnya
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _error = null);
  }

  /// Mengisi field mulai dari [start] dengan [digits], maksimal sampai field ke-6.
  void _fillFrom(int start, String digits) {
    var i = start;
    for (final ch in digits.split('')) {
      if (i > 5) break;
      _controllers[i].text = ch;
      i++;
    }
    setState(() => _error = null);
    if (i > 5) {
      _focusNodes[5].unfocus();
      _submit();
    } else {
      _focusNodes[i].requestFocus();
    }
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _submit() async {
    if (_loading) return; // cegah submit ganda saat request berjalan
    final otp = _otpCode;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Masukkan 6 digit kode OTP');
      return;
    }

    final verify = widget.onVerifyOtp;
    if (verify == null) {
      // Mode lama: kembalikan kode ke pemanggil
      Navigator.pop(context, otp);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final OtpResult result;
    try {
      result = await verify(otp);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memverifikasi kode. Coba lagi.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.ok) {
      Navigator.pop(context, 'verified');
      return;
    }

    setState(() => _error = result.error ?? 'Kode salah. Coba lagi.');
    for (final ctrl in _controllers) {
      ctrl.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _resend() async {
    if (!_canResend || _loading) return;
    
    setState(() => _loading = true);
    final result = await widget.onResendOtp();
    
    if (!mounted) return;
    setState(() => _loading = false);
    
    if (result.ok) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode OTP baru telah dikirim ke email Anda.'),
          backgroundColor: AppColors.mint,
        ),
      );
      // Clear semua input
      for (final ctrl in _controllers) {
        ctrl.clear();
      }
      setState(() => _error = null);
      _focusNodes[0].requestFocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Gagal mengirim ulang OTP. Coba lagi.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String get _countdownText {
    final minutes = _countdown ~/ 60;
    final seconds = _countdown % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.mint.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mail_lock_rounded,
                      color: AppColors.mint,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'Verifikasi Email',
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
                    'Kami telah mengirim kode OTP 6 digit ke',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: fg.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mint,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // OTP Input Fields (responsif & anti-overflow)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = ((constraints.maxWidth - (5 * 8)) / 6).clamp(38.0, 48.0);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Container(
                            width: itemWidth,
                            height: 54,
                            margin: EdgeInsets.symmetric(
                              horizontal: index == 0 || index == 5 ? 0 : 3.5,
                            ),
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: isDark 
                                    ? AppColors.void2 
                                    : AppColors.frostCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: fg.withAlpha(30),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.mint,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) => _onDigitChanged(index, val),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  
                  // Error message
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
                  
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verifikasi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Countdown & Resend
                  if (!_canResend)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: fg.withAlpha(150),
                        ),
                        Text(
                          'Kode berlaku selama $_countdownText',
                          style: TextStyle(
                            fontSize: 13,
                            color: fg.withAlpha(150),
                          ),
                        ),
                      ],
                    )
                  else
                    TextButton.icon(
                      onPressed: _loading ? null : _resend,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Kirim Ulang Kode'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.mint,
                      ),
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
