import 'package:flutter/services.dart';

import 'formatters.dart';

/// Keeps an amount field readable while the user types.
///
/// Digits are grouped as they are entered (`1200000` -> `1.200.000`), which is
/// how a nominal is read in Indonesian. The field only ever holds digits and
/// separators, so callers can strip non-digits and parse straight to a number.
///
/// Lives in `core` rather than beside one editor because the transaction,
/// budget, wallet, goal and recurring forms all accept money — and a second
/// copy of this rule is how one screen silently starts accepting 1.2 million
/// as 12 rupiah.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    // Guard against a value large enough to lose precision as a double.
    final clamped = digits.length > 15 ? digits.substring(0, 15) : digits;
    final value = num.tryParse(clamped) ?? 0;
    final text = Formatters.thousands(value);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
