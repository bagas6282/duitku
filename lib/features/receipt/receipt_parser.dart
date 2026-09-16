/// Parsed information extracted from an Indonesian cash/shopping receipt.
class ReceiptData {
  const ReceiptData({
    this.amount,
    this.date,
    this.merchantName,
    this.suggestedCategory,
    this.rawLines = const [],
  });

  /// The identified bill/grand total amount in Rupiah.
  final int? amount;

  /// The transaction date printed on the receipt, if detected.
  final DateTime? date;

  /// Store or merchant name (e.g. "INDOMARET", "ALFAMART", "KOPI KENANGAN").
  final String? merchantName;

  /// Suggested matching category name from default database categories.
  final String? suggestedCategory;

  /// All recognized lines for debugging or fallback inspection.
  final List<String> rawLines;

  bool get hasData => amount != null || merchantName != null || date != null;
}

/// Robust regex-based parser for Indonesian receipts & invoices.
///
/// Designed to extract merchant names, total amounts, and dates from OCR output
/// produced by Google ML Kit or similar on-device engines.
class ReceiptParser {
  ReceiptParser._();

  static const List<String> _categoryKeywordsFood = [
    'kopi', 'coffee', 'cafe', 'kafe', 'resto', 'restaurant', 'warung', 'makan',
    'bakso', 'mie', 'sate', 'nasi', 'ayam', 'burger', 'pizza', 'kfc', 'mcd',
    'starbucks', 'indomaret', 'alfamart', 'roti', 'bakery', 'kitchen', 'tea',
    'boba', 'chatime', 'haus', 'mixue', 'dapur', 'snack', 'food', 'beverage',
    'kuliner', 'solaria', 'hokben', 'richeese', 'jco', 'breadtalk', 'martabak'
  ];

  static const List<String> _categoryKeywordsTransport = [
    'spbu', 'pertamina', 'shell', 'bp', 'parkir', 'parking', 'tol', 'jasamarga',
    'grab', 'gojek', 'maxim', 'krl', 'kai', 'kereta', 'bensin', 'pertalite',
    'pertamax', 'solar', 'dex', 'stasiun', 'bandara', 'tiket'
  ];

  static const List<String> _categoryKeywordsHealth = [
    'apotek', 'apotik', 'kimia farma', 'k24', 'k-24', 'obat', 'klinik', 'clinic',
    'rs', 'rumah sakit', 'laboratorium', 'guardian', 'watsons', 'century',
    'dokter', 'dental', 'gigi', 'medika'
  ];

  static const List<String> _categoryKeywordsShopping = [
    'supermarket', 'hypermart', 'superindo', 'transmart', 'uniqlo', 'zara',
    'h&m', 'miniso', 'toko', 'mall', 'shopee', 'tokopedia', 'fashion',
    'distro', 'dept store', 'matahari', 'ramayana', 'ace hardware', 'mr diy'
  ];

  static const List<String> _categoryKeywordsBooks = [
    'gramedia', 'buku', 'book', 'fotocopy', 'fotokopi', 'stationery', 'atk',
    'paper', 'print', 'percetakan', 'togamas'
  ];

  static const List<String> _categoryKeywordsEntertainment = [
    'cinema', 'xxi', 'cgv', 'cinepolis', 'bioskop', 'timezone', 'funworld',
    'game', 'steam', 'playstation', 'karaoke', 'billiard', 'wisata'
  ];

  /// Parses raw text extracted by OCR into [ReceiptData].
  static ReceiptData parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ReceiptData();
    }

    final rawLines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (rawLines.isEmpty) {
      return const ReceiptData();
    }

    final merchant = _extractMerchant(rawLines);
    final amount = _extractAmount(rawLines);
    final date = _extractDate(rawLines);
    final suggestedCategory = _suggestCategory(merchant, rawLines);

    return ReceiptData(
      amount: amount,
      date: date,
      merchantName: merchant,
      suggestedCategory: suggestedCategory,
      rawLines: rawLines,
    );
  }

  /// Extracts the merchant name from the header lines of the receipt.
  static String? _extractMerchant(List<String> lines) {
    // Noise patterns commonly found at the top of receipts
    final noise = RegExp(
      r'^(struk|bukti|nota|invoice|faktur|bon|selamat datang|terima kasih|'
      r'npwp|telp|tlp|phone|jalan|jl\.|jl |kav|alamat|no\.|trx|kasir|cashier|'
      r'pos|tanggal|date|waktu|time|order|meja|table|http|www|\d+)',
      caseSensitive: false,
    );

    // Look within the first 5 lines
    final candidates = lines.take(5);
    for (final line in candidates) {
      final clean = line.trim();
      if (clean.length < 3) continue;
      // Skip if it starts with obvious noise
      if (noise.hasMatch(clean)) continue;
      // Must have at least 3 alphabetic letters to be a store name
      final letterCount = clean.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      if (letterCount < 3) continue;

      // Clean up common receipt header symbols
      final formatted = clean
          .replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9\.\s]+$'), '')
          .trim();
      if (formatted.length >= 3) {
        return formatted;
      }
    }
    return null;
  }

  /// Extracts the total transaction amount.
  static int? _extractAmount(List<String> lines) {
    // 1. Look for explicit total patterns: TOTAL, GRAND TOTAL, TOTAL AKHIR, TAGIHAN, JUMLAH
    // Avoid cash/paid (TUNAI, CASH, BAYAR, DIBAYAR) and change (KEMBALI, KEMBALIAN, CHANGE).
    final totalHeaderPattern = RegExp(
      r'(grand\s*total|total\s*akhir|total\s*belanja|total\s*bayar|total\s*transaksi|tagihan|total|jumlah)',
      caseSensitive: false,
    );
    final paymentExcludePattern = RegExp(
      r'(tunai|cash|kembali|kembalian|change|dibayar|bayar\s*tunai|kembalian\s*tunai)',
      caseSensitive: false,
    );

    int? candidateTotal;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // If line contains exclusion (e.g. "KEMBALI : Rp 50.000"), skip it
      if (paymentExcludePattern.hasMatch(line) && !line.toLowerCase().contains('total')) {
        continue;
      }

      if (totalHeaderPattern.hasMatch(line)) {
        // Try to find amount on the same line
        final amountInLine = _findNumberInText(line);
        if (amountInLine != null && amountInLine > 0) {
          candidateTotal = amountInLine;
          // Grand total or Total Akhir takes highest priority
          if (line.toLowerCase().contains('grand') ||
              line.toLowerCase().contains('akhir')) {
            return candidateTotal;
          }
        } else if (i + 1 < lines.length) {
          // Sometimes total label is on one line and value is on the next line
          final nextLine = lines[i + 1];
          if (!totalHeaderPattern.hasMatch(nextLine) &&
              !paymentExcludePattern.hasMatch(nextLine)) {
            final nextAmount = _findNumberInText(nextLine);
            if (nextAmount != null && nextAmount > 0) {
              candidateTotal = nextAmount;
              if (line.toLowerCase().contains('grand') ||
                  line.toLowerCase().contains('akhir')) {
                return candidateTotal;
              }
            }
          }
        }
      }
    }

    if (candidateTotal != null) {
      return candidateTotal;
    }

    // 2. Fallback: Search from the bottom upwards for currency patterns "Rp xx.xxx"
    for (final line in lines.reversed) {
      if (paymentExcludePattern.hasMatch(line)) continue;
      if (line.toLowerCase().contains('rp')) {
        final val = _findNumberInText(line);
        if (val != null && val >= 1000) {
          return val;
        }
      }
    }

    // 3. Fallback: Search all parsed numbers and find highest reasonable number
    final allNumbers = <int>[];
    for (final line in lines) {
      if (paymentExcludePattern.hasMatch(line)) continue;
      final val = _findNumberInText(line);
      if (val != null && val >= 1000 && val <= 100000000) {
        allNumbers.add(val);
      }
    }

    if (allNumbers.isNotEmpty) {
      allNumbers.sort();
      return allNumbers.last;
    }

    return null;
  }

  /// Cleans and extracts a numeric integer amount from text.
  static int? _findNumberInText(String text) {
    // Normalise OCR common misrecognitions in price strings:
    // Replace 'O' or 'o' with '0' inside number strings
    var s = text;

    // Pattern matching currency amounts like:
    // 50.000, 50,000, 1.250.000, 15000, Rp 75.000,00, Rp. 100.000
    final regex = RegExp(r'(?:rp\.?\s*)?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]{4,10})', caseSensitive: false);
    final matches = regex.allMatches(s).toList();

    if (matches.isEmpty) return null;

    int? bestNumber;

    for (final m in matches.reversed) {
      var numStr = m.group(1);
      if (numStr == null) continue;

      // Check if ends with cents/sen: e.g. .00 or ,00
      if (numStr.length >= 4 && (numStr.endsWith(',00') || numStr.endsWith('.00'))) {
        numStr = numStr.substring(0, numStr.length - 3);
      }

      // Strip dots and commas
      final digitsOnly = numStr.replaceAll(RegExp(r'[.,]'), '');
      final parsed = int.tryParse(digitsOnly);
      if (parsed != null && parsed > 0) {
        // Prefer numbers >= 500 (realistic IDR transaction amount)
        if (parsed >= 500) {
          return parsed;
        }
        bestNumber ??= parsed;
      }
    }

    return bestNumber;
  }

  /// Extracts date from receipt text lines.
  static DateTime? _extractDate(List<String> lines) {
    final now = DateTime.now();

    // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final dmyPattern = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])[-/.](0?[1-9]|1[012])[-/.](20\d\d|\d\d)\b',
    );

    // YYYY-MM-DD or YYYY/MM/DD
    final ymdPattern = RegExp(
      r'\b(20\d\d)[-/.](0?[1-9]|1[012])[-/.](0?[1-9]|[12][0-9]|3[01])\b',
    );

    // DD Month YYYY (Indonesian or English)
    final textMonthPattern = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])\s+(jan|feb|mar|apr|mei|may|jun|jul|agu|ags|aug|sep|okt|oct|nov|des|dec)[a-z]*\s+(20\d\d|\d\d)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      // Check DD Month YYYY
      final textMatch = textMonthPattern.firstMatch(line);
      if (textMatch != null) {
        final day = int.tryParse(textMatch.group(1)!);
        final monthStr = textMatch.group(2)!.toLowerCase();
        var year = int.tryParse(textMatch.group(3)!);
        if (year != null && year < 100) year += 2000;

        final month = _monthStringToNumber(monthStr);
        if (day != null && month != null && year != null) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }

      // Check DD/MM/YYYY
      final dmyMatch = dmyPattern.firstMatch(line);
      if (dmyMatch != null) {
        final day = int.tryParse(dmyMatch.group(1)!);
        final month = int.tryParse(dmyMatch.group(2)!);
        var year = int.tryParse(dmyMatch.group(3)!);
        if (year != null && year < 100) year += 2000;

        if (day != null && month != null && year != null) {
          try {
            // Basic sanity check: year within +/- 5 years from now
            if ((year - now.year).abs() <= 5) {
              return DateTime(year, month, day);
            }
          } catch (_) {}
        }
      }

      // Check YYYY-MM-DD
      final ymdMatch = ymdPattern.firstMatch(line);
      if (ymdMatch != null) {
        final year = int.tryParse(ymdMatch.group(1)!);
        final month = int.tryParse(ymdMatch.group(2)!);
        final day = int.tryParse(ymdMatch.group(3)!);
        if (day != null && month != null && year != null) {
          try {
            if ((year - now.year).abs() <= 5) {
              return DateTime(year, month, day);
            }
          } catch (_) {}
        }
      }
    }

    return null;
  }

  static int? _monthStringToNumber(String m) {
    if (m.startsWith('jan')) return 1;
    if (m.startsWith('feb')) return 2;
    if (m.startsWith('mar')) return 3;
    if (m.startsWith('apr')) return 4;
    if (m.startsWith('mei') || m.startsWith('may')) return 5;
    if (m.startsWith('jun')) return 6;
    if (m.startsWith('jul')) return 7;
    if (m.startsWith('agu') || m.startsWith('ags') || m.startsWith('aug')) return 8;
    if (m.startsWith('sep')) return 9;
    if (m.startsWith('okt') || m.startsWith('oct')) return 10;
    if (m.startsWith('nov')) return 11;
    if (m.startsWith('des') || m.startsWith('dec')) return 12;
    return null;
  }

  /// Suggests a category name based on merchant and line items in the receipt.
  static String? _suggestCategory(String? merchant, List<String> lines) {
    final fullText = '${merchant ?? ''} ${lines.join(' ')}'.toLowerCase();

    for (final kw in _categoryKeywordsFood) {
      if (fullText.contains(kw)) return 'Food & Drink';
    }
    for (final kw in _categoryKeywordsTransport) {
      if (fullText.contains(kw)) return 'Transport';
    }
    for (final kw in _categoryKeywordsHealth) {
      if (fullText.contains(kw)) return 'Health';
    }
    for (final kw in _categoryKeywordsShopping) {
      if (fullText.contains(kw)) return 'Shopping';
    }
    for (final kw in _categoryKeywordsBooks) {
      if (fullText.contains(kw)) return 'Books';
    }
    for (final kw in _categoryKeywordsEntertainment) {
      if (fullText.contains(kw)) return 'Entertainment';
    }

    return null;
  }
}
