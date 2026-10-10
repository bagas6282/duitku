import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Hasil operasi OTP.
class OtpResult {
  final bool ok;
  final String? error;

  /// true kalau kegagalannya di jaringan (timeout / koneksi terputus),
  /// bukan penolakan dari server.
  final bool networkError;

  const OtpResult(this.ok, [this.error, this.networkError = false]);

  static const OtpResult success = OtpResult(true);

  /// Kegagalan jaringan.
  static OtpResult network(String msg) => OtpResult(false, msg, true);
}

/// Service OTP Duitku.
///
/// Backend-nya Google Apps Script + GmailApp, bukan VPS. Kode OTP di-generate
/// dan diverifikasi di Apps Script, lalu dikirim lewat GmailApp.
/// Endpoint dan app key diberikan saat build lewat --dart-define, sehingga
/// kredensial email tidak pernah ikut ke APK.
class EmailService {
  /// URL web app Apps Script (akhiran /exec), diisi lewat --dart-define.
  static const String _endpoint = String.fromEnvironment(
    'OTP_ENDPOINT',
    defaultValue: '',
  );

  /// Shared secret yang dicek Apps Script, diisi lewat --dart-define.
  static const String _appKey = String.fromEnvironment(
    'OTP_APP_KEY',
    defaultValue: '',
  );

  static const Duration _timeout = Duration(seconds: 20);

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  /// Handler tiruan untuk pengujian otomatis (unit/widget test).
  @visibleForTesting
  static Future<OtpResult> Function(String path, Map<String, dynamic> body)?
  mockHandler;

  /// Minta server mengirim kode OTP ke [email].
  static Future<OtpResult> requestOtp({
    required String email,
    String purpose = 'verifikasi akun',
  }) {
    return _post('otp/send', {
      'email': email.trim().toLowerCase(),
      'purpose': purpose,
    });
  }

  /// Verifikasi kode yang dimasukkan user.
  static Future<OtpResult> verifyOtp({
    required String email,
    required String code,
  }) {
    return _post('otp/verify', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
  }

  /// Kirim satu request ke endpoint Apps Script.
  ///
  /// [action] dikirim sebagai field `action` di body (mis. 'otp/send').
  static Future<OtpResult> _post(
    String action,
    Map<String, dynamic> body,
  ) async {
    if (mockHandler != null) {
      return mockHandler!('/api/$action', body);
    }

    if (_endpoint.isEmpty) {
      return const OtpResult(false, 'Layanan OTP belum dikonfigurasi.');
    }

    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'action': action,
              'appKey': _appKey,
              ...body,
            }),
          )
          .timeout(_timeout);

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return const OtpResult(false, 'Respons server tidak dikenal.');
      }

      if (decoded['ok'] == true) return OtpResult.success;

      final msg = decoded['error']?.toString();
      return OtpResult(false, msg ?? 'Terjadi kesalahan. Coba lagi.');
    } on TimeoutException {
      return OtpResult.network(
        'Server tidak merespons. Periksa koneksi internet Anda lalu coba lagi.',
      );
    } on SocketException {
      return OtpResult.network(
        'Tidak dapat terhubung ke server. Pastikan internet aktif, '
        'lalu coba lagi.',
      );
    } on HttpException {
      debugPrint('EmailService error (action: $action): HttpException');
      return OtpResult.network(
        'Koneksi ke server terputus. Coba beberapa saat lagi.',
      );
    } on FormatException {
      // Respons bukan JSON (mis. halaman login Google atau HTML error),
      // jadi ini bukan masalah jaringan.
      debugPrint('EmailService error (action: $action): FormatException');
      return const OtpResult(false, 'Respons server tidak dikenal.');
    } on http.ClientException {
      // Termasuk kegagalan redirect (mis. terlalu banyak redirect).
      debugPrint('EmailService error (action: $action): ClientException');
      return OtpResult.network(
        'Tidak dapat terhubung ke server. Pastikan internet aktif, '
        'lalu coba lagi.',
      );
    } catch (e) {
      debugPrint(
        'EmailService error (action: $action): ${e.runtimeType}',
      );
      return OtpResult.network(
        'Tidak dapat terhubung ke server. Pastikan internet aktif, '
        'lalu coba lagi.',
      );
    }
  }

  /// Validasi format email basic (dipakai internal).
  static bool isValidEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    return trimmed.contains('@') &&
        trimmed.contains('.') &&
        trimmed.length >= 5;
  }
}
