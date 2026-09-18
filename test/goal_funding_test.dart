@Tags(['db'])
library;

import 'dart:io';

import 'package:duitku/core/formatters.dart';
import 'package:duitku/data/app_state.dart';
import 'package:duitku/data/database.dart';
import 'package:duitku/data/models/budget.dart';
import 'package:duitku/data/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Funding a savings goal has two distinct paths — a manual top-up that only
/// touches the goal, and a wallet transfer that also books a transaction. The
/// distinction is the whole feature, so each is asserted separately against a
/// real database rather than a mocked state object.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Formatters.init();
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  });

  late Directory tmp;
  late String dbPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('duitku_funding');
    dbPath = p.join(tmp.path, 'funding.db');
  });

  tearDown(() async {
    AppDatabase.overridePath(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Opens the app, runs [body], closes it as if the user swiped it away.
  Future<T> withApp<T>(Future<T> Function(AppState s) body) async {
    final state = await AppState.bootstrapForTests(dbPath: dbPath);
    try {
      return await body(state);
    } finally {
      await state.dispose();
    }
  }

  /// Adds a goal and returns it.
  ///
  /// A fresh database is already seeded with one demo goal, so `goals.first`
  /// is not the one just added — the id has to be read back. Ordering is
  /// `done ASC, id DESC`, so the demo goal can even sort ahead of it.
  Future<SavingsGoal> seedGoal(AppState s, {num target = 1000000}) async {
    final before = s.goals.map((g) => g.id).toSet();
    await s.addGoal('Dana Darurat', target, null, 0);
    return s.goals.firstWhere((g) => !before.contains(g.id));
  }

  /// The goal under test, refetched so assertions never read a stale copy.
  SavingsGoal goalNamed(AppState s, String name) =>
      s.goals.firstWhere((g) => g.name == name);

  test('a manual top-up raises the goal without creating a transaction',
      () async {
    await withApp((s) async {
      final goal = await seedGoal(s);
      final txBefore = s.transactions.length;
      final balanceBefore = s.totalBalance;

      final added = await s.contributeToGoal(goal.id, 250000);

      expect(added, 250000);
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 250000);
      // The defining property of a manual top-up: no money moved.
      expect(s.transactions, hasLength(txBefore),
          reason: 'a manual top-up must not invent a transaction');
      expect(s.totalBalance, balanceBefore,
          reason: 'a manual top-up must not move any wallet balance');
    });
  });

  test('a wallet top-up books a transaction and moves the balance', () async {
    await withApp((s) async {
      final goal = await seedGoal(s);
      final wallet = s.wallets.first;
      final category = s.categoriesFor(TxType.expense).first;
      final balanceBefore = s.totalBalance;
      final txBefore = s.transactions.length;

      // The Funding sheet credits the goal and books the expense, in that
      // order: the goal can only take its headroom, and the transaction is
      // what the user actually requested.
      final added = await s.contributeToGoal(goal.id, 300000);
      await s.addTransaction(
        Transaction(
          id: 0,
          walletId: wallet.id,
          categoryId: category.id,
          type: TxType.expense,
          amount: 300000,
          note: 'Add funds: Dana Darurat',
          date: DateTime.now(),
        ),
      );

      expect(added, 300000);
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 300000);
      expect(s.transactions, hasLength(txBefore + 1),
          reason: 'the wallet transfer must be booked');
      expect(s.totalBalance, balanceBefore - 300000,
          reason: 'the money really left the wallet');
    });
  });

  test('a contribution is clamped at the target and reports what landed',
      () async {
    await withApp((s) async {
      final goal = await seedGoal(s, target: 500000);

      // Ask for more than the goal can hold.
      final added = await s.contributeToGoal(goal.id, 800000);

      expect(added, 500000, reason: 'only the headroom can be credited');
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 500000);
      expect(goalNamed(s, 'Dana Darurat').done, isTrue,
          reason: 'reaching the target completes the goal');
    });
  });

  test('contributing to a completed goal changes nothing', () async {
    await withApp((s) async {
      final goal = await seedGoal(s, target: 200000);
      await s.contributeToGoal(goal.id, 200000);
      expect(goalNamed(s, 'Dana Darurat').done, isTrue);

      final added = await s.contributeToGoal(goal.id, 100000);

      expect(added, 0);
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 200000,
          reason: 'a finished goal must not keep growing');
    });
  });

  test('a contribution survives a restart', () async {
    await withApp((s) async {
      final goal = await seedGoal(s);
      await s.contributeToGoal(goal.id, 400000);
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 400000);
    });

    // Fresh AppState on the same file: this is the real test.
    await withApp((s) async {
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 400000);
    });
  });

  test('contributing only touches the saved amount, not the goal definition',
      () async {
    await withApp((s) async {
      final goal = await seedGoal(s, target: 750000);

      await s.contributeToGoal(goal.id, 100000);

      final after = goalNamed(s, 'Dana Darurat');
      expect(after.name, 'Dana Darurat');
      expect(after.targetAmount, 750000,
          reason: 'a top-up must not rewrite the goal definition');
      expect(after.id, goal.id);
    });
  });

  test('a zero or negative contribution is rejected', () async {
    await withApp((s) async {
      final goal = await seedGoal(s);

      expect(await s.contributeToGoal(goal.id, 0), 0);
      expect(await s.contributeToGoal(goal.id, -50000), 0);
      expect(goalNamed(s, 'Dana Darurat').savedAmount, 0);
    });
  });

  test('contributing to a goal that does not exist is harmless', () async {
    await withApp((s) async {
      final before = s.goals.map((g) => g.savedAmount).toList();
      final added = await s.contributeToGoal(99999, 100000);
      expect(added, 0);
      // The seeded demo goal must be untouched: an unknown id is not an excuse
      // to credit somebody else's row.
      expect(s.goals.map((g) => g.savedAmount).toList(), before);
    });
  });

  test('two top-ups accumulate rather than replace each other', () async {
    await withApp((s) async {
      final goal = await seedGoal(s, target: 5000000);

      await s.contributeToGoal(goal.id, 150000);
      await s.contributeToGoal(goal.id, 350000);

      expect(goalNamed(s, 'Dana Darurat').savedAmount, 500000);
      expect(goalNamed(s, 'Dana Darurat').done, isFalse);
    });
  });
}
