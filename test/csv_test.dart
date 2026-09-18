import 'package:duitku/core/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Csv.field', () {
    test('leaves ordinary text untouched', () {
      expect(Csv.field('Groceries'), 'Groceries');
      expect(Csv.field(''), '');
      expect(Csv.field('1234.56'), '1234.56');
    });

    test('quotes a field containing a comma', () {
      expect(Csv.field('Makan, Minum'), '"Makan, Minum"');
    });

    test('doubles inner quotes', () {
      expect(Csv.field('Warung "Bu Tini"'), '"Warung ""Bu Tini"""');
    });

    test('quotes a field containing a newline', () {
      expect(Csv.field('line1\nline2'), '"line1\nline2"');
      expect(Csv.field('line1\r\nline2'), '"line1\r\nline2"');
    });
  });

  group('Csv.encode', () {
    test('a comma in a category name does not shift the columns', () {
      final csv = Csv.encode([
        ['Date', 'Type', 'Category', 'Wallet', 'Amount', 'Note'],
        ['17/09/2026', 'expense', 'Makan, Minum', 'Cash', '25000', 'lunch'],
      ]);

      final dataRow = csv.trim().split('\n').last;
      // Six logical fields even though a literal comma appears in the data.
      expect(_splitRespectingQuotes(dataRow).length, 6);
      expect(_splitRespectingQuotes(dataRow)[4], '25000');
    });

    test('every row ends with a newline so no record is dropped', () {
      final csv = Csv.encode([
        ['a', 'b'],
      ]);
      expect(csv.endsWith('\n'), isTrue);
    });

    test('a note with quotes round-trips through the escaping', () {
      final csv = Csv.encode([
        ['note'],
        ['He said "hi", loudly'],
      ]);
      expect(csv, contains('"He said ""hi"", loudly"'));
    });
  });
}

/// Splits a CSV line on commas that are not inside a quoted section.
///
/// Deliberately independent of [Csv] so the test does not simply restate the
/// implementation it is checking.
List<String> _splitRespectingQuotes(String line) {
  final out = <String>[];
  final current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      out.add(current.toString());
      current.clear();
    } else {
      current.write(c);
    }
  }
  out.add(current.toString());
  return out;
}
