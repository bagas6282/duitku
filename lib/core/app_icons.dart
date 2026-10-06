import 'package:flutter/material.dart';

/// Glyphs that must stay in lock-step with the seed names in [AppDatabase].
class AppIcons {
  AppIcons._();

  /// Reconstructs a [Category]'s icon from the integer stored in the database.
  ///
  /// Using a factory method rather than calling [IconData] directly at each
  /// call site makes this the single place that has to deal with the runtime
  /// code point: Flutter wants literal constants in [IconData] so the icon font
  /// can be tree-shaken, but category glyphs live in the database and are only
  /// known at runtime. The release build therefore ships with
  /// `--no-tree-shake-icons` (see README), and the lint is silenced here on
  /// purpose rather than at every call site.
  static IconData fromCode(int codePoint) =>
      // ignore: non_const_argument_for_const_parameter
      IconData(codePoint, fontFamily: 'MaterialIcons');

  /// Cash / bank / e-wallet — used on the wallet manager and the
  /// transaction-editor chip row.
  static IconData wallet(String name) {
    switch (name) {
      case 'Cash':
        return Icons.payments_rounded;
      case 'Bank Account':
        return Icons.account_balance_rounded;
      case 'E-Wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }
}
