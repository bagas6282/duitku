import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted hashing for the app passcode.
///
/// The PIN is a 4-digit secret that also guards biometric fallback, so it is
/// never written to disk as-is: SharedPreferences is plain XML that ADB backup
/// and root can read. Only `salt` and `sha256(salt + pin)` are persisted, and
/// comparison is constant-time so a wrong guess cannot be narrowed by timing.
class PinHasher {
  PinHasher._();

  /// Number of PBKDF2-style iterations applied before storing.
  ///
  /// A 4-digit PIN has only 10,000 possible values, so a single SHA-256 round
  /// would fall to a trivial offline brute force. Stretching the hash makes
  /// each guess cost real time while staying instant for the user.
  static const int _iterations = 20000;

  /// Produces `iterations:salts:hash`, where salt is 16 random bytes in hex.
  static String hashPin(String pin, {String? salt}) {
    final useSalt = salt ?? _randomSalt();
    List<int> digest = utf8.encode('$useSalt$pin');
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return '$_iterations:$useSalt:${_hex(digest)}';
  }

  /// True when [pin] produces [stored]. Returns false for malformed records
  /// instead of throwing, so a corrupt preference cannot lock the user out of
  /// the app with a crash.
  static bool verify(String pin, String? stored) {
    if (stored == null || stored.isEmpty) return false;

    final parts = stored.split(':');
    if (parts.length != 3) return false;

    final iterations = int.tryParse(parts[0]);
    if (iterations == null || iterations <= 0) return false;

    // Refuse to honour a weakened record. The iteration count is stored on
    // disk, so anyone who can edit SharedPreferences could rewrite it as `1`
    // and turn an expensive offline attack into a cheap one. Only the exact
    // current constant is accepted.
    if (iterations != _iterations) return false;

    final salt = parts[1];
    List<int> digest = utf8.encode('$salt$pin');
    for (var i = 0; i < iterations; i++) {
      digest = sha256.convert(digest).bytes;
    }

    return _constantTimeEquals(_hex(digest), parts[2]);
  }

  /// Compares without early exit, so timing reveals nothing about the hash.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return _hex(bytes);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
