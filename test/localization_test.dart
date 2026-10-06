import 'package:duitku/core/formatters.dart';
import 'package:duitku/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the two promises that make the language picker trustworthy:
/// every visible string has an Indonesian entry, and switching the language
/// changes what the widgets read rather than only what a map contains.
void main() {
  // DateFormat needs the locale data loaded before it can format anything;
  // without this every date assertion throws instead of comparing.
  setUpAll(() async {
    await Formatters.init();
  });

  group('dictionary coverage', () {
    test('every entry is either translated or a genuine look-alike', () {
      // Some words are spelled the same in both languages and that is correct,
      // not a missed translation: brand names, the word "Transfer", and the
      // month abbreviations Indonesia shares with English (Jan, Feb, Mar...).
      const identicalByDesign = {
        'Duitku', 'English', 'MaterialIcons', 'Freelance',
        'Duitku 1.0.0', 'Duitku 1.5.4',
        'Duitku backup', 'Duitku CSV', 'Indonesia', 'Transfer',
        'Jan', 'Feb', 'Mar', 'Apr', 'Jun', 'Jul', 'Sep', 'Nov',
      };
      final suspicious = <String>[];
      L.indonesian.forEach((key, value) {
        if (value == key && !identicalByDesign.contains(key)) {
          suspicious.add(key);
        }
      });
      expect(suspicious, isEmpty,
          reason: 'these are identical in both languages but not listed as '
              'intentional: $suspicious');
    });

    test('no Indonesian value is left empty', () {
      final empty = L.indonesian.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(empty, isEmpty);
    });

    test('seeded wallet and category names are translated', () {
      // These come straight from the database seed; if a name is missing the
      // user sees "Transport" in an otherwise Indonesian screen.
      const seeded = [
        'Cash', 'Bank Account', 'E-Wallet',
        'Food & Drink', 'Transport', 'Tuition', 'Books', 'Entertainment',
        'Health', 'Rent', 'Shopping', 'Other', 'Salary', 'Allowance',
        'Freelance', 'Gift', 'Emergency Fund',
      ];
      for (final name in seeded) {
        expect(L.indonesian.containsKey(name), isTrue,
            reason: 'seed "$name" has no Indonesian translation');
      }
    });
  });

  group('lookup', () {
    test('known keys translate in both languages', () {
      expect(L.t('Budgets', AppLanguage.indonesian), 'Anggaran');
      expect(L.t('Budgets', AppLanguage.english), 'Budgets');
      expect(L.t('Salary', AppLanguage.indonesian), 'Gaji');
    });

    test('unknown keys fall through to the key itself', () {
      // Better to show English than an empty box.
      expect(L.t('Nonexistent Key', AppLanguage.indonesian),
          'Nonexistent Key');
    });

    test('a custom category name the user typed is never rewritten', () {
      // Users may name a category anything; only known defaults translate.
      expect(L.t('Kopi Pagi', AppLanguage.indonesian), 'Kopi Pagi');
    });
  });

  group('formatters follow the language', () {
    test('month abbreviation changes with the language', () {
      // May is a reliable probe: Indonesian "Mei" vs English "May".
      final date = DateTime(2026, 5, 17);
      Formatters.setLanguage(AppLanguage.indonesian);
      expect(Formatters.monthShort(date), 'Mei');
      Formatters.setLanguage(AppLanguage.english);
      expect(Formatters.monthShort(date), 'May');
    });

    test('relative day words are translated, not hardcoded', () {
      final now = DateTime.now();
      Formatters.setLanguage(AppLanguage.indonesian);
      expect(Formatters.dayHeader(now), 'Hari ini');
      final yesterday = now.subtract(const Duration(days: 1));
      expect(Formatters.dayHeader(yesterday), 'Kemarin');

      Formatters.setLanguage(AppLanguage.english);
      expect(Formatters.dayHeader(now), 'Today');
      expect(Formatters.dayHeader(yesterday), 'Yesterday');
    });

    test('relative labels are translated too', () {
      final now = DateTime.now();
      Formatters.setLanguage(AppLanguage.indonesian);
      final idLabel = Formatters.remainingLabel(now);
      Formatters.setLanguage(AppLanguage.english);
      final enLabel = Formatters.remainingLabel(now);
      expect(idLabel, isNot(enLabel));
    });
  });

  group('language codes', () {
    test('codes round-trip', () {
      expect(AppLanguage.fromCode('id'), AppLanguage.indonesian);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
    });

    test('an unknown code falls back to Indonesian', () {
      expect(AppLanguage.fromCode('fr'), AppLanguage.indonesian);
      expect(AppLanguage.fromCode(null), AppLanguage.indonesian);
    });
  });
}
