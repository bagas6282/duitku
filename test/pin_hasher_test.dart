import 'package:duitku/core/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinHasher', () {
    test('the PIN itself never appears in the stored record', () {
      const pin = '4821';
      final stored = PinHasher.hashPin(pin);

      // The whole point: a leaked preference file must not reveal the code.
      expect(stored.contains(pin), isFalse);
    });

    test('the record carries its own salt and iteration count', () {
      final stored = PinHasher.hashPin('1234');
      final parts = stored.split(':');

      expect(parts.length, 3);
      expect(int.tryParse(parts[0]), greaterThan(0));
      expect(parts[1].length, 32); // 16 random bytes, hex encoded
    });

    test('the same PIN produces a different record every time', () {
      // Distinct salts, so two users with PIN 1111 look nothing alike and one
      // precomputed table cannot unlock every install.
      expect(PinHasher.hashPin('1111'), isNot(equals(PinHasher.hashPin('1111'))));
    });

    test('verification accepts the right PIN and rejects others', () {
      final stored = PinHasher.hashPin('0042');

      expect(PinHasher.verify('0042', stored), isTrue);
      expect(PinHasher.verify('0043', stored), isFalse);
      expect(PinHasher.verify('', stored), isFalse);
      expect(PinHasher.verify('00421', stored), isFalse);
    });

    test('leading zeros are significant', () {
      // Guards against a "parse as int" shortcut sneaking in later.
      final stored = PinHasher.hashPin('0123');
      expect(PinHasher.verify('123', stored), isFalse);
      expect(PinHasher.verify('0123', stored), isTrue);
    });

    test('a malformed or empty record fails closed instead of throwing', () {
      expect(PinHasher.verify('1234', null), isFalse);
      expect(PinHasher.verify('1234', ''), isFalse);
      expect(PinHasher.verify('1234', 'garbage'), isFalse);
      expect(PinHasher.verify('1234', 'notanumber:salt:hash'), isFalse);
      expect(PinHasher.verify('1234', '0:salt:hash'), isFalse);
      expect(PinHasher.verify('1234', '-1:salt:hash'), isFalse);
    });
  });
}
