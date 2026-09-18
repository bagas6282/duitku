/// CSV writing that survives real-world text.
///
/// The obvious `row.join(',')` breaks the moment a category is named
/// "Makan, Minum" — Excel then reads the amount as a column and the note as
/// another, silently corrupting the numbers the user exported the file for.
/// RFC 4180 says a field containing a comma, a quote, or a newline must be
/// wrapped in double quotes with inner quotes doubled; that is what this does.
library;

class Csv {
  Csv._();

  /// Wraps [field] in quotes only when it needs them, so ordinary values stay
  /// readable in a plain text editor.
  ///
  /// Also defuses spreadsheet formula injection. A note or category named
  /// `=HYPERLINK("http://evil","click")`, or starting with `+`, `-`, `@` or a
  /// tab/CR, is executed as a formula when the exported file is opened in
  /// Excel, LibreOffice or Sheets — the exporter is how untrusted text gets
  /// into a spreadsheet. A leading apostrophe forces the cell to stay text and
  /// is the fix recommended by OWASP.
  static String field(String value) {
    final safe = _looksLikeFormula(value) ? "'$value" : value;

    final needsQuotes = safe.contains(',') ||
        safe.contains('"') ||
        safe.contains('\n') ||
        safe.contains('\r');

    if (!needsQuotes) return safe;
    return '"${safe.replaceAll('"', '""')}"';
  }

  /// True when a spreadsheet would treat [value] as a formula rather than text.
  ///
  /// The leading whitespace check matters: ` =1+1` is still evaluated by some
  /// spreadsheet versions, so the space cannot simply be skipped.
  static bool _looksLikeFormula(String value) {
    if (value.isEmpty) return false;
    final first = value[0];
    return first == '=' ||
        first == '+' ||
        first == '-' ||
        first == '@' ||
        first == '\t' ||
        first == '\r' ||
        (first == ' ' && value.length > 1 && _looksLikeFormula(value.substring(1)));
  }

  /// Joins [rows] into a document.
  ///
  /// A trailing newline is included because some tools (notably older Excel
  /// and `pandas.read_csv` without `skip_blank_lines=False`) drop the last
  /// record when the file does not end with one.
  static String encode(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(row.map(field).join(','));
    }
    return buffer.toString();
  }
}
