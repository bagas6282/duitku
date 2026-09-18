import 'package:duitku/features/receipt/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptParser', () {
    test('extracts Indomaret receipt data accurately', () {
      const indomaretReceipt = '''
INDOMARET RAYA DARMO
PT. INDOMARCO PRISMATAMA
JL. RAYA DARMO NO 45 SURABAYA
NPWP: 01.337.890.1-012.000
18/09/2026 14:23
ROTI TAWAR SARI ROTI    1   16.500
TEH PUCUK HARUM 350ML   2   10.000
ULTRA MILK COKLAT 250ML 1    7.500
HARGA JUAL                  34.000
TOTAL                       34.000
TUNAI                       50.000
KEMBALI                     16.000
TERIMA KASIH
''';

      final result = ReceiptParser.parse(indomaretReceipt);
      expect(result.merchantName, contains('INDOMARET'));
      expect(result.amount, equals(34000));
      expect(result.date, equals(DateTime(2026, 9, 18)));
      expect(result.suggestedCategory, equals('Food & Drink'));
    });

    test('extracts Alfamart receipt with Grand Total and change', () {
      const alfamartReceipt = '''
ALFAMART TEBET TIMUR
PT. SUMBER ALFARIA TRIJAYA TBK
JL. TEBET TIMUR DALAM NO. 12
TANGGAL: 15-08-2026 19:10
INDOMIE GORENG SPESIAL 5  15.000
CHITATO SAPI PANGGANG  1  12.500
SUB TOTAL                 27.500
PPN 11%                    3.025
GRAND TOTAL               30.525
CASH                      50.000
CHANGE                    19.475
''';

      final result = ReceiptParser.parse(alfamartReceipt);
      expect(result.merchantName, contains('ALFAMART'));
      expect(result.amount, equals(30525));
      expect(result.date, equals(DateTime(2026, 8, 15)));
      expect(result.suggestedCategory, equals('Food & Drink'));
    });

    test('extracts Cafe receipt with words and date', () {
      const cafeReceipt = '''
KOPI KENANGAN
MALL KELAPA GADING
12 Mei 2026 10:45
1 KOPI KENANGAN MANTAN L  24.000
1 ROTI COKLAT KLASIK      12.000
TOTAL BAYAR               36.000
QRIS                      36.000
TERIMA KASIH
''';

      final result = ReceiptParser.parse(cafeReceipt);
      expect(result.merchantName, equals('KOPI KENANGAN'));
      expect(result.amount, equals(36000));
      expect(result.date, equals(DateTime(2026, 5, 12)));
      expect(result.suggestedCategory, equals('Food & Drink'));
    });

    test('extracts SPBU Pertamina receipt for transport', () {
      const spbuReceipt = '''
SPBU 34-12345
PERTAMINA PASTEUR
2026-07-20 08:30
PERTAMAX 92
VOLUME : 15.00 L
HARGA/L : 13.700
TOTAL : Rp 205.500
BAYAR : TUNAI
''';

      final result = ReceiptParser.parse(spbuReceipt);
      expect(result.merchantName, contains('SPBU'));
      expect(result.amount, equals(205500));
      expect(result.date, equals(DateTime(2026, 7, 20)));
      expect(result.suggestedCategory, equals('Transport'));
    });

    test('extracts Apotek receipt for health category', () {
      const apotekReceipt = '''
APOTEK KIMIA FARMA
JL. SUDIRMAN KAV 21
05/06/2026
PANADOL EXTRA 1 STRIP    15.500
VITAMIN C IPI            8.000
TOTAL                    23.500
DEBIT BCA                23.500
''';

      final result = ReceiptParser.parse(apotekReceipt);
      expect(result.merchantName, contains('APOTEK'));
      expect(result.amount, equals(23500));
      expect(result.date, equals(DateTime(2026, 6, 5)));
      expect(result.suggestedCategory, equals('Health'));
    });

    test('handles empty or malformed input safely', () {
      final emptyResult = ReceiptParser.parse('');
      expect(emptyResult.amount, isNull);
      expect(emptyResult.merchantName, isNull);
      expect(emptyResult.date, isNull);
      expect(emptyResult.hasData, isFalse);

      final noisyResult = ReceiptParser.parse('Halo apa kabar\nIni bukan struk\n12345');
      expect(noisyResult.hasData, isTrue); // found some candidate
    });
  });
}
