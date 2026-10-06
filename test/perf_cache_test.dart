@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// Its `Transaction` would otherwise collide with the app's own model.
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Guards the summary cache and the future-reload keys added during the
/// performance pass.
///
/// The failure mode these catch is silent: every number still *looks* right,
/// it just stops moving when the data underneath changes.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Formatters.init();
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('duitku_perf');
  });

  tearDown(() async {
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<AppState> boot() async {
    final state = await AppState.bootstrapForTests(
      dbPath: p.join(tmp.path, 'perf.db'),
    );
    addTearDown(state.dispose);
    return state;
  }

  Transaction expense(AppState state, num amount, DateTime date) => Transaction(
        type: TxType.expense,
        amount: amount,
        categoryId: state.categories.firstWhere((c) => !c.isIncome).id,
        walletId: state.wallets.first.id,
        date: date,
      );

  Transaction income(AppState state, num amount, DateTime date) => Transaction(
        type: TxType.income,
        amount: amount,
        categoryId: state.categories.firstWhere((c) => c.isIncome).id,
        walletId: state.wallets.first.id,
        date: date,
      );

  group('summary cache', () {
    test('an amount edit is picked up even though the row count does not move',
        () async {
      final state = await boot();
      final now = DateTime.now();

      await state.addTransaction(expense(state, 10000, now));
      expect(state.monthExpense, 10000);
      final rows = state.transactions.length;

      // Retyping an amount: same rows, different money. The old cache key
      // was built from the row count, so charts and budgets kept the stale
      // figure until something else forced a reload.
      final rev = state.dataRevision;
      await state
          .updateTransaction(state.transactions.first.copyWith(amount: 25000));

      expect(state.transactions.length, rows,
          reason: 'the edit must not change how many rows exist');
      expect(state.dataRevision, greaterThan(rev),
          reason: 'every reload must bump the staleness token');
      expect(state.monthExpense, 25000,
          reason: 'cached summaries must follow the edit');
      expect(state.periodNet, -25000);
    });

    test('summaries stay correct when the period mode toggles', () async {
      final state = await boot();
      final now = DateTime.now();

      await state.addTransaction(expense(state, 4000, now));
      await state.addTransaction(income(state, 9000, now));

      expect(state.monthExpense, 4000);
      expect(state.monthIncome, 9000);
      expect(state.monthNet, 5000);

      state.setPeriodMode(PeriodMode.daily);
      expect(state.dailyExpense, 4000);
      expect(state.dailyIncome, 9000);
      expect(state.periodTransactions.length, 2,
          reason: 'daily mode shows only the selected day');

      state.setPeriodMode(PeriodMode.monthly);
      expect(state.periodTransactions, same(state.transactions),
          reason: 'monthly mode is the whole loaded month');
      expect(state.periodNet, 5000);
    });

    test('summaries follow a month switch', () async {
      final state = await boot();
      final now = DateTime.now();

      await state.addTransaction(expense(state, 1000, now));
      await state.setMonth(DateTime(now.year, now.month - 1));
      expect(state.monthExpense, 0,
          reason: 'the previous month must not inherit this month totals');

      await state.addTransaction(
        expense(state, 7000, DateTime(now.year, now.month - 1, 12)),
      );
      expect(state.monthExpense, 7000);
    });

    test('transfers never leak into income or expense totals', () async {
      final state = await boot();
      final now = DateTime.now();

      await state.addTransaction(Transaction(
        type: TxType.transfer,
        amount: 50000,
        categoryId: state.categories.first.id,
        walletId: state.wallets.first.id,
        date: now,
        transferWalletId: state.wallets.last.id,
      ));

      expect(state.monthIncome, 0);
      expect(state.monthExpense, 0);
      expect(state.periodNet, 0);
    });
  });

  group('monthlyTotals', () {
    test('the combined per-month query matches the old two-scan result',
        () async {
      final state = await boot();
      final now = DateTime.now();

      // Three months of data: an expense two months back, income last month,
      // an expense in the visible month.
      await state.addTransaction(
          expense(state, 1000, DateTime(now.year, now.month - 2, 5)));
      await state.addTransaction(
          income(state, 2000, DateTime(now.year, now.month - 1, 7)));
      await state.addTransaction(
          expense(state, 4000, DateTime(now.year, now.month, 9)));

      final totals = await state.monthlyTotals(3);
      expect(totals.length, 3);

      // DateTime normalizes month arithmetic (January minus two is last
      // November), so compare against the same normalized values.
      expect(totals[0].month, DateTime(now.year, now.month - 2));
      expect(totals[0].income, 0);
      expect(totals[0].expense, 1000);

      expect(totals[1].month, DateTime(now.year, now.month - 1));
      expect(totals[1].income, 2000);
      expect(totals[1].expense, 0);

      expect(totals[2].month, DateTime(now.year, now.month));
      expect(totals[2].income, 0);
      expect(totals[2].expense, 4000);
    });

    test('a write shows up on the next read', () async {
      final state = await boot();
      final now = DateTime.now();

      await state.addTransaction(expense(state, 3000, now));
      var totals = await state.monthlyTotals(1);
      expect(totals.single.expense, 3000);

      await state
          .updateTransaction(state.transactions.first.copyWith(amount: 12000));
      totals = await state.monthlyTotals(1);
      expect(totals.single.expense, 12000);
    });
  });
}
