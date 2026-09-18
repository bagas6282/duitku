@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/core/strings.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/budget.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Drives the Budget feature end to end through AppState against a real
/// SQLite file.
///
/// The Budget tab was reported as unusable, so these tests deliberately avoid
/// mocking: they create the same budgets the editor creates, read them back
/// through the same `budgetProgress()` the tab calls, and assert the numbers
/// the user would see.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Formatters.init();
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  });

  late Directory tmp;
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('duitku_budget');
    state = await AppState.bootstrapForTests(dbPath: p.join(tmp.path, 'b.db'));
  });

  tearDown(() async {
    await state.dispose();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('creating a budget', () {
    test('a budget saved through AppState comes back in budgetProgress', () async {
      final category = state.categoriesFor(TxType.expense).first;

      await state.setBudget(category.id, 750000);

      final progress = await state.budgetProgress();
      expect(progress, hasLength(1));
      expect(progress.single.limit, 750000);
      expect(progress.single.category?.id, category.id);
    });

    test('the first budget on an empty month is reachable', () async {
      // The reported symptom: a user with no caps had nothing to tap. An empty
      // list must still accept a cap.
      expect(await state.budgetProgress(), isEmpty);

      await state.setBudget(state.categoriesFor(TxType.expense).first.id, 100000);

      expect(await state.budgetProgress(), hasLength(1));
    });

    test('setting the same category twice updates instead of throwing', () async {
      // budgets is UNIQUE(category, month): a plain INSERT fails the second time.
      final c = state.categoriesFor(TxType.expense).first;

      await state.setBudget(c.id, 100000);
      await state.setBudget(c.id, 250000);

      final progress = await state.budgetProgress();
      expect(progress, hasLength(1), reason: 'must update in place');
      expect(progress.single.limit, 250000);
    });

    test('a zero or negative limit clears the budget', () async {
      final c = state.categoriesFor(TxType.expense).first;

      await state.setBudget(c.id, 100000);
      await state.setBudget(c.id, 0);

      expect(await state.budgetProgress(), isEmpty);
    });

    test('budgets do not leak between months', () async {
      final c = state.categoriesFor(TxType.expense).first;
      // saveBudget takes the month from the budget itself.
      await state.saveBudget(
        Budget(id: null, categoryId: c.id, limitAmount: 300000, monthKey: '2026-05'),
      );

      // Move the state to a different month, then back.
      final original = state.month;
      await state.setMonth(DateTime(2026, 5, 15));
      expect(await state.budgetProgress(), hasLength(1));
      await state.setMonth(DateTime(2026, 6, 15));
      expect(await state.budgetProgress(), isEmpty);
      await state.setMonth(original);
    });
  });

  group('progress reflects spending', () {
    test('spent and remaining track real transactions', () async {
      final c = state.categoriesFor(TxType.expense).first;
      final wallet = state.wallets.first;

      await state.setBudget(c.id, 500000);
      await state.addTransaction(
        Transaction(
          id: 0,
          amount: 120000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: c.id,
          walletId: wallet.id,
          note: 'groceries',
        ),
      );

      final p = (await state.budgetProgress()).single;
      expect(p.spent, 120000);
      expect(p.remaining, 380000);
      expect(p.ratio, closeTo(0.24, 0.001));
      expect(p.over, isFalse);
    });

    test('income in the same category is not counted as spending', () async {
      final c = state.categoriesFor(TxType.expense).first;
      final wallet = state.wallets.first;

      await state.setBudget(c.id, 500000);
      // An income row pointing at an expense category must not reduce the cap.
      await state.addTransaction(
        Transaction(
          id: 0,
          amount: 90000,
          date: DateTime.now(),
          type: TxType.income,
          categoryId: c.id,
          walletId: wallet.id,
          note: 'refund',
        ),
      );

      expect((await state.budgetProgress()).single.spent, 0);
    });

    test('overspending is flagged rather than hidden', () async {
      final c = state.categoriesFor(TxType.expense).first;
      final wallet = state.wallets.first;

      await state.setBudget(c.id, 50000);
      await state.addTransaction(
        Transaction(
          id: 0,
          amount: 90000,
          date: DateTime.now(),
          type: TxType.expense,
          categoryId: c.id,
          walletId: wallet.id,
          note: 'over',
        ),
      );

      final p = (await state.budgetProgress()).single;
      expect(p.over, isTrue, reason: 'the UI needs this to paint a red bar');
      expect(p.ratio, greaterThan(1));
      expect(Formatters.currency(p.spent), contains('90'));
    });
  });

  group('the tab refreshes after a change', () {
    test('setBudget bumps the revision so the cached future is invalidated', () async {
      // The tab caches `budgetProgress()` keyed on this counter. Without a bump
      // the FutureBuilder keeps the old list and the new cap never appears.
      final before = state.budgetsRevision;

      await state.setBudget(state.categoriesFor(TxType.expense).first.id, 100000);

      expect(state.budgetsRevision, greaterThan(before));
    });

    test('deleting a budget bumps the revision too', () async {
      final c = state.categoriesFor(TxType.expense).first;
      await state.setBudget(c.id, 100000);
      final progress = await state.budgetProgress();
      final before = state.budgetsRevision;

      await state.deleteBudget(progress.single.budget.id!);

      expect(state.budgetsRevision, greaterThan(before));
      expect(await state.budgetProgress(), isEmpty);
    });

    test('copying from the previous month reaches the UI', () async {
      final c = state.categoriesFor(TxType.expense).first;
      await state.setMonth(DateTime(2026, 5, 15));
      await state.setBudget(c.id, 400000);

      await state.setMonth(DateTime(2026, 6, 15));
      expect(await state.budgetProgress(), isEmpty);

      final before = state.budgetsRevision;
      final copied = await state.copyBudgetsFromPreviousMonth();

      expect(copied, greaterThan(0), reason: 'May has one cap to copy');
      expect(state.budgetsRevision, greaterThan(before),
          reason: 'a copy that does not notify leaves the tab empty');
      expect(await state.budgetProgress(), hasLength(1));
      expect((await state.budgetProgress()).single.limit, 400000);
    });
  });

  group('language', () {
    test('the budget tab starts in Indonesian', () {
      expect(state.localeCode, 'id');
      expect(L.t('Budgets', AppLanguage.fromCode(state.localeCode)), 'Anggaran');
    });
  });
}
