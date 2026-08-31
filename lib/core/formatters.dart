import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'strings.dart';

/// Currency, date and percentage formatting in one place.
///
/// Money is stored as [num] in the wallet's own currency, but the UI renders
/// everything as IDR. Keeping every format behind this class means adding a
/// second currency later is a one-line change here.
///
/// Dates follow the language picked in Settings. The active locale lives in a
/// static so formatters can stay static — call sites are spread across every
/// screen and threading a locale argument through each one would be noise.
class Formatters {
  const Formatters._();

  static bool _localesReady = false;
  static AppLanguage _lang = AppLanguage.indonesian;

  /// The language used by [date], [monthYear] and friends.
  static AppLanguage get language => _lang;

  /// Points date formatting at [lang]. Called by the app whenever the setting
  /// changes, so a switch takes effect without rebuilding cached formatters.
  static void setLanguage(AppLanguage lang) => _lang = lang;

  /// intl throws on any locale-specific format until its data is loaded, so
  /// this must run before the first date is rendered. Called from `main()`
  /// and made idempotent for tests and hot restarts.
  static Future<void> init() async {
    if (_localesReady) return;
    await initializeDateFormatting('id_ID');
    await initializeDateFormatting('en_US');
    _localesReady = true;
  }

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _plain = NumberFormat.decimalPattern('id_ID');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'en_US');

  /// `Rp1.250.000` — the default money rendering.
  static String currency(num value) => _idr.format(value);

  /// Alias kept for call sites that read better as `money`.
  static String money(num value) => currency(value);

  /// `1.250.000` — digits with separators, no symbol. Used by text fields
  /// that render their own `Rp` prefix.
  static String thousands(num value) => _plain.format(value);

  /// Short form for chart labels: `Rp1,2 jt` collapses to `Rp1.2M`.
  static String compact(num value) => 'Rp${_compact.format(value)}';

  static String moneyCompact(num value) => compact(value);

  /// Rupiah rendering, spelled out — used in prose where "Rp1,2 jt" reads
  /// worse than the full number.
  static String currencyLong(num value) => _idr.format(value);

  /// Signed amount for a transaction row.
  static String signed(num value, {required bool isIncome}) {
    final sign = isIncome ? '+' : '-';
    return '$sign${_idr.format(value.abs())}';
  }

  /// Signed form used by day-group headers in the statement view, where a
  /// zero total should read as a dash rather than `Rp0`.
  static String signedCurrency(num value) {
    if (value == 0) return currency(0);
    return '${value > 0 ? '+' : '-'}${currency(value.abs())}';
  }

  static String percent(double ratio) =>
      '${(ratio * 100).toStringAsFixed(ratio >= 0.995 ? 0 : 1)}%';

  /// intl locale matching the active app language.
  static String get _locale => _lang == AppLanguage.english ? 'en_US' : 'id_ID';

  static String date(DateTime d) => DateFormat('d MMM yyyy', _locale).format(d);

  /// `Sen, 12 Sep 2026` — full day label for grouped lists.
  static String longDate(DateTime d) =>
      DateFormat('EEE, d MMM yyyy', _locale).format(d);

  /// `12 Sep` — compact form for chips and tight rows.
  static String dateShort(DateTime d) =>
      DateFormat('d MMM', _locale).format(d);

  /// `September 2026` — month picker header.
  static String monthYear(DateTime d) =>
      DateFormat('MMMM yyyy', _locale).format(d);

  /// `Sep` — axis labels.
  static String monthShort(DateTime d) =>
      DateFormat('MMM', _locale).format(d);

  /// Grouping key for the statement view: one bucket per calendar day.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Whole days between [d] and today, ignoring the time of day.
  ///
  /// Negative when [d] is in the future.
  static int _daysFromToday(DateTime d) {
    final today = DateTime.now();
    final target = DateTime(d.year, d.month, d.day);
    final now = DateTime(today.year, today.month, today.day);
    return now.difference(target).inDays;
  }

  /// Header shown above each day group in the transaction list.
  static String dayHeader(DateTime d) {
    final diff = _daysFromToday(d);
    if (diff == 0) return L.t('Today', _lang);
    if (diff == 1) return L.t('Yesterday', _lang);
    return longDate(d);
  }

  static String dayLabel(DateTime d) {
    final diff = _daysFromToday(d);
    if (diff == 0) return L.t('Today', _lang);
    if (diff == 1) return L.t('Yesterday', _lang);
    if (diff < 7) {
      return _lang == AppLanguage.english ? '$diff days ago' : '$diff hari lalu';
    }
    return date(d);
  }

  /// Weeks/months remaining until [d], used by savings goals.
  static String remainingLabel(DateTime d) {
    final diff = -_daysFromToday(d); // positive when the date is ahead
    if (diff < 0) return L.t('Deadline passed', _lang);
    if (diff == 0) return L.t('Today', _lang);
    if (diff < 30) {
      return _lang == AppLanguage.english
          ? '$diff day${diff == 1 ? '' : 's'} left'
          : '$diff hari lagi';
    }
    final months = (diff / 30).round();
    return _lang == AppLanguage.english
        ? 'about $months month${months == 1 ? '' : 's'}'
        : 'sekitar $months bulan';
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
