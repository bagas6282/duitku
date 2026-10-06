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
  /// bukan penolakan dari server. Dipakai untuk mencoba alamat cadangan.
  final bool networkError;

  const OtpResult(this.ok, [this.error, this.networkError = false]);

  static const OtpResult success = OtpResult(true);

  /// Kegagalan jaringan — layak dicoba ke alamat lain.
  static OtpResult network(String msg) => OtpResult(false, msg, true);
}

/// Service OTP Duitku.
///
/// Kode OTP di-generate & diverifikasi di server (VPS), lalu dikirim via Google Apps Script (Gmail).
/// Aplikasi hanya jadi perantara — kredensial email tidak pernah ikut ke APK.
class EmailService {
  // Alamat server OTP (VPS). Port 80 utama, 8081 cadangan — kalau salah
  // satunya diblokir jaringan, alamat berikutnya dicoba otomatis.
  static const List<String> _baseUrls = [
    'http://94.237.78.157',
    'http://94.237.78.157:8081',
  ];

  static int _preferred = 0; // indeks alamat yang terakhir berhasil
  static const String _appKey = 'duitku-otp-2026';
  static const Duration _timeout = Duration(seconds: 15);

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-app-key': _appKey,
  };

  /// Handler tiruan untuk pengujian otomatis (unit/widget test).
  @visibleForTesting
  static Future<OtpResult> Function(String path, Map<String, dynamic> body)? mockHandler;

  /// Minta server mengirim kode OTP ke [email].
  static Future<OtpResult> requestOtp({
    required String email,
    String purpose = 'verifikasi akun',
  }) {
    return _post('/api/otp/send', {
      'email': email.trim().toLowerCase(),
      'purpose': purpose,
    });
  }

  /// Verifikasi kode yang dimasukkan user.
  static Future<OtpResult> verifyOtp({
    required String email,
    required String code,
  }) {
    return _post('/api/otp/verify', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
  }

  /// Coba semua alamat server sampai ada yang menjawab.
  static Future<OtpResult> _post(String path, Map<String, dynamic> body) async {
    if (mockHandler != null) {
      return mockHandler!(path, body);
    }

    final order = <int>[
      _preferred,
      for (var i = 0; i < _baseUrls.length; i++)
        if (i != _preferred) i,
    ];

    OtpResult last = OtpResult.network(
      'Server tidak merespons. Periksa koneksi internet Anda lalu coba lagi.',
    );

    for (final i in order) {
      final res = await _postTo(_baseUrls[i], path, body);

      // Server menjawab (meski menolak) -> alamat ini jalan, berhenti.
      if (!res.networkError) {
        _preferred = i;
        return res;
      }
      last = res;
    }

    debugPrint('❌ EmailService: semua alamat server gagal dijangkau.');
    return last;
  }

  static Future<OtpResult> _postTo(
    String baseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
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
      return OtpResult.network(
        'Koneksi ke server terputus. Coba beberapa saat lagi.',
      );
    } catch (e) {
      debugPrint('❌ EmailService error ($baseUrl$path): $e');
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
