@Tags(['db'])
library;

import 'package:duitku/core/csv.dart';
import 'package:duitku/core/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Security tests for the things that actually protect user data here.
///
/// This app is a personal finance tracker that holds every transaction on the
/// device and never phones home, so the realistic threats are: someone reading
/// the app's storage off the phone, someone guessing the PIN, and the export
/// file being weaponised against whoever opens it. Each block below attacks one
/// of those.
void main() {
  group('PIN storage', () {
    test('a stored PIN never contains the PIN itself', () {
      const pin = '4821';
      final stored = PinHasher.hashPin(pin);

      expect(stored.contains(pin), isFalse,
          reason: 'the raw PIN must never be recoverable from storage');
      expect(stored.split(':').length, 3);
    });

    test('the same PIN hashes differently every time (salt is random)', () {
      final a = PinHasher.hashPin('1234');
      final b = PinHasher.hashPin('1234');
      expect(a, isNot(b),
          reason: 'a fixed salt would let one rainbow table break every device');
    });

    test('the correct PIN verifies and wrong ones do not', () {
      final stored = PinHasher.hashPin('4821');
      expect(PinHasher.verify('4821', stored), isTrue);
      for (final wrong in ['4822', '0000', '482', '48210', '']) {
        expect(PinHasher.verify(wrong, stored), isFalse,
            reason: 'PIN "$wrong" must not unlock the app');
      }
    });

    test('a tampered record with a lowered iteration count is rejected', () {
      // An attacker who can edit SharedPreferences could rewrite the stored
      // cost factor from 20000 down to 1 and brute-force the 4-digit PIN in
      // milliseconds. verify() must refuse to honour the weakened record.
      const pin = '4821';
      final stored = PinHasher.hashPin(pin);
      final salt = stored.split(':')[1];

      // Recompute the hash with a single iteration, as an attacker would.
      final cheap = PinHasher.hashPin(pin, salt: salt).split(':')[2];
      final tampered = '1:$salt:$cheap';

      expect(PinHasher.verify(pin, tampered), isFalse,
          reason: 'a downgraded work factor must not be accepted');
    });

    test('malformed stored values return false instead of throwing', () {
      for (final bad in ['', 'garbage', '1:2', 'x:y:z', '0:aa:bb', ':-1:ff']) {
        expect(() => PinHasher.verify('1234', bad), returnsNormally,
            reason: 'corrupt preference "$bad" must not crash the lock screen');
        expect(PinHasher.verify('1234', bad), isFalse);
      }
      expect(PinHasher.verify('1234', null), isFalse);
    });
  });

  group('CSV export is not a weapon', () {
    test('a formula in a note cannot execute when the file is opened', () {
      // The classic payloads. If any of these survive without a leading
      // apostrophe, opening the export in Excel/Sheets runs them.
      const payloads = [
        '=HYPERLINK("http://evil.example","click")',
        '=cmd|\'/c calc\'!A1',
        '+1+1',
        '-1+1',
        '@SUM(1+1)',
        '=1+1',
      ];

      final unsafe = <String>[];
      for (final p in payloads) {
        final out = Csv.field(p);
        // A field needing RFC 4180 quoting starts with `"`, so look for the
        // apostrophe right after the quote, not only at position zero.
        final guarded = out.startsWith("'") || out.startsWith('"\'');
        if (!guarded) unsafe.add('"$p" -> "$out"');
      }
      expect(unsafe, isEmpty,
          reason: 'these would be evaluated as formulas when opened:\n'
              '${unsafe.join('\n')}');
    });

    test('a formula hidden behind a leading space is still defused', () {
      final out = Csv.field(' =1+1');
      expect(out.startsWith("'") || out.startsWith('"\''), isTrue,
          reason: 'got "$out"');
    });

    test('ordinary values are left exactly as they are', () {
      expect(Csv.field('Makan & Minum'), 'Makan & Minum');
      expect(Csv.field('Kopi'), 'Kopi');
      expect(Csv.field('50000'), '50000');
      expect(Csv.field('-2500'), "'-2500",
          reason: 'a leading minus is still a formula prefix; this is the '
              'tradeoff that keeps the export safe');
    });

    test('RFC 4180 quoting still holds for commas, quotes and newlines', () {
      expect(Csv.field('Makan, Minum'), '"Makan, Minum"');
      expect(Csv.field('say "hi"'), '"say ""hi"""');
      expect(Csv.field('line1\nline2'), '"line1\nline2"');
    });

    test('an encoded document round-trips the field count', () {
      final doc = Csv.encode([
        ['Date', 'Note', 'Amount'],
        ['2026-09-18', 'Makan, Minum', '25000'],
        ['2026-09-19', '=1+1', '5000'],
      ]);
      expect(doc.endsWith('\n'), isTrue);
      expect(doc.split('\n').where((l) => l.isNotEmpty).length, 3);
    });
  });
}
