@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/budget.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:duitku/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
// Alias the sqflite FFI import: it also exports a `Transaction` type, which
// would otherwise collide with the app's own model throughout this file.
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Exercises the repository against a real SQLite file.
///
/// These cover the rules that unit tests on plain objects cannot reach: month
/// boundaries, undo, budget identity, and the recurring catch-up cap.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Formatters.init();
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  });

  setUp(() {
    // AppState reads its preferences through a platform channel, which does
    // not exist in the test runner. An in-memory store keeps it honest.
    SharedPreferences.setMockInitialValues({});
  });

  late Directory tmp;
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('duitku_test');
    db = await AppDatabase.openForTests(p.join(tmp.path, 'test.db'));
    repo = FinanceRepository(db);
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('seed data', () {
    test('a fresh database has wallets and categories ready to use', () async {
      expect((await repo.wallets()).length, 3);
      expect((await repo.categories()).isNotEmpty, isTrue);
      // Both directions must exist or the editor has nothing to show.
      final cats = await repo.categories();
      expect(cats.any((c) => !c.isIncome), isTrue);
      expect(cats.any((c) => c.isIncome), isTrue);
    });
  });

  group('month boundary', () {
    test('a transaction in the final millisecond of a month is included',
        () async {
      final wallets = await repo.wallets();
      final cats = await repo.categories();
      final walletId = wallets.first.id;

      // 31 Aug 2026 23:59:59.999 — the old inclusive-upper-bound query
      // dropped records at this exact instant.
      final edge = DateTime(2026, 8, 31, 23, 59, 59, 999);
      await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 1000,
          categoryId: cats.firstWhere((c) => !c.isIncome).id,
          walletId: walletId,
          date: edge,
        ),
      );

      final august = await repo.transactions(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 9, 1),
      );
      expect(august.length, 1);

      final september = await repo.transactions(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 10, 1),
      );
      expect(september, isEmpty);
    });
  });

  group('wallet balances', () {
    test('income adds, expense subtracts, transfer moves without net loss',
        () async {
      final wallets = await repo.wallets();
      final a = wallets[0].id;
      final b = wallets[1].id;
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      await repo.insertTransaction(
        Transaction(
          type: TxType.income,
          amount: 1000000,
          categoryId: cat,
          walletId: a,
          date: DateTime(2026, 9, 1),
        ),
      );
      await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 250000,
          categoryId: cat,
          walletId: a,
          date: DateTime(2026, 9, 2),
        ),
      );
      await repo.insertTransaction(
        Transaction(
          type: TxType.transfer,
          amount: 300000,
          categoryId: cat,
          walletId: a,
          date: DateTime(2026, 9, 3),
          transferWalletId: b,
        ),
      );

      final balances = await repo.walletBalances();
      // a: 0 + 1,000,000 - 250,000 - 300,000
      expect(balances[a], 450000);
      // b: 0 + 300,000 credited from the transfer
      expect(balances[b], 300000);

      // The transfer must not change the total across wallets.
      final total = balances.values.fold<num>(0, (s, v) => s + v);
      expect(total, 750000);
    });

    test('transfers are excluded from income and expense totals', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 10, 1);

      await repo.insertTransaction(
        Transaction(
          type: TxType.transfer,
          amount: 500000,
          categoryId: cat,
          walletId: wallets[0].id,
          date: DateTime(2026, 9, 5),
          transferWalletId: wallets[1].id,
        ),
      );

      expect(await repo.sumFor(TxType.income, from: from, to: to), 0);
      expect(await repo.sumFor(TxType.expense, from: from, to: to), 0);
    });
  });

  group('budgets', () {
    test('budget identity is (category, month), so re-saving updates', () async {
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;
      const month = '2026-09';

      await repo.insertBudget(
        Budget(categoryId: cat, limitAmount: 500000, monthKey: month),
      );
      await repo.insertBudget(
        Budget(categoryId: cat, limitAmount: 900000, monthKey: month),
      );

      // The UNIQUE constraint must have collapsed these into one row.
      final rows = await repo.budgetsFor(month);
      expect(rows.length, 1);
    });

    test('the same category can hold different caps in different months',
        () async {
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;
      await repo.insertBudget(
        Budget(categoryId: cat, limitAmount: 500000, monthKey: '2026-09'),
      );
      await repo.insertBudget(
        Budget(categoryId: cat, limitAmount: 750000, monthKey: '2026-10'),
      );

      expect((await repo.budgetsFor('2026-09')).single.limitAmount, 500000);
      expect((await repo.budgetsFor('2026-10')).single.limitAmount, 750000);
    });

    test('copying last month keeps existing entries untouched', () async {
      final cats = await repo.categories();
      final a = cats[0].id;
      final b = cats[1].id;

      await repo.insertBudget(
        Budget(categoryId: a, limitAmount: 100000, monthKey: '2026-08'),
      );
      await repo.insertBudget(
        Budget(categoryId: b, limitAmount: 200000, monthKey: '2026-08'),
      );
      // September already has its own cap for `a`; it must not be overwritten.
      await repo.insertBudget(
        Budget(categoryId: a, limitAmount: 999000, monthKey: '2026-09'),
      );

      final copied = await repo.copyBudgetsFrom(
        fromMonth: '2026-08',
        toMonth: '2026-09',
      );
      expect(copied, 1); // only `b` was missing

      final sept = await repo.budgetsFor('2026-09');
      expect(sept.length, 2);
      expect(
        sept.firstWhere((x) => x.categoryId == a).limitAmount,
        999000,
      );
    });
  });

  group('undo', () {
    test('a deleted row can be restored with its original id', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      final id = await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 42000,
          categoryId: cat,
          walletId: wallets.first.id,
          date: DateTime(2026, 9, 10),
        ),
      );

      final fetched = await repo.transactionsById(id);
      expect(fetched.length, 1);

      await repo.deleteTransaction(id);
      expect(await repo.transactionsById(id), isEmpty);

      await repo.restoreTransaction(fetched.first);
      final restored = await repo.transactionsById(id);
      expect(restored.length, 1);
      expect(restored.single.amount, 42000);
    });

    test('restoring twice is a no-op instead of clobbering other rows',
        () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      final id = await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 10000,
          categoryId: cat,
          walletId: wallets.first.id,
          date: DateTime(2026, 9, 11),
        ),
      );
      final row = (await repo.transactionsById(id)).single;

      await repo.deleteTransaction(id);
      await repo.restoreTransaction(row);
      await repo.restoreTransaction(row); // double tap on Undo

      final all = await repo.transactions(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 10, 1),
      );
      expect(all.length, 1);
      expect(all.single.amount, 10000);
    });
  });

  group('recurring rules', () {
    test('catch-up is capped and the schedule still moves forward', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      // A monthly rule that has been dormant for three years.
      await repo.insertRecurring(
        RecurringRule(
          id: 0,
          type: TxType.expense,
          amount: 50000,
          categoryId: cat,
          walletId: wallets.first.id,
          frequency: RecurFreq.monthly,
          nextRunAt: DateTime(2023, 1, 15),
          dayOfMonth: 15,
          note: 'Subscription',
        ),
      );

      final now = DateTime(2026, 9, 17);
      final created = await repo.runDueRecurring(now: now, maxCatchUp: 5);
      expect(created, 5);

      // The rule must now be scheduled in the future, not stuck behind today.
      final rule = (await repo.recurringRules()).single;
      expect(
        rule.nextRunAt.isAfter(now),
        isTrue,
        reason: 'a capped rule left in the past would re-post duplicates',
      );

      // Running again immediately must not create anything new.
      final again = await repo.runDueRecurring(now: now, maxCatchUp: 5);
      expect(again, 0);
    });

    test('a weekly rule lands on the weekday the user chose', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      // 2026-09-17 is a Thursday; ask for Fridays.
      final thursday = DateTime(2026, 9, 17, 9);
      expect(thursday.weekday, DateTime.thursday);

      await repo.insertRecurring(
        RecurringRule(
          id: 0,
          type: TxType.expense,
          amount: 20000,
          categoryId: cat,
          walletId: wallets.first.id,
          frequency: RecurFreq.weekly,
          nextRunAt: thursday,
          weekday: DateTime.friday,
          note: 'Weekly',
        ),
      );

      // One occurrence is due (the Thursday it starts on); the schedule must
      // then move to Friday, not to the following Thursday.
      final created = await repo.runDueRecurring(
        now: DateTime(2026, 9, 24, 23, 59),
      );
      expect(created, greaterThan(0));

      final rule = (await repo.recurringRules()).single;
      expect(rule.nextRunAt.weekday, DateTime.friday);
    });

    test('a weekly rule never advances by zero days', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      // nextRunAt already on the requested weekday: the next step must be a
      // full week later, or the same occurrence would post forever.
      final friday = DateTime(2026, 9, 18, 9);
      expect(friday.weekday, DateTime.friday);

      await repo.insertRecurring(
        RecurringRule(
          id: 0,
          type: TxType.expense,
          amount: 20000,
          categoryId: cat,
          walletId: wallets.first.id,
          frequency: RecurFreq.weekly,
          nextRunAt: friday,
          weekday: DateTime.friday,
        ),
      );

      await repo.runDueRecurring(now: DateTime(2026, 9, 18, 23));
      final rule = (await repo.recurringRules()).single;
      expect(rule.nextRunAt, DateTime(2026, 9, 25, 9));
    });

    test('a monthly rule clamps to the last day of a short month', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      // The 31st must land on 28 Feb, not skip into March.
      await repo.insertRecurring(
        RecurringRule(
          id: 0,
          type: TxType.expense,
          amount: 50000,
          categoryId: cat,
          walletId: wallets.first.id,
          frequency: RecurFreq.monthly,
          nextRunAt: DateTime(2026, 1, 31, 9),
          dayOfMonth: 31,
        ),
      );

      await repo.runDueRecurring(now: DateTime(2026, 1, 31, 23));
      final rule = (await repo.recurringRules()).single;
      expect(rule.nextRunAt, DateTime(2026, 2, 28, 9));
    });

    test('a rule that is not yet due posts nothing', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      await repo.insertRecurring(
        RecurringRule(
          id: 0,
          type: TxType.expense,
          amount: 50000,
          categoryId: cat,
          walletId: wallets.first.id,
          frequency: RecurFreq.monthly,
          nextRunAt: DateTime(2026, 12, 1),
          dayOfMonth: 1,
        ),
      );

      expect(await repo.runDueRecurring(now: DateTime(2026, 9, 17)), 0);
    });
  });

  group('reset', () {
    test('wiping leaves usable defaults, not an empty app', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;

      await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 1000,
          categoryId: cat,
          walletId: wallets.first.id,
          date: DateTime(2026, 9, 1),
        ),
      );
      expect(await repo.countTransactions(), 1);

      await repo.wipe();

      expect(await repo.countTransactions(), 0);
      // Defaults must come back, otherwise the user cannot record anything.
      expect((await repo.wallets()).length, 3);
      expect((await repo.categories()).isNotEmpty, isTrue);
    });

    test('deleting a wallet cascades its transactions away', () async {
      final wallets = await repo.wallets();
      final cat = (await repo.categories()).firstWhere((c) => !c.isIncome).id;
      final walletId = wallets.first.id;

      await repo.insertTransaction(
        Transaction(
          type: TxType.expense,
          amount: 1000,
          categoryId: cat,
          walletId: walletId,
          date: DateTime(2026, 9, 1),
        ),
      );

      await repo.deleteWallet(walletId);
      expect(await repo.countTransactions(), 0);
    });
  });

  group('AppState derived totals', () {
    test('month totals only count the visible month', () async {
      final dir = await Directory.systemTemp.createTemp('duitku_state');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final state = await AppState.bootstrapForTests(
        dbPath: p.join(dir.path, 'state.db'),
      );
      addTearDown(state.dispose);

      final cat = state.categories.firstWhere((c) => !c.isIncome).id;
      final walletId = state.wallets.first.id;

      await state.setMonth(DateTime(2026, 9));
      await state.addTransaction(
        Transaction(
          type: TxType.expense,
          amount: 100000,
          categoryId: cat,
          walletId: walletId,
          date: DateTime(2026, 9, 10),
        ),
      );
      await state.addTransaction(
        Transaction(
          type: TxType.expense,
          amount: 777000,
          categoryId: cat,
          walletId: walletId,
          date: DateTime(2026, 10, 10),
        ),
      );

      expect(state.monthExpense, 100000);
      expect(state.transactions.length, 1);

      await state.setMonth(DateTime(2026, 10));
      expect(state.monthExpense, 777000);
    });

    test('saving a budget onto an existing category updates instead of throwing',
        () async {
      final dir = await Directory.systemTemp.createTemp('duitku_budget');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final state = await AppState.bootstrapForTests(
        dbPath: p.join(dir.path, 'budget.db'),
      );
      addTearDown(state.dispose);

      await state.setMonth(DateTime(2026, 9));
      final catA = state.categories[0].id;
      final catB = state.categories[1].id;

      await state.saveBudget(
        Budget(categoryId: catA, limitAmount: 500000, monthKey: '2026-09'),
      );
      await state.saveBudget(
        Budget(categoryId: catB, limitAmount: 300000, monthKey: '2026-09'),
      );

      // Re-point the second budget at category A, which already has a cap.
      // This used to violate the UNIQUE constraint and throw.
      await state.saveBudget(
        Budget(categoryId: catA, limitAmount: 800000, monthKey: '2026-09'),
      );

      final progress = await state.budgetProgress();
      final forA = progress.where((x) => x.category?.id == catA).toList();
      expect(forA.length, 1, reason: 'must not create a duplicate row');
      expect(forA.single.limit, 800000);
    });
  });
}
